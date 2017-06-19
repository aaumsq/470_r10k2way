//when we mispredict, it means everything in the instruction buffer is wrong and will be flushed
//therefore, if br_pred_wrong is set, we should not dispatch anything. this is taken care by 
//the if_id_haz module (if br_pred_wrong, nDispatch = 0)
`define ROB_DEBUG
module ROB(
    input logic             clk,
    input logic             reset,
    
    input logic [1:0]       halt,
    input logic [1:0]       noop,
    input logic [1:0]       is_store,
        //inputs from free list
    input PHYS_REG [1:0]    fl_freeRegs,
        //inputs from map table
    input PHYS_REG [1:0]    mt_dispatchTagOld,
        //inputs from cdb
    input PHYS_REG [1:0]    cdb_rd,                 
    input logic[1:0]        cdb_rd_en,
        //inputs from if_id_hazard
    input logic[1:0]        haz_nDispatched,
        //inputs from branch functional unit
    input logic             br_pred_wrong,            // if prediction is wrong
        //inputs from branch stack
    input ROB_PTR           bs_recov_rob_tail,

            //outputs to if_id_hazard
    output logic[5:0]       rob_availableSlots,
            //retire outputs
    output logic[1:0]       rob_nRetired,    //the number of instructions to being retired THIS CYCLE
    output logic [1:0]	    rob_nRetireStores,    
            //outputs to arch map
    output PHYS_REG [1:0]   rob_retireTag,    //retire tag for THIS CYCLE, will be updated into arch_table at next posedge
            //outputs to free list
    output PHYS_REG [1:0]   rob_retireTagOld,  //retire tagOld for THIS CYCLE, will be updated into freelist at next posedge
            //output to branch stack
    output ROB_PTR          rob_tail,
    output logic            rob_halted

    `ifdef ROB_DEBUG
      , output ROBEntry_t[31:0] buffer
      , output ROB_PTR          head
      , output logic[1:0]       prev_nRetired
      , output PHYS_REG [1:0]   rob_prev_retireTag
      , output PHYS_REG [1:0]   rob_prev_retireTagOld
    `endif
  );

  `ifndef ROB_DEBUG
    ROBEntry_t[31:0] buffer;
    ROB_PTR head;
  `endif
  ROB_PTR nextHead, nextTail;
  ROB_PTR[1:0] dispatchPtr;
  ROB_PTR head_plus1_ptr;
  logic[5:0] nextAvailableSlots;
  logic[5:0] recovAvailableSlots;
  ROBEntry_t[31:0] nextBuffer;
  logic nextHalted;

  //recov logic
  //note: we will never recover to empty ROB (at least the branch will be in ROB)
  //so, if tail is before head, it must be full!
  assign recovAvailableSlots = (nextHead > bs_recov_rob_tail) ? 
                               (nextHead - bs_recov_rob_tail - 1) : 
                               (32 - (bs_recov_rob_tail - nextHead + 1));

  //Dispatch logic
  assign nextAvailableSlots = rob_availableSlots - haz_nDispatched + rob_nRetired;
  assign nextTail = rob_tail + haz_nDispatched;
  assign nextHead = head + rob_nRetired;
  assign dispatchPtr[0] = rob_tail + 1;
  assign dispatchPtr[1] = rob_tail + 2;
  
  //Retire logic
  assign head_plus1_ptr = head + 1;
  assign rob_retireTag[0] = buffer[head].tag;
  assign rob_retireTag[1] = buffer[head_plus1_ptr].tag;
  assign rob_retireTagOld[0] = buffer[head].tagOld;
  assign rob_retireTagOld[1] = buffer[head_plus1_ptr].tagOld;
  assign nextHalted = rob_halted || ((rob_nRetired >= 1) && buffer[head].halt) ||
                                    ((rob_nRetired >= 2) && buffer[head_plus1_ptr].halt);

  always_comb begin
    nextBuffer = buffer;
        
    //Retire logic
    if(buffer[head].complete && (rob_availableSlots <= 6'd31)) begin
      if(buffer[head_plus1_ptr].complete && (rob_availableSlots <= 6'd30) && !buffer[head].halt) begin
        rob_nRetired = 2;
        if(buffer[head].is_store) begin
          if(buffer[head_plus1_ptr].is_store) begin
            rob_nRetireStores = 2;
          end else begin
            rob_nRetireStores = 1;
          end
        end else begin
          if(buffer[head_plus1_ptr].is_store) begin
            rob_nRetireStores = 1;
          end else begin
            rob_nRetireStores = 0;
          end        
        end
      end else begin
        if(buffer[head].is_store) begin
          rob_nRetireStores = 1;
        end else begin
          rob_nRetireStores = 0;
        end
        rob_nRetired = 1;
      end
    end else begin
      rob_nRetireStores = 0;
      rob_nRetired = 0;
    end
  
    //Complete CAM logic
    for(int i = 0; i < 32; i++) begin
      if((cdb_rd_en[0] && (cdb_rd[0] == buffer[i].tag)) ||
          (cdb_rd_en[1] && (cdb_rd[1] == buffer[i].tag))) begin
        nextBuffer[i].complete = 1;
      end
    end
    
    //Dispatch logic
    if (haz_nDispatched[1]) begin
      //$display("halt[1]: %d", halt[1]);
      nextBuffer[dispatchPtr[1]].halt = halt[1];
      nextBuffer[dispatchPtr[1]].is_store = is_store[1];
      // nextBuffer[dispatchPtr[1]].valid = 1;
      nextBuffer[dispatchPtr[1]].tag = fl_freeRegs[1];
      nextBuffer[dispatchPtr[1]].tagOld = mt_dispatchTagOld[1];
      nextBuffer[dispatchPtr[1]].complete = halt[1] || noop[1];
    end 
    if (haz_nDispatched[0]||haz_nDispatched[1]) begin
      //$display("halt[0]: %d", halt[0]);
      nextBuffer[dispatchPtr[0]].halt = halt[0];
      nextBuffer[dispatchPtr[0]].is_store = is_store[0];
      // nextBuffer[dispatchPtr[0]].valid = 1;
      nextBuffer[dispatchPtr[0]].tag = fl_freeRegs[0];
      nextBuffer[dispatchPtr[0]].tagOld = mt_dispatchTagOld[0];
      nextBuffer[dispatchPtr[0]].complete = halt[0] || noop[0];
    end
    
  end // always_comb
  
  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      head <= `SD 0;
      rob_tail <= `SD 5'd31;
      // for (int i = 0; i < 32; i++) begin
      //   buffer[i].valid <= `SD 0;
      // end
      rob_availableSlots <= `SD 6'd32;
      rob_halted <= `SD 0;
      `ifdef ROB_DEBUG
         prev_nRetired <= `SD 0;
      `endif
    end else begin
      //Retire
      head <= `SD nextHead;
      
      `ifdef ROB_DEBUG
        prev_nRetired <= `SD rob_nRetired;
        rob_prev_retireTag <= `SD rob_retireTag;
        rob_prev_retireTagOld <= `SD rob_retireTagOld;
      `endif
      
      buffer <= `SD nextBuffer;      
      
      if(br_pred_wrong) begin
        //prediction recovery
        rob_tail <= `SD bs_recov_rob_tail;
        rob_availableSlots <= `SD recovAvailableSlots;
      end else begin
        rob_tail <= `SD nextTail;
        rob_availableSlots <= `SD nextAvailableSlots;
      end
      
      rob_halted <= `SD nextHalted;
    end
  end // always_ff
endmodule // module ROB

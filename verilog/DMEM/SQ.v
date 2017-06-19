`define SQ_DEBUG
module SQ(
    input logic             clk,
    input logic             reset,

    // From InstrBuffer
    input logic [1:0]    ib_store_en,
    // From RS
    input logic [1:0]    st_en,
    input logic [1:0]   ld_en,
    input SQ_PTR [1:0]  fus_SQIndex,
    // From ROB
    input logic [1:0]    rob_nRetireStores,
    // From alu
    input DATA  [1:0]    alu_data,
    input ADDR  [1:0]    alu_addr,
    // From LD fu
    input ADDR  [1:0]   ld_addr,

    //inputs from branch functional unit
    input logic         br_pred_wrong,
    //inputs from branch stack
    input SQ_PTR        bs_recov_sq_tail,
    input logic         bs_recov_sq_empty,

    input logic         dcachectrl_st_request_sent,
  
    // Output
    // To InstrBuffer
    output logic [1:0]  sq_nAvailable,
    // To D$
    output DATA           sq_mem_data,
    output logic         sq_mem_en,
    output ADDR         sq_mem_addr,
    // To BS
    output SQ_PTR        sq_tail, 
    output logic        sq_empty,
    // To RS
    output SQ_PTR[1:0]  sq_index,
    output logic[1:0]   sq_index_empty,
    output SQ_PTR       sq_ea_ptr,
    output logic        sq_ea_empty,
    output SQ_PTR       sq_trueHead,
    
    output logic[1:0]   sq_ld_match,
    output DATA[1:0]    sq_ld_data
    
    `ifdef SQ_DEBUG
      , output SQEntry_t[7:0]  queue
      , output SQ_PTR          retireHead
      , output logic[3:0]      slotsOpen
      , output logic[7:0]      ea_calcd
      , output logic[7:0]      shifted_ea_calcd
    `endif
  );

  `ifndef SQ_DEBUG
    SQEntry_t[7:0] queue;
    SQ_PTR retireHead;
    logic[3:0] slotsOpen;
    logic[7:0] ea_calcd;
    logic[7:0] shifted_ea_calcd;
  `endif

  SQ_PTR nextRetireHead, nextTail;
  SQ_PTR nextTrueHead;
  SQEntry_t[7:0] nextQueue;
  SQ_PTR rhead_plus1;
  logic nextEmpty;
  
  logic[7:0] next_ea_calcd;
  SQ_PTR tailsum;
  SQ_PTR halfTailsum;

  genvar i;
  generate
    for(i = 0; i < 8; i++) begin
      assign shifted_ea_calcd[i] = ea_calcd[(sq_trueHead+i)&4'b0111];
    end
  endgenerate

  
  always_comb begin
    sq_ea_ptr = sq_trueHead;
    sq_ea_empty = 1;
    for(int i = 0; i < 8; i++) begin
      if(shifted_ea_calcd[i]) begin
        sq_ea_empty = 0;
        sq_ea_ptr = sq_trueHead + i;
      end else begin
        break;
      end
    end
  end  
  
  /*assign sq_ea_empty = !ea_calcd[0] && !ea_calcd[1] && !ea_calcd[2] && !ea_calcd[3] 
                    && !ea_calcd[4] && !ea_calcd[5] && !ea_calcd[6] && !ea_calcd[7];*/

  
  // nothing is dispatched on branch mispredict recovery
  assign halfTailsum = sq_tail + (sq_empty? 0 : ib_store_en[0]);
  assign tailsum = sq_empty && (!ib_store_en[0])? halfTailsum : halfTailsum + ib_store_en[1];
  
  
                                   
  assign rhead_plus1 = retireHead + 1;
  
  assign sq_index[0] = halfTailsum;
  assign sq_index[1] = tailsum;
  
  assign sq_index_empty[0] = sq_empty && !ib_store_en[0];
  assign sq_index_empty[1] = sq_empty && !ib_store_en[0] && !ib_store_en[1];
  
  assign sq_nAvailable = slotsOpen > 2? 2 : slotsOpen;

  assign slotsOpen = sq_empty? 8: 7-((sq_tail - sq_trueHead) & 3'b111);

  always_comb begin
    nextQueue = queue;
    nextTail = tailsum;
    next_ea_calcd = ea_calcd;
      
    sq_mem_en = 0;
    sq_mem_addr = 0;
    sq_mem_data = 0;

    
    nextTrueHead = sq_trueHead;
    nextRetireHead = retireHead;
    nextEmpty = sq_empty;
    
       
    if(ib_store_en[0]) begin
      nextQueue[sq_index[0]].retired = 0;
      nextQueue[sq_index[0]].addr = 0;
      nextQueue[sq_index[0]].data = 0;
      next_ea_calcd[sq_index[0]] = 0;
    end
    if(ib_store_en[1]) begin
      nextQueue[sq_index[1]].retired = 0;
      nextQueue[sq_index[1]].addr = 0;
      nextQueue[sq_index[1]].data = 0;
      next_ea_calcd[sq_index[1]] = 0;
    end
  
    if(ib_store_en[0] || ib_store_en[1]) begin
      nextEmpty = 0;
    end    
  
    // Execute
    for (int i = 0; i < 2; i++) begin
      if(st_en[i]) begin
        nextQueue[fus_SQIndex[i]].data = alu_data[i];
        nextQueue[fus_SQIndex[i]].addr = alu_addr[i];
        next_ea_calcd[fus_SQIndex[i]] = 1;
      end
    end
  
    for(int i = 0; i < 2; i++) begin
      sq_ld_match[i] = 0;
      sq_ld_data[i] = 0;
      for(int j = 0; j < 8; j++) begin
        if(ld_en[i] && (j <= ((fus_SQIndex[i]-sq_trueHead)&3'b111)) && !sq_empty) begin
          if(queue[(j+sq_trueHead)&3'b111].addr == ld_addr[i]) begin
            //$display("sq ld cam hit j=%0d", j);
            sq_ld_match[i] = 1;
       			//$display("sq_ld_match[%0d]=%0d", i, sq_ld_match[i]);
            //$display("fus_SQIndex[%0d]=%0d", i, fus_SQIndex[i]);
            sq_ld_data[i] = queue[(j+sq_trueHead)&3'b111].data;
         //XXX   break;
          end/* else begin
            $display("sq ld cam not hit j=%0d", j);
          end*/
        end
      end
    end
    
    // Retire
    //$display("rob_nRetireStores: %0d, nextTail: %0d", rob_nRetireStores, nextTail);
    if (rob_nRetireStores == 2) begin
      //$display("4");
      nextQueue[retireHead].retired = 1;
      nextQueue[rhead_plus1].retired = 1;
      nextRetireHead = retireHead + 2;
    end else if (rob_nRetireStores == 1) begin
       //$display("7");
      nextQueue[retireHead].retired = 1;
      nextRetireHead = retireHead + 1;
    end
    
    //$monitor("sq_trueHead: %d, retired: %d\n", sq_trueHead, nextQueue[sq_trueHead].retired);
    if(nextQueue[sq_trueHead].retired) begin
      sq_mem_en = 1;
      sq_mem_addr = nextQueue[sq_trueHead].addr;
      sq_mem_data = nextQueue[sq_trueHead].data;
      if(dcachectrl_st_request_sent) begin
        //$display("STQ SENT");
        nextQueue[sq_trueHead].retired = 0;
        nextTrueHead = sq_trueHead + 1;
        if(sq_trueHead == nextTail) begin
          nextTail = nextTrueHead;
          nextEmpty = 1;
        end
      end
    end    
        
    
    if(br_pred_wrong) begin
      //must use nextEmpty on right side because when true head change above, nextEmpty is changed   
      nextEmpty = (bs_recov_sq_empty || nextEmpty);
      nextTail = bs_recov_sq_tail;
      //$display("sq_tail: %0d, bs_recov_sq_tail: %0d, retireHead: %0d, trueHead: %0d, recov_tail+1: %0d, bs_recov_sq_empty: %0d",
      // sq_tail, bs_recov_sq_tail, retireHead, sq_trueHead, (bs_recov_sq_tail+1)&4'b0111, bs_recov_sq_empty);
      if(((bs_recov_sq_tail+1)&4'b0111) == nextTrueHead) begin
        //$display("3");
        nextTail = nextTrueHead;
        nextEmpty = 1;
      end
    end

    if(((nextRetireHead+1)&3'b111) == nextTrueHead) begin
      nextRetireHead = nextTrueHead;
    end

  end
  
  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      for(int i = 0; i < 8; i++) begin
        ea_calcd[i]      <= `SD 1'b0;
        queue[i].addr    <= `SD 13'b0;
        queue[i].data    <= `SD 64'b0;
        queue[i].retired <= `SD 0;
      end
      retireHead  <= `SD 0;
      sq_trueHead <= `SD 0;
      sq_tail     <= `SD 0;
      sq_empty    <= `SD 1;
    end else begin
      queue       <= `SD nextQueue;
      ea_calcd    <= `SD next_ea_calcd;
      retireHead  <= `SD nextRetireHead;
      sq_trueHead <= `SD nextTrueHead;
      sq_tail     <= `SD nextTail;
      sq_empty    <= `SD nextEmpty;
    end
  end
endmodule

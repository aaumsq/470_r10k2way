//NOTE: this buffer is slightly different than the others. we use tail to point to the entry that wll be 
//      filled next instead of the last valid entry
//NOTE: this buffer is similar to the (first) map table, we only can fill up an entry one cycle after it is cleared (cannot fill immediately)

`define IB_DEBUG

module InstrBuffer(
    input logic               clk,
    input logic               reset,
    // input from br_fub (execution)
    input logic               br_pred_wrong,
    // input from BP
    input logic [1:0]         bp_pred_taken,
    input PC    [1:0]         bp_pred_NPC,
    input PC    [1:0]         bp_not_taken_NPC,
    // From IF stage
    input INSTRUCTION [1:0]   if_inst_in,
    input logic [1:0]         if_valid_in,
    input FD_control_t [1:0]  fd_control,
    // From hazard detection
    input logic [1:0]         haz_nDispatched,
    // From branch stack
    input logic[2:0] bs_nEntries,
    input logic [1:0]	sq_nAvailable,
    
    //output to dispatch
    output IBEntry_t [1:0]     ib_data,
    output logic [1:0]         ib_valid,
    output logic [1:0]         ib_nIsnBuffer,  //number of filled entries (0-2), can dispatch out of buffer
    //output to fetch
    output logic[1:0]          ib_nAvai,       //number of empty entries (0-2), can fill from if_stage
    output logic [1:0]	       ib_store_en

    //debug outputs
    `ifdef IB_DEBUG
      , output logic[3:0] numIns_buffer 
      , output IBEntry_t [7:0] buffer
      , output IB_PTR head
      , output IB_PTR tail
    `endif
  );


  IB_PTR headplus1;
  IB_PTR tailplus1;

  IBEntry_t [7:0] nextBuffer;  
  logic[3:0] nextnumIns_buffer;
  logic[1:0] branchLimit;
  logic[1:0] storeLimit;
  logic[1:0] harderLimit;
  logic[1:0] nFill;


  `ifndef IB_DEBUG
    logic[3:0] numIns_buffer;  // this is the actual number of filled entries (0-8)
    IBEntry_t [7:0] buffer;
    IB_PTR head, tail;
  `endif


  assign headplus1 = head + 1;
  assign tailplus1 = tail + 1;

  //comb output to fetch
  always_comb begin
    //find available entries
    if (numIns_buffer == 4'b1000) begin
      ib_nAvai = 2'b00;
    end else if (numIns_buffer == 4'b111) begin
      ib_nAvai = 2'b01;
    end else begin
      ib_nAvai = 2'b10;
    end
  end


  always_comb begin
    //corner cases for branches
    branchLimit = 2'b00;      //this may be required for synthesis to work (optimization will remove it if not needed)
    if (bs_nEntries == 4) begin
      if(buffer[head].fd_control.branch) begin
        branchLimit = 2'b00;
      end else if (buffer[headplus1].fd_control.branch) begin
        branchLimit = 2'b01;
      end else begin
        branchLimit = 2'b10;
      end
    end else begin
      if(buffer[head].fd_control.branch) begin
        branchLimit = 2'b01;
      end else begin
        branchLimit = 2'b10;
      end
    end
    
    storeLimit = 2'b00;
    if(sq_nAvailable == 2) begin
      storeLimit = 2;
    end else if (sq_nAvailable == 1) begin
      if(!buffer[head].fd_control.wr_mem || !buffer[headplus1].fd_control.wr_mem) begin
        storeLimit = 2;
      end else begin
        storeLimit = 1;
      end
    end else begin // sq_nAvailable == 0
      if(buffer[head].fd_control.wr_mem) begin
        storeLimit = 0;
      end else if(buffer[headplus1].fd_control.wr_mem) begin
        storeLimit = 1;
      end else begin
        storeLimit = 2;
      end
    end
    
    harderLimit = branchLimit < storeLimit ? branchLimit: storeLimit;
    //$display("storeLimit: %0d, harderLimit: %0d", storeLimit, harderLimit);
    
    ib_nIsnBuffer = 2'b00;        //this may be required for synthesis to work (optimization will remove it if not needed)
    //use the corner branch cases and the number of available entries to find nIsnBuffer
    if (numIns_buffer >= 4'b10) begin
      ib_nIsnBuffer = harderLimit;
    end else begin
      ib_nIsnBuffer = (numIns_buffer[1:0] > harderLimit) ? harderLimit : numIns_buffer[1:0];
    end

    nFill = 0;
    nextBuffer = buffer;

    //dispatch stuff to go to ROB and RS
    unique case(ib_nIsnBuffer)
      2'b00: begin
        ib_valid = 2'b00;
        ib_data[0] = `NOOP_INST;
        ib_data[1] = `NOOP_INST;
        //ib_store_en[0] = 0;
        //ib_store_en[1] = 0;
      end
      2'b01: begin
        ib_valid = 2'b01;
        ib_data[0] = buffer[head];
        ib_data[1] = `NOOP_INST;
        //ib_store_en[0] = buffer[head].fd_control.wr_mem;
        //ib_store_en[1] = 0;
      end
      2'b10: begin
        ib_valid = 2'b11;
        ib_data[0] = buffer[head];
        ib_data[1] = buffer[headplus1];
        //ib_store_en[0] = buffer[head].fd_control.wr_mem;;
        //ib_store_en[1] = buffer[headplus1].fd_control.wr_mem;;
      end
    endcase
    
    ib_store_en[0] = (haz_nDispatched > 0) && buffer[head].fd_control.wr_mem;
    ib_store_en[1] = (haz_nDispatched > 1) && buffer[headplus1].fd_control.wr_mem;
    
    //incoming stuff coming from fetch stage
    //the fetch stage knows how many entries are available in the InstrBuffer
    //and if_valid_in is set according to the available entries
    if(if_valid_in[0]) begin
      nextBuffer[tail].instruction = if_inst_in[0];
      nextBuffer[tail].fd_control = fd_control[0];
      nextBuffer[tail].pred_NPC = bp_pred_NPC[0];
      nextBuffer[tail].not_taken_NPC = bp_not_taken_NPC[0];
      nextBuffer[tail].bp_pred_taken = bp_pred_taken[0];
      nFill = 1;
    end
    if(if_valid_in[1]) begin
      nextBuffer[tailplus1].instruction = if_inst_in[1];
      nextBuffer[tailplus1].fd_control = fd_control[1];
      nextBuffer[tailplus1].pred_NPC = bp_pred_NPC[1];
      nextBuffer[tailplus1].not_taken_NPC = bp_not_taken_NPC[1];
      nextBuffer[tailplus1].bp_pred_taken = bp_pred_taken[1];
      nFill = 2;
    end 
    //to update the numIsn_buffer
    nextnumIns_buffer = numIns_buffer + nFill - haz_nDispatched ;
  end // always_comb

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      head <= `SD 0;
      tail <= `SD 0;
      buffer <= `SD '0;
      numIns_buffer <= `SD 0;
    end else if(br_pred_wrong) begin   //wrong prediction from FU, have to flush
      head <= `SD 0;
      tail <= `SD 0;
      buffer <= `SD '0;
      numIns_buffer <= `SD 0;
    end else begin
      buffer <= `SD nextBuffer;
      numIns_buffer <=  `SD nextnumIns_buffer;
      unique case(if_valid_in)
        2'b00:
          tail <= `SD tail;
        2'b01:
          tail <= `SD tail + 1;
        2'b11:
          tail <= `SD tail + 2;
      endcase
      unique case(haz_nDispatched)
        2'b00:
          head <= `SD head;
        2'b01:
          head <= `SD head + 1;
        2'b10:
          head <= `SD head + 2;
      endcase
    end
  end // always_ff

endmodule

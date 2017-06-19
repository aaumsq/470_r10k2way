/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       // 
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

//note: we may want to split this into several stage if period too long

`timescale 1ns/100ps

`define IF_DEBUG

module if_stage(
          input  logic            clk,      // system clock
          input  logic            reset,    // system reset

          //input from branch fuctional unit (not the fub)
          input  logic            br_pred_wrong,  // if prediction is wrong
          input  PC               br_recov_NPC,   // recovery NPC. used if prediction wrong
          input  logic            br_branch_resolved,
          input  logic            br_pred_dir_wrong,
          input logic             br_pred_taken,
          input logic             br_taken_NPC_wrong,
          input PC                br_not_taken_NPC,
          // input from I$
          input INSTRUCTION[1:0]  icache_data,  // Data coming back from instruction-memory
          input logic[1:0]        icache_valid,
          input logic             icache_pf_stall,
          // input for instruction buffer
          input  logic[1:0]       ib_nAvai,      // value from 0-2, number of fillable entries

          // output to I$
          output PC                  if_requested_addr,    // Address sent to Instruction memory
          //output to instruction buffer
          output logic [1:0]         bp_pred_taken,
          output PC    [1:0]         bp_pred_NPC,
          output PC    [1:0]         bp_not_taken_NPC,
          output INSTRUCTION [1:0]   if_inst,
          output logic [1:0]         if_valid,
          output FD_control_t [1:0]  fd_control,
          output PC                  pf_requested_addr,
          output logic               pf_request_valid
          `ifdef IF_DEBUG
            , output PC PC_reg
            , output logic PC_enable
          `endif
      );

  `ifndef IF_DEBUG
    PC  PC_reg;               // PC we are currently fetching
    logic       PC_enable;
  `endif

  PC  PC_plus_4;
  PC  PC_plus_8;
  PC  next_PC;
  PC[1:0] bp_not_pred_NPC;
  FD_control_t[1:0] internal_control;
  logic halt_fetched;
  logic next_halt_fetched;
  
  assign PC_plus_4 = PC_reg + 4;  // default next PC values
  assign PC_plus_8 = PC_reg + 8;

  assign if_requested_addr = PC_reg;

  // send instructions into fetch decoders
  FetchDecoder fd [1:0] (.inst(icache_data) , .fd_control(internal_control));
  assign fd_control[0].cond_branch = if_valid[0] && internal_control[0].cond_branch;
  assign fd_control[0].uncond_branch = if_valid[0] && internal_control[0].uncond_branch;
  assign fd_control[0].branch = if_valid[0] && internal_control[0].branch;
  assign fd_control[0].wr_mem = if_valid[0] && internal_control[0].wr_mem;
  assign fd_control[1].cond_branch = if_valid[1] && internal_control[1].cond_branch;
  assign fd_control[1].uncond_branch = if_valid[1] && internal_control[1].uncond_branch;
  assign fd_control[1].branch = if_valid[1] && internal_control[1].branch;
  assign fd_control[1].wr_mem = if_valid[1] && internal_control[1].wr_mem;
  
  // send into branch predictors
  BP bp (.clk(clk), .reset(reset), .if_fd_control(fd_control), .if_not_taken_NPC({PC_plus_8, PC_plus_4}),
              .br_pred_taken(br_pred_taken), .br_branch_resolved(br_branch_resolved),
              .br_taken_NPC_wrong(br_taken_NPC_wrong), .br_pred_dir_wrong(br_pred_dir_wrong),
              .br_not_taken_NPC(br_not_taken_NPC), .br_recov_NPC(br_recov_NPC),
              .if_valid(if_valid), .bp_pred_NPC(bp_pred_NPC), .bp_not_taken_NPC(bp_not_taken_NPC),
              .bp_not_pred_NPC(bp_not_pred_NPC), .bp_pred_taken(bp_pred_taken));

  //assign pf_request_valid = 0;
`ifndef ADV_PREFETCHER
  Prefetcher pf(.clk(clk), .reset(reset), .icache_pf_stall(icache_pf_stall), .fd_control(fd_control),
              .bp_pred_NPC(bp_pred_NPC), .bp_not_pred_NPC(bp_not_pred_NPC), .br_branch_resolved(br_branch_resolved),
              .br_pred_wrong(br_pred_wrong), .br_recov_NPC(br_recov_NPC),
              .if_PC(PC_reg), .pf_requested_addr(pf_requested_addr), .pf_request_valid(pf_request_valid));
`else
  AdvPrefetcher apf(.clk(clk), .reset(reset), .icache_pf_stall(icache_pf_stall), .fd_control(fd_control),
              .bp_pred_NPC(bp_pred_NPC), .bp_not_pred_NPC(bp_not_pred_NPC), .br_branch_resolved(br_branch_resolved),
              .br_pred_wrong(br_pred_wrong), .br_recov_NPC(br_recov_NPC),
              .if_PC(PC_reg), .pf_requested_addr(pf_requested_addr), .pf_request_valid(pf_request_valid));
`endif
  // if buffer is full (and br_pred_wrong is zero), PC_enable is zero. Will not update PC
  // however, the instruction buffer is cleared if prediction is wrong. so we
  // can go on even if ib_nAvai is zero (wrong prediction overides stalling).

  always_comb begin
    if_valid = 2'b0;
    if_inst = 64'b0;
    next_PC = 13'b0;
    PC_enable = 0;
    next_halt_fetched = 0;

    if(br_pred_wrong) begin
      next_PC = br_recov_NPC;
      PC_enable = 1;
    end else if (halt_fetched) begin
      PC_enable = 0;
      if_valid = 2'b00;
      next_halt_fetched = 1;
    end else begin
      if((ib_nAvai >= 2) && icache_valid[0] && icache_valid[1] && !(internal_control[0].branch)) begin
        next_PC = bp_pred_NPC[1];
        PC_enable = 1;
        if(icache_data[0] != 32'b0) begin
          if_valid[0] = 1;
          if_inst[0] = icache_data[0];
          if(icache_data[1] != 32'b0) begin
            if_valid[1] = 1;
            if_inst[1] = icache_data[1];
          end
          if(internal_control[0].halt) begin
            if_valid[1] = 0;
            next_halt_fetched = 1;
            PC_enable = 0;
          end else if (internal_control[1].halt) begin
            next_halt_fetched = 1;
            PC_enable = 0;
          end
        end else if(icache_data[1] != 32'b0) begin
          if_valid[0] = 1;
          if_inst[0] = icache_data[1];
          if(internal_control[1].halt) begin
            next_halt_fetched = 1;
            PC_enable = 0;
          end
        end
      end else if((ib_nAvai >= 1) && icache_valid[0]) begin
        next_PC = bp_pred_NPC[0];
        PC_enable = 1;
        if_valid[0] = icache_data[0] != 32'b0;
        if_valid[1] = 0;
        if_inst[0] = icache_data[0];
        if(internal_control[0].halt) begin
          next_halt_fetched = 1;
          PC_enable = 0;
        end
      end
    end

    //check for halt

  end

  // This register holds the PC value
  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      PC_reg <= `SD 0;
      halt_fetched <= `SD 0;
    end else if(PC_enable) begin
      PC_reg <= `SD next_PC;
      halt_fetched <= `SD next_halt_fetched;
    end else begin      
      halt_fetched <= `SD next_halt_fetched;
    end
  end  // always
  
endmodule  // module if_stage

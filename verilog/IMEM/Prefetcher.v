`ifndef ADV_PREFETCHER
typedef enum logic {
  PF_IDLE =  1'b0,
  PF_SEQ =   1'b1
} PF_STATE_t;

module Prefetcher #(parameter EN = 1)(
    input logic clk,
    input logic reset,
    
    input logic             icache_pf_stall,
    
    input FD_control_t[1:0] fd_control,
    
    input PC[1:0]           bp_pred_NPC,  
    input PC[1:0]           bp_not_pred_NPC,  
    
    input logic             br_branch_resolved,
    input logic             br_pred_wrong,
    input PC                br_recov_NPC,
    
    input PC                if_PC,
    
    output PC     pf_requested_addr,
    output logic  pf_request_valid);
  
  PC sequentialPC, nextSequentialPC, largestPC;
  
  PF_STATE_t state, nextState;
  logic[7:0] SEQ_DIST;
  logic isLargerPC;
    
  assign pf_requested_addr = nextSequentialPC;
  assign pf_request_valid = EN && (nextState != PF_IDLE);
  
  assign isLargerPC = if_PC > largestPC;
  assign SEQ_DIST = largestPC > 1600? 8:
                    largestPC > 800?  16:
                    largestPC > 400?  32:
                    largestPC > 200?  64: 128;
  
  always_comb begin
    if(br_branch_resolved) begin
      nextSequentialPC = br_recov_NPC+8;
      nextState = PF_SEQ;
    end else begin
      if(sequentialPC - if_PC >= SEQ_DIST) begin
        nextSequentialPC = sequentialPC;
        nextState = PF_IDLE;
      end else if(if_PC >= sequentialPC) begin
        nextSequentialPC = if_PC + 8;
        nextState = PF_SEQ;
      end else begin
        nextSequentialPC = sequentialPC + 8;
        nextState = PF_SEQ;
      end
    end
  end
    
    // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      sequentialPC <= `SD 0;
      if(EN) begin
        state <= `SD PF_SEQ;
      end else begin
        state <= `SD PF_IDLE;
      end
      largestPC <= `SD 0;
    end else begin
      if(EN && (!icache_pf_stall || br_pred_wrong)) begin
        state <= `SD nextState;
        sequentialPC <= `SD nextSequentialPC;
      end
      if(isLargerPC) begin
        largestPC <= `SD if_PC;
      end
    end
  end
    
endmodule

`endif





`ifdef ADV_PREFETCHER
typedef enum logic[1:0] {
  PF_IDLE =  2'b00,
  PF_SEQ =   2'b01,
  PF_P =     2'b10,
  PF_NP =    2'b11
} PF_STATE_t;

module AdvPrefetcher #(parameter EN = 1, parameter SEQ_DIST=8, parameter PRED_DIST=8, parameter NOT_PRED_DIST=0)(
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
  
  PC seqPC, next_seqPC;
  PC pPC, next_pPC, next_stdpPC, stdpPC;
  PC npPC, next_npPC, next_stdnpPC, stdnpPC;
  
  PF_STATE_t state, next_state;
  
  logic firstPPC_fetched, next_firstPPC_fetched, firstNPPC_fetched, next_firstNPPC_fetched;
  
  logic isbranch, branchidx, seqLimited, pLimited, npLimited;
  
  assign isbranch = fd_control[0].branch || fd_control[1].branch;
  assign branchidx = !fd_control[0].branch;
  assign seqLimited = seqPC - if_PC >= SEQ_DIST;
  assign pLimited = pPC - next_stdpPC >= PRED_DIST;
  assign npLimited = npPC - next_stdnpPC >= NOT_PRED_DIST;
 
  always_comb begin
    next_state = state;
    next_seqPC = seqPC;
    next_pPC = pPC;
    next_npPC = npPC;
    next_stdpPC = stdpPC;
    next_stdnpPC = stdnpPC;
    next_firstPPC_fetched = firstPPC_fetched;
    next_firstNPPC_fetched = firstNPPC_fetched;
    
    if(br_branch_resolved) begin
      next_state = PF_SEQ;
      next_seqPC = br_recov_NPC+8; //may attempt to re-prefetch instructions pf'd by the NP state before the branch, but this seems safer
    end else if(isbranch && (state == PF_IDLE || state == PF_SEQ)) begin
      next_stdpPC = bp_pred_NPC[branchidx];
      next_stdnpPC = bp_not_pred_NPC[branchidx];
      next_state = PF_P;
      next_pPC = bp_pred_NPC[branchidx];
      next_npPC = bp_not_pred_NPC[branchidx];
      next_firstNPPC_fetched = 0;
      next_firstPPC_fetched = 0;
    end else begin
      case(state)
        PF_IDLE: begin
          if(!seqLimited) begin
            next_state = PF_SEQ;
            next_seqPC = seqPC + 8;
          end
        end
        PF_SEQ: begin
          if(!seqLimited) begin
            next_state = PF_SEQ;
            next_seqPC = seqPC + 8;
          end else begin
            next_state = PF_IDLE;
          end
        end
        PF_P: begin
          next_pPC = pPC + 8;
          next_firstPPC_fetched = 1;
          if(!npLimited) begin
            next_state = PF_NP;
          end else if(!pLimited) begin
            next_state = PF_P;
          end else begin
            next_state = PF_IDLE;
          end
        end
        PF_NP: begin
          next_npPC = npPC + 8;
          next_firstNPPC_fetched = 1;
          if(!pLimited) begin
            next_state = PF_P;
          end else if(!npLimited) begin
            next_state = PF_NP;
          end else begin
            next_state = PF_IDLE;
          end
        end
      endcase
    end
  
    pf_request_valid = EN;
    pf_requested_addr = 0;
    case(next_state)
      PF_IDLE: begin
        pf_request_valid = 0;
      end
      PF_SEQ: begin
        pf_requested_addr = next_seqPC;
      end
      PF_P: begin
        pf_requested_addr = firstPPC_fetched? pPC: next_pPC;
      end
      PF_NP: begin
        pf_requested_addr = firstNPPC_fetched? npPC: next_npPC;
      end
    endcase
  end
    
    // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      seqPC <= `SD 0;
      firstPPC_fetched  <= `SD 0;
      firstNPPC_fetched <= `SD 0;
      if(EN) begin
        state <= `SD PF_SEQ;
      end else begin
        state <= `SD PF_IDLE;
      end
    end else begin
      state   <= `SD next_state;
      seqPC   <= `SD next_seqPC;
      pPC     <= `SD next_pPC;
      npPC    <= `SD next_npPC;
      stdpPC  <= `SD next_stdpPC;
      stdnpPC <= `SD next_stdnpPC;
      firstPPC_fetched  <= `SD next_firstPPC_fetched;
      firstNPPC_fetched <= `SD next_firstNPPC_fetched;
      $display("PF State: %d, isbranch: %d", state, isbranch);
    end
  end
    
endmodule

`endif

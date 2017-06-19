`define RS_DEBUG
module RS(
      input  logic   clk,
      input  logic   reset,

    //Dispatch stage inputs
      //Input from hazard detection
      input logic[1:0]           haz_nDispatched,
      //Input from free list
      input PHYS_REG[1:0]        fl_freeRegs,
      //Inputs from map table
      input PHYS_WITH_READY[1:0] mt_tagA,
      input PHYS_WITH_READY[1:0] mt_tagB,
      //Inputs from decoder
      input FU_TYPE[1:0]      de_fuType,
      input DE_control_t[1:0] de_control,
      //Inputs from branch stack
      input B_MASK            bs_bmask,
      input BS_PTR            bs_ptr,
      //Inputs from alu branch resolution
      input BS_PTR            br_bs_ptr,
      input logic             br_pred_wrong,
      input logic             br_branch_resolved,
    //Issue stage input
      //Input from FUs
      input logic[6:0]           fub_busy,
      //SQ inputs
      input SQ_PTR [1:0]         sq_index,
      input logic[1:0]           sq_index_empty,
      input SQ_PTR               sq_trueHead,
      input SQ_PTR               sq_tail,
      input SQ_PTR               sq_ea_ptr,
      input logic                sq_ea_empty,
      input logic                sq_empty,
    //Complete stage input
      //Input from CDB
      input logic[1:0]           cdb_rd_en,
      input PHYS_REG[1:0]        cdb_rd,
      
      
    //Dispatch stage output
      //Output to hazard detection
      output logic[3:0]          rs_availableSlots,
    //Issue stage outputs
      //Outputs to register file
      output PHYS_REG[1:0]       rs_tagA,
      output PHYS_REG[1:0]       rs_tagB,
      //Outputs to FUS
      output DE_control_t[1:0] rs_control,
      output PHYS_REG[1:0]    rs_tagDest,
      output logic[6:0][1:0]  rs_fu_en,
      output B_MASK[1:0]      rs_bmask,
      output BS_PTR[1:0]      rs_bs_ptr,
      output SQ_PTR[1:0]      rs_SQIndex

    
    `ifdef RS_DEBUG
      , output RSEntry_t[7:0]   entries
      , output RS_PTR[1:0]       rs_issuePtr
      , output logic[1:0]        rs_nIssue
      , output logic [7:0]       canLoadIssue
    `endif
  );
  
  `ifndef RS_DEBUG
    RSEntry_t[7:0] entries;
    RS_PTR[1:0] rs_issuePtr;
    logic[1:0]  rs_nIssue;
    logic [7:0] canLoadIssue;
  `endif
  
  RS_PTR[1:0] dispatchPtr;
  //logic[3:0]  nextAvailableSlots;  
  logic[7:0] nextAReady, nextBReady, nextValid;
  RS_PTR[1:0] next_issuePtr;
  logic[1:0]  next_nIssue;  //number of instructions being issued during cycle, rs_nIssue is from the previous
  logic[6:0][1:0]  next_fu_en;
  B_MASK[7:0] next_bmasks;
  //logic [3:0]  numInvalidated;
  logic [7:0] wasInvalidated;
  logic loadissued;
  
  genvar i;
  generate
    for(i = 0; i < 8; i++) begin 
      assign canLoadIssue[i] = sq_empty || 
                              (( ((entries[i].sq_index - sq_trueHead)&4'b0111) <= ((sq_ea_ptr - sq_trueHead)&4'b0111) )
                                && (entries[i].sq_index_empty || !sq_ea_empty))
                              ||( ((entries[i].sq_index - sq_trueHead)&4'b0111) > ((sq_tail - sq_trueHead)&4'b0111) );
    end
  endgenerate
  
  assign rs_availableSlots = 8 - entries[0].valid - entries[1].valid - entries[2].valid - entries[3].valid
                               - entries[4].valid - entries[5].valid - entries[6].valid - entries[7].valid;
  
    //outputs to the register file need to be combinational
      //otherwise the regfile outputs are a cycle delayed.
      //other outputs are sequential.
  genvar j;
  generate
    for(j = 0; j < 2; j++) begin
      assign rs_tagA[j] = entries[rs_issuePtr[j]].tagA.register;
      assign rs_tagB[j] = entries[rs_issuePtr[j]].tagB.register;  
      assign rs_control[j] = entries[rs_issuePtr[j]].control;      
      assign rs_tagDest[j] = entries[rs_issuePtr[j]].tag;      
      assign rs_bmask[j] = entries[rs_issuePtr[j]].bmask;      
      assign rs_bs_ptr[j] = entries[rs_issuePtr[j]].bs_ptr;
      assign rs_SQIndex[j] = entries[rs_issuePtr[j]].sq_index;
    end
  endgenerate


  //XXX: When issued, the instruction stays in the entries, but it'd valid bit is set to 0.
      //Dispatch is not allowed to write to an entry in the same cycle that it is was freed
      //regardless of the valid bit.
  always_comb begin
      //Default values
    for(int i = 0; i < 8; i++) begin
      nextValid[i] = entries[i].valid;
      nextAReady[i] = entries[i].tagA.ready;
      nextBReady[i] = entries[i].tagB.ready;
      next_bmasks[i] = entries[i].bmask;
    end
    
      //CDB complete, set ready bit
    for(int i = 0; i < 2; i++) begin
      for(int j = 0; j < 8; j++) begin
        if(cdb_rd_en[i] && (cdb_rd[i] == entries[j].tagA.register)) begin
          nextAReady[j] = 1;
        end
        if(cdb_rd_en[i] && (cdb_rd[i] == entries[j].tagB.register)) begin
          nextBReady[j] = 1;
        end
      end
    end
    
      //branch complete. must either clear bmask or invalidate entry
    wasInvalidated = 0;
    if(br_branch_resolved) begin
      for(int i = 0; i < 8; i++) begin
        if(entries[i].bmask[br_bs_ptr] && ~br_pred_wrong) begin
          next_bmasks[i][br_bs_ptr] = 0;
        end else if (entries[i].bmask[br_bs_ptr] && br_pred_wrong && entries[i].valid) begin
          nextValid[i] = 0;
          wasInvalidated[i] = 1;
        end
      end
    end
    
      //Issue logic
      //mispredicted entry cannot be issued
    next_issuePtr = '0;
    next_fu_en = '0;
    next_nIssue = 0;
    loadissued = 0;
    for(int i = 0; i < 8; i++) begin
      if((next_nIssue == 0) && entries[i].valid && nextAReady[i] && nextBReady[i] && !wasInvalidated[i]) begin

        unique case(entries[i].fuType)
        FUT_LDST: begin
            for(int j = 0; j < 2; j++) begin
              if(~fub_busy[j] && (!entries[i].control.rd_mem || canLoadIssue[i])) begin
                loadissued = entries[i].control.rd_mem;
                next_issuePtr[0] = i;
                next_fu_en[j] = 1;
                next_nIssue = 1;
                nextValid[i] = 0;
                break;
              end
            end
          end
        FUT_MULT: begin
            for(int j = 2; j < 4; j++) begin
              if(~fub_busy[j]) begin
                next_issuePtr[0] = i;
                next_fu_en[j] = 1;
                next_nIssue = 1;
                nextValid[i] = 0;
                break;
              end
            end
          end
        FUT_ALU: begin
            for(int j = 4; j < 6; j++) begin
              if(~fub_busy[j]) begin
                next_issuePtr[0] = i;
                next_fu_en[j] = 1;
                next_nIssue = 1;
                nextValid[i] = 0;
                break;  
              end
            end
          end
        FUT_BR: begin
            for(int j = 6; j < 7; j++) begin
              if(~fub_busy[j]) begin
                next_issuePtr[0] = i;
                next_fu_en[j] = 1;
                next_nIssue = 1;
                nextValid[i] = 0;
                break;
              end
            end
          end
        endcase
      end //if valid and ready
    end // for i    
    
    if(next_nIssue == 1) begin
      for(int i = 1; i < 8; i++) begin
        if(i != next_issuePtr[0]  && entries[i].valid && nextAReady[i] && nextBReady[i] && (next_nIssue == 1)
            && !wasInvalidated[i]) begin

          unique case(entries[i].fuType)
            FUT_LDST: begin
                for(int j = 0; j < 2; j++) begin
                  if(~fub_busy[j] && !next_fu_en[j] 
                      && (!entries[i].control.rd_mem || (canLoadIssue[i] && !loadissued))) begin
                    next_issuePtr[1] = i;
                    next_fu_en[j] = 2;
                    next_nIssue = 2;
                    nextValid[i] = 0;
                    break;
                  end
                end
              end
            FUT_MULT: begin
                for(int j = 2; j < 4; j++) begin
                  if(~fub_busy[j] && !next_fu_en[j]) begin
                    next_issuePtr[1] = i;
                    next_fu_en[j] = 2;
                    next_nIssue = 2;
                    nextValid[i] = 0;
                    break;
                  end
                end
              end
            FUT_ALU: begin
                for(int j = 4; j < 6; j++) begin
                  if(~fub_busy[j] && !next_fu_en[j]) begin
                    next_issuePtr[1] = i;
                    next_fu_en[j] = 2;
                    next_nIssue = 2;
                    nextValid[i] = 0;
                    break;
                  end
                end
              end
            FUT_BR: begin
                for(int j = 6; j < 7; j++) begin
                  if(~fub_busy[j] && !next_fu_en[j]) begin
                    next_issuePtr[1] = i;
                    next_fu_en[j] = 2;
                    next_nIssue = 2;
                    nextValid[i] = 0;
                    break;
                  end
                end
              end
          endcase
        end //if valid and ready
     end // for i   
    end //if rs nissued == 1   
    
      //Dispatch logic
    dispatchPtr[0] = 7;
    dispatchPtr[1] = 7;
    if(haz_nDispatched > 0) begin
      for(int i = 0; i < 8; i++) begin
        if(!entries[i].valid && !(bs_bmask[br_bs_ptr] && br_pred_wrong && br_branch_resolved)
            && !de_control[0].halt && !de_control[0].noop) begin
          //$display("dispatch to %0d", i);
          nextAReady[i] = mt_tagA[0].ready;
          nextBReady[i] = mt_tagB[0].ready;
          nextValid[i] = 1;
          dispatchPtr[0] = i;
          next_bmasks[i] = bs_bmask;
          if(bs_bmask[br_bs_ptr] && !br_pred_wrong && br_branch_resolved) begin
            next_bmasks[i][br_bs_ptr] = 0;
          end 
          break;
        end
      end
    end
    if(haz_nDispatched > 1) begin
      for(int i = 1; i < 8; i++) begin
        if(!entries[i].valid && (i != dispatchPtr[0]) && !(bs_bmask[br_bs_ptr] && br_pred_wrong)
            && !de_control[1].halt && !de_control[1].noop) begin
          //$display("dispatch to %0d", i);
          nextAReady[i] = mt_tagA[1].ready;
          nextBReady[i] = mt_tagB[1].ready;
          nextValid[i] = 1;
          dispatchPtr[1] = i;
          next_bmasks[i] = bs_bmask;
          if(bs_bmask[br_bs_ptr] && !br_pred_wrong && br_branch_resolved) begin
            next_bmasks[i][br_bs_ptr] = 0;
          end 
          break;
        end
      end
    end    
    
    for(int i = 0; i < haz_nDispatched; i++) begin
      for(int j = 0; j < 2; j++) begin
        if(cdb_rd_en[j] && (mt_tagA[i].register == cdb_rd[j]))begin
          nextAReady[dispatchPtr[i]] = 1;
        end 
        if(cdb_rd_en[j] && (mt_tagB[i].register == cdb_rd[j]))begin
          nextBReady[dispatchPtr[i]] = 1;
        end 
      end
    end
  end //always_comb
  
  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    // $display("RS fub_busy: %b", fub_busy);
    if(reset) begin
      for(int i = 0; i < 8; i++) begin
        entries[i].valid <= `SD 0;
      end
      
      for(int i = 0; i < 7; i++) begin
        rs_fu_en[i] <= `SD 0;
      end
      
      rs_nIssue <= `SD 0;
      //rs_availableSlots <= `SD 8;
    end else begin
      //Issue
      rs_nIssue <= `SD next_nIssue;
      for(int i = 0; i < 2; i++) begin
        rs_issuePtr[i] <= `SD next_issuePtr[i];
      end
      for(int i = 0; i < 7; i++) begin
        rs_fu_en[i] <= `SD next_fu_en[i];
      end
      
      //Dispatch
      for(int i = 0; i < haz_nDispatched; i++) begin
        if(!de_control[i].halt && !de_control[i].noop) begin
          entries[dispatchPtr[i]].fuType <= `SD de_fuType[i];
          entries[dispatchPtr[i]].control <= `SD de_control[i];
          entries[dispatchPtr[i]].tag <= `SD fl_freeRegs[i];
          entries[dispatchPtr[i]].tagA <= `SD mt_tagA[i];
          entries[dispatchPtr[i]].tagB <= `SD mt_tagB[i];
          entries[dispatchPtr[i]].bs_ptr <= `SD bs_ptr;
          entries[dispatchPtr[i]].sq_index <= `SD sq_index[i];
          entries[dispatchPtr[i]].sq_index_empty <= `SD sq_index_empty[i];
          //$display("i: %0d, tag: %0d, sq_index: %0d", i, fl_freeRegs[i], sq_index[i]);
        end
      end
      
      //Entry state
      for(int i = 0; i < 8; i++) begin
        entries[i].bmask <= `SD next_bmasks[i];
        entries[i].valid <= `SD nextValid[i];
        entries[i].tagA.ready <= `SD nextAReady[i];
        entries[i].tagB.ready <= `SD nextBReady[i];
        //$display("rs[%0d].sq_index_empty: %0d", i, entries[i].sq_index_empty);
      end
      //$display("sq_ea_empty: %0d", sq_ea_empty);
      
      //General state
     // rs_availableSlots <= `SD nextAvailableSlots;
    end
  end
endmodule

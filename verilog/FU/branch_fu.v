module branch_fu(
    // Inputs from FUS
    input logic         clk,
    input logic         reset,
    input logic         fus_en,
    input DATA          fus_opA, fus_opB,
    input PHYS_REG      fus_tagDest,
    input DE_control_t  fus_control,
    input B_MASK        fus_bmask,
    input BS_PTR        fus_bs_ptr,
    
    // Outputs to FUB for branch entry
    output PHYS_REG     br_tagDest,
    output DATA         br_result,
    output logic        br_done,
    output B_MASK       br_bmask,

    // Seqential outputs to FUB and elsewhere
    output logic        br_pred_taken,
    output logic        br_pred_wrong,      //if either direction or NPC prediction wrong, must recover
    output logic        br_pred_dir_wrong,  //if direction prediction wrong, fix BHT   
    output logic        br_taken_NPC_wrong, //if NPC prediction wrong, fix BTB (this is necessary for jump!)
    output BS_PTR       br_bs_ptr,
    output PC           br_not_taken_NPC,
    output PC           br_recov_NPC,
    output logic        br_branch_resolved
    );

  logic [63:0] opa_mux_out, opb_mux_out;
  logic        brcond_result;
  
  logic        next_take_branch;
  logic        next_pred_taken;
  logic        next_pred_wrong;
  logic        next_taken_NPC_wrong;
  BS_PTR       next_bs_ptr;
  PC           next_recov_NPC;
  logic        next_pred_dir_wrong;
  PC           alu_result;
    
  // br_disp: sign-extended 21-bit immediate * 4 for branch displacement
  wire [63:0] br_disp = {{41{fus_control.ib_data.instruction[20]}},
                         fus_control.ib_data.instruction[20:0],
                         2'b00};
  
  assign next_pred_taken = fus_control.ib_data.bp_pred_taken;


  //destination tag for CDB to cam
  assign br_tagDest  = fus_tagDest;
  assign next_bs_ptr = fus_bs_ptr;
  assign br_result = fus_control.ib_data.not_taken_NPC;


  always_comb begin

    // Branch opA mux
    case (fus_control.opa_select)
      `ALU_OPA_IS_REGA:     opa_mux_out = 64'hbaadbeefdeadbee1; // UNUSED
      `ALU_OPA_IS_MEM_DISP: opa_mux_out = 64'hbaadbeefdeadbee2; // UNUSED
      `ALU_OPA_IS_NPC:      opa_mux_out = fus_control.ib_data.not_taken_NPC;
      `ALU_OPA_IS_NOT3:     opa_mux_out = ~64'h3;
    endcase

    // Branch opB mux
    opb_mux_out = 64'hbaadbeefdeadbee3;                         // UNUSED
    case (fus_control.opb_select)
      `ALU_OPB_IS_REGB:    opb_mux_out = fus_opB;
      `ALU_OPB_IS_ALU_IMM: opb_mux_out = 64'hbaadbeefdeadbee4;  // UNUSED
      `ALU_OPB_IS_BR_DISP: opb_mux_out = br_disp;
    endcase

    // Branch address calculations (contents of alu module)
    if (fus_control.alu_func == `ALU_ADDQ) begin
      alu_result = opa_mux_out + opb_mux_out;
    end else if (fus_control.alu_func == `ALU_AND) begin
      alu_result = opa_mux_out & opb_mux_out;
    end else begin
      alu_result = 64'hbaadbeefdeadbee5; // Should never be reached
    end

    // Contents of brcond module
    case (fus_control.ib_data.instruction[27:26])
      2'b00: brcond_result = (fus_opA[0] == 0);                        // LBC
      2'b01: brcond_result = (fus_opA == 0);                           // EQ
      2'b10: brcond_result = (fus_opA[63] == 1);                       // LT
      2'b11: brcond_result = (fus_opA[63] == 1) || (fus_opA == 0); // LE
    endcase
    // negate cond if func[2] is set
    if (fus_control.ib_data.instruction[28]) begin
      brcond_result = ~brcond_result;
    end
    // ultimate "take branch" signal:
    // unconditional, or conditional and the condition is true
    next_take_branch = fus_control.ib_data.fd_control.uncond_branch ||
                  (fus_control.ib_data.fd_control.cond_branch && brcond_result);
                  
    // Branch done bits and mask pass throughs
    br_done  = fus_en;
    br_bmask = fus_bmask;
    if (br_branch_resolved) begin
      br_done = fus_en && !(br_pred_wrong && fus_bmask[br_bs_ptr]);
      br_bmask[br_bs_ptr] = 0;
    end

    //check if prediction correct and output
    next_recov_NPC = next_take_branch && br_done? alu_result : fus_control.ib_data.not_taken_NPC;
    //this is to check if the taken NPC in the BTB is wrong. Must fix BTB if wrong
    next_taken_NPC_wrong = (next_recov_NPC != fus_control.ib_data.pred_NPC) && next_take_branch && br_done;
    //direction of prediction is wrong (this can still be correc when pred_NPC is wrong). To fix BHT
    next_pred_dir_wrong = (next_pred_taken != next_take_branch) && br_done;
    //this is to check if direction of prediction is wrong or if we used a wrong taken_NPC as prediction. if wrong must recover from misprediction
    next_pred_wrong = (next_pred_dir_wrong | next_taken_NPC_wrong) && br_done;
  end // always_comb

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if (reset) begin
      br_pred_taken       <= `SD 0;
      br_pred_wrong       <= `SD 0;
      br_bs_ptr           <= `SD 0;
      br_not_taken_NPC    <= `SD 0;
      br_recov_NPC        <= `SD 0;
      br_branch_resolved  <= `SD 0;
      br_taken_NPC_wrong   <= `SD 0;
    end else begin
      if(next_pred_wrong) begin
       // $display("next_pred_taken: %d, next_take_branch: %d", next_pred_taken, next_take_branch);
       // $display("brcond_result: %d", brcond_result);
      end
      br_pred_taken       <= `SD next_pred_taken;
      br_pred_wrong       <= `SD next_pred_wrong;
      br_bs_ptr           <= `SD next_bs_ptr;
      br_not_taken_NPC    <= `SD fus_control.ib_data.not_taken_NPC;
      br_recov_NPC        <= `SD next_recov_NPC;
      br_branch_resolved  <= `SD br_done;
      br_taken_NPC_wrong  <= `SD next_taken_NPC_wrong;
      br_pred_dir_wrong   <= `SD next_pred_dir_wrong;
    end
  end // always_ff

endmodule // branch_fu

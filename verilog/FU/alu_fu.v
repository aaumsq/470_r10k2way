
//
// The ALU
//
// given the command code CMD and proper operands A and B, compute the
// result of the instruction
//
// This module is purely combinational
//
module alu(
      input logic[63:0] opa,
      input logic[63:0] opb,
      input logic[4:0]  func,
           
      output logic [63:0] result
    );

    // This function computes a signed less-than operation
  function signed_lt;
    input [63:0] a, b;

    if (a[63] == b[63]) 
      signed_lt = (a < b); // signs match: signed compare same as unsigned
    else
      signed_lt = a[63];   // signs differ: a is smaller if neg, larger if pos
  endfunction

  always_comb begin
    case (func)
      `ALU_ADDQ:   result = opa + opb;
      `ALU_SUBQ:   result = opa - opb;
      `ALU_AND:    result = opa & opb;
      `ALU_BIC:    result = opa & ~opb;
      `ALU_BIS:    result = opa | opb;
      `ALU_ORNOT:  result = opa | ~opb;
      `ALU_XOR:    result = opa ^ opb;
      `ALU_EQV:    result = opa ^ ~opb;
      `ALU_SRL:    result = opa >> opb[5:0];
      `ALU_SLL:    result = opa << opb[5:0];
      `ALU_SRA:    result = (opa >> opb[5:0]) | ({64{opa[63]}} << (64 -
                 opb[5:0])); // arithmetic from logical shift
      // `ALU_MULQ:   result = opa * opb; //mult is done in pipe_mult_fu
      `ALU_CMPULT: result = { 63'd0, (opa < opb) };
      `ALU_CMPEQ:  result = { 63'd0, (opa == opb) };
      `ALU_CMPULE: result = { 63'd0, (opa <= opb) };
      `ALU_CMPLT:  result = { 63'd0, signed_lt(opa, opb) };
      `ALU_CMPLE:  result = { 63'd0, (signed_lt(opa, opb) || (opa == opb)) };
      default:     result = 64'hdeadbeefbaadbeef; // here only to force
                            // a combinational solution
                            // a casex would be better
    endcase
  end
endmodule // alu

module alu_fu(
      input logic         fus_en,
      input DATA          fus_opA, fus_opB,
      input PHYS_REG      fus_tagDest,
      input DE_control_t  fus_control,
      input B_MASK        fus_bmask,
      input logic         br_pred_wrong,
      input logic         br_branch_resolved,
      input BS_PTR        br_bs_ptr,

      output PHYS_REG     alu_tagDest,
      output DATA         alu_result,
      output logic        alu_done,
      output B_MASK       alu_bmask
      );


    DATA opa_mux_out, opb_mux_out;


      // set up possible immediates:
    //   mem_disp: sign-extended 16-bit immediate for memory format
    //   br_disp: sign-extended 21-bit immediate * 4 for branch displacement
    //   alu_imm: zero-extended 8-bit immediate for ALU ops
    DATA mem_disp;
    DATA br_disp;
    DATA alu_imm;
    
    assign mem_disp = { {48{fus_control.ib_data.instruction[15]}}, fus_control.ib_data.instruction[15:0] };
    assign br_disp  = { {41{fus_control.ib_data.instruction[20]}}, fus_control.ib_data.instruction[20:0], 2'b00 };
    assign alu_imm  = { 56'b0, fus_control.ib_data.instruction[20:13] };

    //
    // ALU opA mux
    //
    always_comb
    begin
      case (fus_control.opa_select)
        `ALU_OPA_IS_REGA:     opa_mux_out = fus_opA;
        `ALU_OPA_IS_MEM_DISP: opa_mux_out = mem_disp;
        `ALU_OPA_IS_NPC:      opa_mux_out = fus_control.ib_data.not_taken_NPC;
        `ALU_OPA_IS_NOT3:     opa_mux_out = ~64'h3;
      endcase
    end

    //
    // ALU opB mux
    //
    always_comb
    begin
       // Default value, Set only because the case isnt full.  If you see this
       // value on the output of the mux you have an invalid opb_select
      opb_mux_out = 64'hbaadbeefdeadbeef;
      case (fus_control.opb_select)
        `ALU_OPB_IS_REGB:    opb_mux_out = fus_opB;
        `ALU_OPB_IS_ALU_IMM: opb_mux_out = alu_imm;
        `ALU_OPB_IS_BR_DISP: opb_mux_out = br_disp;
      endcase 
  end

  //
  // instantiate the ALU
  //
  alu alu_0 (// Inputs
       .opa(opa_mux_out),   //this is the actual operand used after muxing
       .opb(opb_mux_out),
       .func(fus_control.alu_func),

       // Output
       .result(alu_result)
      );
  
  always_comb begin
    alu_done = fus_en;
    alu_bmask = fus_bmask;
    if (br_branch_resolved) begin
      alu_done = fus_en & ~(br_pred_wrong & fus_bmask[br_bs_ptr]);
      alu_bmask[br_bs_ptr] = 0;
    end
  end

  //destionation tag for CDB to cam
  assign alu_tagDest = fus_tagDest;
  
endmodule // alu

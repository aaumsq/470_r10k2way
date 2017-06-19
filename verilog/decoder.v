// Decode an instruction: given instruction bits IR produce the
// appropriate datapath control signals.
//
// This is a *combinational* module (basically a PLA).
//
module decoder(
    input logic         ib_valid,
    input IBEntry_t     ib_data,

    output FU_TYPE      de_fuType,
    output ARCH_REG     de_destidx,
    output ARCH_REG     de_regAidx,
    output ARCH_REG     de_regBidx,
    
    output DE_control_t de_control
  );

  assign de_control.ib_data = ib_data;

  assign de_control.valid_inst = ib_valid & ~de_control.illegal;
  
  
  // instruction fields read from IF/ID pipeline register
  ARCH_REG ra_idx;
  ARCH_REG rb_idx;
  ARCH_REG rc_idx;

  assign ra_idx = ib_data.instruction[25:21];   // inst operand A register index
  assign rb_idx = ib_data.instruction[20:16];   // inst operand B register index
  assign rc_idx = ib_data.instruction[4:0];     // inst operand C register index
  
  always_comb begin
    // default control values:
    // - valid instructions must override these defaults as necessary.
    //   de_control.opa_select, de_control.opb_select, and de_control.alu_func should be set explicitly.
    // - invalid instructions should clear de_control.valid_inst.
    // - These defaults are equivalent to a noop
    // * see sys_defs.vh for the constants used here
    de_control.opa_select = 0;
    de_control.opb_select = 0;
    de_control.alu_func = 0;
    de_control.dest_reg = `DEST_NONE;
    de_control.rd_mem = `FALSE;
    de_control.halt = `FALSE;
    de_control.illegal = `FALSE;
    de_control.noop = ib_data.instruction == `NOOP_INST;

    de_destidx = `ZERO_REG;
    de_regAidx = `ZERO_REG;
    de_regBidx = `ZERO_REG;
    de_fuType = FUT_ALU;

    if(ib_valid)
    begin
      case ({ib_data.instruction[31:29], 3'b0})
        6'h0:
          case (ib_data.instruction[31:26])
            `PAL_INST: begin
              if (ib_data.instruction[25:0] == `PAL_HALT) begin
                de_fuType = FUT_ALU;
                de_control.halt = `TRUE;
              end else begin
                de_control.illegal = `TRUE;
              end
            end
            default: de_control.illegal = `TRUE;
          endcase // case(inst[31:26])

        6'h10:
        begin
          de_destidx = rc_idx;
          de_regAidx = ra_idx;
          de_regBidx = ib_data.instruction[12] ? `ZERO_REG : rb_idx;
          de_fuType = (ib_data.instruction[31:26] == `INTM_GRP && ib_data.instruction[11:5] == `MULQ_INST)? FUT_MULT : FUT_ALU;
          de_control.opa_select = `ALU_OPA_IS_REGA;
          de_control.opb_select = ib_data.instruction[12] ? `ALU_OPB_IS_ALU_IMM : `ALU_OPB_IS_REGB;
          de_control.dest_reg = `DEST_IS_REGC;
          case (ib_data.instruction[31:26])
            `INTA_GRP:
              case (ib_data.instruction[11:5])
                `CMPULT_INST:  de_control.alu_func = `ALU_CMPULT;
                `ADDQ_INST:    de_control.alu_func = `ALU_ADDQ;
                `SUBQ_INST:    de_control.alu_func = `ALU_SUBQ;
                `CMPEQ_INST:   de_control.alu_func = `ALU_CMPEQ;
                `CMPULE_INST:  de_control.alu_func = `ALU_CMPULE;
                `CMPLT_INST:   de_control.alu_func = `ALU_CMPLT;
                `CMPLE_INST:   de_control.alu_func = `ALU_CMPLE;
                default:        de_control.illegal = `TRUE;
              endcase // case(inst[11:5])
            `INTL_GRP:
              case (ib_data.instruction[11:5])
                `AND_INST:    de_control.alu_func = `ALU_AND;
                `BIC_INST:    de_control.alu_func = `ALU_BIC;
                `BIS_INST:    de_control.alu_func = `ALU_BIS;
                `ORNOT_INST:  de_control.alu_func = `ALU_ORNOT;
                `XOR_INST:    de_control.alu_func = `ALU_XOR;
                `EQV_INST:    de_control.alu_func = `ALU_EQV;
                default:       de_control.illegal = `TRUE;
              endcase // case(inst[11:5])
            `INTS_GRP:
              case (ib_data.instruction[11:5])
                `SRL_INST:  de_control.alu_func = `ALU_SRL;
                `SLL_INST:  de_control.alu_func = `ALU_SLL;
                `SRA_INST:  de_control.alu_func = `ALU_SRA;
                default:    de_control.illegal = `TRUE;
              endcase // case(inst[11:5])
            `INTM_GRP:
              case (ib_data.instruction[11:5])
                `MULQ_INST:       de_control.alu_func = `ALU_MULQ;
                default:          de_control.illegal = `TRUE;
              endcase // case(inst[11:5])
            `ITFP_GRP:       de_control.illegal = `TRUE;       // unimplemented
            `FLTV_GRP:       de_control.illegal = `TRUE;       // unimplemented
            `FLTI_GRP:       de_control.illegal = `TRUE;       // unimplemented
            `FLTL_GRP:       de_control.illegal = `TRUE;       // unimplemented
          endcase // case(inst[31:26])
        end

        6'h18:
          case (ib_data.instruction[31:26])
            `MISC_GRP:       de_control.illegal = `TRUE; // unimplemented
            `JSR_GRP:
            begin
              de_regBidx = rb_idx;
              de_destidx = ra_idx;
              // JMP, JSR, RET, and JSR_CO have identical semantics
              de_control.opa_select = `ALU_OPA_IS_NOT3;
              de_control.opb_select = `ALU_OPB_IS_REGB;
              de_control.alu_func = `ALU_AND; // clear low 2 bits (word-align)
              de_control.dest_reg = `DEST_IS_REGA;
              de_fuType = FUT_BR;
            end
            `FTPI_GRP:       de_control.illegal = `TRUE;       // unimplemented
          endcase // case(inst[31:26])

        6'h08, 6'h20, 6'h28:
        begin
          de_regBidx = rb_idx;
          de_destidx = ra_idx;
          de_control.opa_select = `ALU_OPA_IS_MEM_DISP;
          de_control.opb_select = `ALU_OPB_IS_REGB;
          de_control.alu_func = `ALU_ADDQ;
          de_control.dest_reg = `DEST_IS_REGA;
          case (ib_data.instruction[31:26])
            `LDA_INST:  ;
            `LDQ_L_INST: de_control.illegal = `TRUE;
            `STQ_C_INST: de_control.illegal = `TRUE;
            `LDQ_INST:
            begin
              de_fuType = FUT_LDST;
              de_control.rd_mem = `TRUE;
              de_control.dest_reg = `DEST_IS_REGA;
            end // case: `LDQ_INST
            `STQ_INST:
            begin
              de_regAidx = ra_idx;
              de_destidx = `ZERO_REG;
              de_fuType = FUT_LDST;
              de_control.dest_reg = `DEST_NONE;
            end // case: `STQ_INST
            default:       de_control.illegal = `TRUE;
          endcase // case(inst[31:26])
        end

        6'h30, 6'h38:
        begin
          de_regAidx = ra_idx;
          de_control.opa_select = `ALU_OPA_IS_NPC;
          de_control.opb_select = `ALU_OPB_IS_BR_DISP;
          de_control.alu_func = `ALU_ADDQ;
          de_fuType = FUT_BR;
          case (ib_data.instruction[31:26])
            `FBEQ_INST, `FBLT_INST, `FBLE_INST,
            `FBNE_INST, `FBGE_INST, `FBGT_INST:
            begin
              // FP conditionals not implemented
              de_control.illegal = `TRUE;
            end

            `BR_INST, `BSR_INST:
            begin
              de_destidx = ra_idx;
              de_control.dest_reg = `DEST_IS_REGA;
            end
          endcase // case(inst[31:26])
        end
      endcase // case(inst[31:29] << 3)
    end // if(~ib_valid)
  end // always_comb

endmodule // decoder

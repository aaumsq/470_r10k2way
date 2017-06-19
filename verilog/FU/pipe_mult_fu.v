// This is an NUM_STAGE (NUM_STAGE+1 depending on how you look at it) pipelined 
// multiplier that multiplies 2 64-bit integers and returns the low 64 bits 
// of the result.  This is not an ideal multiplier but is sufficient to 
// allow a faster clk period than straight *
// This module instantiates NUM_STAGE pipeline stages as an array of submodules.

//NUM_STAGE and BIT_SHIFT are in sys_defs

// This is one stage of a NUM_STAGE (NUM_STAGE+1 depending on how you look at it)
// pipelined multiplier that multiplies 2 64-bit integers and returns
// the low 64 bits of the result.  This is not an ideal multiplier but
// is sufficient to allow a faster clk period than straight *

//NUM_STAGE and BIT_SHIFT are in sys_defs

module mult_stage(
        input logic         clk, reset, start,
        input logic[63:0]   product_in, mplier_in, mcand_in,
        input PHYS_REG      tagDest_in,
        input logic         next_stage_stalled,
        input B_MASK        bmask_in,
        input logic         br_pred_wrong,
        input logic         br_branch_resolved,
        input BS_PTR        br_bs_ptr,

        output logic done,
        output logic stall,
        output logic [63:0] product_out, mplier_out, mcand_out,
        output PHYS_REG     tagDest_out,
        output B_MASK       bmask_out
        );

  logic [63:0] partial_product, next_mplier, next_mcand, next_product_out;
  B_MASK next_bmask_out;
  logic next_done;

  assign next_product_out = product_in + partial_product;

  assign partial_product = mplier_in[(`BIT_SHIFT - 1):0] * mcand_in;

  assign next_mplier = {{`BIT_SHIFT{1'b0}}, mplier_in[63:`BIT_SHIFT]};
  assign next_mcand = {mcand_in[(63 - `BIT_SHIFT):0],{`BIT_SHIFT{1'b0}}};
  assign stall = next_stage_stalled & done;

  always_comb begin
    next_bmask_out = next_stage_stalled? bmask_out : bmask_in;
    if (br_branch_resolved) begin
      next_bmask_out[br_bs_ptr] = 0;
    end
    if(br_branch_resolved & bmask_in[br_bs_ptr] & br_pred_wrong) begin
      next_done = 0;
    end else begin
      next_done = start;
    end
  end

  // if fub is full, we will just stall the mult pipeline entirely
  //synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    bmask_out <= `SD next_bmask_out;
    if (stall) begin
      product_out      <= `SD product_out;
      mplier_out       <= `SD mplier_out;
      mcand_out        <= `SD mcand_out;
      tagDest_out      <= `SD tagDest_out;
    end else begin
      product_out      <= `SD next_product_out;
      mplier_out       <= `SD next_mplier;
      mcand_out        <= `SD next_mcand;
      tagDest_out      <= `SD tagDest_in;
    end
    // $display("done: %0d, stall: %0d, ", done, stall);
    // $display("product_out: %0d, tagDest_out: %0d, bmask_out: %0d", product_out, tagDest_out, bmask_out);
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset)
      done <= `SD 1'b0;
    else if (stall)
      done <= `SD done;
    else
      done <= `SD next_done;
  end

endmodule

module mult_comb(
        input logic         reset, start,
        input logic[63:0]   product_in, mplier_in, mcand_in,
        input PHYS_REG      tagDest_in,
        input logic         next_stage_stalled,
        input B_MASK        bmask_in,
        input logic         br_pred_wrong,
        input logic         br_branch_resolved,
        input BS_PTR        br_bs_ptr,

        output logic done,
        output logic stall,
        output logic [63:0] product_out,
        output PHYS_REG     tagDest_out,
        output B_MASK       bmask_out
        );

  logic [63:0] partial_product, next_mplier, next_mcand, next_product_out;
  B_MASK next_bmask_out;

  assign product_out = product_in + partial_product;

  assign partial_product = mplier_in[(`BIT_SHIFT - 1):0] * mcand_in;

  assign stall = next_stage_stalled & done;

  always_comb begin
    tagDest_out = tagDest_in;
    bmask_out = bmask_in;
    if (br_branch_resolved) begin
      bmask_out[br_bs_ptr] = 0;
    end
    if(reset | (br_branch_resolved & bmask_in[br_bs_ptr] & br_pred_wrong)) begin
      done = 0;
    end else begin
      done = start;
    end
  end
endmodule


module pipe_mult_fu(
      input logic         clk, reset,
      input DATA          fus_opA, fus_opB,
      input logic         fus_en,
      input PHYS_REG      fus_tagDest,
      input logic         fub_mult_busy,
      input B_MASK        fus_bmask,
      input DE_control_t  fus_control,
      input logic         br_pred_wrong,
      input logic         br_branch_resolved,
      input BS_PTR        br_bs_ptr,
      
      output DATA         mult_result,
      output logic        mult_done,
      output PHYS_REG     mult_tagDest,
      output B_MASK       mult_bmask,
      output logic        mult_busy
      );

  logic [63:0] mcand_out, mplier_out;
  logic [(`NUM_STAGE - 2):0][63:0] internal_products, internal_mcands, internal_mpliers;
  PHYS_REG [(`NUM_STAGE - 2):0] internal_tagDest_out;
  logic [(`NUM_STAGE - 2):0] internal_dones;
  logic [(`NUM_STAGE - 2):0] internal_stall;
  B_MASK [(`NUM_STAGE - 2):0] internal_bmask;
  DATA alu_imm, opb_mux_out;
  assign alu_imm  = { 56'b0, fus_control.ib_data.instruction[20:13] };
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
    endcase 
  end

  
  mult_stage mstage [(`NUM_STAGE - 2):0]  (
    .clk(clk),
    .reset(reset),
    .product_in({internal_products[`NUM_STAGE-3:0],64'h0}),
    .mplier_in({internal_mpliers[`NUM_STAGE-3:0],opb_mux_out}),
    .mcand_in({internal_mcands[`NUM_STAGE-3:0],fus_opA}),
    .tagDest_in({internal_tagDest_out[`NUM_STAGE-3:0],fus_tagDest}),
    .start({internal_dones[`NUM_STAGE-3:0],fus_en}),
    .next_stage_stalled({internal_stall}),
    .bmask_in({internal_bmask[`NUM_STAGE-3:0], fus_bmask}),
    .br_pred_wrong(br_pred_wrong),
    .br_branch_resolved(br_branch_resolved),
    .br_bs_ptr(br_bs_ptr),

    .product_out({internal_products}),
    .mplier_out({internal_mpliers}),
    .mcand_out({internal_mcands}),
    .done({internal_dones}),
    .stall({internal_stall[`NUM_STAGE-3:0], mult_busy}),
    .tagDest_out(internal_tagDest_out),
    .bmask_out(internal_bmask)
  );

  mult_comb mult_comb0(
        .reset(reset),
        .start(internal_dones[`NUM_STAGE-2]),
        .product_in(internal_products[`NUM_STAGE-2]), 
        .mplier_in(internal_mpliers[`NUM_STAGE-2]), 
        .mcand_in(internal_mcands[`NUM_STAGE-2]),
        .tagDest_in(internal_tagDest_out[`NUM_STAGE-2]),
        .next_stage_stalled(fub_mult_busy),
        .bmask_in(internal_bmask[`NUM_STAGE-2]),
        .br_pred_wrong(br_pred_wrong),
        .br_branch_resolved(br_branch_resolved),
        .br_bs_ptr(br_bs_ptr),

        .done(mult_done),
        .stall(internal_stall[`NUM_STAGE-2]),
        .product_out(mult_result),
        .tagDest_out(mult_tagDest),
        .bmask_out(mult_bmask)
  );

  //always_ff @(posedge clk) begin  
    // $display("mult_done: %0d, comb_stall: %0d, ", mult_done, internal_stall[`NUM_STAGE-2]);
    // $display("product_out: %0d, tagDest_out: %0d, bmask_out: %0d", mult_result, mult_tagDest, mult_bmask);
  //end

endmodule

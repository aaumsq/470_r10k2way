`define FUS_DEBUG
module FUS(
    input logic[1:0]          rs_fu_en,
    input DATA [1:0]          rf_opA,
    input DATA [1:0]          rf_opB,
    input PHYS_REG [1:0]      rs_tagDest,
    input DE_control_t [1:0]  rs_control,
    input B_MASK[1:0]         rs_bmask,
    input BS_PTR[1:0]         rs_bs_ptr,
    input SQ_PTR[1:0]         rs_SQIndex,

    output logic              fus_en,
    output DATA               fus_opA,
    output DATA               fus_opB,
    output PHYS_REG           fus_tagDest,
    output DE_control_t       fus_control,
    output B_MASK             fus_bmask,
    output BS_PTR             fus_bs_ptr,
    output SQ_PTR             fus_SQIndex
    );

  always_comb begin

    if (rs_fu_en[0]) begin
      fus_en = 1;
      fus_opA = rf_opA[0];
      fus_opB = rf_opB[0];
      fus_tagDest = rs_tagDest[0];
      fus_control = rs_control[0];
      fus_bmask =   rs_bmask[0];
      fus_bs_ptr =  rs_bs_ptr[0];
      fus_SQIndex =  rs_SQIndex[0];
    end else if (rs_fu_en[1]) begin
      fus_en = 1;
      fus_opA = rf_opA[1];
      fus_opB = rf_opB[1];
      fus_tagDest = rs_tagDest[1];
      fus_control = rs_control[1];
      fus_bmask =   rs_bmask[1];
      fus_bs_ptr =  rs_bs_ptr[1];
      fus_SQIndex =  rs_SQIndex[1];
    end else begin
      fus_en = 0;
      fus_opA = 64'h0;
      fus_opB = 64'h0;
      fus_tagDest = `PHYS_ZERO_REG;
      fus_control = 0;
      fus_bmask =   0;
      fus_bs_ptr =  0;
      fus_SQIndex = 0;
    end
    
  end // always_comb

endmodule

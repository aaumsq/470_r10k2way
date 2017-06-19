module if_id_hazard(
    input logic[5:0]         rob_availableSlots,
    input logic[1:0]         rob_nRetired,
    input logic[3:0]         rs_availableSlots,
    input logic[5:0]         fl_availableRegs,
    input logic[1:0]         ib_nIsnBuffer,    //this value can only be from 0 to 2 (2 if buffer has more than or equal two insn)

    input logic              br_pred_wrong,

    output logic [1:0]  haz_nDispatched
  );

  wire [5:0] rob_vs_rs, fl_vs_fetched;
  wire [1:0] rob_vs_rs_2b, fl_vs_fetched_2b;

  assign rob_vs_rs = ((rob_availableSlots + rob_nRetired) < rs_availableSlots) ? 
                      (rob_availableSlots + rob_nRetired) : rs_availableSlots;
  assign rob_vs_rs_2b = (rob_vs_rs > 2) ? 2'b10 : rob_vs_rs[1:0];

  assign fl_vs_fetched = (fl_availableRegs < ib_nIsnBuffer) ? fl_availableRegs : ib_nIsnBuffer;
  assign fl_vs_fetched_2b = (fl_vs_fetched > 2) ? 2'b10 : fl_vs_fetched[1:0];

  assign haz_nDispatched = (br_pred_wrong) ? 0: (rob_vs_rs_2b < fl_vs_fetched_2b) ? 
                           rob_vs_rs_2b : fl_vs_fetched_2b;

endmodule // if_id_hazard

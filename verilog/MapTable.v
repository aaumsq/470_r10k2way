`define MT_DEBUG
module MapTable(
    input logic clk,
    input logic reset,
    
    input ARCH_REG[1:0]          de_destidx,
    input ARCH_REG[1:0]          de_regAidx,
    input ARCH_REG[1:0]          de_regBidx,
    input PHYS_REG[1:0]          fl_freeRegs,
    input logic[1:0]             haz_nDispatched,
    input logic[1:0]             cdb_rd_en,
    input PHYS_REG[1:0]          cdb_rd,
    input logic                  br_pred_wrong,
    input PHYS_WITH_READY [30:0] bs_recov_map,
    
    output PHYS_WITH_READY[1:0]  mt_tagA,
    output PHYS_WITH_READY[1:0]  mt_tagB,
    output PHYS_REG [1:0]        mt_dispatchTagOld,
    output PHYS_WITH_READY[30:0] mt_nextMap   //doesn't include 31 because it is constant


    `ifdef MT_DEBUG
      , output PHYS_WITH_READY [31:0] map
    `endif
  );
  
  `ifndef MT_DEBUG
    PHYS_WITH_READY [31:0] map;
  `endif

  
  assign mt_tagA[0] = map[de_regAidx[0]];
  assign mt_tagB[0] = map[de_regBidx[0]];
  assign mt_dispatchTagOld[0] = map[de_destidx[0]].register;

  assign mt_tagA[1].register = ((de_regAidx[1] == de_destidx[0]) && (de_destidx[0] != `ZERO_REG))? 
                               fl_freeRegs[0]: map[de_regAidx[1]].register;
  assign mt_tagB[1].register = ((de_regBidx[1] == de_destidx[0]) && (de_destidx[0] != `ZERO_REG))?
                               fl_freeRegs[0]:map[de_regBidx[1]].register;
  assign mt_tagA[1].ready = ((de_regAidx[1] == de_destidx[0]) && (de_destidx[0] != `ZERO_REG))?
                            0: map[de_regAidx[1]].ready;
  assign mt_tagB[1].ready = ((de_regBidx[1] == de_destidx[0]) && (de_destidx[0] != `ZERO_REG))?
                            0: map[de_regBidx[1]].ready;
  assign mt_dispatchTagOld[1] = ((de_destidx[0] == de_destidx[1]) && (de_destidx[0] != `ZERO_REG))
                                ? fl_freeRegs[0] : map[de_destidx[1]].register;

  always_comb begin
      //defaults      
    if(br_pred_wrong) begin
      mt_nextMap = bs_recov_map;
    end else begin
      mt_nextMap = map[30:0];
    end
        
      //complete
    for(int i = 0; i < 31; i++) begin
      for(int j = 0; j < 2; j++) begin
        if(cdb_rd_en[j]) begin
          if(mt_nextMap[i].register == cdb_rd[j]) begin //use netMap because it maybe coming from bs_recov
            mt_nextMap[i].ready = 1;
          end
        end
      end
    end
    
      //dispatch
    for(int i = 0; i < 2; i++) begin
      if(haz_nDispatched > i && de_destidx[i] != 5'd31) begin
        mt_nextMap[de_destidx[i]].register = fl_freeRegs[i];
        mt_nextMap[de_destidx[i]].ready = 0;
      end
    end
  end
  
  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      for(int i = 0; i < 32; i++) begin
        map[i].register <= `SD i;
        map[i].ready <= `SD 1;
      end
    end else begin
      map[30:0] <= `SD mt_nextMap;
    end
  end
endmodule

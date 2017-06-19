/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.v                                           //
//                                                                     //
//  Description :  This module creates the Regfile                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`timescale 1ns/100ps

`define RF_DEBUG
module regfile(
    input logic    clk,
    input logic    reset,
    input PHYS_REG rda_idx, rdb_idx, rdc_idx, rdd_idx, wra_idx, wrb_idx,
    input [63:0]   wra_data, wrb_data,
    input logic    wra_en, wrb_en,

    output logic [63:0] rf_rda_out, rf_rdb_out, rf_rdc_out, rf_rdd_out 
    `ifdef RF_DEBUG
      , output logic [63:0] [63:0] registers   // 64, 64-bit Registers
    `endif    
    );
    
  `ifndef RF_DEBUG
    logic [63:0] [63:0] registers;   // 64, 64-bit Registers
  `endif
  
  logic [63:0] rda_reg;
  logic [63:0] rdb_reg;
  logic [63:0] rdc_reg;
  logic [63:0] rdd_reg;

  always_comb begin
    rda_reg = registers[rda_idx];
    rdb_reg = registers[rdb_idx];
    rdc_reg = registers[rdc_idx];
    rdd_reg = registers[rdd_idx];
  end

  //
  // Read port A
  //
  always_comb begin
    if (rda_idx == `PHYS_ZERO_REG)
      rf_rda_out = 0;
    else if (wra_en && (wra_idx == rda_idx))
      rf_rda_out = wra_data;  // internal forwarding
    else if (wrb_en && (wrb_idx == rda_idx))
      rf_rda_out = wrb_data;  // internal forwarding
    else
      rf_rda_out = rda_reg;
  end

  //
  // Read port B
  //
  always_comb begin
    if (rdb_idx == `PHYS_ZERO_REG)
      rf_rdb_out = 0;
    else if (wra_en && (wra_idx == rdb_idx))
      rf_rdb_out = wra_data;  // internal forwarding
    else if (wrb_en && (wrb_idx == rdb_idx))
      rf_rdb_out = wrb_data;  // internal forwarding
    else
      rf_rdb_out = rdb_reg;
  end

  //
  // Read port C
  //
  always_comb begin
    if (rdc_idx == `PHYS_ZERO_REG)
      rf_rdc_out = 0;
    else if (wra_en && (wra_idx == rdc_idx))
      rf_rdc_out = wra_data;  // internal forwarding
    else if (wrb_en && (wrb_idx == rdc_idx))
      rf_rdc_out = wrb_data;  // internal forwarding
    else
      rf_rdc_out = rdc_reg;
  end

  //
  // Read port D
  //
  always_comb begin
    if (rdd_idx == `PHYS_ZERO_REG)
      rf_rdd_out = 0;
    else if (wra_en && (wra_idx == rdd_idx))
      rf_rdd_out = wra_data;  // internal forwarding
    else if (wrb_en && (wrb_idx == rdd_idx))
      rf_rdd_out = wrb_data;  // internal forwarding
    else
      rf_rdd_out = rdd_reg;
  end


  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      registers[31] <= `SD 0;
    end else begin
      // Write port A
      if (wra_en) begin
        registers[wra_idx] <= `SD wra_data;
        //$display("RF: writing reg[%0d]=%0d", wra_idx, wra_data);
      end
      // Write port b    
      if (wrb_en) begin
        registers[wrb_idx] <= `SD wrb_data;
        //$display("RF: writing reg[%0d]=%0d", wrb_idx, wrb_data);
      end
    end
  end

endmodule // regfile

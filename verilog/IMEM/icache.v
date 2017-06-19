// cachemem32x64

`timescale 1ns/100ps

module icache(
        input clock, reset, wr_en,
        input  ICACHE_FULL_IDX wr_idx, pf_idx, 
        input  ICACHE_BANK_IDX rd_even_idx, rd_odd_idx,
        input  ICACHE_TAG wr_tag, rd_even_tag, rd_odd_tag, pf_tag,
        input  DATA wr_data, 

        output DATA rd_even_data, rd_odd_data,
        output rd_even_valid, rd_odd_valid, pf_in_cache
      );
      
  DATA[15:0] evenData;
  DATA[15:0] oddData;
  ICACHE_TAG[15:0] evenTags; 
  ICACHE_TAG[15:0] oddTags; 
  logic[15:0] evenValids;
  logic[15:0] oddValids;

  assign rd_even_data = evenData[rd_even_idx];
  assign rd_odd_data = oddData[rd_odd_idx];
  assign rd_even_valid = evenValids[rd_even_idx] && (evenTags[rd_even_idx] == rd_even_tag);
  assign rd_odd_valid = oddValids[rd_odd_idx] && (oddTags[rd_odd_idx] == rd_odd_tag);

  assign pf_in_cache = pf_idx[0]? oddValids[pf_idx[4:1]] && (oddTags[pf_idx[4:1]] == pf_tag)
                                : evenValids[pf_idx[4:1]] && (evenTags[pf_idx[4:1]] == pf_tag);

  always_ff @(posedge clock)
  begin
    if(reset) begin
      evenValids <= `SD 16'b0;
      oddValids <= `SD 16'b0;
    end else if(wr_en/* && wr_data*/) begin
      if(wr_idx[0]) begin
        oddValids[wr_idx[4:1]] <= `SD 1;
        oddData[wr_idx[4:1]] <= `SD wr_data;
        oddTags[wr_idx[4:1]] <= `SD wr_tag;
      end else begin
        evenValids[wr_idx[4:1]] <= `SD 1;
        evenData[wr_idx[4:1]] <= `SD wr_data;
        evenTags[wr_idx[4:1]] <= `SD wr_tag;      
      end
    end
//    $display("ICache: ");
//    $display("rd_even_tag: %d, rd_even_idx: %d", rd_even_tag, rd_even_idx);
//    $display("rd_odd_tag: %d, rd_odd_idx: %d", rd_odd_tag, rd_odd_idx);
  end
endmodule

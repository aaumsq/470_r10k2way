// cachemem32x64

`timescale 1ns/100ps

module dcache(
        input logic clock, reset, 
        input DCACHE_IDX[1:0] rd_idx,
        input DCACHE_TAG[1:0] rd_tag,
        input logic           ld_en,
        input DCACHE_IDX      ld_idx,
        input DCACHE_TAG      ld_tag,
        input DATA            ld_data,
        input logic           st_en,
        input DCACHE_IDX      st_idx,
        input DCACHE_TAG      st_tag,
        input DATA            st_data, 

        output DATA[1:0] rd_data,
        output logic[1:0] rd_valid
        
      );



  DATA[31:0] data;
  DCACHE_TAG[31:0] tags; 
  logic [31:0] valids;
  
  genvar i;
  generate
    for(i = 0; i < 2; i++) begin
      assign rd_data[i] = data[rd_idx[i]];
      assign rd_valid[i] = valids[rd_idx[i]] && (tags[rd_idx[i]] == rd_tag[i]);
    end
  endgenerate

  /*always_comb begin
    for(int i = 0; i < 2; i++) begin
      $display("rd_valid[%0d]: %0d, rd_idx[%0d]: %0d, valids[%0d]: %0d, tags[%0d]: %0d, rd_tag[%0d]: %0d",
              i, rd_valid[i], i, rd_idx[i], rd_idx[i], valids[rd_idx[i]], rd_idx[i], tags[rd_idx[i]],
              i, rd_tag[i]);
    end    
  end*/

  always_ff @(posedge clock)
  begin
    if(reset) begin
      valids <= `SD 32'b0;
    end else begin 
      if(st_en) begin
        valids[st_idx] <= `SD 1;
        data[st_idx]   <= `SD st_data;
        tags[st_idx]   <= `SD st_tag;
      end
      if(ld_en && !(ld_idx == st_idx)) begin
        valids[ld_idx] <= `SD 1;
        data[ld_idx]   <= `SD ld_data;
        tags[ld_idx]   <= `SD ld_tag;        
      end
    end
  end
endmodule

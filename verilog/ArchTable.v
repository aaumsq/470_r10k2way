module ArchTable(
    input logic clk,
    input logic reset,
    
    input PHYS_REG[1:0]          rob_retireTag,
    input PHYS_REG[1:0]          rob_retireTagOld,
    input logic[1:0]             rob_nRetired,
    
    output PHYS_WITH_READY [31:0] at_map
  );
  
  PHYS_WITH_READY [30:0] nextMap;
    
  always_comb begin
      //defaults
    for(int i = 0; i < 31; i++) begin
      nextMap[i] = at_map[i];
    end
      //retire
    for(int i = 0; i < 31; i++) begin
      for(int j = 0; j < rob_nRetired; j++) begin
        if(nextMap[i].register == rob_retireTagOld[j]) begin
          nextMap[i].register = rob_retireTag[j];
        end
      end
    end
  end
  
  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      for(int i = 0; i < 32; i++) begin
        at_map[i].register <= `SD i;
        at_map[i].ready <= `SD 1;
      end
    end else begin
      at_map[30:0] <= `SD nextMap[30:0];
    end
  end
endmodule

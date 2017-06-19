module memAlu(
  input DATA data_op,
  input DATA addr_op,
  input DE_control_t control,
    
  output DATA data,
  output ADDR addr);
  
  assign data = data_op;
  assign addr = addr_op + {{48{control.ib_data.instruction[15]}}, control.ib_data.instruction[15:0]};
  
  /*always_comb begin
    $display("memAlu addr: %0d", addr);
  end*/
endmodule

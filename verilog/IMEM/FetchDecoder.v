// Decode an instruction: given instruction bits IR produce the
// appropriate datapath control signals.
//
// This is a *combinational* module (basically a PLA).
//
module FetchDecoder(
    input INSTRUCTION   inst,
    output FD_control_t fd_control
  );
  
  assign fd_control.branch = fd_control.cond_branch || fd_control.uncond_branch;

  always_comb begin
    // default control values:
    // - valid instructions must override these defaults as necessary.
    //   de_control_out.opa_select, de_control_out.opb_select, and de_control_out.alu_func should be set explicitly.
    // - invalid instructions should clear de_control_out.valid_inst.
    // - These defaults are equivalent to a noop
    // * see sys_defs.vh for the constants used here
    fd_control.halt = `FALSE;
    fd_control.cond_branch = `FALSE;
    fd_control.uncond_branch = `FALSE;
    fd_control.wr_mem = `FALSE;
    if(({inst[31:29], 3'b0} == 6'h18) && (inst[31:26] == `JSR_GRP)) begin
      fd_control.uncond_branch = `TRUE;
    end
    if(({inst[31:29], 3'b0} == 6'h30) || ({inst[31:29], 3'b0} == 6'h38)) begin
      if((inst[31:26] == `BR_INST) || (inst[31:26] == `BSR_INST)) begin
        fd_control.uncond_branch = `TRUE;
      end else begin
        fd_control.cond_branch = `TRUE; // all others are conditional
      end
    end
    if(({inst[31:29], 3'b0} == 6'h08) || ({inst[31:29], 3'b0} == 6'h20) || ({inst[31:29], 3'b0} == 6'h28)) begin
      if(inst[31:26] == `STQ_INST) begin
        fd_control.wr_mem = `TRUE;
      end
    end
    if(inst == `PAL_HALT) begin
      fd_control.halt = `TRUE;
    end
  end // always_comb

endmodule // decoder

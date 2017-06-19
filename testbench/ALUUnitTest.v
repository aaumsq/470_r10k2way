`timescale 1ns/100ps

/*
runs the following code : 
  lda $r5,1   # i=1 
jloop:
  bne $r5,ifinish       #conditional branch taken
  subq $r19,3,$r5  #index to a[j]   #subtract with imme r19 = 1 - 3 = fffffffffffffffe
  beq $r19, ifinish       #conditional branch not taken         
  br jloop          #unconditoinal branch taken
ifinish:      
  addq $r9,$r19,$r5       #add with 2 registers   
*/

module testbench();
  //alu_fu inputs
  logic             fus_en;
  DATA              fus_opA;
  DATA              fus_opB;
  PHYS_REG          fus_tagDest;
  DE_control_t      fus_control;
  B_MASK            fus_bmask;
  BS_PTR            fus_bs_ptr;
  logic             br_fub_pred_wrong;
  logic             br_fub_done;
  BS_PTR            br_fub_bs_ptr;

  //alu_fu outputs
  PHYS_REG          alu_tagDest;
  DATA              alu_result;
  logic             alu_done;
  B_MASK            alu_bmask;
  BS_PTR            alu_bs_ptr;
  logic             alu_pred_taken;
  logic             alu_pred_wrong;
  PC                alu_recov_NPC;

  // Testing Variables
  IBEntry_t         ib_data;

  alu_fu alu_fu0(.fus_en(fus_en),
                 .fus_opA(fus_opA),
                 .fus_opB(fus_opB),
                 .fus_tagDest(fus_tagDest),
                 .fus_control(fus_control),
                 .fus_bmask(fus_bmask),            
                 .fus_bs_ptr(fus_bs_ptr),
                 .br_fub_pred_wrong(br_fub_pred_wrong),
                 .br_fub_done(br_fub_done),
                 .br_fub_bs_ptr(br_fub_bs_ptr),

                 .alu_tagDest(alu_tagDest),
                 .alu_result(alu_result),
                 .alu_done(alu_done),
                 .alu_bmask(alu_bmask),
                 .alu_bs_ptr(alu_bs_ptr),
                 .alu_pred_taken(alu_pred_taken),
                 .alu_pred_wrong(alu_pred_wrong),
                 .alu_recov_NPC(alu_recov_NPC)
                );

  decoder de0(.ib_valid(fus_en), .ib_data(ib_data), .de_control(fus_control));

  logic clk;
  // Drive clk
  always begin
      #5;
      clk = ~clk;
  end

  //check output values
  task check_output;
    input  logic [63:0]  ans_result;

    check_no_result();

    if(alu_result != ans_result) begin
      $display("alu_result (dec) = %d ; ans_result (dec) = %d", alu_result, ans_result);
      $finish;
    end

  endtask 

  task check_no_result;
    $display("----------------------------------------------------------");
    $display("now at instruction %h", ib_data.instruction);
    if(fus_tagDest != alu_tagDest) begin
      $display("alu_tagDest (hex) = %h ; fus_tagDest (hex) = %h", alu_tagDest, fus_tagDest);
      $finish;
    end
    if(fus_en != alu_done) begin
      $display("alu_done (bin) = %b ; fus_en (bin) = %b", alu_done, fus_en);
      $finish;
    end
  endtask

  // Print regfile arguments
  task print_values;
    $display("");
  endtask 


  initial begin
    clk = 0;
    //initial values
    //fu not enabled
    fus_en                      = 0;
    fus_opA                     = 64'hf000_0000_0000_0001;
    fus_opB                     = 64'h0;
    fus_tagDest                 = 32;
    ib_data.instruction         = 32'h20bf0001;
    // fus_control.opa_select      = `ALU_OPA_IS_MEM_DISP;
    // fus_control.opb_select      = `ALU_OPB_IS_REGB;
    // fus_control.dest_reg        = `DEST_IS_REGA;
    // fus_control.alu_func        = `ALU_ADDQ;
    // fus_control.rd_mem          = 0;
    // fus_control.wr_mem          = 0;
    // fus_control.ldl_mem         = 0;
    // fus_control.stc_mem         = 0;
    // fus_control.cond_branch     = 0;
    // fus_control.uncond_branch   = 0;
    // fus_control.halt            = 0;
    // fus_control.illegal         = 0;
    // fus_control.valid_inst      = 1;
    // fus_control.writes_to_zero  = 0;
    @(negedge clk);
    check_no_result();
    @(posedge clk);

    //fu enabled
    fus_en                      = 1;
    @(negedge clk);
    check_output(1);
    @(posedge clk);

    fus_en                      = 1;
    fus_opA                     = 64'hf000_0000_0000_0001;
    fus_opB                     = 64'h123;
    fus_tagDest                 = 31;
    ib_data.instruction         = 32'hf4a00003;
    // fus_control.opa_select      = `ALU_OPA_IS_NPC;
    // fus_control.opb_select      = `ALU_OPB_IS_BR_DISP;
    // fus_control.dest_reg        = `DEST_NONE;
    // fus_control.alu_func        = `ALU_ADDQ;
    // fus_control.rd_mem          = 0;
    // fus_control.wr_mem          = 0;
    // fus_control.ldl_mem         = 0;
    // fus_control.stc_mem         = 0;
    // fus_control.cond_branch     = 1;
    // fus_control.uncond_branch   = 0;
    // fus_control.halt            = 0;
    // fus_control.illegal         = 0;
    // fus_control.valid_inst      = 1;
    // fus_control.writes_to_zero  = 1;
    @(negedge clk);
    check_output(20);
    @(posedge clk);

    fus_en                      = 1;
    fus_opA                     = 64'h0000_0000_0000_0001;
    fus_opB                     = 64'hffff;
    fus_tagDest                 = 19;
    ib_data.instruction         = 32'h42607525;
    @(negedge clk);
    check_output(64'hfffffffffffffffe);
    @(posedge clk);

    fus_en                      = 1;
    fus_opA                     = 64'hffff_ffff_ffff_fffe;
    fus_opB                     = 64'h0;
    fus_tagDest                 = 31;
    ib_data.instruction             = 32'he6600001;
    @(negedge clk);
    check_output(20);
    @(posedge clk);

    fus_en                      = 1;
    fus_opA                     = 64'hffff_0000_0000_0000;
    fus_opB                     = 64'h0000_0000_0000_ffff;
    fus_tagDest                 = 31;
    ib_data.instruction         = 32'hc3fffffc;
    @(negedge clk);
    check_output(4);
    @(posedge clk);


    fus_en                      = 1;
    fus_opA                     = 64'h0000_0000_0000_0001;
    fus_opB                     = 64'hffff_ffff_ffff_fffe;
    fus_tagDest                 = 9;
    ib_data.instruction         = 32'h41300409;
    @(negedge clk);
    check_output(64'hffff_ffff_ffff_ffff);
    @(posedge clk);


    $display("PASSED");
    $finish;
  end

endmodule // testbench

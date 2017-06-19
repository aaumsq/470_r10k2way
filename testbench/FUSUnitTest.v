module testbench();
  logic clk;

  // FUS Inputs
  logic         [1:0] rs_fu_en;
  DATA          [1:0] rf_opA;
  DATA          [1:0] rf_opB;
  PHYS_REG      [1:0] rs_tagDest;
  DE_control_t  [1:0] rs_control;
  B_MASK        [1:0] rs_bmask;
  BS_PTR        [1:0] rs_bs_ptr;

  // FUS Outputs
  logic               fus_en;
  DATA                fus_opA;
  DATA                fus_opB;
  PHYS_REG            fus_tagDest;
  DE_control_t        fus_control;
  B_MASK              fus_bmask;
  BS_PTR              fus_bs_ptr;

  FUS DUT(
    .rs_fu_en(rs_fu_en),
    .rf_opA(rf_opA),
    .rf_opB(rf_opB),
    .rs_tagDest(rs_tagDest),
    .rs_control(rs_control),
    .rs_bmask(rs_bmask),
    .rs_bs_ptr(rs_bs_ptr),

    .fus_en(fus_en),
    .fus_opA(fus_opA),
    .fus_opB(fus_opB),
    .fus_tagDest(fus_tagDest),
    .fus_control(fus_control),
    .fus_bmask(fus_bmask),
    .fus_bs_ptr(fus_bs_ptr)
  );

  // Drive clk
  always
  begin
    #5;
    clk = ~clk;
  end

  // Display messages and finish
  task end_for_failure;
    print_values();
    $display("FUS Failed");
    $finish;
  endtask

  // Print regfile arguments
  task print_values;
    $display("Time:%4.0f FUS_EN:%h FUS_OPA:%h FUS_OPB:%h FUS_TAGDEST:%h FUS_CONTROL:%h",
            $time, fus_en, fus_opA, fus_opB, fus_tagDest, fus_control);
  endtask

  // Test Cases
  initial
  begin
    // Set initial values
    clk = 0;
    rs_fu_en = 2'b01;
    rf_opA = {64'h10, 64'h20};
    rf_opB = {64'h30, 64'h40};
    rs_tagDest = {6'h5, 6'h10};
    rs_control = {179'h11111, 179'h22222};

    @(negedge clk);
    if (!(fus_en == 1 &&
          fus_opA == 64'h20 &&
          fus_opB == 64'h40 &&
          fus_tagDest == 6'h10 &&
          fus_control == 20'h22222))
      end_for_failure();
    @(negedge clk);

    rs_fu_en = 2'b10;
    
    @(negedge clk);
    if (!(fus_en == 1 &&
          fus_opA == 64'h10 &&
          fus_opB == 64'h30 &&
          fus_tagDest == 6'h5 &&
          fus_control == 20'h11111))
      end_for_failure();
    @(negedge clk);

    rs_fu_en = 2'b00;

    @(negedge clk);
    if (!(fus_en == 0 &&
          fus_opA == 64'h0 &&
          fus_opB == 64'h0 &&
          fus_tagDest == `PHYS_ZERO_REG &&
          fus_control == 0))
      end_for_failure();
    @(negedge clk);

    $display("PASSED");
    $finish;
  end

endmodule

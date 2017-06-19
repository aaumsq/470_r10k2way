`timescale 1ns/100ps

module testbench();

  // Regfile Inputs
  PHYS_REG      rda_idx, rdb_idx, rdc_idx, rdd_idx, wra_idx, wrb_idx;
  logic [63:0]  wra_data, wrb_data;
  logic         wra_en, wrb_en;
  logic         clk;

  // Regfile Outputs
  logic [63:0] rf_rda_out, rf_rdb_out, rf_rdc_out, rf_rdd_out;

  regfile DUT(
    .rda_idx(rda_idx),
    .rdb_idx(rdb_idx),
    .rdc_idx(rdc_idx),
    .rdd_idx(rdd_idx),
    .wra_idx(wra_idx),
    .wrb_idx(wrb_idx),
    .wra_data(wra_data),
    .wrb_data(wrb_data),
    .wra_en(wra_en),
    .wrb_en(wrb_en),
    .clk(clk),

    .rf_rda_out(rf_rda_out),
    .rf_rdb_out(rf_rdb_out),
    .rf_rdc_out(rf_rdc_out),
    .rf_rdd_out(rf_rdd_out)
  );

  // Drive clk
  always
  begin
    #5;
    clk = ~clk;
  end

  // Display messages and finish
  task end_for_failure;
    $display("Regfile Failed");
    $finish;
  endtask

  // Print regfile arguments
  task print_values;
    $display("Time:%4.0f ReadA:%d ReadB:%d ReadC:%d ReadD:%d IdxA:%d IdxB:%d IdxC:%d IdxD:%d",
            $time, rf_rda_out, rf_rdb_out, rf_rdc_out, rf_rdd_out,
            rda_idx, rdb_idx, rdc_idx, rdd_idx);
  endtask

  // Test Cases
  initial
  begin
    // Set initial values
    clk = 0;
    rda_idx = 0;
    rdb_idx = 0;
    rdc_idx = 0;
    rdd_idx = 0;
    wra_idx = 0;
    wrb_idx = 0;
    wra_data = 0;
    wrb_data = 0;
    wra_en = 1;
    wrb_en = 1;
    
    // General Cases
    for (int i = 0; i < 64; i += 2) begin
      wra_idx = i;
      wrb_idx = i + 1;

      wra_data = i;
      wrb_data = i + 1;

      @(negedge clk);
    end
    
    for (int i = 0; i < 64; i += 4) begin
      rda_idx = i;
      rdb_idx = i + 1;
      rdc_idx = i + 2;
      rdd_idx = i + 3;

      @(negedge clk);

      print_values();

      if (rf_rda_out != i)
        end_for_failure();
      if (rf_rdb_out != i + 1)
        end_for_failure();
      if (rf_rdc_out != i + 2)
        end_for_failure();
      if (rf_rdd_out != i + 3) begin
        if (!(rf_rdd_out == 0 && rdd_idx == `PHYS_ZERO_REG))
          end_for_failure();
      end
    end
    
    // Zero Reg Corner Case
    @(posedge clk);
    wra_idx = `PHYS_ZERO_REG;
    wrb_idx = `PHYS_ZERO_REG;
    wra_data = 7;
    wrb_data = 1203487;

    rda_idx = `PHYS_ZERO_REG;
    rdb_idx = `PHYS_ZERO_REG;

    #0.5;

    print_values();

    if (rf_rda_out != 0)
      end_for_failure();
    if (rf_rdb_out != 0)
      end_for_failure();
    if (rf_rdc_out != rdc_idx)
      end_for_failure();
    if (rf_rdd_out != rdd_idx)
      end_for_failure();
    
    // Internal Forwarding Case
    @(posedge clk);
    rda_idx = 1;
    rdb_idx = 2;
    wra_idx = 1;
    wrb_idx = 2;
    wra_data = 10;
    wrb_data = 15;

    #0.5;

    print_values();

    if (rf_rda_out != 10)
      end_for_failure();
    if (rf_rdb_out != 15)
      end_for_failure();
    
    $display("PASSED");
    $finish;
  end

endmodule

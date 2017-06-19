`timescale 1ns/100ps

extern int get_fub_valid();
extern int get_fub_tagDest(int idx);
extern int get_fub_result(int idx);

extern void updateSim();
extern void init_sim();
extern int checkCDB(int cdb_rd0V, int cdb_rd1V, 
  int cdb_rd_en0V, int cdb_rd_en1V, int cdb_stallV, int cdb_reg0V, int cdb_reg1V);

module testbench();

  // CDB Inputs
  logic     [7:0] fub_valid;
  PHYS_REG  [7:0] fub_tagDest;
  DATA      [7:0] fub_result;

  // CDB Outputs 
  PHYS_REG  [1:0] cdb_rd;
  logic     [1:0] cdb_rd_en;
  logic     [7:0] cdb_stall;
  DATA      [1:0] cdb_reg_value;

  logic clk;

  CDB DUT(
    .fub_valid(fub_valid),
    .fub_tagDest(fub_tagDest),
    .fub_result(fub_result),
    .cdb_rd(cdb_rd),
    .cdb_rd_en(cdb_rd_en),
    .cdb_stall(cdb_stall),
    .cdb_reg_value(cdb_reg_value)
  );

  // Drive clk
  always
  begin
    #5;
    clk = ~clk;
  end

  // Display messages and finish
  task end_for_failure;
    $display("CDB Failed");
    $finish;
  endtask

  // Print regfile arguments
  task print_values;
    $display("---------------------------------------------------------------------------------------");
    $display("Time:%4.0f fub_valid:%b cdb_tagDest[0]:%d cdb_tagDest[1]:%d cdb_en[0]:%b cdb_en[1]:%b \ncdb_stall:%b cdb_reg_value[0]:%h cdb_reg_value[1]:%h",
            $time, fub_valid, cdb_rd[0], cdb_rd[1], cdb_rd_en[0], cdb_rd_en[1], cdb_stall, cdb_reg_value[0], cdb_reg_value[1]);
    $display("---------------------------------------------------------------------------------------");
  endtask

  task CompTest;
    init_sim();
    initCDB();
    for(int i = 0; i < 255; i++) begin
      @(negedge clk);
      if (!checkCDB(cdb_rd[0], cdb_rd[1], cdb_rd_en[0], cdb_rd_en[1], cdb_stall, cdb_reg_value[0], cdb_reg_value[1])) begin
        $finish;
      end
      updateSim();
      print_values();
      //Read inputs from the file
      fub_valid = get_fub_valid();
      for (int j = 0; j < 8; j++) begin
        fub_tagDest[j] = get_fub_tagDest(j);
        fub_result[j] = get_fub_result(j);
      end
      @(posedge clk);
            
    end    
  endtask
    
  task initCDB;
    clk = 0;
    for(int i = 0; i < 8; i++) begin
      fub_valid[i] = 1'b0;
      fub_tagDest[i] = i;
      fub_result[i] = i;
    end
    @(posedge clk);  
  endtask
    
  initial begin
    CompTest();

    $display("PASSED");
    $finish;
  end

endmodule

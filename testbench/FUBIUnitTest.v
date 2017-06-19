extern void init_filetest(string filename);
extern int readline();

extern int get_fu_result();
extern int get_fu_done();
extern int get_fu_tagDest();
extern int get_cdb_stall();
extern int get_pred_wrong();
extern int get_br_fub_done();
extern int get_bs_ptr();
extern int get_fu_bmask();

extern void print_fub(int valid0, int tag0, int bmask0, int valid1, int tag1, int bmask1);



`timescale 1ns/100ps

module testbench();
  logic               clk, reset;
  //FUB inputs
  DATA                fu_result;
  logic               fu_done;
  PHYS_REG            fu_tagDest;
  logic               cdb_stall;
  logic               br_fub_pred_wrong;
  logic               br_fub_done;
  BS_PTR              br_fub_bs_ptr;
  B_MASK              fu_bmask;

  //FUB outputs
  logic               fub_busy;
  logic               fub_valid;
  DATA                fub_result;
  PHYS_REG            fub_tagDest;
  FUBIBREntry_t[1:0]  buffer;

  `define FUB_DEBUG

  FUBi FUB0(.clk(clk),
           .reset(reset),
           .fu_result(fu_result),
           .fu_done(fu_done),
           .fu_tagDest(fu_tagDest),
           .cdb_stall(cdb_stall),
           .br_fub_done_in(br_fub_done),
           .br_fub_pred_wrong_in(br_fub_pred_wrong),
           .br_fub_bs_ptr_in(br_fub_bs_ptr),
           .fu_bmask(fu_bmask),
           .br_pred_taken(unused0),
           .br_pred_wrong(unused1),
           .br_bs_ptr(unusedbsptr0),
           .br_recov_NPC(unusedPC0),
           .fub_busy(fub_busy),
           .fub_valid(fub_valid),
           .fub_result(fub_result),
           .fub_tagDest(fub_tagDest),
           .br_fub_pred_taken(unused2),
           .br_fub_pred_wrong(unused3),
           .br_fub_bs_ptr(unusedbsptr1),
           .br_fub_recov_NPC(unusedPC1),
           .buffer(buffer)
           );

  // Drive clk
  always begin
      #5;
      clk = ~clk;
  end

  task init_FUB;
    clk = 1'b0;
    reset = 1'b1;
  endtask

  task filetest;
    input string filename;
    init_FUB();
    init_filetest(filename);
    while(1) begin
      @(negedge clk);
      print();
      //checkSim();
      //Read inputs from the file
      if(readline()) begin
        break;
      end
      getInputsFromC();
      @(posedge clk);
      //updateSim();      
    end    
  endtask
    
  task getInputsFromC;
    reset = 0;
    fu_result = get_fu_result();
    fu_done = get_fu_done();
    fu_tagDest = get_fu_tagDest();
    cdb_stall = get_cdb_stall();
    fu_bmask = get_fu_bmask();
    br_fub_bs_ptr = get_bs_ptr();
    br_fub_pred_wrong = get_pred_wrong();
    br_fub_done = get_br_fub_done();
  endtask

  task print;
    print_fub(buffer[0].valid, buffer[0].tagDest, buffer[0].bmask,
                  buffer[1].valid, buffer[1].tagDest, buffer[1].bmask);
  $display("---------------------------------------------------------------");
  endtask  

  initial begin
    init_FUB();
    filetest("test_cases/FUBICornerCases");

    $display("PASSED");
    $finish;
  end

endmodule // testbench

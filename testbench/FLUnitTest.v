extern void init_filetest(string filename);
extern int readLine();

extern int get_ext_nDispatched();
extern int get_rob_retireTagOld(int idx);
extern int get_rob_nRetired();

extern void updateSim();
extern int checkFLOutputs(int fl_availableRegsV, int ndispatched, int fl_freeRegs0, int fl_freeRegs1);
extern void printSimFL();

`define FL_DEBUG

module FLTest();

  logic clock, reset;
  
  logic[1:0]      haz_nDispatched;
  logic[1:0]      ext_nDispatched;
  PHYS_REG[1:0]   rob_retireTagOld;
  logic[1:0]      rob_nRetired;
  logic           br_fub_pred_wrong;
  FL_PTR          bs_recov_fl_tail;
  
  // FreeList Outputs
  PHYS_REG  [1:0]   fl_freeRegs;
  logic     [5:0]   fl_availableRegs;
  FL_PTR            fl_tail;
  FL_PTR            head;
  PHYS_REG  [31:0]  free;

  // Additional Test Variables
  logic     [1:0]   ext_nDispatched;
  PHYS_REG  [1:0]   test_freeRegs;

  assign haz_nDispatched = ext_nDispatched < fl_availableRegs? ext_nDispatched : fl_availableRegs;
  
  FreeList dut0(
    .clk(clock),
    .reset(reset),
    .haz_nDispatched(haz_nDispatched),
    .rob_retireTagOld(rob_retireTagOld),
    .rob_nRetired(rob_nRetired),
    .br_fub_pred_wrong(br_fub_pred_wrong),
    .bs_recov_fl_tail(bs_recov_fl_tail),
    .fl_freeRegs(fl_freeRegs),
    .fl_availableRegs(fl_availableRegs),
    .fl_tail(fl_tail),
    .head(head),
    .free(free));
  
  always #15 clock = ~clock;
  
  task printFL;
    $display("head: %d, fl_availableRegs: %d", head, fl_availableRegs);
    $write("Regs In Freelist: ");
    for(int i = head; i < head+fl_availableRegs; i++) begin
      $write("%d ", free[i&31]);
    end
    $display("");
    printOutputs();
  endtask
  
  task printOutputs;
    $write("Dispatched Freelist Regs: ");
    for(int i = 0; i < fl_availableRegs && i < ext_nDispatched; i++) begin
      $write("%d ", test_freeRegs[i]);
    end
    $display("\n-------------------------------------------------");
  endtask
  
  task fileTest;
    input string filename;
    int i = 0;
    init_filetest(filename);
    initFL();
    while(1) begin
      @(negedge clock);
      if(i++ != 0) begin
        checkSim();
      end
      printFL();
      //Read inputs from the file
      if(readLine()) begin
        break;
      end
      getInputsFromC();
      @(posedge clock);
      updateSim();      
    end    
  endtask
  
  task initFL();
    clock = 0;
    reset = 1;
    @(negedge clock);
  endtask
  
  task checkSim;
    if(!checkFLOutputs(fl_availableRegs, haz_nDispatched, test_freeRegs[0], test_freeRegs[1])) begin
      $display("FAILED, incorrect FL Outputs");
      $display("Verilog state:");
      printFL();
      $display("C simulation state:");
      printSimFL();
      $finish; 
    end
  endtask
  
  task getInputsFromC;
    reset = 0;
    ext_nDispatched = get_ext_nDispatched();
    rob_nRetired = get_rob_nRetired();
    for(int i = 0; i < rob_nRetired; i++) begin
      rob_retireTagOld[i] = get_rob_retireTagOld(i);
    end
  endtask
  
  initial begin
    fileTest("test_cases/FLCornerCases");
    $display("PASSED");
    $finish;
  end
  
  always_ff @(posedge clock) begin
    //test_availableRegs <= `SD fl_availableRegs;
    test_freeRegs <= `SD fl_freeRegs;
  end
endmodule

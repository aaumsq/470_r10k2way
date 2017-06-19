
extern void init_filetest(string filename);
extern int readLine();

extern void init_randomtest(int seed);
extern void getRandomValues();


extern int get_ib_nIsnBuffer();
extern int get_br_fub_pred_wrong();
extern int get_br_fub_done();
extern int get_bs_recov_rob_tail();
extern int get_if_id_instructions(int idx);
extern int get_if_id_NPC(int idx);
extern int get_rs_availableSlots();
extern int get_fl_availableRegs();
extern int get_fl_freeRegs(int idx);
extern int get_mt_dispatchTagOld(int idx);
extern int get_cdb_rd(int idx);
extern int get_cdb_rd_en(int idx);

extern void updateSim();
extern int checkROBState(int headV, int tailV, int rob_availableSlotsV, int prev_nRetiredV, 
  int rob_prev_retireTagV0, int rob_prev_retireTagV1, int rob_prev_retireTagOldV0, int rob_prev_retireTagOldV1); 
extern int checkROBEntry(int index, int completeV, int tagV, int tagOldV);
extern void printSimROB();


extern void print_ROBEntry(int idx, int complete, int tag, int tagOld);
extern void print_ROBHeader(int head, int tail, int rob_availableSlots, int prev_nRetired,
        int rob_prev_retireTag0, int rob_prev_retireTag1, int rob_prev_retireTagOld0, int rob_prev_retireTagOld1);
`define ROB_DEBUG
module ROBTest();

  logic clock, reset;
  logic[1:0] halt;
  
  //inputs to hazard detection
  logic[5:0] rob_availableSlots;
  logic[1:0] rob_nRetired;
  logic[1:0] rob_prev_nRetired;
  logic[4:0] rs_availableSlots;
  logic[5:0] fl_availableRegs;
  logic[1:0] ib_nIsnBuffer;
  //input from br_fub
  logic      br_fub_pred_wrong;           // if prediction is wrong
  //inputs from branch stack
  ROB_PTR     bs_recov_rob_tail;

  //output from hazard detection
  logic[1:0] haz_nDispatched;
  //inputs to ROB
  logic[1:0][31:0] if_id_instructions;
  logic[1:0][63:0] if_id_nextPC;
  PHYS_REG[1:0] fl_freeRegs;
  PHYS_REG[1:0] mt_dispatchTagOld;
  PHYS_REG[1:0] cdb_rd;
  logic[1:0] cdb_rd_en;
  //outputs from ROB
  PHYS_REG[1:0] rob_retireTag, rob_retireTagOld;
  PHYS_REG[1:0] rob_prev_retireTag, rob_prev_retireTagOld;
  ROBEntry_t[31:0] buffer;
  ROB_PTR head, rob_tail;
  logic rob_halted;
  
  
  ROB dut0(.clk(clock), .reset(reset), .halt(halt),
      .fl_freeRegs(fl_freeRegs), 
      .mt_dispatchTagOld(mt_dispatchTagOld), 
      .cdb_rd(cdb_rd), .cdb_rd_en(cdb_rd_en), 
      .haz_nDispatched(haz_nDispatched), .br_fub_pred_wrong(br_fub_pred_wrong),
      .bs_recov_rob_tail(bs_recov_rob_tail),
      .rob_availableSlots(rob_availableSlots), .rob_nRetired(rob_nRetired), 
      .rob_retireTag(rob_retireTag), .rob_retireTagOld(rob_retireTagOld), 
      .rob_tail(rob_tail), .rob_halted(rob_halted), .buffer(buffer), .head(head),
      .prev_nRetired(rob_prev_nRetired), .rob_prev_retireTag(rob_prev_retireTag),
      .rob_prev_retireTagOld(rob_prev_retireTagOld));
  
  if_id_hazard dut1(.rob_availableSlots(rob_availableSlots), 
      .rob_nRetired(rob_nRetired), 
      .rs_availableSlots(rs_availableSlots),
      .fl_availableRegs(fl_availableRegs), 
      .ib_nIsnBuffer(ib_nIsnBuffer),
      .br_fub_pred_wrong(br_fub_pred_wrong),
      .haz_nDispatched(haz_nDispatched));
  
  always #15 clock = ~clock;
  
  task printROB;
    int i;
    if(rob_availableSlots == 32) begin
      $display("ROB EMPTY at time %d:", $time);
    end else begin
      $display("ROB at time %d:", $time);
      print_ROBHeader(head, rob_tail, rob_availableSlots, rob_prev_nRetired,
              rob_prev_retireTag[0], rob_prev_retireTag[1], 
              rob_prev_retireTagOld[0], rob_prev_retireTagOld[1]);
      i = head;
      while(i != (rob_tail + 1)%32) begin
        print_ROBEntry(i, buffer[i].complete, buffer[i].tag, buffer[i].tagOld);
        i = (i+1)%32;
      end
      $display("-------------------------------------------------");
    end
  endtask
  
  task randTest;
    input int seed;
    input int n;
    $display("starting test (seed = %d, n = %d)", seed, n);
    init_randomtest(seed);
    initROB();
    for(int i = 0; i < n; i++) begin
      @(negedge clock);
      $display("checking sim");
      checkSim();
      $display("generating values");
      getRandomValues();
      $display("getting values");
      getInputsFromC();
      @(posedge clock);
      $display("updating sim");
      updateSim();
    end
  endtask
  
  task fileTest;
    input string filename;
    init_filetest(filename);
    initROB();
    while(1) begin
      @(negedge clock);
      checkSim();
      //Read inputs from the file
      if(readLine()) begin
        break;
      end
      getInputsFromC();
      @(posedge clock);
      updateSim();      
    end    
  endtask
  
  task initROB;
    clock = 0;
    reset = 1;
    @(posedge clock);  
  endtask
  
  task checkSim;
    if(!checkROBState(head, rob_tail, rob_availableSlots, rob_prev_nRetired, 
                rob_prev_retireTag[0], rob_prev_retireTag[1], rob_prev_retireTagOld[0], rob_prev_retireTagOld[1])) begin
      $display("FAILED, incorrect ROB state");
      $display("Verilog state:");
      printROB();
      $display("C simulation state:");
      printSimROB();
      $finish;
    end
    for(int i = 0; i < 32; i++) begin
      if(!checkROBEntry(i, buffer[i].complete, buffer[i].tag, buffer[i].tagOld)) begin
        $display("FAILED, incorrect ROB entry (%d)", i);
        $display("Verilog state:");
        printROB();
        $display("C simulation state:");
        printSimROB();
        $finish;                         
      end
    end
    
    printROB();  
  endtask
  
  task getInputsFromC;
    reset = 0;
    ib_nIsnBuffer = get_ib_nIsnBuffer();
    rs_availableSlots = get_rs_availableSlots();
    fl_availableRegs = get_fl_availableRegs();
    br_fub_pred_wrong = get_br_fub_pred_wrong();
    bs_recov_rob_tail = get_bs_recov_rob_tail();
    for(int i = 0; i < 2; i++) begin
      fl_freeRegs[i] = get_fl_freeRegs(i);
    end
    mt_dispatchTagOld[0] = get_mt_dispatchTagOld(0);
    mt_dispatchTagOld[1] = get_mt_dispatchTagOld(1);
    cdb_rd[0] = get_cdb_rd(0);
    cdb_rd[1] = get_cdb_rd(1);
    cdb_rd_en[0] = get_cdb_rd_en(0);
    cdb_rd_en[1] = get_cdb_rd_en(1);
  endtask
  
  initial begin
    fileTest("test_cases/robCornerCases");
    randTest(0, 5000);
    randTest(1, 5000);
    randTest(2, 5000);
    randTest(3, 5000);
    randTest(4, 5000);
    randTest(5, 5000);
    $display("PASSED");
    $finish;
  end
  
endmodule

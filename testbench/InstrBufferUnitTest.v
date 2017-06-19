
extern void init_filetest(string filename);
extern int readLine();

//extern void init_randomtest(int seed);
//extern void getRandomValues();


extern int get_br_fub_pred_wrong();
extern int get_haz_nDispatched();
extern int get_bs_nEntries();
extern int get_bp_pred_taken(int idx);
extern int get_bp_pred_NPC(int idx);
extern int get_bp_not_taken_NPC(int idx);
extern int get_if_inst_in(int idx);
extern int get_if_valid_in(int idx);
extern int get_fd_control_uncond(int idx);
extern int get_fd_control_cond(int idx);

extern void updateSim();
extern int checkIBState(int headV, int tailV, int numIns_bufferV, int ib_nIsnBufferV,
  int ib_fetch_instV0, int ib_fetch_instV1, int ib_validV0, int ib_validV1, int ib_nAvai); 
extern int checkIBEntry(int index, int instructionV, int fd_control_uncondV,
  int fd_control_condV, int pred_NPCV, int not_taken_NPCV, int bp_pred_takenV);
extern void printSimIB();


extern void print_IBEntry(int instruction, int fd_control_uncond, int fd_control_cond,
  int pred_NPC, int not_taken_NPC, int bp_pred_taken);
extern void print_IBHeader(int head, int tail, int numIns_buffer, int ib_nIsnBuffer, int ib_nAvai,
  int instruction0, int fd_control_uncond0, int fd_control_cond0,int pred_NPC0,
  int not_taken_NPC0, int bp_pred_taken0, int ib_valid0,
  int instruction1, int fd_control_uncond1, int fd_control_cond1,int pred_NPC1,
  int not_taken_NPC1, int bp_pred_taken1, int ib_valid1);


`define IB_DEBUG
module IBTest();

  logic clock, reset;
  
  // input from alu (execution)
  logic               br_fub_pred_wrong;
  // input from BP
  logic [1:0]         bp_pred_taken;
  PC    [1:0]         bp_pred_NPC;
  PC    [1:0]         bp_not_taken_NPC;
  // From IF stage
  INSTRUCTION [1:0]   if_inst_in;
  logic [1:0]         if_valid_in;
  FD_control_t [1:0]  fd_control;
  // From hazard detection
  logic [1:0]         haz_nDispatched;
  // From branch stack
  logic[2:0] bs_nEntries;
  
  // Output
  IBEntry_t [1:0]     ib_data;
  logic [1:0]         ib_valid;
  logic [1:0]         ib_nIsnBuffer;
  IBEntry_t [7:0] buffer;
  IB_PTR head, tail;
  logic[3:0] numIns_buffer;
  logic[1:0] ib_nAvai;
  
  //glue logic
  logic [2:0] three_bit;
  
  InstrBuffer dut0(.clk(clock), .reset(reset), 
      .br_fub_pred_wrong(br_fub_pred_wrong), 
      .bp_pred_taken(bp_pred_taken), 
      .bp_pred_NPC(bp_pred_NPC), .bp_not_taken_NPC(bp_not_taken_NPC), 
      .if_inst_in(if_inst_in), .if_valid_in(if_valid_in), .fd_control(fd_control), 
      .haz_nDispatched(haz_nDispatched), .bs_nEntries(bs_nEntries), 
      .ib_data(ib_data), .ib_valid(ib_valid), .ib_nIsnBuffer(ib_nIsnBuffer), .ib_nAvai(ib_nAvai),
      .numIns_buffer(numIns_buffer), .buffer(buffer), .head(head), .tail(tail));
  

  always #15 clock = ~clock;
  
  task printIB;
    $display("IB at time %d:", $time);
    print_IBHeader(head, tail, numIns_buffer, ib_nIsnBuffer, ib_nAvai,
    ib_data[0].instruction, ib_data[0].fd_control.uncond_branch,
    ib_data[0].fd_control.cond_branch, ib_data[0].pred_NPC,
    ib_data[0].not_taken_NPC, ib_data[0].bp_pred_taken, ib_valid[0],
  
    ib_data[1].instruction, ib_data[1].fd_control.uncond_branch,
    ib_data[1].fd_control.cond_branch, ib_data[1].pred_NPC,
    ib_data[1].not_taken_NPC, ib_data[1].bp_pred_taken, ib_valid[1]);


    for(int i = 0; i < 8; i++) begin
      print_IBEntry(buffer[i].instruction, buffer[i].fd_control.uncond_branch,
        buffer[i].fd_control.cond_branch, buffer[i].pred_NPC, 
        buffer[i].not_taken_NPC, buffer[i].bp_pred_taken);
    end
    $display("-------------------------------------------------");
  endtask
  
  /*
  task randTest;
    input int seed;
    input int n;
    $display("starting test (seed = %d, n = %d)", seed, n);
    init_randomtest(seed);
    initIB();
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
  */
  
  task fileTest;
    input string filename;
    init_filetest(filename);
    initIB();
    while(1) begin
      @(negedge clock);
      checkSim();
      //Read inputs from the file\

      if(readLine()) begin
        break;
      end

      getInputsFromC();
      @(posedge clock);
      updateSim();      
    end    
  endtask
  
  task initIB;
    clock = 0;
    reset = 1;
    @(posedge clock);  
  endtask
  
  task checkSim;
    if(!checkIBState(head, tail, numIns_buffer, ib_nIsnBuffer,
          ib_data[0].instruction, ib_data[1].instruction, ib_valid[0], ib_valid[1], ib_nAvai)) begin
      $display("FAILED, incorrect IB state");
      $display("Verilog state:");
      printIB();
      $display("C simulation state:");
      printSimIB();
      $finish;
    end
    if (head != tail) begin
      int i = head;
      while(i != tail) begin
        if(!checkIBEntry(i, buffer[i].instruction, buffer[i].fd_control.uncond_branch, buffer[i].fd_control.cond_branch,
         buffer[i].pred_NPC, buffer[i].not_taken_NPC, buffer[i].bp_pred_taken)) begin
          $display("FAILED, incorrect IB entry (%d)", i);
          $display("Verilog state:");
          printIB();
          $display("C simulation state:");
          printSimIB();
          $finish;                         
        end
        i = (i + 1)%8;
      end
    end
    
    printIB();  
  endtask
  
  task getInputsFromC;
    reset = 0;
    br_fub_pred_wrong = get_br_fub_pred_wrong();
    haz_nDispatched = get_haz_nDispatched();
    bs_nEntries = get_bs_nEntries();
    for(int i = 0; i < 2; i++) begin
      bp_pred_taken[i] = get_bp_pred_taken(i);
      bp_pred_NPC[i] = get_bp_pred_NPC(i);
      bp_not_taken_NPC[i] = get_bp_not_taken_NPC(i);
      if_inst_in[i] = get_if_inst_in(i);
      if_valid_in[i] = get_if_valid_in(i);
      fd_control[i].uncond_branch = get_fd_control_uncond(i);
      fd_control[i].cond_branch = get_fd_control_cond(i);
    end
  endtask
  
  initial begin
    fileTest("test_cases/ibCornerCases");
    $display("PASSED");
    $finish;
  end
  
endmodule

extern void print_RSHeader();
extern void print_RSEntry(int index, int instruction, int fuType, int tag, 
                              int tagA, int tagB, int aReady, int bReady);
extern void print_RSOutputs(int slots, int nIssue);
extern void print_fu_en(int fu_en0, int fu_en1, int fu_en2, int fu_en3, 
         int fu_en4, int fu_en5, int fu_en6, int fu_en7);  
          
extern void init_filetest(string filename);
extern int readLine();
extern int get_ext_nDispatched();
extern int get_de_instruction(int idx);
extern int get_de_fuType(int idx);
extern int get_if_id_NPC(int idx);
extern int get_fl_freeRegs(int idx);
extern int get_cdb_rd(int idx);
extern int get_cdb_rd_en(int idx);
extern int get_fuBusy(int idx);
extern int get_mt_tagA(int idx);
extern int get_mt_tagB(int idx);
extern int get_mt_aReady(int idx);
extern int get_mt_bReady(int idx);

extern void init_randomtest(int seed, int cdbSelective);
extern void getRandomValues();

extern void updateSim();

extern int checkRSState(int rs_availableSlots);
extern int checkRSEntry(int index, int valid, int tag, int tagA, int tagB, 
            int tagAReady, int tagBReady, int fuType);
extern int checkRSOutputs(int rs_nIssueV, int rs_issuePtr0V, int rs_issuePtr1V,
        int regA_val0V, int regA_val1V, int regB_val0V, int regB_val1V, 
        int rs_tagDest0V, int rs_tagDest1V);
extern int checkFU_EN(int f0, int f1, int f2, int f3, int f4, int f5, int f6, int f7);

extern void printSimRS();

`define RS_DEBUG
module RSTest();
  logic clock, reset;
    
    //inputs to hazard detection
  logic[1:0]  ext_nDispatched;
  logic[4:0]  rs_availableSlots;
    //output from hazard detection
  logic[1:0]  haz_nDispatched;
  assign haz_nDispatched = 
    (rs_availableSlots < ext_nDispatched)? rs_availableSlots: ext_nDispatched;
    
    //inputs to RS
  PC[1:0]           if_id_nextPC;
  PHYS_REG[1:0]     fl_freeRegs;
  PHYS_WITH_READY[1:0] mt_tagA;
  PHYS_WITH_READY[1:0] mt_tagB;
  FU_TYPE[1:0]      de_fuType;
  DE_control_t[1:0] de_control;
  INSTRUCTION[1:0]  de_instruction;
  logic[7:0]        fub_busy;
  logic[1:0]        cdb_rd_en;
  PHYS_REG[1:0]     cdb_rd;
  logic[3:0]    zero;
  assign zero = 0;
    //outputs from RS
  PHYS_REG[1:0]     rs_tagA;
  PHYS_REG[1:0]     rs_tagB;
  DE_control_t[1:0] rs_control;
  PHYS_REG[1:0]     rs_tagDest;
  logic[7:0][1:0]   rs_fu_en;
  INSTRUCTION[1:0]    rs_instruction;
  RSEntry_t[15:0]   entries;
  logic[1:0]        rs_nIssue;
  RS_PTR[1:0]       rs_issuePtr;
  
    //outputs from fake regfile
  PHYS_REG[1:0]     regA_val;
  PHYS_REG[1:0]     regB_val;
  
  
  RS dut0(.clk(clock), .reset(reset), .haz_nDispatched(haz_nDispatched),
      .fl_freeRegs(fl_freeRegs),
      .mt_tagA(mt_tagA), .mt_tagB(mt_tagB),
      .de_fuType(de_fuType), .de_control(de_control),
      .fub_busy(fub_busy),
      .cdb_rd_en(cdb_rd_en), .cdb_rd(cdb_rd),
      
      .bs_bmask(zero), .bs_ptr(zero), .br_fub_bs_ptr(zero), .br_fub_pred_wrong(zero), 
      .br_fub_done(zero),
      
      .rs_availableSlots(rs_availableSlots), .rs_tagA(rs_tagA), .rs_tagB(rs_tagB),
      .rs_control(rs_control), .rs_tagDest(rs_tagDest), .rs_fu_en(rs_fu_en), 
      .entries(entries), .rs_issuePtr(rs_issuePtr), .rs_nIssue(rs_nIssue)
  );
 
  
  //fake regfile, just saves the tags for a cycle
  always_ff @(posedge clock) begin
    regA_val <= `SD rs_tagA;
    regB_val <= `SD rs_tagB;
  end
  
  always #15 clock = ~clock;
  
 
  task printRS;
    $display("RS at time %d:", $time);
    print_RSHeader();
    for(int i = 0; i < 16; i++) begin
      if(entries[i].valid) begin
        print_RSEntry(i, entries[i].control.ib_data.not_taken_NPC, 
                      entries[i].fuType, entries[i].tag, 
                      entries[i].tagA.register, entries[i].tagB.register, 
                      entries[i].tagA.ready, entries[i].tagB.ready);
      end
    end
    print_RSOutputs(rs_availableSlots, rs_nIssue);
    for(int i = 0; i < rs_nIssue; i++) begin
      $display("rs_issuePtr: %d, tagb: %d", rs_issuePtr[i], entries[rs_issuePtr[i]].tagB.register);
      print_RSEntry(rs_issuePtr[i],  
                    entries[rs_issuePtr[i]].control.ib_data.instruction, 
                    entries[rs_issuePtr[i]].fuType, entries[rs_issuePtr[i]].tag, 
                    entries[rs_issuePtr[i]].tagA.register, entries[rs_issuePtr[i]].tagB.register, 
                    entries[rs_issuePtr[i]].tagA.ready, entries[rs_issuePtr[i]].tagB.ready);
    end
    print_fu_en(rs_fu_en[0], rs_fu_en[1], rs_fu_en[2], rs_fu_en[3], rs_fu_en[4], 
              rs_fu_en[5], rs_fu_en[6], rs_fu_en[7]);
    $display("-------------------------------------------------");
  endtask
  
  task fileTest;
    input string filename;
    init_filetest(filename);
    initRS();
    while(1) begin
      @(negedge clock);
      checkSim();
      //Read inputs from the fil
      if(readLine()) begin
        break;
      end
      getInputsFromC();
      @(posedge clock);
      updateSim();      
    end    
  endtask
  
  task randTest;
    input int seed;
    input int cdbSelective;
    input int n;
    $display("starting test (seed = %d, n = %d)", seed, n);
    init_randomtest(seed, cdbSelective);
    initRS();
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
  
  task initRS;
    clock = 0;
    reset = 1;
    @(posedge clock);  
  endtask
  
  task checkSim;
    if(!checkRSState(rs_availableSlots)) begin
      $display("FAILED, incorrect RS state");
      $display("Verilog state:");
      printRS();
      $display("C simulation state:");
      printSimRS();
      $finish;
    end
    for(int i = 0; i < 16; i++) begin
      if(!checkRSEntry(i, entries[i].valid, entries[i].tag, 
            entries[i].tagA.register, entries[i].tagB.register, 
            entries[i].tagA.ready, entries[i].tagB.ready, entries[i].fuType)) begin  
        $display("FAILED, incorrect RS entry (%d)", i);
        $display("Verilog state:");
        printRS();
        $display("C simulation state:");
        printSimRS();
        $finish;
    end
    end
    if(!checkRSOutputs(rs_nIssue, rs_issuePtr[0], rs_issuePtr[1],
                    regA_val[0], regA_val[1], regB_val[0], regB_val[1], 
                    rs_tagDest[0], rs_tagDest[1])
        || !checkFU_EN(rs_fu_en[0], rs_fu_en[1], rs_fu_en[2], rs_fu_en[3],
                      rs_fu_en[4], rs_fu_en[5], rs_fu_en[6], rs_fu_en[7])) begin
      $display("FAILED, incorrect RS outputs");
      $display("Verilog state:");
      printRS();
      $display("C simulation state:");
      printSimRS();
      $finish;
    end
    printRS();
  endtask;
  
  task getInputsFromC;
    reset = 0;
    
    ext_nDispatched = get_ext_nDispatched();
    for(int i = 0; i < 2; i++) begin
      de_instruction[i] = get_de_instruction(i);
      de_fuType[i] = FU_TYPE'(get_de_fuType(i));
      if_id_nextPC[i] = get_if_id_NPC(i);
      fl_freeRegs[i] = get_fl_freeRegs(i);
      mt_tagA[i].register = get_mt_tagA(i);
      mt_tagB[i].register = get_mt_tagB(i);
      mt_tagA[i].ready = get_mt_aReady(i);
      mt_tagB[i].ready = get_mt_bReady(i);
      
      cdb_rd[i] = get_cdb_rd(i);
      cdb_rd_en[i] = get_cdb_rd_en(i);
    end
    
    for(int i = 0; i < 8; i++) begin
      fub_busy[i] = get_fuBusy(i);
    end
  endtask
  
  initial begin
    fileTest("test_cases/RSCornerCases");
    randTest(0, 0, 5000);
    randTest(1, 0, 5000);
    randTest(2, 0, 5000);
    randTest(3, 1, 5000); 
    randTest(4, 1, 5000);
    randTest(5, 1, 5000);
    $display("PASSED");
    $finish;
  end
endmodule

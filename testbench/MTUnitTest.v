extern void printMapEntries(int index0, int reg0, int ready0, int reg8, int ready8, int reg16, int ready16, int reg24, int ready24);

extern void init_filetest(string filename);
extern int readLine();

extern void init_randomtest(int seed);
extern void getRandomValues();

extern int get_de_destidx(int idx);
extern int get_de_regAidx(int idx);
extern int get_de_regBidx(int idx);
extern int get_ext_nDispatched();
extern int get_fl_freeRegs(int idx);
extern int get_cdb_rd(int idx);
extern int get_cdb_rd_en(int idx);

extern int checkMapEntry(int arch, int phys, int ready);
extern int checkOutputs(int mt_tagA0, int mt_tagA1, int mt_tagB0, int mt_tagB1, 
          int aReady0, int aReady1, int bReady0, int bReady1,
          int mt_dispatchTagOld0,  int mt_dispatchTagOld1);

extern void updateSim();

extern void printSimMT();

`define MT_DEBUG
module MTTest();

  logic clock, reset;

  ARCH_REG[1:0]           de_destidx;
  ARCH_REG[1:0]           de_regAidx;
  ARCH_REG[1:0]           de_regBidx;
  PHYS_REG[1:0]           fl_freeRegs;
  logic[1:0]              haz_nDispatched;
  logic[1:0]              cdb_rd_en;
  PHYS_REG[1:0]           cdb_rd;
  logic                   br_fub_pred_wrong;
  PHYS_WITH_READY [30:0]  bs_recov_map;
    
  PHYS_WITH_READY[1:0]    mt_tagA;
  PHYS_WITH_READY[1:0]    mt_tagB;
  PHYS_REG [1:0]          mt_dispatchTagOld;
  PHYS_REG [1:0]          test_dispatchTagOld;

  PHYS_WITH_READY [31:0]  map;

  MapTable dut0(
    .clk(clock),
    .reset(reset),
    .de_destidx(de_destidx),
    .de_regAidx(de_regAidx),
    .de_regBidx(de_regBidx),
    .fl_freeRegs(fl_freeRegs),
    .haz_nDispatched(haz_nDispatched),
    .cdb_rd_en(cdb_rd_en),
    .cdb_rd(cdb_rd),
    .br_fub_pred_wrong(br_fub_pred_wrong),
    .bs_recov_map(bs_recov_map),
    .mt_tagA(mt_tagA),
    .mt_tagB(mt_tagB),
    .mt_dispatchTagOld(mt_dispatchTagOld),
    .map(map)
  );
  
  always #15 clock = ~clock;
  
  task printMT;
    for(int i = 0; i < 8; i++) begin
      printMapEntries(i, map[i].register, map[i].ready, 
                         map[i+8].register, map[i+8].ready, 
                         map[i+16].register, map[i+16].ready, 
                         map[i+24].register, map[i+24].ready);
    end
    printOutputs();
  endtask
  
  task printOutputs;
    $display("mt_tagA[0]=%d%s, mt_tagB[0]=%d%s, mt_dispatchTagOld[0]=%d, mt_tagA[1]=%d%s, mt_tagB[1]=%d%s, mt_dispatchTagOld[1]=%d"
             , mt_tagA[0].register, mt_tagA[0].ready? "+" : "", mt_tagB[0].register, mt_tagB[0].ready? "+" : "", test_dispatchTagOld[0]
             , mt_tagA[1].register, mt_tagA[1].ready? "+" : "", mt_tagB[1].register, mt_tagB[1].ready? "+" : "", test_dispatchTagOld[1]);
    $display("-------------------------------------------------");
  endtask
  
  task randTest;
    input int seed;
    input int n;
    $display("starting test (seed = %d, n = %d)", seed, n);
    init_randomtest(seed);
    initMT();
    for(int i = 0; i < n; i++) begin
      @(negedge clock);
      if(i > 0) begin
        $display("checking sim");
        checkSim();
      end
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
    int i = 0;
    init_filetest(filename);
    initMT();
    while(1) begin
      @(negedge clock);
      if(i++ != 0) begin
        checkSim();
      end
      //Read inputs from the file
      if(readLine()) begin
        break;
      end
      getInputsFromC();
      @(posedge clock);
      updateSim();      
    end    
  endtask
  
  task initMT;
    clock = 0;
    reset = 1;
    @(posedge clock);  
  endtask
  
  task checkSim;
    if(!checkOutputs(mt_tagA[0].register, mt_tagA[1].register, 
                    mt_tagB[0].register, mt_tagB[1].register, 
                    mt_tagA[0].ready, mt_tagA[1].ready, 
                    mt_tagB[0].ready, mt_tagB[1].ready, 
                    test_dispatchTagOld[0], test_dispatchTagOld[1])) begin
      $display("FAILED, incorrect MT state");
      $display("Verilog state:");
      printMT();
      $display("C simulation state:");
      printSimMT();
      $finish;                   
    end
    for(int i = 0; i < 32; i++) begin
      if(!checkMapEntry(i, map[i].register, map[i].ready)) begin
        $display("FAILED, incorrect MT entry (%d)", i);
        $display("Verilog state:");
        printMT();
        $display("C simulation state:");
        printSimMT();
        $finish;
      end
    end
    printMT();
  endtask
  
  task getInputsFromC;
    reset = 0;
    haz_nDispatched = get_ext_nDispatched();
    for(int i = 0; i < 2; i++) begin
      fl_freeRegs[i] = get_fl_freeRegs(i);
      de_destidx[i] = get_de_destidx(i);
      de_regAidx[i] = get_de_regAidx(i);
      de_regBidx[i] = get_de_regBidx(i);
      
      cdb_rd[i] = get_cdb_rd(i);
      cdb_rd_en[i] = get_cdb_rd_en(i);
    end
  endtask


  initial begin
    fileTest("test_cases/MTCornerCases");
    randTest(0, 5000);
    randTest(1, 5000);
    randTest(2, 5000);
    randTest(3, 5000);
    randTest(4, 5000);
    randTest(5, 5000);
    $display("PASSED");
    $finish;
  end
  
  always_ff @(posedge clock) begin
    test_dispatchTagOld  <= `SD mt_dispatchTagOld;
  end
endmodule

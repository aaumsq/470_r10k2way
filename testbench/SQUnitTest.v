
extern void init_filetest(string filename);
extern int readLine();

/*
extern void init_randomtest(int seed);
extern void getRandomValues();
*/


extern int get_ib_store_en();
extern int get_st_en();
extern int get_rob_nRetireStores();
extern int get_alu_addr(int idx);
extern int get_fus_SQIndex(int idx);
extern int get_alu_data(int idx);
extern int get_ld_en();
extern int get_ld_addr(int idx);
extern int get_br_pred_wrong();
extern int get_bs_recov_sq_tail();
extern int get_bs_recov_sq_empty();
extern int get_dcachectrl_st_request_sent();

extern void updateSim();
extern int checkSQState(int sq_trueHeadV, int sq_tailV, int sq_emptyV, int slotsOpenV, int sq_nAvailableV, int sq_mem_dataV, int sq_mem_enV, int sq_mem_addrV,  
  int sq_indexV0, int sq_indexV1, int sq_index_emptyV, int sq_ea_ptrV, int sq_ea_emptyV, int sq_ld_matchV, int sq_ld_dataV0, int sq_ld_dataV1, int retireHeadV); 
extern int checkSQEntry(int index, int addrV, int dataV, int retiredV);
extern void printSimSQ();


extern void print_SQEntry(int idx, int addr, int data, int retired, int ea_calcd);
extern void print_SQHeader(int sq_trueHead, int sq_tail, int sq_empty, int slotsOpen, int sq_nAvailable, int sq_mem_data, int sq_mem_en, int sq_mem_addr,  
  int sq_index0, int sq_index1, int sq_index_empty, int sq_ea_ptr, int sq_ea_empty, int sq_ld_match, int sq_ld_data0, int sq_ld_data1, int retireHead);
`define SQ_DEBUG
module SQTest();

    logic             clk;
    logic             reset;

    // From InstrBuffer
    logic [1:0]   ib_store_en;
    // From RS
    logic [1:0]   st_en;
    logic [1:0]   ld_en;
    SQ_PTR [1:0]  fus_SQIndex;
    // From ROB
    logic [1:0]   rob_nRetireStores;    

    // From alu
    DATA  [1:0]   alu_data;
    ADDR  [1:0]   alu_addr;
    // From LD fu
    ADDR  [1:0]   ld_addr;

    //inputs from branch functional unit
    logic         br_pred_wrong;            // if prediction is wrong
    //inputs from branch stack
    SQ_PTR        bs_recov_sq_tail;
    logic         bs_recov_sq_empty;

    logic         dcachectrl_st_request_sent;
  
    // Output
    // To InstrBuffer
    logic [1:0]  sq_nAvailable;
    // To D$
    DATA         sq_mem_data;
    logic        sq_mem_en;
    ADDR         sq_mem_addr;
    // To BS
    SQ_PTR       sq_tail; 
    logic        sq_empty;
    // To RS
    SQ_PTR[1:0]  sq_index;
    logic[1:0]   sq_index_empty;
    SQ_PTR       sq_ea_ptr;
    logic        sq_ea_empty;
    SQ_PTR       sq_trueHead;
    
    logic[1:0]   sq_ld_match;
    DATA [1:0]   sq_ld_data;

    SQEntry_t[7:0]  queue;
    SQ_PTR          retireHead;
    logic[3:0]     slotsOpen;

    logic[7:0] ea_calcd;
    logic[7:0] shifted_ea_calcd;

    //outputs from fake regfile
    SQ_PTR[1:0]  index_val;
    DATA         data_val;
    logic        en_val;
    ADDR         addr_val;
    SQ_PTR       head_val;
  
  SQ dut0(.clk(clk), .reset(reset),
    .ib_store_en(ib_store_en), .st_en(st_en), .rob_nRetireStores(rob_nRetireStores),    
    .fus_SQIndex(fus_SQIndex), .alu_data(alu_data), .alu_addr(alu_addr),
    .ld_en(ld_en), .ld_addr(ld_addr),
    .br_pred_wrong(br_pred_wrong), .bs_recov_sq_tail(bs_recov_sq_tail), .bs_recov_sq_empty(bs_recov_sq_empty),
    .dcachectrl_st_request_sent(dcachectrl_st_request_sent), .sq_nAvailable(sq_nAvailable),
    .sq_mem_data(sq_mem_data), .sq_mem_en(sq_mem_en), .sq_mem_addr(sq_mem_addr),
    .sq_tail(sq_tail), .sq_empty(sq_empty), 
    .sq_index(sq_index), .sq_index_empty(sq_index_empty), 
    .sq_ea_ptr(sq_ea_ptr), .sq_ea_empty(sq_ea_empty),
    .sq_trueHead(sq_trueHead), .sq_ld_match(sq_ld_match), .sq_ld_data(sq_ld_data),
    .queue(queue), .retireHead(retireHead), .slotsOpen(slotsOpen),
    .ea_calcd(ea_calcd), .shifted_ea_calcd(shifted_ea_calcd));
  

  //fake regfile, just saves the tags for a cycle
  always_ff @(posedge clk) begin
    index_val <= `SD sq_index;
    en_val <= `SD sq_mem_en;
    data_val <= `SD sq_mem_data;
    addr_val <= `SD sq_mem_addr;
    head_val <= `SD sq_trueHead;
  end

  always #30 clk = ~clk;
  
  task printSQ;
    int i;
    //if(slotsOpen == 8) begin
      $display("SQ EMPTY at time %d:", $time);
    //end else begin
      $display("SQ at time %d:", $time);
      print_SQHeader(sq_trueHead, sq_tail, sq_empty, slotsOpen, sq_nAvailable, data_val, en_val, addr_val, 
        index_val[0], index_val[1], sq_index_empty, sq_ea_ptr, sq_ea_empty, sq_ld_match, 
        sq_ld_data[0], sq_ld_data[1], retireHead);
      for(int i = 0; i < 8; i++) begin
        print_SQEntry(i, queue[i].addr, queue[i].data, queue[i].retired, ea_calcd[i]);
      end
      $display("-------------------------------------------------");
    //end
  endtask

  
  task fileTest;
    input string filename;
    init_filetest(filename);
    initSQ();
    while(1) begin
      @(negedge clk);
      checkSim();
      //Read inputs from the file
      if(readLine()) begin
        break;
      end
      getInputsFromC();
      @(posedge clk);
      updateSim();      
    end    
  endtask
  
  task initSQ;
    clk = 0;
    reset = 1;
    @(posedge clk);  
  endtask
  
  task checkSim;
    if(!checkSQState(sq_trueHead, sq_tail, sq_empty, slotsOpen, sq_nAvailable, data_val, en_val, addr_val, 
        index_val[0], index_val[1], sq_index_empty, sq_ea_ptr, sq_ea_empty, sq_ld_match, 
        sq_ld_data[0], sq_ld_data[1], retireHead)) begin
      $display("FAILED, incorrect SQ state");
      $display("Verilog state:");
      printSQ();
      $display("C simulation state:");
      printSimSQ();
      $finish;
    end
    for(int i = 0; i < 8; i++) begin
      if(!checkSQEntry(i, queue[i].addr, queue[i].data, queue[i].retired)) begin
        $display("FAILED, incorrect SQ entry (%d)", i);
        $display("Verilog state:");
        printSQ();
        $display("C simulation state:");
        printSimSQ();
        $finish;                         
      end
    end
    $display("Verilog state:");
    printSQ();
    $display("C simulation state:");
    printSimSQ();
  endtask
  
  task getInputsFromC;
    reset = 0;
    ib_store_en = get_ib_store_en();
    st_en = get_st_en();
    rob_nRetireStores = get_rob_nRetireStores();
    ld_en = get_ld_en();
    br_pred_wrong = get_br_pred_wrong();
    bs_recov_sq_tail = get_bs_recov_sq_tail();
    bs_recov_sq_empty = get_bs_recov_sq_empty();
    dcachectrl_st_request_sent = get_dcachectrl_st_request_sent();
    for(int i = 0; i < 2; i++) begin
      ld_addr[i] = get_ld_addr(i);
      alu_addr[i] = get_alu_addr(i);
      fus_SQIndex[i] = get_fus_SQIndex(i);
      alu_data[i] = get_alu_data(i);
    end
  endtask
  
  initial begin
    fileTest("test_cases/sqCornerCases");
    /*
    randTest(0, 5000);
    randTest(1, 5000);
    randTest(2, 5000);
    randTest(3, 5000);
    randTest(4, 5000);
    randTest(5, 5000);
    */
    $display("PASSED");
    $finish;
  end
  
endmodule

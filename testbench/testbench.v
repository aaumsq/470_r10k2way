/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  testbench.v                                         //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////
//`default_nettype none
`timescale 1ns/100ps
`include "sys_defs.vh"

//RS Printing
extern void print_RSHeader();
extern void print_RSEntry(int index, int instruction, int fuType, int tag, 
    int tagA, int tagB,  int aReady, int bReady, int bmask, int sq_index, int canLoadIssue);
extern void print_RSOutputs(int slots, int nIssue);
extern void print_fu_en(int fu_en0, int fu_en1, int fu_en2, int fu_en3, 
         int fu_en4, int fu_en5, int fu_en6);

//ROB Printing
extern void print_ROBHeader(int head, int tail, int rob_availableSlots, int prev_nRetired,
    int rob_prev_retireTag0, int rob_prev_retireTag1, 
    int rob_prev_retireTagOld0, int rob_prev_retireTagOld1);
extern void print_ROBEntry(int idx, int complete, int tag, int tagOld);

//IB Printing
extern void print_IBEntry(int instruction, int fd_control_uncond, int fd_control_cond,
  int pred_NPC, int not_taken_NPC, int bp_pred_taken);
extern void print_IBHeader(int head, int tail, int numIns_buffer, int ib_nIsnBuffer, int ib_nAvai,
  int instruction0, int fd_control_uncond0, int fd_control_cond0,int pred_NPC0,
  int not_taken_NPC0, int bp_pred_taken0, int ib_valid0,
  int instruction1, int fd_control_uncond1, int fd_control_cond1,int pred_NPC1,
  int not_taken_NPC1, int bp_pred_taken1, int ib_valid1);
  
`define DE_DEBUG
`define RS_DEBUG
`define ROB_DEBUG
`define IB_DEBUG
`define IF_DEBUG
`define BR_DEBUG
`define ALU_DEBUG
`define MULT_DEBUG
`define CDB_DEBUG
`define MT_DEBUG
`define RF_DEBUG
`define FUS_DEBUG
`define FL_DEBUG
`define SQ_DEBUG
module testbench();

  // Registers and wires used in the testbench
  logic        clock;
  logic        reset;
  logic [31:0] clock_count;
  logic [31:0] instr_count;
  int          wb_fileno;

  logic  [1:0] proc2mem_command;
  logic [63:0] proc2mem_addr;
  logic [63:0] proc2mem_data;
  logic  [3:0] mem2proc_response;
  logic [63:0] mem2proc_data;
  logic  [3:0] mem2proc_tag;

  logic  [3:0] pipeline_completed_insts;
  logic  [3:0] pipeline_error_status;

  ARCH_REG [1:0]        de_destidx;
  ARCH_REG [1:0]        de_regAidx;
  ARCH_REG [1:0]        de_regBidx;
    
  RSEntry_t[7:0]  rs_entries;
  logic[1:0]      rs_nIssue;
  RS_PTR[1:0]     rs_issuePtr;
  logic[3:0]      rs_availableSlots;
  PHYS_REG[1:0]   rs_tagA;
  PHYS_REG[1:0]   rs_tagB;
  PHYS_REG[1:0]   rs_tagDest;
  logic[6:0][1:0] rs_fu_en;
  logic [7:0]     canLoadIssue;
  
  ROBEntry_t[31:0] rob_buffer;
  ROB_PTR          rob_head;
  logic[1:0]       rob_prev_nRetired;
  PHYS_REG [1:0]   rob_prev_retireTag;
  PHYS_REG [1:0]   rob_prev_retireTagOld;
  logic [5:0]      rob_availableSlots;
  ROB_PTR          rob_tail;
  logic            halted;
  
  IBEntry_t [1:0]  ib_data;
  logic [1:0]      ib_valid;
  logic [1:0]      ib_nIsnBuffer;
  logic[1:0]       ib_nAvai;
  logic[3:0]       ib_numIns_buffer;
  IBEntry_t [7:0]  ib_buffer;
  IB_PTR           ib_head;
  IB_PTR           ib_tail;
  
  PC                PC_reg;
  logic             PC_enable;
  INSTRUCTION [1:0] if_inst;
  logic [1:0]       if_valid;

  PHYS_REG              br_tagDest;
  DATA                  br_result;
  logic                 br_done;
  B_MASK                br_bmask;
  logic                 br_branch_resolved;
  BS_PTR                br_bs_ptr;
  logic                 br_pred_taken;
  logic                 br_pred_wrong;
  PC                    br_recov_NPC;
  
  PHYS_REG [1:0]  alu_tagDest;
  DATA [1:0]      alu_result;
  logic [1:0]     alu_done;

  DATA [1:0]            mult_result;
  logic [1:0]           mult_done;
  PHYS_REG [1:0]        mult_tagDest;
  
  PHYS_REG [1:0]  cdb_rd;                 
  logic[1:0]      cdb_rd_en;
  DATA [1:0]      cdb_reg_value;
  
  PHYS_WITH_READY[31:0] mt_map;
  PHYS_WITH_READY[31:0] at_map;
  logic [63:0] [63:0] registers;   // 64, 64-bit Registers

  logic [6:0]           fus_en;
  DATA [6:0]            fus_opA, fus_opB;
  PHYS_REG [6:0]        fus_tagDest;

  PHYS_REG [1:0]        fl_freeRegs;
  logic [5:0]           fl_availableRegs;
  FL_PTR                fl_head;
  FL_PTR                fl_tail;
  PHYS_REG[31:0]        free_list;
  
  SQEntry_t[7:0]        sq_queue;
  SQ_PTR                sq_retireHead;
  logic                 sq_empty;
  logic[3:0]            sq_slotsOpen;
  SQ_PTR                sq_trueHead;
  SQ_PTR		            sq_tail;
  logic[7:0]            ea_calcd, shifted_ea_calcd;

  // Instantiate the Pipeline
  pipeline pipeline_0 (// Inputs
             .clk               (clock),
             .reset             (reset),
             .mem2proc_response (mem2proc_response),
             .mem2proc_data     (mem2proc_data),
             .mem2proc_tag      (mem2proc_tag),

            // Outputs
             .proc2mem_command  (proc2mem_command),
             .proc2mem_addr     (proc2mem_addr),
             .proc2mem_data     (proc2mem_data),

             .pipeline_completed_insts(pipeline_completed_insts),
             .pipeline_error_status(pipeline_error_status),
             
             .at_map(at_map),
             
             .rs_availableSlots(rs_availableSlots),
             .rs_nIssue(rs_nIssue),
             .rs_issuePtr(rs_issuePtr),
             .rs_tagA(rs_tagA),
             .rs_tagB(rs_tagB),
             .rs_tagDest(rs_tagDest),
             .rs_fu_en(rs_fu_en),
             .rs_entries(rs_entries),
             .canLoadIssue(canLoadIssue),
              
             .rob_availableSlots(rob_availableSlots),
             .rob_tail(rob_tail),
             .rob_buffer(rob_buffer),
             .rob_head(rob_head),
             .rob_prev_nRetired(rob_prev_nRetired),
             .rob_prev_retireTag(rob_prev_retireTag),
             .rob_prev_retireTagOld(rob_prev_retireTagOld),
             .halted(halted),
             
             .ib_data(ib_data),
             .ib_valid(ib_valid),
             .ib_nIsnBuffer(ib_nIsnBuffer),
             .ib_nAvai(ib_nAvai),
             .ib_numIns_buffer(ib_numIns_buffer),
             .ib_buffer(ib_buffer),
             .ib_head(ib_head),
             .ib_tail(ib_tail),
             
             .PC_reg(PC_reg),
             .PC_enable(PC_enable),
             .if_inst(if_inst),
             .if_valid(if_valid),

             .de_regAidx(de_regAidx),
             .de_regBidx(de_regBidx),
             .de_destidx(de_destidx),

             .br_tagDest(br_tagDest),
             .br_result(br_result),
             .br_done(br_done),
             .br_bmask(br_bmask),
             .br_branch_resolved(br_branch_resolved),
             .br_bs_ptr(br_bs_ptr),
             .br_pred_taken(br_pred_taken),
             .br_pred_wrong(br_pred_wrong),
             .br_recov_NPC(br_recov_NPC),

             .alu_tagDest(alu_tagDest),
             .alu_result(alu_result),
             .alu_done(alu_done),
             
             .mult_tagDest(mult_tagDest),
             .mult_result(mult_result),
             .mult_done(mult_done),

             .cdb_rd(cdb_rd),
             .cdb_rd_en(cdb_rd_en),
             .cdb_reg_value(cdb_reg_value),
             
             .mt_map(mt_map),

             .registers(registers),

             .fus_en(fus_en),
             .fus_opA(fus_opA),
             .fus_opB(fus_opB),
             .fus_tagDest(fus_tagDest),

             .fl_freeRegs(fl_freeRegs),
             .fl_availableRegs(fl_availableRegs),
             .fl_head(fl_head),
             .fl_tail(fl_tail),
             .free_list(free_list),
             
             .sq_queue(sq_queue),
             .sq_retireHead(sq_retireHead),
             .sq_empty(sq_empty),
             .sq_trueHead(sq_trueHead),
             .sq_tail(sq_tail),
             .sq_slotsOpen(sq_slotsOpen),
             .ea_calcd(ea_calcd),
             .shifted_ea_calcd(shifted_ea_calcd)
            );


  // Instantiate the Data Memory
  mem memory (// Inputs
      .clk               (clock),
      .proc2mem_command  (proc2mem_command),
      .proc2mem_addr     (proc2mem_addr),
      .proc2mem_data     (proc2mem_data),

       // Outputs

      .mem2proc_response (mem2proc_response),
      .mem2proc_data     (mem2proc_data),
      .mem2proc_tag      (mem2proc_tag)
       );

  // Generate System Clock
  always
  begin
    #(`VERILOG_CLOCK_PERIOD/2.0);
    clock = ~clock;
  end

  // Task to display # of elapsed clock edges
  task show_clk_count;
    real cpi;

    begin
      instr_count--;
      cpi = (clock_count + 1.0) / instr_count;
      $display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
      clock_count+1, instr_count, cpi);
      $display("@@  %4.2f ns total time to execute\n@@\n",
      clock_count*`VIRTUAL_CLOCK_PERIOD);
    end
    
  endtask  // task show_clk_count 

  // Show contents of a range of Unified Memory, in both hex and decimal
  task show_mem_with_decimal;
    input [31:0] start_addr;
    input [31:0] end_addr;
    int showing_data;
    begin
      $display("@@@");
      showing_data=0;
      for(int k=start_addr;k<=end_addr; k=k+1)
        if (memory.unified_memory[k] != 0)
        begin
          $display("@@@ mem[%5d] = %x : %0d", k*8,  memory.unified_memory[k], 
                                memory.unified_memory[k]);
          showing_data=1;
        end
        else if(showing_data!=0)
        begin
          $display("@@@");
          showing_data=0;
        end
      $display("@@@");
    end
  endtask  // task show_mem_with_decimal

  initial
  begin
    `ifdef DUMP
      $vcdplusdeltacycleon;
      $vcdpluson();
      $vcdplusmemon(memory.unified_memory);
    `endif
      
    clock = 1'b0;
    reset = 1'b0;

    // Pulse the reset signal
    $display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
    reset = 1'b1;
    @(posedge clock);
    @(posedge clock);

    $readmemh("program.mem", memory.unified_memory);

    @(posedge clock);
    @(posedge clock);
    `SD;
    // This reset is at an odd time to avoid the pos & neg clock edges

    reset = 1'b0;
    $display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);

    wb_fileno = $fopen("writeback.out");

    //Open header AFTER throwing the reset otherwise the reset state is displayed
    //print_header("                                                                            D-MEM Bus &\n");
  end


  // Count the number of posedges and number of instructions completed
  // till simulation ends
  always @(posedge clock or posedge reset)
  begin
    if(reset)
    begin
      clock_count <= `SD 0;
      instr_count <= `SD 0;
    end
    else
    begin
      clock_count <= `SD (clock_count + 1);
      instr_count <= `SD (instr_count + pipeline_completed_insts);
    end
  end  


  always @(negedge clock)
  begin
    if(reset)
      $display(  "@@\n@@  %t : System STILL at reset, can't show anything\n@@",
            $realtime);
    else begin
      `SD;
       printMEMBUS();
       printIF();
       printIB();
       printFL();
       printMT();
       printROB();
       printRS();
       printFU();
       printCDB();
       printRF();
       printAT();
       printSQ();
//       $display("========================================================================================================");
      // deal with any halting conditions
      if((pipeline_error_status!=`NO_ERROR) || clock_count > 80000)
      begin
        //#100;
        $display(  "@@@ Unified Memory contents: ");
              show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
        // 8Bytes per line, 16kB total

        $display("@@  %t : System halted\n@@", $realtime);

        case(pipeline_error_status)
          `HALTED_ON_MEMORY_ERROR:  
            $display(  "@@@ System halted on memory error");
          `HALTED_ON_HALT:          
            $display(  "@@@ System halted on HALT instruction");
          `HALTED_ON_ILLEGAL:
            $display(  "@@@ System halted on illegal instruction");
          default: 
            $display(  "@@@ System halted on unknown error code %x",
                  pipeline_error_status);
        endcase
        $display("@@@\n@@");
        show_clk_count;
        //print_close(); // close the pipe_print output file
        $fclose(wb_fileno);
        printArchRegs();
         $finish;
      end

    end  // if(reset)
  end 

  function [8*7:0] get_instr_string;
  input [31:0] IR;
  input        instr_valid;
  begin
    if (!instr_valid)
      get_instr_string = "-";
    else if (IR==`NOOP_INST)
      get_instr_string = "nop";
    else
      case (IR[31:26])
        6'h00: get_instr_string = (IR == 32'h555) ? "halt" : "call_pal";
        6'h08: get_instr_string = "lda";
        6'h09: get_instr_string = "ldah";
        6'h0a: get_instr_string = "ldbu";
        6'h0b: get_instr_string = "ldqu";
        6'h0c: get_instr_string = "ldwu";
        6'h0d: get_instr_string = "stw";
        6'h0e: get_instr_string = "stb";
        6'h0f: get_instr_string = "stqu";
        6'h10: // INTA_GRP
        begin
          case (IR[11:5])
            7'h00: get_instr_string = "addl";
            7'h02: get_instr_string = "s4addl";
            7'h09: get_instr_string = "subl";
            7'h0b: get_instr_string = "s4subl";
            7'h0f: get_instr_string = "cmpbge";
            7'h12: get_instr_string = "s8addl";
            7'h1b: get_instr_string = "s8subl";
            7'h1d: get_instr_string = "cmpult";
            7'h20: get_instr_string = "addq";
            7'h22: get_instr_string = "s4addq";
            7'h29: get_instr_string = "subq";
            7'h2b: get_instr_string = "s4subq";
            7'h2d: get_instr_string = "cmpeq";
            7'h32: get_instr_string = "s8addq";
            7'h3b: get_instr_string = "s8subq";
            7'h3d: get_instr_string = "cmpule";
            7'h40: get_instr_string = "addlv";
            7'h49: get_instr_string = "sublv";
            7'h4d: get_instr_string = "cmplt";
            7'h60: get_instr_string = "addqv";
            7'h69: get_instr_string = "subqv";
            7'h6d: get_instr_string = "cmple";
            default: get_instr_string = "invalid";
          endcase
        end
        6'h11: // INTL_GRP
        begin
          case (IR[11:5])
            7'h00: get_instr_string = "and";
            7'h08: get_instr_string = "bic";
            7'h14: get_instr_string = "cmovlbs";
            7'h16: get_instr_string = "cmovlbc";
            7'h20: get_instr_string = "bis";
            7'h24: get_instr_string = "cmoveq";
            7'h26: get_instr_string = "cmovne";
            7'h28: get_instr_string = "ornot";
            7'h40: get_instr_string = "xor";
            7'h44: get_instr_string = "cmovlt";
            7'h46: get_instr_string = "cmovge";
            7'h48: get_instr_string = "eqv";
            7'h61: get_instr_string = "amask";
            7'h64: get_instr_string = "cmovle";
            7'h66: get_instr_string = "cmovgt";
            7'h6c: get_instr_string = "implver";
            default: get_instr_string = "invalid";
          endcase
        end
        6'h12: // INTS_GRP
        begin
          case(IR[11:5])
            7'h02: get_instr_string = "mskbl";
            7'h06: get_instr_string = "extbl";
            7'h0b: get_instr_string = "insbl";
            7'h12: get_instr_string = "mskwl";
            7'h16: get_instr_string = "extwl";
            7'h1b: get_instr_string = "inswl";
            7'h22: get_instr_string = "mskll";
            7'h26: get_instr_string = "extll";
            7'h2b: get_instr_string = "insll";
            7'h30: get_instr_string = "zap";
            7'h31: get_instr_string = "zapnot";
            7'h32: get_instr_string = "mskql";
            7'h34: get_instr_string = "srl";
            7'h36: get_instr_string = "extql";
            7'h39: get_instr_string = "sll";
            7'h3b: get_instr_string = "insql";
            7'h3c: get_instr_string = "sra";
            7'h52: get_instr_string = "mskwh";
            7'h57: get_instr_string = "inswh";
            7'h5a: get_instr_string = "extwh";
            7'h62: get_instr_string = "msklh";
            7'h67: get_instr_string = "inslh";
            7'h6a: get_instr_string = "extlh";
            7'h72: get_instr_string = "mskqh";
            7'h77: get_instr_string = "insqh";
            7'h7a: get_instr_string = "extqh";
            default: get_instr_string = "invalid";
          endcase
        end
        6'h13: // INTM_GRP
        begin
          case (IR[11:5])
            7'h01: get_instr_string = "mull";
            7'h20: get_instr_string = "mulq";
            7'h30: get_instr_string = "umulh";
            7'h40: get_instr_string = "mullv";
            7'h60: get_instr_string = "mulqv";
            default: get_instr_string = "invalid";
          endcase
        end
        6'h14: get_instr_string = "itfp"; // unimplemented
        6'h15: get_instr_string = "fltv"; // unimplemented
        6'h16: get_instr_string = "flti"; // unimplemented
        6'h17: get_instr_string = "fltl"; // unimplemented
        6'h1a: get_instr_string = "jsr";
        6'h1c: get_instr_string = "ftpi";
        6'h20: get_instr_string = "ldf";
        6'h21: get_instr_string = "ldg";
        6'h22: get_instr_string = "lds";
        6'h23: get_instr_string = "ldt";
        6'h24: get_instr_string = "stf";
        6'h25: get_instr_string = "stg";
        6'h26: get_instr_string = "sts";
        6'h27: get_instr_string = "stt";
        6'h28: get_instr_string = "ldl";
        6'h29: get_instr_string = "ldq";
        6'h2a: get_instr_string = "ldll";
        6'h2b: get_instr_string = "ldql";
        6'h2c: get_instr_string = "stl";
        6'h2d: get_instr_string = "stq";
        6'h2e: get_instr_string = "stlc";
        6'h2f: get_instr_string = "stqc";
        6'h30: get_instr_string = "br";
        6'h31: get_instr_string = "fbeq";
        6'h32: get_instr_string = "fblt";
        6'h33: get_instr_string = "fble";
        6'h34: get_instr_string = "bsr";
        6'h35: get_instr_string = "fbne";
        6'h36: get_instr_string = "fbge";
        6'h37: get_instr_string = "fbgt";
        6'h38: get_instr_string = "blbc";
        6'h39: get_instr_string = "beq";
        6'h3a: get_instr_string = "blt";
        6'h3b: get_instr_string = "ble";
        6'h3c: get_instr_string = "blbs";
        6'h3d: get_instr_string = "bne";
        6'h3e: get_instr_string = "bge";
        6'h3f: get_instr_string = "bgt";
        default: get_instr_string = "invalid";
      endcase
    end
  endfunction

  task printROB;
    int i;
    if(rob_availableSlots == 32) begin
      $display("ROB at time %0d EMPTY", $time);
      //$display("head: %0d, tail: %0d, rob_availableSlots: %0d, rob_prev_nRetired: %0d", rob_head, rob_tail, rob_availableSlots, rob_prev_nRetired);
      print_ROBHeader(rob_head, rob_tail, rob_availableSlots, rob_prev_nRetired,
        rob_prev_retireTag[0], rob_prev_retireTag[1], 
        rob_prev_retireTagOld[0], rob_prev_retireTagOld[1]);
    end else begin
      //$display("head: %0d, tail: %0d, rob_availableSlots: %0d, rob_prev_nRetired: %0d", rob_head, rob_tail, rob_availableSlots, rob_prev_nRetired);

      print_ROBHeader(rob_head, rob_tail, rob_availableSlots, rob_prev_nRetired,
        rob_prev_retireTag[0], rob_prev_retireTag[1], 
        rob_prev_retireTagOld[0], rob_prev_retireTagOld[1]);
      $display("ROB at time %0d", $time);
      i = rob_head;
      while(i != (rob_head+32-rob_availableSlots)) begin
      print_ROBEntry(i%32, rob_buffer[i%32].complete, rob_buffer[i%32].tag, rob_buffer[i%32].tagOld);
      i = i+1;
      end
    end
    $display("halted: %d", halted);
    $display("--------------------------------------------------------------------------------------------");
  endtask
  
  task printRS;
    if(rs_availableSlots == 8) begin
      $display("RS at time %0d EMPTY", $time);
      print_RSOutputs(rs_availableSlots, rs_nIssue);
      if(rs_nIssue > 0) begin
        print_RSHeader();
      end
      for(int i = 0; i < rs_nIssue; i++) begin
        $display("rs_issuePtr: %0d, tagb: %0d", rs_issuePtr[i], rs_entries[rs_issuePtr[i]].tagB.register);
        print_RSEntry(rs_issuePtr[i],  
                      rs_entries[rs_issuePtr[i]].control.ib_data.instruction, 
                      rs_entries[rs_issuePtr[i]].fuType, rs_entries[rs_issuePtr[i]].tag, 
                      rs_entries[rs_issuePtr[i]].tagA.register, rs_entries[rs_issuePtr[i]].tagB.register, 
                      rs_entries[rs_issuePtr[i]].tagA.ready, rs_entries[rs_issuePtr[i]].tagB.ready,
                      rs_entries[rs_issuePtr[i]].bmask, rs_entries[rs_issuePtr[i]].sq_index,
                      canLoadIssue[rs_issuePtr[i]]);
      end
    end else begin
      $display("RS at time %0d", $time);
      print_RSHeader();
      for(int i = 0; i < 8; i++) begin
        if(rs_entries[i].valid) begin
          print_RSEntry(i, rs_entries[i].control.ib_data.instruction, 
                        rs_entries[i].fuType, rs_entries[i].tag, 
                        rs_entries[i].tagA.register, rs_entries[i].tagB.register, 
                        rs_entries[i].tagA.ready, rs_entries[i].tagB.ready, rs_entries[i].bmask,
                        rs_entries[i].sq_index, canLoadIssue[i]);
        end
      end
      print_RSOutputs(rs_availableSlots, rs_nIssue);
      for(int i = 0; i < rs_nIssue; i++) begin
        $display("rs_issuePtr: %0d, tagb: %0d", rs_issuePtr[i], rs_entries[rs_issuePtr[i]].tagB.register);
        print_RSEntry(rs_issuePtr[i],  
                      rs_entries[rs_issuePtr[i]].control.ib_data.instruction, 
                      rs_entries[rs_issuePtr[i]].fuType, rs_entries[rs_issuePtr[i]].tag, 
                      rs_entries[rs_issuePtr[i]].tagA.register, rs_entries[rs_issuePtr[i]].tagB.register, 
                      rs_entries[rs_issuePtr[i]].tagA.ready, rs_entries[rs_issuePtr[i]].tagB.ready,
                      rs_entries[rs_issuePtr[i]].bmask, rs_entries[rs_issuePtr[i]].sq_index,
                      canLoadIssue[rs_issuePtr[i]]);
      end
      print_fu_en(rs_fu_en[0], rs_fu_en[1], rs_fu_en[2], rs_fu_en[3], rs_fu_en[4], 
                rs_fu_en[5], rs_fu_en[6]);
    end
    $display("--------------------------------------------------------------------------------------------");
  endtask
  
  task printIB;
    if(ib_numIns_buffer == 0) begin
      $display("IB at time %0d EMPTY", $time);
      //$display("ib_numIns_buffer: %0d, ib_nIsnBuffer:%0d, ib_nAvai: %0d", ib_numIns_buffer, ib_nIsnBuffer, ib_nAvai);
      print_IBHeader(ib_head, ib_tail, ib_numIns_buffer, ib_nIsnBuffer, ib_nAvai,
      ib_data[0].instruction, ib_data[0].fd_control.uncond_branch,
      ib_data[0].fd_control.cond_branch, ib_data[0].pred_NPC,
      ib_data[0].not_taken_NPC, ib_data[0].bp_pred_taken, ib_valid[0],
      ib_data[1].instruction, ib_data[1].fd_control.uncond_branch,
      ib_data[1].fd_control.cond_branch, ib_data[1].pred_NPC,
      ib_data[1].not_taken_NPC, ib_data[1].bp_pred_taken, ib_valid[1]);
    end else begin    
      $display("IB at time %0d", $time);
      //$display("ib_numIns_buffer: %0d, ib_nIsnBuffer:%0d, ib_nAvai: %0d", ib_numIns_buffer, ib_nIsnBuffer, ib_nAvai);
      print_IBHeader(ib_head, ib_tail, ib_numIns_buffer, ib_nIsnBuffer, ib_nAvai,
      ib_data[0].instruction, ib_data[0].fd_control.uncond_branch,
      ib_data[0].fd_control.cond_branch, ib_data[0].pred_NPC,
      ib_data[0].not_taken_NPC, ib_data[0].bp_pred_taken, ib_valid[0],
      ib_data[1].instruction, ib_data[1].fd_control.uncond_branch,
      ib_data[1].fd_control.cond_branch, ib_data[1].pred_NPC,
      ib_data[1].not_taken_NPC, ib_data[1].bp_pred_taken, ib_valid[1]);


      for(int i = ib_head; i < (ib_head+ib_numIns_buffer); i++) begin
        print_IBEntry(ib_buffer[i%8].instruction, ib_buffer[i%8].fd_control.uncond_branch,
          ib_buffer[i%8].fd_control.cond_branch, ib_buffer[i%8].pred_NPC, 
          ib_buffer[i%8].not_taken_NPC, ib_buffer[i%8].bp_pred_taken);
      end
   end
  $display("--------------------------------------------------------------------------------------------");
  endtask
  
  task printIF;
    $display("IF at time %0d", $time);
    $display("PC: %0d \nen: %0d", PC_reg, PC_enable);
    for(int i = 0; i < 2; i++) begin
      if(if_valid[i]) begin
        $display("\t%0d: %0h, (%0s $r%0d, $r%0d, $r%0d)", i, if_inst[i], 
            get_instr_string(if_inst[i], 1), if_inst[i][25:21], if_inst[i][20:16], if_inst[i][4:0]);
      end
    end
    $display("--------------------------------------------------------------------------------------------");
  endtask
  
  task printMEMBUS;
    $display("proc2mem_command:  %0d", proc2mem_command);
    $display("proc2mem_addr:     %0d", proc2mem_addr);
    $display("proc2mem_data:     %0d", proc2mem_data);
    $display("mem2proc_response: %0d", mem2proc_response);
    $display("mem2proc_data:     %0h", mem2proc_data);
    $display("mem2proc_tag:      %0d", mem2proc_tag);
    $display("--------------------------------------------------------------------------------------------");
  endtask

  task printFL;
    $display("FL at time %0d", $time);
    $display("fl_availableRegs: %0d, fl_head: %0d, fl_tail: %0d", fl_availableRegs, fl_head, fl_tail);
    for(int i = 0; i < 2; i++) begin
      $display("fl_freeRegs[%0d]: %0d", i, fl_freeRegs[i]);
    end
    $display("--------------------------------------------------------------------------------------------");
  endtask


  task printFU;
    for(int i = 6; i < 7; i++) begin
      if(fus_en[i]) begin
        $display("BR enabled: opA = %0d, opB = %0d", fus_opA[i], fus_opB[i]);
        $display("BR output: reg[%0d] = %0d", br_tagDest, br_result);
      end
      if(br_branch_resolved) begin
        $display("BR resolved");
        $display("Predicted taken: %0d, Prediction wrong: %0d", br_pred_taken, br_pred_wrong);
        $display("Recov NPC: %0d, BS ptr: %0d", br_recov_NPC, br_bs_ptr);
      end
    end
    for(int i = 0; i < 2; i++) begin
      if(fus_en[i+2]) begin
        $display("MULT[%0d] enabled: opA = %0d, opB = %0d", i[0], fus_opA[i+2], fus_opB[i+2]);
      end
      if(mult_done[i]) begin
        $display("MULT[%0d] Finished execution: reg[%0d] = %0d", i[0], mult_tagDest[i], mult_result[i]);
      end
    end
    for(int i = 0; i < 2; i++) begin
      if(fus_en[i+4]) begin
        $display("ALU[%0d] enabled: opA = %0d, opB = %0d", i[0], fus_opA[i+4], fus_opB[i+4]);
      end
      if(alu_done[i]) begin
        $display("ALU[%0d] Finished execution: reg[%0d] = %0d", i[0], alu_tagDest[i], alu_result[i]);
      end
    end
    for(int i = 0; i < 2; i++) begin
      if(fus_en[i]) begin
        $display("LDST[%0d] enabled: opA = %0d, opB = %0d", i[0], fus_opA[i], fus_opB[i]);
        $display("too many outputs to display :p");
      end
    end

    if(mult_done[0] || mult_done[1] || alu_done[0] || alu_done[1])
      $display("--------------------------------------------------------------------------------------------");
  endtask
  
  task printCDB;
    for(int i = 0; i < 2; i++) begin
      if(cdb_rd_en[i]) begin
        $display("CDB[%d]: pr[%d]=%d", i[0], cdb_rd[i], cdb_reg_value[i]);
      end
    end
  endtask
  
  task printRF;
    for(int i = 0; i < 64; i++) begin
      if(registers[i] === 64'hx || registers[i] === 64'h0) begin
        continue;
      end
      $display("pr[%0d]=%d", i, registers[i]);
    end    
  endtask
  
  task printMT;
    for(int i = 0; i < 32; i++) begin
      if(mt_map[i].register != i || mt_map[i].ready) begin
        if(mt_map[i].ready) begin
          $display("mt[%0d]=%d+", i, mt_map[i].register);
        end else begin
          $display("mt[%0d]=%d", i, mt_map[i].register);
        end
      end
    end
    $display("--------------------------------------------------------------------------------------------");
  endtask
  
  task printAT;
    for(int i = 0; i < 32; i++) begin
      if(at_map[i].register != i) begin
        if(at_map[i].ready) begin
          $display("at[%2d]=pr[%2d]=%d", i, at_map[i].register, registers[at_map[i].register]);
        end else begin
          $display("at[%2d]=pr[%2d]=%d", i, at_map[i].register, registers[at_map[i].register]);
        end
      end
    end
  endtask
  
  task printArchRegs;
    for(int i = 0; i < 32; i++) begin
      $display("### reg[%d]=%d", i, registers[at_map[i].register]);
    end
  endtask
  
  task printSQ;
    $display("SQ:\tHead\tTail\taddr\tdata\tretired\tea_calcd[shifted]");
    for(int i = 0; i < 8; i++) begin
      $display("%0d:\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d[%0d]", i, i==sq_trueHead, i==sq_tail, sq_queue[i].addr, sq_queue[i].data, sq_queue[i].retired,
                                                  ea_calcd[i], shifted_ea_calcd[i]);
    end
    $display("sq_trueHead: %0d, sq_retireHead: %0d, sq_tail: %0d, sq_empty: %0d, sq_slotsOpen: %0d"
            , sq_trueHead, sq_retireHead, sq_tail, sq_empty, sq_slotsOpen);
    $display("--------------------------------------------------------------------------------------------");
  endtask
endmodule  // module testbench

`timescale 1ns/100ps
//`default_nettype none


`define RS_DEBUG
`define DE_DEBUG
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
module pipeline(
    input logic                   clk,
    input logic                   reset,
    
    input logic [3:0]             mem2proc_response,
    input DATA                    mem2proc_data,
    input logic [3:0]             mem2proc_tag,
    
    output logic[63:0]            proc2mem_addr,
    output DATA                   proc2mem_data,
    output logic [1:0]            proc2mem_command,
    
    output logic [3:0]            pipeline_completed_insts,
    output logic [3:0]            pipeline_error_status,
    
    output logic                  halted,
    output PHYS_WITH_READY[31:0]  at_map
    
    `ifdef ROB_DEBUG
      , output ROBEntry_t[31:0]   rob_buffer
      , output ROB_PTR            rob_head
      , output logic[1:0]         rob_prev_nRetired
      , output PHYS_REG [1:0]     rob_prev_retireTag
      , output PHYS_REG [1:0]     rob_prev_retireTagOld
      , output logic [5:0]        rob_availableSlots
      , output ROB_PTR            rob_tail
    `endif

    `ifdef RS_DEBUG
      , output RSEntry_t[7:0]     rs_entries
      , output RS_PTR[1:0]        rs_issuePtr
      , output logic[1:0]         rs_nIssue
      , output logic[3:0]         rs_availableSlots
      , output PHYS_REG[1:0]      rs_tagA
      , output PHYS_REG[1:0]      rs_tagB
      , output PHYS_REG[1:0]      rs_tagDest
      , output logic[6:0][1:0]    rs_fu_en
      , output logic [7:0]        canLoadIssue
    `endif
    
    `ifdef IB_DEBUG
      , output IBEntry_t [1:0]    ib_data
      , output logic [1:0]        ib_valid
      , output logic [1:0]        ib_nIsnBuffer
      , output logic[1:0]         ib_nAvai
      , output logic[3:0]         ib_numIns_buffer 
      , output IBEntry_t [7:0]    ib_buffer
      , output IB_PTR             ib_head
      , output IB_PTR             ib_tail
    `endif
    
    `ifdef IF_DEBUG
      , output PC                 PC_reg
      , output logic              PC_enable
      , output INSTRUCTION [1:0]  if_inst
      , output logic [1:0]        if_valid
    `endif
    
    `ifdef DE_DEBUG
      , output ARCH_REG[1:0]      de_regAidx
      , output ARCH_REG[1:0]      de_regBidx
      , output ARCH_REG[1:0]      de_destidx
    `endif
    
    `ifdef BR_DEBUG
      , output PHYS_REG           br_tagDest
      , output DATA               br_result
      , output logic              br_done
      , output B_MASK             br_bmask
      , output BS_PTR             br_bs_ptr
      , output logic              br_pred_taken
      , output logic              br_pred_wrong
      , output PC                 br_recov_NPC
      , output logic              br_branch_resolved
    `endif
    
    `ifdef ALU_DEBUG
      , output PHYS_REG[1:0]      alu_tagDest
      , output DATA[1:0]          alu_result
      , output logic[1:0]         alu_done
    `endif

    `ifdef MULT_DEBUG
      , output DATA [1:0]          mult_result
      , output logic [1:0]         mult_done
      , output PHYS_REG [1:0]      mult_tagDest
    `endif
    
    `ifdef CDB_DEBUG
      , output PHYS_REG [1:0]     cdb_rd
      , output logic [1:0]        cdb_rd_en
      , output DATA [1:0]         cdb_reg_value
    `endif
    
    `ifdef MT_DEBUG
      , output PHYS_WITH_READY[31:0] mt_map
    `endif
    
    `ifdef RF_DEBUG
      , output logic [63:0] [63:0] registers 
    `endif

    `ifdef FUS_DEBUG
      , output logic [6:0]         fus_en
      , output DATA [6:0]          fus_opA
      , output DATA [6:0]          fus_opB
      , output PHYS_REG [6:0]      fus_tagDest
    `endif

    `ifdef FL_DEBUG
      , output PHYS_REG [1:0]      fl_freeRegs
      , output logic [5:0]         fl_availableRegs
      , output FL_PTR              fl_head
      , output FL_PTR              fl_tail
      , output PHYS_REG[31:0]      free_list
    `endif    

    `ifdef SQ_DEBUG
      , output SQEntry_t[7:0]  sq_queue
      , output SQ_PTR          sq_retireHead
      , output SQ_PTR          sq_trueHead
      , output SQ_PTR          sq_tail
      , output logic           sq_empty
      , output logic[3:0]      sq_slotsOpen
      , output logic[7:0]      ea_calcd, shifted_ea_calcd
    `endif
  );
  
  //fetch outputs
  PC                      if_requested_addr;
  logic [1:0]             bp_pred_taken;
  PC    [1:0]             bp_pred_NPC, bp_not_taken_NPC;
  `ifndef IF_DEBUG
    INSTRUCTION [1:0]     if_inst;
    logic [1:0]           if_valid;
  `endif
  FD_control_t [1:0]      fd_control;
  PC                      pf_requested_addr;
  logic                   pf_request_valid;
  
  //IB outputs
  `ifndef IB_DEBUG
    logic [1:0]           ib_valid;
    IBEntry_t [1:0]       ib_data;
    logic [1:0]           ib_nAvai;
    logic [1:0]           ib_nIsnBuffer;
  `endif
    logic [1:0]           ib_store_en;
  
  /*
  //mem input
  DATA                  proc2mem_data;
  */

  // nbCacheCtrl Outputs
  ADDR                    icache2mem_addr;
  logic[1:0]              icache2mem_command;
  logic[1:0]              icache_valid;
  INSTRUCTION[1:0]        icache_data;
  logic                   icache_pf_stall;
  
  //Fix later
  //cache outputs
  logic [63:0]            rd1_data;
  logic                   rd1_valid;
  
  //decoder outputs
  FU_TYPE [1:0]           de_fuType;
  `ifndef DE_DEBUG
    ARCH_REG [1:0]        de_destidx;
    ARCH_REG [1:0]        de_regAidx;
    ARCH_REG [1:0]        de_regBidx;
  `endif
  DE_control_t [1:0]      de_control;
  
  //CDB output
  `ifndef CDB_DEBUG
    PHYS_REG [1:0]        cdb_rd;                 
    logic[1:0]            cdb_rd_en;
    DATA [1:0]            cdb_reg_value;
  `endif
  logic [7:0]             cdb_stall;
  
  //if_id_hazard output
  logic [1:0]             haz_nDispatched;
  
  //ROB outputs
  `ifndef ROB_DEBUG
    logic [5:0]           rob_availableSlots;
    ROB_PTR               rob_tail;
  `endif
  logic [1:0]             rob_nRetired;
  PHYS_REG [1:0]          rob_retireTag;
  PHYS_REG [1:0]          rob_retireTagOld;
  logic [1:0]             rob_nRetireStores;
  logic                   rob_halted;
  
  //RS outputs
  `ifndef RS_DEBUG
    logic[3:0]            rs_availableSlots;
    PHYS_REG[1:0]         rs_tagA;
    PHYS_REG[1:0]         rs_tagB;
    PHYS_REG[1:0]         rs_tagDest;
    logic[6:0][1:0]       rs_fu_en;
  `endif
  DE_control_t[1:0]       rs_control;
  B_MASK [1:0]            rs_bmask;
  BS_PTR [1:0]            rs_bs_ptr;
  SQ_PTR[1:0]             rs_SQIndex;
  
  
  //MT outputs
  PHYS_WITH_READY [1:0]   mt_tagA;
  PHYS_WITH_READY [1:0]   mt_tagB;
  PHYS_REG [1:0]          mt_dispatchTagOld;
  PHYS_WITH_READY [30:0]  mt_nextMap;
  
  //FL outputs
  `ifndef FL_DEBUG
    PHYS_REG [1:0]        fl_freeRegs;
    logic [5:0]           fl_availableRegs;
    FL_PTR                fl_head;
  `endif

  //RF output
  DATA[1:0]               rf_opA;
  DATA[1:0]               rf_opB;
  
  //Mult outputs
  `ifndef MULT_DEBUG
    DATA [1:0]            mult_result;
    logic [1:0]           mult_done;
    PHYS_REG [1:0]        mult_tagDest;
  `endif
  B_MASK [1:0]            mult_bmask;
  logic  [1:0]            mult_busy;
  
  //Alu outputs
  `ifndef ALU_DEBUG
    PHYS_REG [1:0]        alu_tagDest;
    DATA [1:0]            alu_result;
    logic [1:0]           alu_done;
  `endif
  B_MASK [1:0]            alu_bmask;
  
  //Branch outputs
  `ifndef BR_DEBUG
      //combinational logic to FUB
    PHYS_REG              br_tagDest;
    DATA                  br_result;
    logic                 br_done;
    B_MASK                br_bmask;
      //sequential outputs to everything
    BS_PTR                br_bs_ptr;
    logic                 br_pred_taken;
    logic                 br_pred_wrong;
    PC                    br_recov_NPC;
    logic                 br_branch_resolved;
  `endif
    logic                 br_taken_NPC_wrong;
    logic                 br_pred_dir_wrong;
    PC                    br_not_taken_NPC;
  
  //FUS outputs
  `ifndef FUS_DEBUG
    logic [6:0]           fus_en;
    DATA [6:0]            fus_opA, fus_opB;
    PHYS_REG [6:0]        fus_tagDest;
  `endif
  DE_control_t [6:0]      fus_control;
  B_MASK [6:0]            fus_bmask;
  BS_PTR [6:0]            fus_bs_ptr;  
  SQ_PTR[6:0]             fus_SQIndex;  
  
  //FUBi outputs
  logic [7:0]             fub_busy;
  logic [7:0]             fub_valid;
  DATA [7:0]              fub_result;
  PHYS_REG [7:0]          fub_tagDest;
  B_MASK [7:0]            fub_bmask;
  
  /*
  //BP outputs
  PC                      bp_pred_NPC;
  PC                      bp_not_taken_NPC;
  logic                   bp_pred_taken;
  
  //FD outputs
  FD_control_t            fd_control;
  */
  
  //BS outputs
  logic [2:0]             bs_nEntries;
  B_MASK                  bs_bmask;
  BS_PTR                  bs_ptr;
  BSEntry_t               bs_recoverInfo;

  
  
  logic [1:0]    sq_nAvailable;
  SQ_PTR[1:0]    sq_index;
  SQ_PTR         sq_ea_ptr;
  logic          sq_ea_empty;
  logic [1:0]    sq_index_empty;
  `ifndef SQ_DEBUG
    SQ_PTR         sq_trueHead;
    SQ_PTR         sq_tail;
    logic          sq_empty;
  `endif
  
  ADDR           st_requested_addr;
  DATA           st_request_data;
  logic          st_request_valid;
  PC[1:0]        ld_requested_addr;
  logic[1:0]     ld_request_mem_worthy;
  logic[1:0]     ld_request_valid;
  PHYS_REG[1:0]  ld_request_dest;
  B_MASK[1:0]     ld_request_bmask;
  
  logic[2:0]     mem_done;
  PHYS_REG[2:0]  mem_tagDest;
  DATA[2:0]      mem_result;
  B_MASK[2:0]     mem_bmask;
  logic[2:0]        dcachectrl_ld_valid;
  DATA[2:0]         dcachectrl_ld_data;
  PHYS_REG          dcachectrl_mem_dest;
  B_MASK             dcachectrl_mem_bmask;
  logic             dcachectrl_st_request_sent;
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
  

  assign pipeline_completed_insts = rob_nRetired;
  
  assign halted = rob_halted && sq_empty;

  assign pipeline_error_status = /*mem_wb_illegal*/0  ? `HALTED_ON_ILLEGAL
                  : halted  ? `HALTED_ON_HALT
                  : `NO_ERROR;
  
  if_stage fetch(
    .clk(clk),
    .reset(reset),      
      //Inputs
    .br_pred_wrong(br_pred_wrong),
    .br_recov_NPC(br_recov_NPC),
    .br_branch_resolved(br_branch_resolved),
    .br_pred_dir_wrong(br_pred_dir_wrong),
    .br_taken_NPC_wrong(br_taken_NPC_wrong),
    .br_pred_taken(br_pred_taken),
    .br_not_taken_NPC(br_not_taken_NPC),
    .icache_data(icache_data),
    .icache_valid(icache_valid),
    .icache_pf_stall(icache_pf_stall),
    .ib_nAvai(ib_nAvai),
      //Outputs
    .if_requested_addr(if_requested_addr),
    .bp_pred_taken(bp_pred_taken),
    .bp_pred_NPC(bp_pred_NPC),
    .bp_not_taken_NPC(bp_not_taken_NPC),
    .if_inst(if_inst),
    .if_valid(if_valid),
    .fd_control(fd_control), 
    .pf_requested_addr(pf_requested_addr), 
    .pf_request_valid(pf_request_valid)
    `ifdef IF_DEBUG
      , .PC_enable(PC_enable)
      , .PC_reg(PC_reg)
    `endif);
  
  
  CacheCtrl cache(
    .clk(clk),
    .reset(reset),
    .mem2cache_tag(mem2proc_tag),
    .mem2cache_response(mem2proc_response),
    .mem2cache_data(mem2proc_data),
    .br_bs_ptr(br_bs_ptr),
    .br_pred_wrong(br_pred_wrong),
    .br_branch_resolved(br_branch_resolved),
    .if_requested_addr(if_requested_addr),
    .pf_requested_addr(pf_requested_addr),
    .pf_request_valid(pf_request_valid),
    .cache2mem_addr(proc2mem_addr[15:0]),
    .cache2mem_command(proc2mem_command),
    .cache2mem_data(proc2mem_data),
    .icache_valid(icache_valid),
    .icache_data(icache_data),
    .icache_pf_stall(icache_pf_stall),
    .st_requested_addr(st_requested_addr),
    .st_request_data(st_request_data),
    .st_request_valid(st_request_valid),
    .ld_requested_addr(ld_requested_addr),
    .ld_request_mem_worthy(ld_request_mem_worthy),
    .ld_request_bmask(ld_request_bmask),
    .ld_request_valid(ld_request_valid),
    .ld_request_dest(ld_request_dest),
    .dcachectrl_st_request_sent(dcachectrl_st_request_sent),
    .dcachectrl_ld_valid(dcachectrl_ld_valid),
    .dcachectrl_ld_data(dcachectrl_ld_data),
    .dcachectrl_mem_dest(dcachectrl_mem_dest),
    .dcachectrl_mem_bmask(dcachectrl_mem_bmask));
    
  assign proc2mem_addr[63:16] = 0;
  
  decoder de[1:0](
      //Inputs
    .ib_data(ib_data),
    .ib_valid(ib_valid),
      //Outputs
    .de_fuType(de_fuType),
    .de_destidx(de_destidx),
    .de_regAidx(de_regAidx),
    .de_regBidx(de_regBidx),
    .de_control(de_control));
    
  CDB cdb(
      //Inputs
    .fub_valid(fub_valid),
    .fub_tagDest(fub_tagDest),
    .fub_result(fub_result),
    .fub_bmask(fub_bmask),
    .br_bs_ptr(br_bs_ptr),
    .br_pred_wrong(br_pred_wrong),
      //Outputs
    .cdb_rd(cdb_rd),
    .cdb_rd_en(cdb_rd_en),
    .cdb_stall(cdb_stall),
    .cdb_reg_value(cdb_reg_value));
    
    
  if_id_hazard haz(
      //Inputs
    .rob_availableSlots(rob_availableSlots),
    .rob_nRetired(rob_nRetired),
    .rs_availableSlots(rs_availableSlots),
    .fl_availableRegs(fl_availableRegs),
    .br_pred_wrong(br_pred_wrong),
    .ib_nIsnBuffer(ib_nIsnBuffer),    //this value can only be from 0 to 2 (2 if buffer has more than or equal two insn)
      //Outputs
    .haz_nDispatched(haz_nDispatched));
    
  ROB rob(
    .clk(clk),
    .reset(reset),
        //Inputs
    .halt({de_control[1].halt, de_control[0].halt}),
    .noop({de_control[1].noop, de_control[0].noop}),
    .is_store({de_control[1].ib_data.fd_control.wr_mem, de_control[0].ib_data.fd_control.wr_mem}),
    .fl_freeRegs(fl_freeRegs),
    .mt_dispatchTagOld(mt_dispatchTagOld),
    .cdb_rd(cdb_rd),                 
    .cdb_rd_en(cdb_rd_en),
    .haz_nDispatched(haz_nDispatched),
    .br_pred_wrong(br_pred_wrong),
    .bs_recov_rob_tail(bs_recoverInfo.rob_tail),
      //Outputs
    .rob_availableSlots(rob_availableSlots),
    .rob_nRetired(rob_nRetired),
    .rob_nRetireStores(rob_nRetireStores),
    .rob_retireTag(rob_retireTag),
    .rob_retireTagOld(rob_retireTagOld),
    .rob_tail(rob_tail),
    .rob_halted(rob_halted)
    `ifdef ROB_DEBUG
      , .buffer(rob_buffer)
      , .head(rob_head)
      , .prev_nRetired(rob_prev_nRetired)
      , .rob_prev_retireTag(rob_prev_retireTag)
      , .rob_prev_retireTagOld(rob_prev_retireTagOld)
    `endif
    );
  
  RS rs(
    .clk(clk),
    .reset(reset),
      //Inputs
    .haz_nDispatched(haz_nDispatched),
    .fl_freeRegs(fl_freeRegs),
    .mt_tagA(mt_tagA),
    .mt_tagB(mt_tagB),
    .de_fuType(de_fuType),
    .de_control(de_control),
    //doesn't use fub_busy for mult because mult has many cycles
    .fub_busy({fub_busy[7:5], mult_busy, fub_busy[2:1]}),
    .cdb_rd_en(cdb_rd_en),
    .cdb_rd(cdb_rd),
    .bs_bmask(bs_bmask),
    .bs_ptr(bs_ptr),
    .br_bs_ptr(br_bs_ptr),
    .br_pred_wrong(br_pred_wrong),
    .br_branch_resolved(br_branch_resolved),
    .sq_index(sq_index),
    .sq_index_empty(sq_index_empty),
    .sq_trueHead(sq_trueHead),
    .sq_tail(sq_tail),
    .sq_ea_ptr(sq_ea_ptr),
    .sq_ea_empty(sq_ea_empty),
    .sq_empty(sq_empty),
      //Ouputs
    .rs_availableSlots(rs_availableSlots),
    .rs_tagA(rs_tagA),
    .rs_tagB(rs_tagB),
    .rs_tagDest(rs_tagDest),
    .rs_fu_en(rs_fu_en),
    .rs_control(rs_control),
    .rs_bmask(rs_bmask),
    .rs_bs_ptr(rs_bs_ptr),
    .rs_SQIndex(rs_SQIndex)
    `ifdef RS_DEBUG
      , .entries(rs_entries)
      , .rs_issuePtr(rs_issuePtr)
      , .rs_nIssue(rs_nIssue)
      , .canLoadIssue(canLoadIssue)
    `endif
    );
    
  MapTable mt(
    .clk(clk),
    .reset(reset),
      //Inputs
    .de_destidx(de_destidx),
    .de_regAidx(de_regAidx),
    .de_regBidx(de_regBidx),
    .fl_freeRegs(fl_freeRegs),
    .haz_nDispatched(haz_nDispatched),
    .cdb_rd_en(cdb_rd_en),
    .cdb_rd(cdb_rd),
    .br_pred_wrong(br_pred_wrong),
    .bs_recov_map(bs_recoverInfo.map),
      //Outputs
    .mt_tagA(mt_tagA),
    .mt_tagB(mt_tagB),
    .mt_dispatchTagOld(mt_dispatchTagOld),
    .mt_nextMap(mt_nextMap)
    `ifdef MT_DEBUG
      , .map(mt_map)
    `endif
    );
    
  ArchTable at(
    .clk(clk),
    .reset(reset),
      //Inputs
    .rob_nRetired(rob_nRetired),
    .rob_retireTag(rob_retireTag),
    .rob_retireTagOld(rob_retireTagOld),
      //Outputs
    .at_map(at_map));
    
  FreeList fl(
    .clk(clk),
    .reset(reset),
      //Inputs
    .haz_nDispatched(haz_nDispatched),
    .rob_retireTagOld(rob_retireTagOld),
    .rob_retireTag(rob_retireTag),
    .rob_nRetired(rob_nRetired),
    .br_pred_wrong(br_pred_wrong),
    .bs_recov_fl_head(bs_recoverInfo.fl_head),
      //Outputs
    .fl_freeRegs(fl_freeRegs),
    .fl_availableRegs(fl_availableRegs),
    .fl_head(fl_head)
    `ifdef FL_DEBUG
      , .fl_tail(fl_tail)
      , .free(free_list)
    `endif
    );
    
  regfile rf(
    .clk(clk),
    .reset(reset), 
      //Inputs
    .rda_idx(rs_tagA[0]),
    .rdb_idx(rs_tagA[1]),
    .rdc_idx(rs_tagB[0]),
    .rdd_idx(rs_tagB[1]),
    .wra_idx(cdb_rd[0]),
    .wrb_idx(cdb_rd[1]),
    .wra_data(cdb_reg_value[0]),
    .wrb_data(cdb_reg_value[1]),
    .wra_en(cdb_rd_en[0]),
    .wrb_en(cdb_rd_en[1]),
      //Outputs
    .rf_rda_out(rf_opA[0]),  
    .rf_rdb_out(rf_opA[1]),
    .rf_rdc_out(rf_opB[0]),
    .rf_rdd_out(rf_opB[1])
    `ifdef RF_DEBUG
      , .registers(registers)
    `endif
    );
    
  pipe_mult_fu mult [1:0](
    .clk(clk),
    .reset(reset),
      //Inputs
    .fus_opA(fus_opA[3:2]),
    .fus_opB(fus_opB[3:2]),
    .fus_en(fus_en[3:2]),
    .fus_tagDest(fus_tagDest[3:2]),
    .fus_bmask(fus_bmask[3:2]),
    .fus_control(fus_control[3:2]),
    .fub_mult_busy(fub_busy[4:3]),  //4:3 because for fub, the 0th entry is for the store from memory
    .br_bs_ptr(br_bs_ptr),
    .br_pred_wrong(br_pred_wrong),
    .br_branch_resolved(br_branch_resolved),
      //Outputs
    .mult_result(mult_result),
    .mult_done(mult_done),
    .mult_tagDest(mult_tagDest),
    .mult_bmask(mult_bmask),
    .mult_busy(mult_busy)
    );

  branch_fu branch(
      //Inputs
    .clk(clk),
    .reset(reset),
    .fus_en(fus_en[6]),
    .fus_opA(fus_opA[6]),
    .fus_opB(fus_opB[6]),
    .fus_tagDest(fus_tagDest[6]),
    .fus_control(fus_control[6]),
    .fus_bmask(fus_bmask[6]),
    .fus_bs_ptr(fus_bs_ptr[6]),
      //Outputs
    .br_tagDest(br_tagDest),
    .br_result(br_result),
    .br_done(br_done),
    .br_bmask(br_bmask),
    .br_pred_taken(br_pred_taken),
    .br_pred_wrong(br_pred_wrong),
    .br_bs_ptr(br_bs_ptr),
    .br_recov_NPC(br_recov_NPC),
    .br_branch_resolved(br_branch_resolved),
    .br_taken_NPC_wrong(br_taken_NPC_wrong),
    .br_pred_dir_wrong(br_pred_dir_wrong),
    .br_not_taken_NPC(br_not_taken_NPC));

  alu_fu alu [1:0](
      //Inputs
    .fus_en(fus_en[5:4]),
    .fus_opA(fus_opA[5:4]),
    .fus_opB(fus_opB[5:4]),
    .fus_tagDest(fus_tagDest[5:4]),
    .fus_control(fus_control[5:4]),
    .fus_bmask(fus_bmask[5:4]),
    .br_pred_wrong(br_pred_wrong),
    .br_branch_resolved(br_branch_resolved),
    .br_bs_ptr(br_bs_ptr),
      //Outputs
    .alu_tagDest(alu_tagDest),
    .alu_result(alu_result),
    .alu_done(alu_done),
    .alu_bmask(alu_bmask));
    
  dmemFU mem(
    .clk(clk),
    .reset(reset),
    .rob_nRetireStores(rob_nRetireStores),
    .ib_store_en(ib_store_en),
    .fus_en(fus_en[1:0]),
    .fus_opA(fus_opA[1:0]),
    .fus_opB(fus_opB[1:0]),
    .fus_tagDest(fus_tagDest[1:0]),
    .fus_control(fus_control[1:0]),
    .fus_bmask(fus_bmask[1:0]),
    .fus_SQIndex(fus_SQIndex[1:0]),
    .br_pred_wrong(br_pred_wrong),
    .bs_recov_sq_tail(bs_recoverInfo.sq_tail),
    .bs_recov_sq_empty(bs_recoverInfo.sq_empty),
    
    .dcachectrl_st_request_sent(dcachectrl_st_request_sent),
    .dcachectrl_ld_valid(dcachectrl_ld_valid),
    .dcachectrl_ld_data(dcachectrl_ld_data),
    .dcachectrl_mem_dest(dcachectrl_mem_dest),
    .dcachectrl_mem_bmask(dcachectrl_mem_bmask),
    
    .sq_nAvailable(sq_nAvailable),
    .sq_empty(sq_empty),
    .sq_index_empty(sq_index_empty),
    .sq_tail(sq_tail), 
    .sq_index(sq_index),
    .sq_ea_ptr(sq_ea_ptr),
    .sq_ea_empty(sq_ea_empty),
    .sq_trueHead(sq_trueHead),
    
    .st_requested_addr(st_requested_addr),
    .st_request_data(st_request_data),
    .st_request_valid(st_request_valid),
    .ld_requested_addr(ld_requested_addr),
    .ld_request_mem_worthy(ld_request_mem_worthy),
    .ld_request_valid(ld_request_valid),
    .ld_request_dest(ld_request_dest),
    .ld_request_bmask(ld_request_bmask),
    
    .done(mem_done),
    .tagDest(mem_tagDest),
    .result(mem_result),
    .bmask(mem_bmask)
    
    `ifdef SQ_DEBUG
      , .sq_queue(sq_queue)
      , .sq_retireHead(sq_retireHead)
      , .sq_slotsOpen(sq_slotsOpen)
      , .ea_calcd(ea_calcd)
      , .shifted_ea_calcd(shifted_ea_calcd)
    `endif
    );
    
  FUS fus [6:0](
      //Inputs
    .rs_fu_en(rs_fu_en),
    .rf_opA(rf_opA),
    .rf_opB(rf_opB),
    .rs_tagDest(rs_tagDest),
    .rs_control(rs_control),
    .rs_bmask(rs_bmask),
    .rs_bs_ptr(rs_bs_ptr),
    .rs_SQIndex(rs_SQIndex),
      //Outputs
    .fus_en(fus_en),
    .fus_opA(fus_opA),
    .fus_opB(fus_opB),
    .fus_tagDest(fus_tagDest),
    .fus_control(fus_control),
    .fus_bmask(fus_bmask),
    .fus_bs_ptr(fus_bs_ptr),
    .fus_SQIndex(fus_SQIndex));
  
  FUBi fubi [7:0](
    .clk(clk),
    .reset(reset),
      //Inputs
    .fu_result({br_result, alu_result[1:0], mult_result[1:0], mem_result[1:0], mem_result[2]}),
    .fu_done({br_done, alu_done[1:0], mult_done[1:0], mem_done[1:0], mem_done[2]}),
    .fu_tagDest({br_tagDest, alu_tagDest[1:0], mult_tagDest[1:0], mem_tagDest[1:0], mem_tagDest[2]}),
    .cdb_stall(cdb_stall[7:0]),
    .br_pred_wrong(br_pred_wrong),
    .br_branch_resolved(br_branch_resolved),
    .br_bs_ptr(br_bs_ptr),
    .fu_bmask({br_bmask, alu_bmask[1:0], mult_bmask[1:0], mem_bmask[1:0], mem_bmask[2]}),
    
      //Outputs
    .fub_busy(fub_busy[7:0]),
    .fub_valid(fub_valid[7:0]),
    .fub_result(fub_result[7:0]),
    .fub_tagDest(fub_tagDest[7:0]),
    .fub_bmask(fub_bmask[7:0]));
    
  InstrBuffer ib(
    .clk(clk),
    .reset(reset),
      //Inputs
    .br_pred_wrong(br_pred_wrong),
    .bp_pred_taken(bp_pred_taken),
    .bp_pred_NPC(bp_pred_NPC),
    .bp_not_taken_NPC(bp_not_taken_NPC),
    .if_inst_in(if_inst),
    .if_valid_in(if_valid),
    .fd_control(fd_control),
    .haz_nDispatched(haz_nDispatched),
    .bs_nEntries(bs_nEntries),
    .sq_nAvailable(sq_nAvailable),
      //Outputs
    .ib_data(ib_data),
    .ib_valid(ib_valid),
    .ib_nIsnBuffer(ib_nIsnBuffer),
    .ib_nAvai(ib_nAvai),
    .ib_store_en(ib_store_en)
    `ifdef IB_DEBUG
      , .numIns_buffer(ib_numIns_buffer) 
      , .buffer(ib_buffer)
      , .head(ib_head)
      , .tail(ib_tail)
    `endif
    );

  branchStack bs(
    .clk(clk),
    .reset(reset),
      //Inputs
    .haz_nDispatched(haz_nDispatched),
    .ib_data(ib_data),
    .br_pred_wrong(br_pred_wrong),
    .br_bs_ptr(br_bs_ptr),
    .br_branch_resolved(br_branch_resolved),
    .fl_head(fl_head),
    .rob_tail(rob_tail),
    .mt_nextMap(mt_nextMap),
    .cdb_rd_en(cdb_rd_en),
    .cdb_rd(cdb_rd),
    .sq_tail(sq_tail),
    .sq_empty(sq_empty),
      //Outputs
    .bs_nEntries(bs_nEntries),
    .bs_bmask(bs_bmask),
    .bs_ptr(bs_ptr),
    .bs_recoverInfo(bs_recoverInfo));
    
   
endmodule

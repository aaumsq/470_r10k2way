`define SQ_DEBUG

module dmemFU(
    input logic clk,
    input logic reset,
    input logic[1:0]        rob_nRetireStores,
    input logic[1:0]        ib_store_en,
    input SQ_PTR [1:0]      fus_SQIndex,
    input logic[1:0]        fus_en,
    input DATA[1:0]         fus_opA, fus_opB,
    input PHYS_REG[1:0]     fus_tagDest,
    input DE_control_t[1:0] fus_control,
    input B_MASK[1:0]       fus_bmask,
    input logic             br_pred_wrong,
    input SQ_PTR            bs_recov_sq_tail,
    input logic             bs_recov_sq_empty,
    
    input logic[2:0]        dcachectrl_ld_valid,
    input DATA[2:0]         dcachectrl_ld_data,
    input PHYS_REG          dcachectrl_mem_dest,
    input B_MASK            dcachectrl_mem_bmask,
    input logic             dcachectrl_st_request_sent,
    
    output logic [1:0]	  sq_nAvailable,
    output SQ_PTR		      sq_tail, 
    output SQ_PTR[1:0]    sq_index,
    output logic[1:0]     sq_index_empty,
    output SQ_PTR         sq_ea_ptr,
    output logic          sq_ea_empty,
    output SQ_PTR         sq_trueHead, 
    output logic          sq_empty,
    
    output ADDR           st_requested_addr,
    output DATA           st_request_data,
    output logic          st_request_valid,
    output PC[1:0]        ld_requested_addr,
    output logic[1:0]     ld_request_mem_worthy,
    output logic[1:0]     ld_request_valid,
    output PHYS_REG[1:0]  ld_request_dest,
    output B_MASK[1:0]    ld_request_bmask,
    
    output logic[2:0]     done,
    output PHYS_REG[2:0]  tagDest,
    output DATA[2:0]      result,
    output B_MASK[2:0]    bmask

    `ifdef SQ_DEBUG
      , output SQEntry_t[7:0]  sq_queue
      , output SQ_PTR          sq_retireHead
      , output logic[3:0] 		 sq_slotsOpen
      , output logic[7:0]      ea_calcd, shifted_ea_calcd
    `endif
    );
  
  logic[1:0] ld_en, st_en;
  genvar g;
  generate
    for(g = 0; g < 2; g++) begin
      assign ld_en[g] = fus_en[g] && fus_control[g].rd_mem;
      assign st_en[g] = fus_en[g] && fus_control[g].ib_data.fd_control.wr_mem; 
    end
  endgenerate
  
  DATA[1:0] alu_data;
  ADDR[1:0] alu_addr;
  
  DATA sq_mem_data;
  logic sq_mem_en;
  ADDR sq_mem_addr;
  assign st_requested_addr = sq_mem_addr;
  assign st_request_data = sq_mem_data;
  assign st_request_valid = sq_mem_en;
  
  logic[1:0] sq_ld_match;
  DATA[1:0] sq_ld_data;
  assign ld_requested_addr = alu_addr;
  assign ld_request_mem_worthy = ld_en & ~sq_ld_match;
  assign ld_request_valid = ld_en;
  assign ld_request_dest = fus_tagDest;
  assign ld_request_bmask = fus_bmask;  

  always_comb begin
    for(int i = 0; i < 2; i++) begin
      //$display("st_en[%0d]: %0d, ld_en[%0d]: %0d, sq_ld_match[%0d]: %0d", 
          //i, st_en[i], i, ld_en[i], i, sq_ld_match[i]);
      if(st_en[i]) begin
        done[i] = 1;
        tagDest[i] = fus_tagDest[i];
        result[i] = alu_addr[i];
        bmask[i] = fus_bmask[i];
      end else if(ld_en[i]) begin
        if(sq_ld_match[i]) begin
          done[i] = 1;
          result[i] = sq_ld_data[i];
        end else begin
          done[i] = dcachectrl_ld_valid[i];
          result[i] = dcachectrl_ld_data[i];
        end
        tagDest[i] = fus_tagDest[i];
        bmask[i] = fus_bmask[i];
      end else begin
        done[i] = 0;
        tagDest[i] = `PHYS_ZERO_REG;
        result[i] = 0;
        bmask[i] = 0;
      end
    end
    done[2] = dcachectrl_ld_valid[2];
    tagDest[2] = dcachectrl_mem_dest;
    result[2] = dcachectrl_ld_data[2];
    bmask[2] = dcachectrl_mem_bmask;
    //$display("done[0]: %0d, done[1]: %0d, done[2]: %0d", done[0], done[1], done[2]);
    //$display("---");
  end
  
  SQ sq(.clk(clk), .reset(reset),
        .ib_store_en(ib_store_en),
        
        .st_en(st_en),
        .ld_en(ld_en),
        .fus_SQIndex(fus_SQIndex),
        
        .rob_nRetireStores(rob_nRetireStores),
        
        .alu_data(alu_data),
        .alu_addr(alu_addr),
        .ld_addr(alu_addr),
        
        .br_pred_wrong(br_pred_wrong),
        .bs_recov_sq_tail(bs_recov_sq_tail),
        .bs_recov_sq_empty(bs_recov_sq_empty),
        
        .dcachectrl_st_request_sent(dcachectrl_st_request_sent),
        
        
        .sq_nAvailable(sq_nAvailable),
        
        .sq_mem_data(sq_mem_data),
        .sq_mem_en(sq_mem_en),
        .sq_mem_addr(sq_mem_addr),
        
        .sq_tail(sq_tail), 
        .sq_empty(sq_empty),
        
        .sq_index(sq_index),
        .sq_index_empty(sq_index_empty),
        .sq_ea_ptr(sq_ea_ptr),
        .sq_ea_empty(sq_ea_empty),
        .sq_trueHead(sq_trueHead),
        
        .sq_ld_match(sq_ld_match),
        .sq_ld_data(sq_ld_data)
        `ifdef SQ_DEBUG
          , .queue(sq_queue)
          , .retireHead(sq_retireHead)
          , .slotsOpen(sq_slotsOpen)
          , .ea_calcd(ea_calcd)
          , .shifted_ea_calcd(shifted_ea_calcd)
        `endif
        );
  
  memAlu alu[1:0](
        .data_op(fus_opA),
        .addr_op(fus_opB),
        .control(fus_control),
        
        .data(alu_data),
        .addr(alu_addr));
  
endmodule

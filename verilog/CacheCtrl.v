
module CacheCtrl #(parameter MSHR_SIZE=15)(
    input logic clk, 
    input logic reset,
    
    input MEM_TAG     mem2cache_tag,
    input MEM_TAG     mem2cache_response,
    input DATA        mem2cache_data,
    
    input PC          st_requested_addr,
    input DATA        st_request_data,
    input logic       st_request_valid,
    input PC[1:0]     ld_requested_addr,
    input logic[1:0]  ld_request_mem_worthy,
    input logic[1:0]  ld_request_valid,
    input PHYS_REG[1:0] ld_request_dest,
    input B_MASK[1:0]  ld_request_bmask,
    
    input PC          if_requested_addr,
    
    input PC          pf_requested_addr,
    input logic       pf_request_valid,
    
    input logic       br_branch_resolved,
    input logic       br_pred_wrong,
    input BS_PTR      br_bs_ptr,
    
    output ADDR             cache2mem_addr,
    output logic[1:0]       cache2mem_command,
    output DATA             cache2mem_data,
    
    output logic[2:0]       dcachectrl_ld_valid,
    output DATA[2:0]        dcachectrl_ld_data,
    output PHYS_REG         dcachectrl_mem_dest,
    output B_MASK            dcachectrl_mem_bmask,
    
    output logic            dcachectrl_st_request_sent,
    
    output logic[1:0]       icache_valid,
    output INSTRUCTION[1:0] icache_data,
    output logic            icache_pf_stall
    /*output logic            ld_stall*/);
    
  logic cache_wr_en;
  ICACHE_FULL_IDX cache_wr_idx;
  ICACHE_TAG cache_wr_tag;
  
  ICACHE_BANK_IDX cache_rd_even_idx, cache_rd_odd_idx;
  ICACHE_TAG cache_rd_even_tag, cache_rd_odd_tag;
  
  ICACHE_FULL_IDX pf_idx;
  ICACHE_TAG pf_tag;
  logic pf_in_cache;
  
  DCACHE_IDX[1:0] ld_idx;
  DCACHE_TAG[1:0] ld_tag;
  DCACHE_IDX st_idx;
  DCACHE_TAG st_tag;
  
  logic if_odd_inst, if_odd_bank;
  ICACHE_BANK_IDX if_idx;
  ICACHE_TAG if_tag;
  
  DATA cache_even_data, cache_odd_data;
  logic cache_even_valid, cache_odd_valid;
  
  logic internal_pf_stall;    
  logic[3:0] memoryTagPointer;
  logic ifCAMHit, pfCAMHit;
  logic[1:0] ldCAMHit;
  
  logic[1:0] if_cache_miss;  
  
  ADDR cache_even_addr, cache_odd_addr;

  DCACHE_IDX dcache_st_idx;
  DCACHE_TAG dcache_st_tag;
  DATA dcache_st_data;
  
  DCACHE_IDX dcache_ld_idx;
  DCACHE_TAG dcache_ld_tag;
  DATA dcache_ld_data;
  logic dcache_ld_en;
  
  DCACHE_IDX[1:0] dcache_rd_idx;
  DCACHE_TAG[1:0] dcache_rd_tag;
  DATA[1:0]       dcache_rd_data;
  logic[1:0]      dcache_rd_valid;
  /*
  LQEntry_t[7:0] load_queue, next_lq;
  LQ_PTR lqHead, lqTail, nextLQHead, nextLQTail;
  logic[3:0] lqNEntries, nextLQNEntries;
  
  assign ld_stall = lqNEntries >= 7;*/
  
  

  //XXX: SHOULD ONLY be WR_EN ON NON-LOAD RESPONSES
  icache cache0(.clock(clk), .reset(reset), 
                .wr_en(cache_wr_en), 
                .wr_idx(cache_wr_idx),
                .wr_data(mem2cache_data),
                .wr_tag(cache_wr_tag),

                .rd_even_idx(cache_rd_even_idx),
                .rd_odd_idx(cache_rd_odd_idx),
                .rd_even_tag(cache_rd_even_tag),
                .rd_odd_tag(cache_rd_odd_tag),
                
                .pf_idx(pf_idx),
                .pf_tag(pf_tag),
                .pf_in_cache(pf_in_cache),
                
                .rd_even_data(cache_even_data),
                .rd_odd_data(cache_odd_data),
                .rd_even_valid(cache_even_valid),
                .rd_odd_valid(cache_odd_valid));

  //XXX: SHOULD ONLY BE WR_EN ON LOAD RESPONSES
  dcache cache1(.clock(clk), .reset(reset),
                .st_idx(dcache_st_idx),
                .st_tag(dcache_st_tag),
                .st_en(dcachectrl_st_request_sent),
                .st_data(dcache_st_data),
                
                .ld_idx(dcache_ld_idx),
                .ld_tag(dcache_ld_tag),
                .ld_en(dcache_ld_en),
                .ld_data(dcache_ld_data),
                
                .rd_idx(dcache_rd_idx),
                .rd_tag(dcache_rd_tag),
                .rd_data(dcache_rd_data),
                .rd_valid(dcache_rd_valid));
  
  MSHR_t[MSHR_SIZE-1:0] statuses, nextStatuses;
  MSHR_t ifstatus, pfstatus;
  MSHR_t[1:0] ldstatus;
  assign ifstatus.is_load = 0;
  assign ifstatus.destTag = 0;
  assign ifstatus.addr = if_requested_addr;
  assign ifstatus.memTag = mem2cache_response;
  assign ifstatus.bmask = 0;
  assign pfstatus.is_load = 0;
  assign pfstatus.destTag = 0;
  assign pfstatus.addr = pf_requested_addr;
  assign pfstatus.memTag = mem2cache_response;
  assign pfstatus.bmask = 0;
  
  genvar i;
  generate
    for(i = 0; i < 2; i++) begin
      assign dcache_rd_idx[i] = ld_requested_addr[i][7:3];
      assign dcache_rd_tag[i] = ld_requested_addr[i][15:8];
      assign ldstatus[i].is_load = 1;
      assign ldstatus[i].addr = ld_requested_addr[i];
      assign ldstatus[i].memTag = mem2cache_response;
      assign ldstatus[i].destTag = ld_request_dest[i];
      assign ldstatus[i].bmask = ld_request_bmask[i];
    end
  endgenerate
  
  assign dcache_st_data = st_request_data;
  assign dcache_st_tag = st_requested_addr[15:8];
  assign dcache_st_idx = st_requested_addr[7:3];
  
  assign if_odd_inst = if_requested_addr[2];
  assign if_odd_bank = if_requested_addr[3];
  assign if_idx = if_requested_addr[7:4];
  assign if_tag = if_requested_addr[15:8];
  assign pf_idx = pf_requested_addr[7:3];
  assign pf_tag = pf_requested_addr[15:8];
  
  assign cache_rd_even_idx = cache_even_addr[7:4];
  assign cache_rd_even_tag = cache_even_addr[15:8];
  assign cache_rd_odd_idx = cache_odd_addr[7:4];
  assign cache_rd_odd_tag = cache_odd_addr[15:8];
   
  assign memoryTagPointer = mem2cache_tag-1;
  assign cache_wr_tag = statuses[memoryTagPointer].addr[15:8];
  assign cache_wr_idx = statuses[memoryTagPointer].addr[7:3];
  assign cache_wr_en  = mem2cache_tag != 0 && !statuses[memoryTagPointer].is_load;
  
  always_comb begin
    nextStatuses = statuses;
      //Get cached data and check for misses
    if(if_odd_inst) begin
      if(if_odd_bank) begin
        cache_odd_addr = if_requested_addr;
        cache_even_addr = if_requested_addr + 4;
        if_cache_miss[0] = !cache_odd_valid;
        if_cache_miss[1] = !cache_even_valid;
      end else begin
        cache_even_addr = if_requested_addr;
        cache_odd_addr = if_requested_addr + 4;
        if_cache_miss[0] = !cache_even_valid;
        if_cache_miss[1] = !cache_odd_valid;
      end
    end else begin
      if(if_odd_bank) begin
        cache_odd_addr = if_requested_addr;
        cache_even_addr = 0;
        if_cache_miss[0] = !cache_odd_valid;
        if_cache_miss[1] = !cache_odd_valid;
      end else begin
        cache_even_addr = if_requested_addr;
        cache_odd_addr = 0;
        if_cache_miss[0] = !cache_even_valid;
        if_cache_miss[1] = !cache_even_valid;
      end
    end
    
    for(int i = 0; i < 2; i++) begin
      //$display("dcachectrl_ld_valid[%0d]: %0d, dcache_rd_valid[%0d]: %0d, ld_request_valid[%0d]: %0d",
      //          i, dcachectrl_ld_valid[i], i, dcache_rd_valid[i], i, ld_request_valid[i]);
      dcachectrl_ld_valid[i] = dcache_rd_valid[i] && ld_request_valid[i];
      dcachectrl_ld_data[i] = dcache_rd_data[i];
    end
    
    //CAM for if and pf requests
    ifCAMHit = 0;
    pfCAMHit = 0;
    for(int i = 0; i < MSHR_SIZE; i++) begin
      if(statuses[i].valid && (statuses[i].addr == if_requested_addr)) begin
        ifCAMHit = 1;
      end
    end
    for(int i = 0; i < MSHR_SIZE; i++) begin
      if(statuses[i].valid && (statuses[i].addr == pf_requested_addr)) begin
        pfCAMHit = 1;
      end
    end
      
      //Calculate next memory request source
    ldstatus[0].valid = ld_request_valid[0] && ld_request_mem_worthy[0] 
                        && !dcache_rd_valid[0];
    ldstatus[1].valid = ld_request_valid[1] && ld_request_mem_worthy[1] 
                        && !dcache_rd_valid[1] && !ldstatus[0].valid;
                        
    dcachectrl_st_request_sent = st_request_valid && !ldstatus[0].valid && !ldstatus[1].valid;
                        
    ifstatus.valid = !ifCAMHit && if_cache_miss[0] 
                  && !ldstatus[0].valid && !ldstatus[1].valid && !st_request_valid;
    
    pfstatus.valid = !pfCAMHit && !pf_in_cache 
                              && !ifstatus.valid 
                              && !ldstatus[0].valid && !ldstatus[1].valid && !st_request_valid
                               && pf_request_valid;
                               
    icache_pf_stall = ~pfstatus.valid;
    
      //Calculate memory outputs
    unique if(ldstatus[0].valid && !reset) begin        
      cache2mem_addr = {ld_requested_addr[0][15:3], 3'b0};
      cache2mem_command = `BUS_LOAD;
      cache2mem_data = 0;
    end else if(ldstatus[1].valid && !reset) begin        
      cache2mem_addr = {ld_requested_addr[1][15:3], 3'b0};
      cache2mem_command = `BUS_LOAD;
      cache2mem_data = 0;
    end else if(dcachectrl_st_request_sent && !reset) begin
      cache2mem_addr = {st_requested_addr[15:3], 3'b0};
      cache2mem_command = `BUS_STORE;
      cache2mem_data = st_request_data;
      if (mem2cache_response == 0) begin
        dcachectrl_st_request_sent = 0;
      end
    end else if(ifstatus.valid && !reset) begin        
      cache2mem_addr = {if_requested_addr[15:3], 3'b0};
      cache2mem_command = `BUS_LOAD;
      cache2mem_data = 0;
    end else if(pfstatus.valid && !reset) begin
      cache2mem_addr = {pf_requested_addr[15:3], 3'b0};
      cache2mem_command = `BUS_LOAD;
      cache2mem_data = 0;
    end else begin
      cache2mem_addr = 0;
      cache2mem_command = `BUS_NONE;
      cache2mem_data = 0;
    end
    
      //Calculate interleaved data outputs
    if(mem2cache_tag && (statuses[memoryTagPointer].addr == if_requested_addr)) begin
      icache_valid[0] = 1;
      if(if_odd_inst) begin
        icache_data[0] = mem2cache_data[63:32];
        icache_valid[1] = !if_cache_miss[1];
        icache_data[1] = if_odd_bank? cache_even_data[31:0] : cache_odd_data[31:0];
      end else begin
        icache_valid[1] = 1;
        icache_data[0] = mem2cache_data[31:0];
        icache_data[1] = mem2cache_data[63:32];
      end
    end else begin
      icache_valid = ~if_cache_miss;
      if(if_odd_inst) begin
        icache_data[0] = if_odd_bank? cache_odd_data[63:32] : cache_even_data[63:32];
        icache_data[1] = if_odd_bank? cache_even_data[31:0] : cache_odd_data[31:0];
      end else begin
        icache_data[0] = if_odd_bank? cache_odd_data[31:0] : cache_even_data[31:0];
        icache_data[1] = if_odd_bank? cache_odd_data[63:32] : cache_even_data[63:32];
      end
    end
    
    if(mem2cache_tag && statuses[memoryTagPointer].is_load && statuses[memoryTagPointer].valid) begin
      dcachectrl_ld_data[2] = mem2cache_data;
      dcachectrl_ld_valid[2] = 1;
      dcachectrl_mem_dest = statuses[memoryTagPointer].destTag;
      dcachectrl_mem_bmask = statuses[memoryTagPointer].bmask;
      dcache_ld_data = mem2cache_data;
      dcache_ld_tag = statuses[memoryTagPointer].addr[15:8];
      dcache_ld_idx = statuses[memoryTagPointer].addr[7:3];
      dcache_ld_en = 1;
    end else begin
      dcachectrl_ld_data[2] = 0;
      dcachectrl_ld_valid[2] = 0;
      dcachectrl_mem_dest = 0;
      dcachectrl_mem_bmask = 0;
      dcache_ld_data = 0;
      dcache_ld_tag = 0;
      dcache_ld_idx = 0;
      dcache_ld_en = 0;      
    end
    
    
      //Calculate next state
    if(ldstatus[0].valid && (mem2cache_response != 0)) begin
      nextStatuses[mem2cache_response-1] = ldstatus[0];
    end else if(ldstatus[1].valid && (mem2cache_response != 0)) begin
      nextStatuses[mem2cache_response-1] = ldstatus[1];
    end else if(ifstatus.valid && (mem2cache_response != 0)) begin
      nextStatuses[mem2cache_response-1] = ifstatus;
    end else if (pfstatus.valid && (mem2cache_response != 0)) begin
      nextStatuses[mem2cache_response-1] = pfstatus;
    end
    if(mem2cache_tag != 0) begin
      nextStatuses[memoryTagPointer].valid = 0;
    end
    
    for(int i = 0; i < 8; i++) begin
      if(br_branch_resolved) begin
        if(br_pred_wrong) begin
          if(nextStatuses[i].bmask[br_bs_ptr]) begin
            nextStatuses[i].valid = 0;
          end   
        end else begin
          nextStatuses[i].bmask[br_bs_ptr] = 0;
        end
      end
    end
  end  
  
    // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      for(int i = 0; i < MSHR_SIZE; i++) begin
        statuses[i].valid <= `SD 0;
      end
      /*lqHead <= `SD 0;
      lqTail <= `SD 7;
      lqNEntries <= `SD 0;*/
    end else begin
      statuses <= `SD nextStatuses;
      /*lqHead <= `SD nextLQHead;
      lqTail <= `SD nextLQTail;
      lqNEntries <= `SD nextLQNEntries;*/
//        $display("ICacheCtrl:");
//        $display("pf_request: %d %s", pf_requested_addr, pf_request_valid? "(en)" : "   ");
//        $display("pf reqs: %d %d %d %d %d %d %d", !pfCAMHit, !pf_in_cache, !ifstatus.valid, 
//                            !ldstatus[0].valid, !ldstatus[1].valid, !st_request_valid, pf_request_valid);
//        $display("ifstatus: %0d, pfstatus: %0d", ifstatus.valid, pfstatus.valid);
//        $display("mem2cache_response: %d", mem2cache_response);
//        $display("memoryTagPointer: %d", memoryTagPointer);
//        $display("icache2mem_addr: %d, valid[0]: %d, valid[1]: %d", 
//                  cache2mem_addr, icache_valid[0], icache_valid[1]);
//        $display("cache_even_addr: %d, cache_odd_addr: %d", cache_even_addr, cache_odd_addr);
//        $display("if_cache_miss: %b", if_cache_miss);
//        $display("cache_rd_even_tag: %d, cache_rd_even_idx: %d", cache_rd_even_tag, cache_rd_even_idx);
//        $display("cache_rd_odd_tag: %d, cache_rd_odd_idx: %d", cache_rd_odd_tag, cache_rd_odd_idx);
//        $display("idx,\tvalid\taddress\tmemtag\tisLoad\ttagdest");
//        for(int i = 0; i < MSHR_SIZE; i++) begin
//          $display("%0d:\t%d\t%d\t%d\t%d\t%d", i, nextStatuses[i].valid, nextStatuses[i].addr, nextStatuses[i].memTag,
//                    nextStatuses[i].is_load, nextStatuses[i].destTag);
      //  end
    end
  end
endmodule

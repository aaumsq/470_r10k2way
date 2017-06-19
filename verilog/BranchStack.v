module branchStack(
    input clk,
    input reset,
    
    //inputs for dispatch
    input logic[1:0]            haz_nDispatched,
    input IBEntry_t[1:0]        ib_data,
    input FL_PTR                fl_head,
    input ROB_PTR               rob_tail,
    input PHYS_WITH_READY[30:0] mt_nextMap,
    //inputs for branch resolution
    input BS_PTR                br_bs_ptr,
//    input AGE[1:0]              br_branch_age,
    input logic                 br_pred_wrong,
    input logic                 br_branch_resolved,
    input logic[1:0]            cdb_rd_en,
    input PHYS_REG[1:0]         cdb_rd,
    input SQ_PTR                sq_tail,
    input logic                 sq_empty,

    output logic[2:0] bs_nEntries, //outputs to the fetch buffer, not the hazard detection,
                                   //goes from 0 to 4 (need 3 bits) 
                                   //even if there are no slots left here, it's ok to dispatch non branches
    output B_MASK      bs_bmask,
    output BS_PTR      bs_ptr,
    output BSEntry_t   bs_recoverInfo
    `ifdef BS_DEBUG
      , output BSEntry_t[3:0] bs_stack
    `endif
    );
  
  `ifndef BS_DEBUG
    BSEntry_t[3:0] bs_stack; 
  `endif
  
  BSEntry_t[3:0] next_stack;

  assign bs_ptr = ~bs_stack[0].valid ? 0 : 
                 (~bs_stack[1].valid ? 1 : 
                 (~bs_stack[2].valid ? 2 : 3));

  assign bs_nEntries = bs_stack[0].valid + bs_stack[1].valid + bs_stack[2].valid + bs_stack[3].valid;


  // if we are dispatching first branch, bmask should be 0000                                    
  // the 1st branch does not depend on any other branch.
  assign bs_bmask[0] = bs_stack[0].valid;
  assign bs_bmask[1] = bs_stack[1].valid;
  assign bs_bmask[2] = bs_stack[2].valid;
  assign bs_bmask[3] = bs_stack[3].valid;
  
  
  always_comb begin
    next_stack = bs_stack;
    bs_recoverInfo = '0;

    //fill up the stack
    if((haz_nDispatched == 1) && ib_data[0].fd_control.branch) begin
      next_stack[bs_ptr].valid = 1;
      next_stack[bs_ptr].fl_head = fl_head + 1;
      next_stack[bs_ptr].rob_tail = rob_tail + 1;
      next_stack[bs_ptr].sq_tail = sq_tail;
      next_stack[bs_ptr].sq_empty = sq_empty;
      next_stack[bs_ptr].map = mt_nextMap;
      next_stack[bs_ptr].bmask = bs_bmask;
    end else if((haz_nDispatched == 2) && ib_data[1].fd_control.branch) begin
      next_stack[bs_ptr].valid = 1;
      next_stack[bs_ptr].fl_head = fl_head + 2;
      next_stack[bs_ptr].rob_tail = rob_tail + 2;
      next_stack[bs_ptr].sq_tail = sq_empty? sq_tail : sq_tail + ib_data[0].fd_control.wr_mem;
      next_stack[bs_ptr].sq_empty = sq_empty && !ib_data[0].fd_control.wr_mem;
      next_stack[bs_ptr].map = mt_nextMap;
      next_stack[bs_ptr].bmask = bs_bmask;
    end 
    
    //update the map table based on completes
    for(int cdb_idx = 0; cdb_idx < 2; cdb_idx++) begin
      if(cdb_rd_en[cdb_idx]) begin
        for(int bs_idx = 0; bs_idx < 4; bs_idx++) begin
          for(int mt_idx = 0; mt_idx < 31; mt_idx++) begin
            if(cdb_rd[cdb_idx] == next_stack[bs_idx].map[mt_idx].register) begin
              next_stack[bs_idx].map[mt_idx].ready = 1;
            end
          end
        end
      end
    end
    
    //note: if something completes this cycle, doesn't go to recoverInfo. We do the complete in MT and ROB
    if(br_branch_resolved) begin
      //output that entry
      bs_recoverInfo = bs_stack[br_bs_ptr];
      
      next_stack[br_bs_ptr].valid = 1'b0;
      //invalidate this branch's entry      
      //this line is also needed for wrong_pred because the mispredicted branch does not have bmask set
      
      //branch prediction wrong, invalidate all entries dependent on this branch by checking bmask
      if(br_pred_wrong) begin
        for (int i = 0; i < 4; i++) begin
          if(bs_stack[i].bmask[br_bs_ptr])
            next_stack[i].valid = 0;
        end
      end
      //branch prediction correct.
      else begin
        //clear the bmask for other entries
        for (int i = 0; i < 4; i++) begin
          next_stack[i].bmask[br_bs_ptr] = 1'b0;
        end
      end
    end
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      bs_stack[0].valid <= `SD 0;
      bs_stack[1].valid <= `SD 0;
      bs_stack[2].valid <= `SD 0;
      bs_stack[3].valid <= `SD 0;
    end else begin
      bs_stack <= `SD next_stack;
    end
  end
endmodule

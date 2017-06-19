`define FL_DEBUG
module FreeList(
    input logic clk,
    input logic reset,

    input logic[1:0]      haz_nDispatched,
    input PHYS_REG[1:0]   rob_retireTag,
    input PHYS_REG[1:0]   rob_retireTagOld,
    input logic[1:0]      rob_nRetired,
    input logic           br_pred_wrong,
    input FL_PTR          bs_recov_fl_head,
    
    output PHYS_REG[1:0]  fl_freeRegs,
    output logic[5:0]     fl_availableRegs,
    output FL_PTR         fl_head
    
    `ifdef FL_DEBUG
      , output            FL_PTR fl_tail
      , output            PHYS_REG[31:0] free
    `endif
  );
  
  `ifndef FL_DEBUG
    FL_PTR fl_tail; 
    PHYS_REG[31:0] free;
  `endif
  
  FL_PTR headPlus1, tailPlus1, tailPlus2, nextHead, nextTail;
  logic[5:0] nextAvailableRegs;
  logic[5:0] recovAvailableRegs;
  logic[1:0] retire_en;
  PHYS_REG[1:0] freed_reg;
  
  assign retire_en[0] = rob_nRetired[0] || rob_nRetired[1];  //31 not welcomed in land of the free list
  assign retire_en[1] = rob_nRetired[1];
              
  assign freed_reg[0] = rob_retireTagOld[0] == `PHYS_ZERO_REG? 
                              rob_retireTag[0] : rob_retireTagOld[0];
  assign freed_reg[1] = rob_retireTagOld[1] == `PHYS_ZERO_REG? 
                              rob_retireTag[1] : rob_retireTagOld[1];
  
  assign headPlus1 = fl_head + 1; //wraps from 32 to 0
  assign tailPlus1 = fl_tail + 1; //wraps from 32 to 0
  assign tailPlus2 = fl_tail + 2; //wraps from 32 to 0
  
  assign fl_freeRegs[0] = free[fl_head];
  assign fl_freeRegs[1] = free[headPlus1];
  
  assign nextHead = fl_head + haz_nDispatched; //wraps from 32 to 0
  assign nextTail = fl_tail + retire_en[0] + retire_en[1]; //wraps from 32 to 0
  assign nextAvailableRegs = fl_availableRegs + retire_en[0] + retire_en[1] - haz_nDispatched;
  
  //opposite of the ROB, if tail is right before head, the free list must be empty
  //because there is at least one instruction in the ROB, meaning
  //that the free list cannot be full after rollback
  assign recovAvailableRegs = (bs_recov_fl_head > nextTail || (bs_recov_fl_head == 0 && nextTail == 5'd31)) ? 
                              (32 - (bs_recov_fl_head - nextTail - 1)) :
                              (nextTail - bs_recov_fl_head + 1);

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      fl_head <= `SD 0;
      fl_tail <= `SD 5'd31;
      fl_availableRegs <= `SD 32;
      for(int i = 0; i < 32; i++) begin
        free[i] <= `SD i + 32;
      end
    end else begin      
      fl_tail <= `SD nextTail;
      
      if(retire_en[0]) begin
        free[tailPlus1] <= `SD freed_reg[0];
        if(retire_en[1]) begin
          free[tailPlus2] <= `SD freed_reg[1];
        end
      end else if(retire_en[1]) begin
        free[tailPlus1] <= `SD freed_reg[1];
      end

      if (br_pred_wrong) begin
        fl_head <= `SD bs_recov_fl_head;
        fl_availableRegs <= `SD recovAvailableRegs;
      end else begin
        fl_head <= `SD nextHead;  
        fl_availableRegs <= `SD nextAvailableRegs;
      end
    end
  end
endmodule

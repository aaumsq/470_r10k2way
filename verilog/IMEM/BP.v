//the BTB is direct mapped now
//BTB_TAG_SIZE is defined in sys_defs.vh with the BTBEntry_t
//for direct mapped BTB, the BTB_TAG_SIZE must be set to log2(BTB_SIZE)
module BTB #(parameter SIZE=`BTB_SIZE )(
    input logic         clk,
    input logic         reset,

    //input from if to get NPC of branches
    input PC [1:0]      if_not_taken_NPC,
    input logic [1:0]   if_is_branch,
    //input from branch recovery to fix BTB stored value
    input logic         br_taken_NPC_wrong,
    input PC            br_not_taken_NPC,
    input PC            br_recov_NPC,
    //input from ib
    input  logic[1:0]   if_valid,

    //output to BP,
    output PC [1:0]     btb_taken_NPC
  );

  BTBEntry_t [SIZE-1:0] buffer;
  BTBEntry_t [SIZE-1:0] nextBuffer;
  BTB_TAG [1:0]         btb_tag_in;
  BTB_TAG               br_btb_tag;
  //logic [1:0]           btb_hit;  //not needed for direct mapped

  //truncate the NPC for btb tag
  //0th ant 1st bit of PC is always zero, can ignore them
  assign btb_tag_in[1] = if_not_taken_NPC[1][`BTB_TAG_SIZE+1:2];
  assign btb_tag_in[0] = if_not_taken_NPC[0][`BTB_TAG_SIZE+1:2];
  assign br_btb_tag    = br_not_taken_NPC[`BTB_TAG_SIZE+1:2];
  
  always_comb begin
    nextBuffer = buffer;
    if(br_taken_NPC_wrong) begin   //must fix BTB value (this will only happen with jump because they use regB)
      nextBuffer[br_btb_tag].taken_NPC = br_recov_NPC;
    end
    for(int i = 0; i < 2; i++) begin
      if(if_is_branch[i] && if_valid[i]) begin  //only update if we are putting into instrbuffer
        //find for the branch in BTB
        if(buffer[btb_tag_in[i]].valid) begin   //hit
          btb_taken_NPC[i] = nextBuffer[btb_tag_in[i]].taken_NPC; //use next buffer because we might have fixed this entry above
        end else begin   //no hit. first time fill entry
          nextBuffer[btb_tag_in[i]].taken_NPC = if_not_taken_NPC[i];  //just put not taken in there for now
          nextBuffer[btb_tag_in[i]].valid = 1;
          btb_taken_NPC[i] = if_not_taken_NPC[i]; //just put not taken in here because we haven't found the taken addr
        end
      end else begin    //not branch, no need to touch the BTB entries
        btb_taken_NPC[i] = if_not_taken_NPC[i]; //doesn't matter, just a place holder
      end
    end
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      buffer <= `SD '0;
    end else begin
      buffer <= `SD nextBuffer;
    end
  end
endmodule

module BHT #(parameter SIZE=`BHT_SIZE)(
    input logic         clk,
    input logic         reset,

    //input from fetch
    input PC  [1:0]     if_not_taken_NPC,
    input logic [1:0]   if_is_branch,
    //input from branch_fu
    input logic         br_branch_resolved,
    input logic         br_pred_taken,
    input logic         br_pred_dir_wrong,
    input PC            br_not_taken_NPC,
    //input from ib
    input  logic[1:0]   if_valid,

    output logic [1:0]  bht_pred_taken
  );

  //note: the BHT and BTB does not need to have the same size and tag size

  BHTEntry_t [SIZE-1:0] buffer;
  BHTEntry_t [SIZE-1:0] nextBuffer;
  BHT_TAG [1:0]         bht_tag_in;
  BHT_TAG               br_bht_tag;
  //logic [1:0]           bht_hit;  //not needed for direct mapped

  //truncate the NPC for BHT tag
  //0th ant 1st bit of PC is always zero, can ignore them
  assign bht_tag_in[1] = if_not_taken_NPC[1][`BHT_TAG_SIZE+1:2];
  assign bht_tag_in[0] = if_not_taken_NPC[0][`BHT_TAG_SIZE+1:2];
  assign br_bht_tag    = br_not_taken_NPC[`BHT_TAG_SIZE+1:2];

  always_comb begin
    nextBuffer = buffer;
    bht_pred_taken = 2'b00;
    if(br_branch_resolved) begin   //update counter
      if(br_pred_taken) begin
        unique case(buffer[br_bht_tag].counter)
          2'b00: begin  //this case should not happen unless multiple of same branch fetched before resolving
            nextBuffer[br_bht_tag].counter = br_pred_dir_wrong? 2'b00 : 2'b01;
          end
          2'b01: begin //this case should not happen unless multiple of same branch fetched before resolving
            nextBuffer[br_bht_tag].counter = br_pred_dir_wrong? 2'b00 : 2'b10;
          end
          2'b10: begin
            nextBuffer[br_bht_tag].counter = br_pred_dir_wrong? 2'b01 : 2'b11;
          end
          2'b11: begin
            nextBuffer[br_bht_tag].counter = br_pred_dir_wrong? 2'b10 : 2'b11;
          end
        endcase
      end else begin
        unique case(buffer[br_bht_tag].counter)
          2'b00: begin
            nextBuffer[br_bht_tag].counter = br_pred_dir_wrong? 2'b01 : 2'b00;
          end
          2'b01: begin
            nextBuffer[br_bht_tag].counter = br_pred_dir_wrong? 2'b10 : 2'b00;
          end
          2'b10: begin //this case should not happen unless multiple of same branch fetched before resolving
            nextBuffer[br_bht_tag].counter = br_pred_dir_wrong? 2'b11 : 2'b01;
          end
          2'b11: begin //this case should not happen unless multiple of same branch fetched before resolving
            nextBuffer[br_bht_tag].counter = br_pred_dir_wrong? 2'b11 : 2'b10;
          end
        endcase
      end
    end
    //give prediction for fetched branches
    for(int i = 0; i < 2; i++) begin
      if(if_is_branch[i] && if_valid[i]) begin
        unique case(nextBuffer[bht_tag_in[i]].counter)  //use nextBuffer because it may be updated from branch_fu
          2'b00: begin
            bht_pred_taken[i] = 0;
          end
          2'b01: begin
            bht_pred_taken[i] = 0;
          end
          2'b10: begin
            bht_pred_taken[i] = 1;
          end
          2'b11: begin
            bht_pred_taken[i] = 1;
          end
        endcase
      end else begin  //not branch, just predict not taken
        bht_pred_taken[i] = 0;
      end
    end
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
      //reset to weakly not taken (goes to taken faster for loops)
      for(int i = 0; i < `BHT_SIZE; i++) begin
        buffer[i].counter <= `SD 2'b01;
      end
    end else begin
      buffer <= `SD nextBuffer;
    end
  end
endmodule

module BP(
    input logic clk,
    input logic reset,

    //input from if
    input FD_control_t [1:0]  if_fd_control,
    input PC  [1:0]           if_not_taken_NPC,
    //input from branch_fu
    input logic         br_pred_taken,
    input logic         br_branch_resolved,
    input logic         br_pred_dir_wrong,
    input logic         br_taken_NPC_wrong,
    input PC            br_not_taken_NPC,
    input PC            br_recov_NPC,
    //input from ib
    input  logic[1:0]   if_valid,

    output PC [1:0]     bp_pred_NPC,      //predicted NPC. can be taken or not taken
    output PC [1:0]     bp_not_pred_NPC,  //opposite of predicted NPC, used for prefetching
    output PC [1:0]     bp_not_taken_NPC, //normal NPC. it is the not taken NPC (used by fu to calculate actual NPC)
    output logic [1:0]  bp_pred_taken
  );

  PC [1:0]    btb_taken_NPC;
  logic [1:0] if_is_branch;
  //
  always_comb begin
    if_is_branch[1] = if_fd_control[1].cond_branch | if_fd_control[1].uncond_branch;
    if_is_branch[0] = if_fd_control[0].cond_branch | if_fd_control[0].uncond_branch;
    bp_not_taken_NPC = if_not_taken_NPC;
  end

  //BTB_SIZE defined in sys_defs.vh with the BTBEntry_t
  BTB btb_0(.clk(clk), .reset(reset), .if_not_taken_NPC(if_not_taken_NPC),
        .if_is_branch(if_is_branch), .br_taken_NPC_wrong(br_taken_NPC_wrong),
        .br_not_taken_NPC(br_not_taken_NPC), .br_recov_NPC(br_recov_NPC),
        .if_valid(if_valid), .btb_taken_NPC(btb_taken_NPC));

  BHT bht_0(.clk(clk), .reset(reset),
        .if_not_taken_NPC(if_not_taken_NPC), .if_is_branch(if_is_branch),
        .br_pred_taken(br_pred_taken), .br_pred_dir_wrong(br_pred_dir_wrong),
        .br_branch_resolved(br_branch_resolved), .br_not_taken_NPC(br_not_taken_NPC), 
        .if_valid(if_valid), .bht_pred_taken(bp_pred_taken));

  //assign bp_pred_taken = 0;
  always_comb begin
    for(int i = 0; i < 2; i++) begin
      if(bp_pred_taken) begin
        bp_pred_NPC[i] = btb_taken_NPC[i];
        bp_not_pred_NPC[i] = bp_not_taken_NPC[i];
      end else begin
        bp_pred_NPC[i] = bp_not_taken_NPC[i];
        bp_not_pred_NPC[i] = btb_taken_NPC[i];
      end
    end
  end
endmodule

`define CDB_DEBUG
module CDB(
    input logic[7:0]        fub_valid, // fub =  Functional Unit Buffer
    input PHYS_REG [7:0]    fub_tagDest,
    input DATA [7:0]        fub_result,
    input B_MASK[7:0]       fub_bmask,
    input logic             br_pred_wrong,
    input BS_PTR            br_bs_ptr,
    
    output PHYS_REG [1:0]   cdb_rd,
    output logic [1:0]      cdb_rd_en,
    output logic [7:0]      cdb_stall,
    output DATA [1:0]       cdb_reg_value
    );

  logic [2:0] first_selected;
  // Priority Selector
  // BR -> LD/ST -> MULT -> ALU
  always_comb begin
    cdb_rd_en[0] = 0;
    cdb_rd_en[1] = 0;
    cdb_stall = 8'hff;
    first_selected = 3'h7;
    cdb_rd[0] = `PHYS_ZERO_REG;
    cdb_rd[1] = `PHYS_ZERO_REG;
    cdb_reg_value = {64'h0, 64'h0};

  //we go through the buffer from low to high index. Our highest priority FU have lowest index
    for (int i = 0; i < 8; i++) begin
      if (fub_valid[i] && !(br_pred_wrong && fub_bmask[i][br_bs_ptr])) begin
        cdb_rd_en[0] = 1;
        cdb_rd[0] = fub_tagDest[i];
        cdb_stall[i] = 0;
        first_selected = i;
        // XXX: Currently all FUs are writing back to the regfile even though not all instructions
        //      need to write to a register. Some branches need to write, loads need to, stores don't.
        //      Because all we know in the CDB is which FU its coming from, we can't optimize this.
        cdb_reg_value[0] = fub_result[i];
        break;
      end
    end // for

    for (int j = 0; j < 8; j++) begin  //note: first_select + 1 is assigned to int, won't overflow
      if (fub_valid[j] && j != first_selected 
          && !(br_pred_wrong && fub_bmask[j][br_bs_ptr])) begin
        cdb_rd_en[1] = 1;
        cdb_rd[1] = fub_tagDest[j];
        cdb_stall[j] = 0;
        cdb_reg_value[1] = fub_result[j];
        break;
      end
    end

  end // always_comb

endmodule

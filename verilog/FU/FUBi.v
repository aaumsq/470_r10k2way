
module FUBi (
    input logic               clk, reset,
    input DATA                fu_result,
    input logic               fu_done,
    input PHYS_REG            fu_tagDest,
    input B_MASK              fu_bmask,
    input logic               cdb_stall,
    input logic               br_pred_wrong,
    input logic               br_branch_resolved,
    input BS_PTR              br_bs_ptr,

    output logic              fub_busy,
    output logic              fub_valid,
    output DATA               fub_result,
    output PHYS_REG           fub_tagDest,
    output B_MASK             fub_bmask
    
    `ifdef FUB_DEBUG
      , output FUBIBREntry_t[1:0] buffer
    `endif

    );
  `ifndef FUB_DEBUG
    FUBIBREntry_t[1:0] buffer;
  `endif
  
  FUBIBREntry_t new_entry;
  FUBIBREntry_t[1:0] next_buffer;

  assign fub_valid = buffer[1].valid;
  assign fub_result = buffer[1].result;
  assign fub_tagDest = buffer[1].tagDest;
  assign fub_bmask = buffer[1].bmask;

  always_comb begin    
    new_entry = '0;
    if(fu_done) begin
      new_entry.result = fu_result;
      new_entry.valid = fu_done;
      new_entry.tagDest = fu_tagDest;
      new_entry.bmask = fu_bmask;
      if(br_branch_resolved && !br_pred_wrong) begin
        new_entry.bmask[br_bs_ptr] = 0;
      end
    end
  end

  always_comb begin
    fub_busy = 0;
    if(br_pred_wrong & ((buffer[1].bmask[br_bs_ptr] &  buffer[1].valid) ||
      (buffer[0].bmask[br_bs_ptr] & buffer[0].valid))) begin
      fub_busy = 0;
    end else if (buffer[0].valid & buffer[1].valid & cdb_stall) begin
      fub_busy = 1;
    end else if (buffer[1].valid & cdb_stall & fu_done) begin
      fub_busy = 1;
    end
  end

  always_comb begin 
    next_buffer = buffer;
    //check for mispredicted entries
    //if mispredicted entry is being completed, we ignore it (too late to invalidate)
    if(br_branch_resolved) begin
      if(br_pred_wrong) begin
        if(buffer[1].bmask[br_bs_ptr] | !buffer[1].valid) begin   //buffer[1] mispredicted or not valid
          if(buffer[0].valid && !buffer[0].bmask[br_bs_ptr]) begin  
            next_buffer[1] = buffer[0];
            next_buffer[0].valid = 0;
          end else if (!buffer[0].valid) begin
            if(fu_done) begin
              next_buffer[1] = new_entry;
            end else begin
              next_buffer[1].valid = 0;
            end
          end else if (buffer[0].valid && buffer[0].bmask[br_bs_ptr]) begin
              next_buffer[0].valid = 0;
              next_buffer[1].valid = 0;
          end
        end else begin //first buffer valid and not mispredicted
          if(cdb_stall) begin //stall
            if(buffer[0].bmask[br_bs_ptr] && buffer[0].valid) begin
              next_buffer[0].valid = 0;
            end else if(!buffer[0].valid) begin
              if(fu_done) begin
                next_buffer[0] = new_entry;
              end
            end
          end else begin  //not stall
            if(buffer[0].bmask[br_bs_ptr] && buffer[0].valid) begin
              next_buffer[1].valid = 0;
              next_buffer[0].valid = 0;
            end else if (!buffer[0].bmask[br_bs_ptr] && buffer[0].valid) begin //not mispredicted
              next_buffer[1] = buffer[0];
              next_buffer[0].valid = 0;
            end else begin  //  !buffer[0].valid
              if(fu_done) begin
                next_buffer[1] = new_entry;
                next_buffer[0].valid = 0;
              end else begin
                next_buffer[1].valid = 0;
                next_buffer[0].valid = 0;
              end
            end
          end
        end
      end else begin // !br_pred_wrong(correct prediction)
            //move stuff through the buffer
        if(buffer[1].valid && !cdb_stall) begin // if we are removing the last entry
          if(buffer[0].valid) begin             // if we are copying the first into the last
            next_buffer[1] = buffer[0];
            next_buffer[0].valid = 0;
          end else if (fu_done) begin           // if we are inserting into the last
            next_buffer[1] = new_entry;
          end else begin                        // else it's invalid (nothing coming from fu)
            next_buffer[1].valid = 0;
          end
        end else if(buffer[1].valid && cdb_stall && fu_done) begin
          if(!buffer[0].valid) begin
            next_buffer[0] = new_entry;
          end
        end else if(!buffer[1].valid) begin
          if(fu_done) begin
            next_buffer[1] = new_entry;
          end
        end
            //clear bmask
        next_buffer[0].bmask[br_bs_ptr] = 0;
        next_buffer[1].bmask[br_bs_ptr] = 0;
      end      
    end else begin
      if(buffer[1].valid && !cdb_stall) begin // if we are removing the last entry
        if(buffer[0].valid) begin             // if we are copying the first into the last
          next_buffer[1] = buffer[0];
          next_buffer[0].valid = 0;
        end else if (fu_done) begin           // if we are inserting into the last
          next_buffer[1] = new_entry;
        end else begin                        // else it's invalid (nothing coming from fu)
          next_buffer[1].valid = 0;
        end
      end else if(buffer[1].valid && cdb_stall && fu_done) begin
        if(!buffer[0].valid) begin
          next_buffer[0] = new_entry;
        end
      end else if(!buffer[1].valid) begin
        if(fu_done) begin
          next_buffer[1] = new_entry;
        end
      end
    end
  end 
  
  // synopsys sync_set_reset "reset"
  always_ff @(posedge clk) begin
    if(reset) begin
        buffer[0].valid <= `SD 0;
        buffer[1].valid <= `SD 0;
    end else begin
      //$display("buffer busy: %0d", fub_busy);
      //$display("buffer valid: %0d, buffer0 valid: %0d", next_buffer[0].valid, next_buffer[1].valid);
      //$display("tag [%d, %d]", next_buffer[0].valid * next_buffer[0].tagDest, next_buffer[1].valid * next_buffer[1].tagDest);
     //$display("storing [%d, %d]", next_buffer[0].valid * next_buffer[0].result, next_buffer[1].valid * next_buffer[1].result);
      buffer    <= `SD next_buffer;
    end
  end
endmodule

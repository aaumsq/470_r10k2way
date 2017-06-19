//this is my project 2 testbench slightly modified (Yi Zhi)

module testbench();

  DATA      a,b;
  logic     quit, clk, start, reset;

  DATA      result;
  logic     done;

  PHYS_REG  fus_tagDest;
  PHYS_REG  mult_tagDest;

  wire [63:0] cres = a*b;

  wire correct = (cres===result && fus_tagDest === mult_tagDest)|~done;


  pipe_mult_fu m0(
            .clk(clk),
            .reset(reset),
            .fus_opA(a),
            .fus_opB(b),
            .fus_en(start),
            .fus_tagDest(fus_tagDest),
            .mult_result(result),
            .mult_done(done),
            .mult_tagDest(mult_tagDest));

  always @(posedge clk)
    #2 if(!correct) begin 
      $display("Incorrect at time %4.0f",$time);
      $display("cres = %h result = %h",cres,result);
      $finish;
    end

  always begin
    #5;
    clk=~clk;
  end

  // Some students have had problems just using "@(posedge done)" because their
  // "done" signals glitch (even though they are the output of a register). This
  // prevents that by making sure "done" is high at the clk edge.
  task wait_until_done;
    forever begin : wait_loop
      @(posedge done);
      @(negedge clk);
      if(done) disable wait_until_done;
    end
  endtask



  initial begin

    //$vcdpluson;
    $monitor("Time:%4.0f done:%b a:%h b:%h product:%h result:%h",$time,done,a,b,cres,result);
    a=2;
    b=3;
    reset=1;
    clk=0;
    start=1;

    @(negedge clk);
    reset=0;
    @(negedge clk);
    start=0;
    wait_until_done();
    start=1;
    a=-1;
    @(negedge clk);
    start=0;
    wait_until_done();
    @(negedge clk);
    start=1;
    a=-20;
    b=5;
    @(negedge clk);
    start=0;
    wait_until_done();
    quit = 0;
    quit <= #10000 1;
    while(~quit) begin
      start=1;
      a={$random,$random};
      b={$random,$random};
      @(negedge clk);
      start=0;
      wait_until_done();
    end
    $display("PASSED");
    $finish;
  end

endmodule


  
  

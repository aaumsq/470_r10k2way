/*
  This test was hand written by Joel VanLaven to put pressure on ROBs
  It generates and stores in order 64 32-bit pseudo-random numbers in 
  16 passes using 64-bit arithmetic.  (i.e. it actually generates 64-bit
  values and only keeps the more random high-order 32 bits).  The constants
  are from Knuth.  To be effective in testing the ROB the mult must take
  a while to execute and the ROB must be "small enough".  Assuming that
  there is any reasonably working form of branch prediction and that the
  Icache works and is large enough, multiple passes should end up going
  into the ROB at the same time increasing the efficacy of the test.  If
  for some reason the ROB is not filling with this test is should be
  easily modifiable to fill the ROB.

  In order to properly pass this test the pseudo-random numbers must be
  the correct numbers.
*/
        data = 0xff        
        lda $r1,data
        lda $r2,2
        mulq    $r1,$r1,$r3
        mulq    $r3,$r3,$r3
        mulq    $r3,$r3,$r3
        srl     $r3,1,$r3
        addq    $r3,0xf,$r3
        mulq    $r3,2,$r5
        mulq    $r3,3,$r6
        mulq    $r3,4,$r7
        mulq    $r3,$r2,$r8
        mulq    $r3,$r2,$r9
        mulq    $r3,$r2,$r10
        mulq    $r3,$r2,$r11
        mulq    $r3,$r2,$r12
        mulq    $r3,$r2,$r13
        mulq    $r3,$r2,$r14
        mulq    $r3,$r2,$r15
        mulq    $r3,$r2,$r16
        mulq    $r3,$r2,$r17
        mulq    $r3,$r2,$r18
        mulq    $r3,$r2,$r19
        mulq    $r3,$r2,$r20
        addq    $r3,$r2,$r13
        addq    $r3,$r2,$r14
        addq    $r3,$r2,$r15
        addq    $r3,$r2,$r13
        mulq    $r3,$r2,$r21
        mulq    $r3,$r2,$r22
        mulq    $r3,$r2,$r23
        mulq    $r3,$r2,$r24
        mulq    $r3,$r2,$r25
        mulq    $r3,$r2,$r26
        mulq    $r3,$r2,$r27
        mulq    $r3,$r2,$r28
        addq    $r3,$r2,$r13
        addq    $r3,$r2,$r14
        addq    $r3,$r2,$r15
        addq    $r3,$r2,$r13
        addq    $r3,$r2,$r14
        mulq    $r2,$r2,$r5
        addq    $r2,$r2,$r6
        addq    $r2,$r2,$r7
        addq    $r2,$r2,$r8
        mulq    $r2,$r2,$r9
        addq    $r2,$r2,$r10
        mulq    $r2,$r2,$r11
	call_pal        0x555

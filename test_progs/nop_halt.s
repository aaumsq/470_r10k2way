/*
	TEST PROGRAM #1: copy memory contents of 16 elements starting at
			 address 0x1000 over to starting address 0x1100. 
	

	long output[16];

	void
	main(void)
	{
	  long i;
	  *a = 0x1000;
          *b = 0x1100;
	 
	  for (i=0; i < 16; i++)
	    {
	      a[i] = i*10; 
	      b[i] = a[i]; 
	    }
	}
*/
  lda $r0, 0
  lda $r1, 1
  lda $r2, 2
  lda $r3, 3
  lda $r4, 4
  lda $r5, 5
  lda $r6, 6
  lda $r7, 7
  lda $r8, 8
  lda $r9, 9
  lda $r10, 10
  lda $r11, 11
  lda $r12, 12
  lda $r13, 13
  lda $r14, 14
  lda $r15, 15
  lda $r16, 16
  lda $r17, 17
  lda $r18, 18
  lda $r19, 19
  lda $r20, 20
  lda $r21, 21
  lda $r22, 22
  lda $r23, 23
  lda $r24, 24
  lda $r25, 25
  lda $r26, 26
  lda $r27, 27
  lda $r28, 28
  lda $r29, 29
  lda $r30, 30
	nop
  nop
  nop
	call_pal        0x555
  nop
  nop

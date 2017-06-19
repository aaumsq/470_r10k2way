/*
	TEST PROGRAM #3: compute first 16 fibonacci numbers
			 with forwarding and stall conditions in the loop


	long output[16];
	
	void
	main(void)
	{
	  long i, fib;
	
	  output[0] = 1;
	  output[1] = 2;
	  for (i=2; i < 16; i++)
	    output[i] = output[i-1] + output[i-2];
	}
*/
	
	data = 0x1000	
	lda     $r3,data					#207f1000
	nop
	nop
	nop
	nop
	lda     $r4,data+8					#209f1008
	nop
	nop
	nop
	nop
	lda     $r5,data+16					#20bf1010
	nop
	nop
	nop
	nop
	lda     $r9,2						#213f0002
	nop
	nop
	nop
	nop
	lda     $r1,1						#203f0001
	nop
	nop
	nop
	nop
	stq     $r1,0($r3)					#b4230000
	nop
	nop
	nop
	nop					
	stq	$r1,0($r4)						#b4240000
	nop
	nop
	nop
	nop	
loop:	ldq     $r1,0($r3)				#a4230000
	nop
	nop
	nop
	nop
	ldq     $r2,0($r4)					#a4440000
	nop
	nop
	nop
	nop
	addq    $r2,$r1,$r2					#40410402
	nop
	nop
	nop
	nop
	addq    $r3,0x8,$r3					#40611403
	nop
	nop
	nop
	nop
	addq	$r4,0x8,$r4					#40811404
	nop
	nop
	nop
	nop
	addq    $r9,0x1,$r9					#41203409
	nop
	nop
	nop
	nop	
	cmple   $r9,0xf,$r10				#4121fdaa
	nop
	nop
	nop
	nop
	stq     $r2,0($r5)					#b4450000
	addq    $r5,0x8,$r5					#40a11405
	nop
	nop
	nop
	nop
	bne     $r10,loop					#f55fffd6
	nop
	nop
	nop
	nop
	call_pal        0x555
	nop
	nop
	nop
	nop

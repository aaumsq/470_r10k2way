/*
	This program tests data hazard. Normal hazard and load-use hazard are tested
*/
	data = 0x1000
	lda     $r3,data
	lda     $r0,0
	lda     $r1,1
	lda     $r2,2
	addq    $r1,$r0,$r4	
	addq    $r4,$r0,$r5	/*data hazard, no stalling*/
	ldq     $r6,0($r3)
	addq    $r6,$r0,$r7	/*load-use hazard, stall one cycle*/
	lda     $r0,9
	addq    $r0,$r0,$r8	/*make sure lda-use does not stall*/
	nop
	nop
	nop			/*test for OPB as well*/
	addq    $r1,$r0,$r4	
	addq    $r0,$r4,$r5	/*data hazard, no stalling*/
	ldq     $r6,0($r3)
	addq    $r0,$r6,$r7	/*load-use hazard, stall one cycle*/
	nop
	nop
	nop
	call_pal        0x555


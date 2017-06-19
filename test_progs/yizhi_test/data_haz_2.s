/*
	This program tests data hazard. Normal hazard and load-use hazard are tested
*/
	data = 0x1000
	lda     $r3,data
	stq     $r3,0($r3)
	nop
	nop
	nop
	ldq     $r0,0($r3)
/*	stq     $r0,0($r0) */
	addq 	$r0,$r0,$r2
	nop
	nop
	nop
	call_pal        0x555


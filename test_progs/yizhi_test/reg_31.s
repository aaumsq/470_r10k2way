/*
	This program tests data hazard. Normal hazard and load-use hazard are tested
*/
	data = 0x1000
	lda     $r31,data
	addq	$r31,$r31,$r0
	nop
	nop
	nop
	nop
	call_pal        0x555


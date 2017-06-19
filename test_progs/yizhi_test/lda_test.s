/*
	This program tests data hazard. Normal hazard and load-use hazard are tested
*/
	data = 0x1000
	lda     $r3,data
	nop
	nop
	nop
	nop
	call_pal        0x555


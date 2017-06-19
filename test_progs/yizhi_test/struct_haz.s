/*
	Note: lda is NOT a memory accessing instruction! It loads immediate into register
	This program brings in structural hazard via memory usage (stq, ldq)
*/
	data = 0x1000
	lda     $r3,data
	lda     $r0,0
	lda     $r1,1
	lda     $r2,2
	stq     $r0,0($r3)
	stq     $r1,16($r3)
	stq     $r2,32($r3)
	lda     $r4,4
	stq     $r3,48($r3)
	ldq     $r5,0($r3)
	ldq     $r6,16($r3)
	ldq     $r7,32($r3)
	call_pal        0x555


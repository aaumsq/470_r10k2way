/*
	Fill up the branch stack
*/
	data = 0x1000
	lda	$r5,data
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
	mulq $r5, $r5, $r5
  mulq $r5, $r5, $r5
  beq $r5, skip
  beq $r5, skip
  beq $r5, skip
  beq $r5, skip
  mulq $r5, $r5, $r5
  beq $r5, skip
skip:	
	lda	$r6,0
	call_pal        0x555

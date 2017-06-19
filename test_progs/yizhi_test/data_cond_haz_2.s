/*
	Test of both data and conditional hazard. With load-use
*/
	data = 0x1000
	lda	$r5,data
	stq     $r5,0($r5)
	ldq     $r6,0($r5)		
	bne     $r6,skip		/*branch taken*/
	addq	$r5,$r5,$r5		/*should not run*/
	call_pal	0x555		/*should not run*/
skip:	lda	$r7,0
	stq     $r7,0($r5)
	ldq     $r8,0($r5)				
	bne     $r8,skip		/*branch not taken*/
end:	call_pal        0x555


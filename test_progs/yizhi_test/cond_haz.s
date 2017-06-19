/*
	Simple test of conditional hazard. Tests branch taken and not taken
*/
	data = 0x1000
	lda	$r5,data
	nop
	nop
	nop				
	bne     $r5,skip		/*branch taken*/
	call_pal	0x555		/*should not run*/
skip:	lda	$r6,0	
	nop
	nop
	nop			
	bne     $r6,skip		/*branch not taken*/
end:	call_pal        0x555


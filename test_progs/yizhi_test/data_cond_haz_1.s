/*
	Simple test of both data and conditional hazard. no load-use
*/
	data = 0x1000
	lda	$r5,data
	nop		
	bne     $r5,skip		/*branch taken*/
	call_pal	0x555		/*should not run*/
skip:	
	lda	$r6,0				
	bne     $r6,skip		/*branch not taken*/
end:	
	call_pal        0x555


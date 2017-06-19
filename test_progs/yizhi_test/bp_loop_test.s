        lda     $r4,0		#84	54
loop:   addq    $r4,1,$r4	#88	58
        cmple   $r4,0xff,$r5	#92	5c
        bne     $r5,loop	#148	94
	call_pal        0x555	#152	98

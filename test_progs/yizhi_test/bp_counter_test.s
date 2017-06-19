        lda     $r4,0		#84	54
        lda     $r6,0		#84	54
loop:   addq    $r4,1,$r4	#88	58
loop2:  cmple   $r4,0x1,$r5	#92	5c
        bne     $r5,loop	#148	94
        addq    $r6,1,$r6	#88	58
        cmple   $r6,0x6,$r7	#92	5c
        bne     $r7,loop2	#148	94
	call_pal        0x555	#152	98

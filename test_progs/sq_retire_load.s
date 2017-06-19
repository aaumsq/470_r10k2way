/*
Written by Jiale Huang
Test whether sq can load the value retired in sq that cycle
*/
        data = 0x1000
	lda	$r0,data
        lda $r1,1
        lda $r2,2
        lda $r3,3
        lda $r4,4
        addq $r1,1,$r1
        addq $r2,1,$r5
        addq $r2,1,$r5
        addq $r2,1,$r3
        stq     $r3,0($r0)
        addq $r2,1,$r5
       # ldq     $r4,0($r0)
        addq $r2,1,$r5
        addq $r2,1,$r5
        ldq     $r4,0($r0)
        addq $r2,1,$r5
        addq $r2,1,$r5
        #ldq     $r4,0($r0)
        addq $r2,1,$r5
        addq $r2,1,$r5
        addq $r2,1,$r5
        addq $r2,1,$r5
	call_pal        0x555
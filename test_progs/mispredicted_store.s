/* A program to ensure that a mispredicted store does not write to memory */
        data = 0x1000
	      lda	      $r0,data
        lda       $r1, 0x10
        lda       $r2, 0x20
        lda       $r3, 0x30
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        br        secd
frst:   stq       $r1,8($r0)
        stq       $r2,16($r0)
secd:   stq       $r3,32($r0)
        nop
        nop
        nop
        nop
        call_pal  0x555

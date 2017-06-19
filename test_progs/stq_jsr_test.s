      data = 0x1000        
        lda     $r1,1       #0  
        lda     $r27,32     #
        lda     $r2,data    #8 <-
        stq    $r1,0($r2)   #
        stq    $r1,8($r2)   #16
        stq    $r1,16($r2)  #
        stq    $r1,24($r2)  #24 <-
        stq    $r1,32($r2)  #
        stq    $r1,40($r2)  #32
        stq    $r1,48($r2)  #
        stq    $r1,56($r2)  #40 <-
        stq    $r1,64($r2)  #
        stq    $r1,72($r2)  #48
        addq    $r1,1,$r1   #
        addq    $r27,8,$r27#56 <-
        jsr     $r26,($r27) #
	call_pal        0x555     #64
	call_pal        0x555     #
	call_pal        0x555     #70 <-

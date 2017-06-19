      data = 0x1000        
        lda     $r1,0       #32
        lda     $r27,0      #33
        lda     $r2,data    #34-
        ldq    $r4,0($r1)   #35
        ldq    $r5,8($r1)   #36-
        ldq    $r6,16($r1)  #37
        ldq    $r7,24($r1)  #38-
        ldq    $r8,32($r1)  #39
        ldq    $r9,40($r1)  #40-
        ldq    $r10,48($r1) #41
        ldq    $r11,56($r1) #42-
        ldq    $r12,64($r1) #43
        ldq    $r13,72($r1) #44-
        addq    $r1,8,$r1   #45
        addq    $r27,8,$r27 #46-
        jsr     $r26,($r27) #47
	call_pal        0x555     #  -
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
	call_pal        0x555     #
  call_pal        0x000
  call_pal        0x111
  call_pal        0x222
  call_pal        0x333
  call_pal        0x444
  call_pal        0x666
  call_pal        0x777
  call_pal        0x888
  call_pal        0x999
  call_pal        0xAAA
  call_pal        0xBBB
  call_pal        0xCCC
  call_pal        0xDDD
  call_pal        0xEEE
  call_pal        0xFFF

/*
	bombards the pipeline with lots of stq. the mulq are used to stall $r3 so the stq cannot retire
  fill up the store buffer and see what happens
*/
	lda     $r2,1000
  lda     $r3,2
  mulq    $r3,2,$r3
  mulq    $r3,2,$r3
  mulq    $r3,2,$r3
  mulq    $r3,2,$r3
  mulq    $r3,2,$r3
  mulq    $r3,2,$r3
  mulq    $r3,2,$r3
  mulq    $r3,2,$r3
	stq     $r3,0($r2)
	stq     $r3,8($r2)
	stq     $r3,16($r2)
	stq     $r3,24($r2)
	stq     $r3,32($r2)
	stq     $r3,40($r2)
	stq     $r3,48($r2)
	stq     $r3,56($r2)
	stq     $r3,64($r2)
	stq     $r3,72($r2)
	stq     $r3,80($r2)
	call_pal        0x555
	stq     $r2,8($r2)
	stq     $r2,16($r2)

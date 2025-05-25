|;*****************************************************************************
|; PRE-RAM UTILITY FUNCTIONS & MACROS
|;*****************************************************************************

|; macro to print string in A0
|; clobbers D0.b
    .macro  ldrPrintStr
L\@mloop:
    move.b  %a0@+,%d0                       |; get byte from string
    beq.s   L\@mexit                        |; exit if null
L\@mwait:
    btst    #1,acia1Com                     |; check ACIA TxRdy bit
    beq.s   L\@mwait                        |; wait until ready
    move.b  %d0,acia1Dat                    |; print byte
    bra.s   L\@mloop                        |; loop until done
L\@mexit:
    .endm


|; macro to print immediate debug string
|; clobbers A0.l, D0.b
    .macro  ldrPrintStrI str
    lea     %pc@(L\@mstr),%a0               |; grab string pointer
L\@mloop:
    move.b  %a0@+,%d0                       |; get byte from string
    beq.s   L\@mexit                        |; exit if null
L\@mwait:
    btst    #1,acia1Com                     |; check ACIA TxRdy bit
    beq.s   L\@mwait                        |; wait until ready
    move.b  %d0,acia1Dat                    |; print byte
    bra.s   L\@mloop                        |; loop until done
L\@mstr:    .ascii "\str\0"                 |; immediate string
    .even
L\@mexit:
    .endm


|; macro to print a hex nybble in D0
|; clobbers D0.b
    .macro  ldrPrintHexNyb
    andi.b  #0x0f,%d0                       |; mask low nybble
    cmpi.b  #0x0a,%d0                       |; check if [0-9] or [a-f]
    blt.s   L\@num                          |; branch if numerical
    addi.b  #0x37,%d0                       |; make result ascii letter
    bra     L\@prt                          |; go print
L\@num:
    addi.b  #0x30,%d0                       |; make result ascii number
L\@prt:
    btst    #1,acia1Com                     |; check ACIA TxRdy bit
    beq.s   L\@prt                          |; wait until ready
    move.b  %d0,acia1Dat                    |; print byte
    .endm


|; function to print a hex byte in D0
|; clobbers D1.b
ldrPrintHexByteF:
    move.b  %d0,%d1                         |; save byte
    lsr.b   #4,%d0                          |; get high nybble
    ldrPrintHexNyb                          |; print high nybble
    move.b  %d1,%d0                         |; restore byte
    ldrPrintHexNyb                          |; print low nybble
    move.b  %d1,%d0                         |; restore byte
    jmp     %a6@                            |; return


|; function to print a hex word in D0
|; clobbers D1.w
ldrPrintHexWordF:
    ror.w   #8,%d0                          |; swap bytes in word
    move.w  %d0,%d1                         |; save swapped word
    ror.b   #4,%d0                          |; get high nyb of high byte
    ldrPrintHexNyb                          |; print it
    move.b  %d1,%d0                         |; restore high byte
    ldrPrintHexNyb                          |; print next nybble
    ror.w   #8,%d1                          |; unswap original word
    move.b  %d1,%d0                         |; get low byte
    ror.w   #4,%d0                          |; get high nyb of low byte
    ldrPrintHexNyb                          |; print it
    move.b  %d1,%d0                         |; restore low byte
    ldrPrintHexNyb                          |; print last nybble
    move.w  %d1,%d0                         |; restore original word
    jmp     %a6@                            |; return

|; function to print a hex longword in D0
|; clobbers D1.l, A0,l
ldrPrintHexLongF:
    move.l  %d0,%d1                         |; save original longword
    swap    %d0                             |; word swap D0
    move.l  %a6,%a0                         |; save return address
    lea     %pc@(1f),%a6                    |; get return address
    bra     ldrPrintHexWordF                |; print high word
1:  swap    %d0                             |; get low word
    lea     %pc@(2f),%a6                    |; get return address
    bra     ldrPrintHexWordF                |; print low word
2:  move.w  %d0,%d1                         |; restore low word
    move.l  %d1,%d0                         |; get original word
    move.l  %a0,%a6                         |; restore return address
    jmp     %a6@                            |; return



|; macro wrappers
    .macro  ldrPrintHexWord
    lea     %pc@(L\@mexit),%a6              |; get return address
    bra     ldrPrintHexWordF                |; go to subroutine
L\@mexit:
    nop
    .endm

    .macro  ldrPrintHexLong
    lea     %pc@(L\@mexit),%a6              |; get return address
    bra     ldrPrintHexLongF                |; go to subroutine
L\@mexit:
    nop
    .endm


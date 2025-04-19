|;*****************************************************************************
|; PRE-RAM UTILITY FUNCTIONS
|;*****************************************************************************


|; these functions are designed to operate without relying on RAM
|; calling convention:
|;      calling function pushes return address to A6
|;      parameters passed & returned in D0

|; print a null-terminated string pointed to by A0
ldrPrintStrF:
    move.b  %a0@,%d0                        |; get byte from string
    beq.s   2f                              |; branch if null
1:  btst    #1,acia1Com                     |; check ACIA TxRdy bit
    beq.s   1b                              |; branch until ready
    move.b  %d0,acia1Dat                    |; print byte
    bra     ldrPrintStrF                    |; continue print loop until null
2:  jmp     %a6@                            |; return

|; macro wrapper for print string in A0
    .macro  ldrPrintStr
    lea     %pc@(L\@mexit),%a6              |; grab return address
    bra     ldrPrintStrF                    |; run print string routine
L\@mexit:
    nop
    .endm

|; macro wrapper for print immediate string
    .macro  ldrPrintStrI str
    lea     %pc@(L\@mexit),%a6              |; grab return address
    lea     %pc@(L\@mstr),%a0               |; grab string pointer
    bra     ldrPrintStrF                    |; print string
L\@mstr:    .ascii "\str\0"                 |; immediate string
    .even
L\@mexit:
    nop
    .endm


|;*****************************************************************************
|; POST-RAM UTILITY FUNCTIONS
|;*****************************************************************************

|; Put Char to Console (blocking)
|; void putc(char)
|;  PARAMETERS:
|;      char        c       - character to put to console
putc:
1:  btst    #1,acia1Com                     |; check ACIA TxRdy bit
    beq.s   1b                              |; wait until ready
    move.b  %sp@(4),acia1Dat                |; put char to ACIA
    rts

|; Put Null-Terminated String to Console (blocking)
|; void puts(char*)
|;  PARAMETERS:
|;      char*       str     - pointer to string to put to console
puts:
    move.l  %sp@(4),%a0                     |; get string pointer
1:  move.b  %a0@+,%d0                       |; get byte from string
    beq.s   3f                              |; done if null
2:  btst    #1,acia1Com                     |; check ACIA TxRdy bit
    beq.s   2b                              |; wait until ready
    move.b  %d0,acia1Dat                    |; put char to ACIA
    bra.s   1b                              |; loop until null
3:  rts

|; Memory Compare
|; bool memCmp(void*, void*, uint16_t)
|;  PARAMETERS:
|;      void*       ptr1    - pointer to region 1
|;      void*       ptr2    - pointer to region 2
|;      uint16_t    count   - number of bytes to compare
|;  RETURNS:
|;      %d0.l       [0: match | else: no match]
memCmp:
    move.l  %sp@(12),%d0                    |; get byte count
    tst.l   %d0                             |; check if null
    beq.s   2f                              |; return if count null
    move.l  %sp@(4),%a0                     |; get pointer 1
    move.l  %sp@(8),%a1                     |; get pointer 2
    subq.l  #1,%d0                          |; pre-decrement count
1:  |; memCmpLp
    move.b  %a0@+,%d1                       |; get ptr1 byte
    cmp.b   %a1@+,%d1                       |; compare with ptr2 byte
    bne.s   2f                              |; end if no match
    subq.l  #1,%d0                          |; decrement counter
    bne.s   1b                              |; loop until done
2:  |; memCmpDone
    rts
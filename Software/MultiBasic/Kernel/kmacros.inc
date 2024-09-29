

|;    .equ    SIMULATE,1

|; macro for printing an immediate character to the kernel console
    .macro  debugPrintCharI char
L\@lp:
    btst    #1,acia1Com                     |; check ACIA txrdy bit
    beq.s   L\@lp                           |; loop until ready
    move.b  #\char,acia1Dat                 |; send byte
    .endm

|; macro for printing an immediate string to the kernel console

.ifdef  SIMULATE
    .macro  debugPrintStrI  str
    movem.l %a1/%d0,%sp@-                   |; save working registers
    move.w  #14,%d0                         |; simulator trap 14 (printstring)
    lea     %pc@(L\@Str),%a1                |; get pointer to string
    trap    #15                             |; simulator system call
    bra     L\@mexit                        |; skip to end of macro
L\@Str:
    .ascii  "\str\0"                        |; immediate string to print
    .even                                   |; word-align
L\@mexit:
    movem.l %sp@+,%a1/%d0                   |; restore working registers
    .endm
.else
    .macro  debugPrintStrI  str
    movem.l %a0/%d0,%sp@-                   |; save working registers
    lea     %pc@(L\@Str),%a0                |; get pointer to string
L\@nxtChr:
    move.b  %a0@+,%d0                       |; get next byte in string
    beq     L\@mexit                        |; if byte is 0, then end print
L\@lp:
    btst    #1,acia1Com                     |; check ACIA txrdy bit
    beq.s   L\@lp                           |; loop until ready 
    move.b  %d0,acia1Dat                    |; send byte
    bra     L\@nxtChr                       |; loop until null
L\@Str:
    .ascii  "\str\0"
    .even 
L\@mexit:
    movem.l %sp@+,%a0/%d0                    |; restore working registers
    .endm
.endif

|; macro for pointing a string in A0 to the kernel console
    .macro  debugPrintStr
    move.l  %d0,%sp@-                       |; save working register
L\@nxtChr:
    move.b  %a0@+,%d0                       |; get next byte in string
    beq     L\@mexit                        |; if byte is 0 then end print
L\@lp:
    btst    #1,acia1Com                     |; check ACIA txrdy bit
    beq.s   L\@lp                           |; loop until ready
    move.b  %d0,acia1Dat                    |; send byte
    bra     L\@nxtChr                       |; loop until null
L\@mexit:
    move.l  %sp@+,%d0                       |; restore working register
    .endm

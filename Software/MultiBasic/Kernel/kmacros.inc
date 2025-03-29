

|;    .equ    SIMULATE,1

|; macro for printing a character from register to kernel console
    .macro debugPrintChar regIn
L\@lp:
    btst    #1,acia1Com                     |; check ACIA txrdy bit
    beq.s   L\@lp                           |; loop until ready
    move.b  \regIn,acia1Dat                 |; send char
    .endm

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
    .macro debugPrintStr
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

|; macro to print a single nybble. clobbers register
    .macro debugPrintHexNyb regIn=%d0
    and.b   #0x0f,\regIn                    |; mask out low nybble
    cmpi.b  #0x0a,\regIn                    |; check if [0-9] or [a-f]
    blt.s   L\@num                          |; jump ahead if [0-9]
    add.b   #0x37,\regIn                    |; make ascii letter
    bra.s   L\@prt                          |; jump ahead to print is
L\@num:
    add.b   #0x30,\regIn                    |; make ascii number
L\@prt:
    debugPrintChar \regIn                   |; print it
    .endm

|; macro to print a single byte
    .macro debugPrintHexByte regInB=%d0
    move.w  \regInB,%sp@-                   |; save register
    ror.b   #4,\regInB                      |; move high nybble into position
    debugPrintHexNyb \regInB                |; print high nybble
    move.w  %sp@,\regInB                    |; restore register
    debugPrintHexNyb \regInB                |; print low nybble
    move.w  %sp@+,\regInB                   |; restore register
    .endm

|; macro to print a word
    .macro debugPrintHexWord regInW=%d0
    ror.w   #8,\regInW                      |; rotate high byte into position
    debugPrintHexByte \regInW               |; print it
    ror.w   #8,\regInW                      |; rotate low byte back into position
    debugPrintHexByte                       |; print it
    .endm

|; macro to print a longword
    .macro debugPrintHexLong regInL=%d0
    swap    \regInL                        |; rotate high word into position
    debugPrintHexWord \regInL              |; print it
    swap    \regInL                        |; rotate low word back into position
    debugPrintHexWord \regInL              |; print it
    .endm


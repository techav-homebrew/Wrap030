

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
|; that doesn't bother with saving working registers
    .macro  debugPrintStrInoram str
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
    nop
    .endm

|; macro for printing an immediate string to the kernel console

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





|; print a single byte in D0 without touching RAM. Clobbers D1
    .macro debugPrintHexByteNoRam
    move.w  %d0,%d1                         |; save register
    ror.b   #4,%d0                          |; move high nybble into position
    debugPrintHexNyb %d0                    |; print high nybble
    move.w  %d1,%d0                         |; restore register
    debugPrintHexNyb %d0                    |; print low nybble
    move.w  %d1,%d0                         |; restore register
    .endm

|; print a single word in D0 without touching RAM. Clobbers D1
    .macro  debugPrintHexWordNoRam
    ror.w   #8,%d0                          |; rotate high byte into position
    debugPrintHexByteNoRam                  |; print it
    ror.w   #8,%d0                          |; rotate low byte back into position
    debugPrintHexByteNoRam                  |; print it
    .endm

|; print a longword in D0 without touching RAM. Clobbers D1
    .macro  debugPrintHexLongNoRam
    swap    %d0                             |; rotate high word into position
    debugPrintHexWordNoRam                  |; print it
    swap    %d0                             |; rotate low word back into position
    debugPrintHexWordNoRam                  |; print it
    .endm

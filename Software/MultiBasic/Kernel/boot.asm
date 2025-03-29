
    .section text,"ax"

    .include "kmacros.inc"

    .global COLDBOOT
    .global _initKernelConsole
    .extern WARMBOOT
    .extern romBot
    .extern ramBot
    .extern overlayPort
    .extern ramTop
    .extern romOffset

    .equ        aciaSet, 0x15               |; 8N1,÷16 (38400),no interrupts

|; cold boot entry
COLDBOOT:
    lea         ramBot,%a0                  |; get pointer to address 0
    move.l      #0x55aa55aa,%d0             |; get a test pattern
    move.l      %d0,%a0@                    |; try to write the test pattern
    cmp.l       %a0@,%d0                    |; read back and check for pattern match
    beq         _doWarm                     |; if pattern matches then skip to warm boot

|; initialize the kernal console acia
_initKernelConsole:
    move.b      #3,acia1Com                 |; reset ACIA 1
    move.b      #aciaSet,acia1Com           |; configure ACIA 1
    debugPrintStrI  "\r\n\r\nWrap030 Cold Boot ...\r\n"

_clearMainMem:
    debugPrintStrI  "Initializing Main Memory ... "
    lea         ramTop+1,%a0                |; get pointer to top of memory space
    lea         ramBot,%a1                  |; get pointer to bottom of memory space
    eor.l       %d0,%d0                     |; get 0 in a data register
1:
    move.l      %d0,%a0@-                   |; clear next longword of memory
    cmpa.l      %a0,%a1                     |; check if we're at the bottom of memory
    bne         1b                          |; loop until we are
    debugPrintStrI  "OK\r\n"

|; copy contents of ROM into RAM above highest ROM address
_shadowROMp1:
    debugPrintStrI "Loading ... "
    move.l      #romTop,%d0                 |; get highest valid ROM address
    addq.l      #1,%d0                      |; get total size of ROM in bytes
    move.l      %d0,%d1                     |; save a copy for later
    lsr.l       #2,%d0                      |; get size of ROM in longwords (131,072)
    lea         romBot,%a0                  |; get pointer to bottom of ROM
    move.l      %a0,%a1                     |; copy pointer
    add.l       %d1,%a1                     |; A1 is destination pointer above ROM
    move.l      %a0,%a5                     |; save source pointer for later
    move.l      %a1,%a6                     |; save destination pointer for later
1:
    move.l      %a0@+,%a1@+                 |; copy next longword
    cmp.l       %d0,%a0                     |; check if top of ROM
    blt.s       1b                          |; loop until all of ROM copied to RAM
    debugPrintStrI "OK\r\n"

|; verify copy was successful
_shadowROMp2:
    debugPrintStrI "Verifying ... "
    move.l      %a5,%a0                     |; get source pointer
    move.l      %a6,%a1                     |; get destination pointer
1:
    move.l      %a0@+,%d2                   |; read ROM byte
    move.l      %a1@+,%d3                   |; read RAM byte
    cmp.l       %d2,%d3                     |; check if they match
    bne         2f                          |; branch on error
    cmp.l       %d0,%a0                     |; loop until all of shadow verified
    blt.s       1b
    debugPrintStrI "OK\r\n"

    debugPrintStrI "Jumping to RAM ... "
    lea         %pc@(_shadowROMp3),%a3      |; get address for next function
    add.l       %d1,%a3                     |; add the offset to it
    move.l      %a3,%d0
    debugPrintHexLong %d0
    jmp         %a3@                        |; jump to the offset address

2:  |; verify error
    debugPrintStrI "ERROR: "
    move.l      %a0,%d0                     |; print source address
    debugPrintHexLong %d0
    debugPrintStrI ":"
    move.l      %d2,%d0                     |; print source longword
    debugPrintHexLong %d0
    debugPrintStrI " => "
    move.l      %a1,%d0                     |; print destination address
    debugPrintHexLong %d0
    debugPrintStrI ":"
    move.l      %d3,%d0                     |; print destination longword
    debugPrintHexLong %d0
    debugPrintStrI "\r\n\r\n"
    jmp COLDBOOT

_shadowROMp3:
    debugPrintStrI "OK\r\n"

|; disable the startup overlay. Since we just copied ROM to the same addresses in RAM
|; this should not disrupt execution.
_clearOverlay:
    debugPrintStrI "Disabling overlay ... "
    move.b      #0,overlayPort              |; disable startup overlay
    debugPrintStrI "OK\r\n"

|; copy contents of ROM to base of RAM
_shadowROMp4:
    debugPrintStrI "Shadowing ROM ... "
    lea         romOffset,%a0               |; get source pointer
    lea         ramBot,%a1                  |; get destination pointer
    move.l      #romTop,%d0                 |; get size of ROM less 1
    addq.l      #1,%d0                      |; get size of ROM in bytes
    lsr.l       #2,%d0                      |; get size of ROM in longwords
    move.l      %a0,%a5                     |; save source pointer
    move.l      %a1,%a6                     |; save destination pointer
    move.l      %d0,%d1                     |; save ROM size
    subq.l      #1,%d0
1:
    move.l      %a0@+,%a1@+                 |; copy ROM to RAM
    subq.l      #1,%d0                      |; decrement count
    bne.s       1b                          |; branch until count 0
    debugPrintStrI "OK\r\n"

|; verify shadow
_shadowROMp5:
    debugPrintStrI "Verifying ROM shadow ... "
    subq.l      #1,%d1
1:
    move.l      %a5@+,%d2                   |; get source byte
    move.l      %a6@+,%d3                   |; get destination byte
    cmp.l       %d2,%d3                     |; check if matching
    bne.s       2f                          |; branch on error
    subq.l      #1,%d1                      |; decrement counter
    bne.s       1b                          |; loop until all verified
    debugPrintStrI "OK\r\n"

    debugPrintStrI "Starting Kernel ... \r\n"
    jmp         WARMBOOT

2:  |; verify error
    debugPrintStrI "ERROR: "
    move.l      %a5,%d0                     |; print source address
    debugPrintHexLong %d0
    debugPrintStrI ":"
    move.l      %d2,%d0                     |; print source longword
    debugPrintHexLong %d0
    debugPrintStrI " => "
    move.l      %a6,%d0                     |; print destination address
    debugPrintHexLong %d0
    debugPrintStrI ":"
    move.l      %d3,%d0                     |; print destination longword
    debugPrintHexLong %d0
    debugPrintStrI "\r\n\r\n"
    jmp COLDBOOT




/*
_copyVectors:
    debugPrintStrI  "Initializing Vectors ... "
    lea         romBot,%a1                  |; get pointer to bottom of ROM
    lea         ramBot,%a0                  |; get pointer to bottom of RAM
    move.l      #256,%d0                    |; prepare to copy 256 vectors
1:
    move.l      %a1@+,%a0@+                 |; copy vector
    dbra        %d0,1b                      |; copy all vectors
    debugPrintStrI  "OK\r\n"
    jmp         WARMBOOT
*/

    jmp         WARMBOOT                    |; go start the kernel

|; our cold/warm boot test clobbered the iniital stack pointer
|; restore it to avoid any potential problems in case of an unexpected reset
|; on cold boot this is redundant, but won't hurt anything
_doWarm:
    move.l      romBot,ramBot               |; copy vector 0
    debugPrintStrI  "\r\nWrap030 Warm Boot ... \r\n"
    jmp         WARMBOOT



    .section text,"ax"

    .include "kmacros.inc"

    .global COLDBOOT
    .extern WARMBOOT
    .extern romBot
    .extern ramBot
    .extern overlayPort
    .extern ramTop

    .equ        aciaSet, 0x15               |; 8N1,÷16 (38400),no interrupts

|; cold boot entry
COLDBOOT:
    lea         ramBot,%a0                  |; get pointer to address 0
    move.l      #0x55aa55aa,%d0             |; get a test pattern
    move.l      %d0,%a0@                    |; try to write the test pattern
    cmp.l       %a0@,%d0                    |; read back and check for pattern match
    beq         _doWarm                     |; if pattern matches then skip to warm boot

_clearOverlay:
    move.b      #0,overlayPort              |; disable startup overlay

|; initialize the kernal console acia
_initKernelConsole:
    move.b      #3,acia1Com                 |; reset ACIA 1
    move.b      #aciaSet,acia1Com           |; configure ACIA 1
    debugPrintStrI  "\r\nWrap030 Cold Boot ...\r\n"

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

|; our cold/warm boot test clobbered the iniital stack pointer
|; restore it to avoid any potential problems in case of an unexpected reset
|; on cold boot this is redundant, but won't hurt anything
_doWarm:
    move.l      romBot,ramBot               |; copy vector 0
    debugPrintStrI  "\r\nWrap030 Warm Boot ... \r\n"
    jmp         WARMBOOT


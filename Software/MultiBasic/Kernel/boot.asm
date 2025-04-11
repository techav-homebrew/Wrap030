
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
    lea         SUPVSTACKINIT,%sp           |; set initial supervisor stack pointer

|; initialize the kernal console acia
_initKernelConsole:
    move.b      #3,acia1Com                 |; reset ACIA 1
    move.b      #aciaSet,acia1Com           |; configure ACIA 1
    debugPrintStrInoram  "\r\n\r\n                                ____  _____  ____ "
    debugPrintStrInoram  "\r\n _      __ _____ ____ _ ____   / __ \\|__  / / __ \\"
    debugPrintStrInoram  "\r\n| | /| / // ___// __ `// __ \\ / / / / /_ < / / / /"
    debugPrintStrInoram  "\r\n| |/ |/ // /   / /_/ // /_/ // /_/ /___/ // /_/ / "
    debugPrintStrInoram  "\r\n|__/|__//_/    \\__,_// .___/ \\____//____/ \\____/  "
    debugPrintStrInoram  "\r\n------------------- /_/ --------------------------\r\n\r\n"

    .even

    lea         %pc@(COLDBOOT),%a3
    debugPrintStrInoram  "Starting vector 0x"
    move.l      %a3,%d0
    debugPrintHexLongNoRam


_clearOverlay:
    debugPrintStrInoram "\r\nDisabling overlay ... "
    move.b      #0,overlayPort              |; disable startup overlay
    debugPrintStrInoram "OK\r\n"

_memTest1:
    debugPrintStrInoram "Writing pattern 0x55aa55aa to start of RAM"
    move.l      #0x55aa55aa,%d3             |; get pattern
    move.l      %d3,ramBot                  |; write to bottom of RAM
    debugPrintStrInoram " ... "
    move.l      ramBot,%d4                  |; read pattern
    debugPrintStrInoram "Read: 0x"
    move.l      %d4,%d0
    debugPrintHexLongNoRam
    cmp.l       %d4,%d3
    beq         1f
    debugPrintStrInoram ". FAIL\r\n"
    bra         _memTest2
1:
    debugPrintStrInoram ". PASS\r\n"

_memTest2:
    debugPrintStrInoram "Writing sequential bytes 0x55aa1188"
    lea         ramBot,%a0                  |; get memory pointer
    move.l      %a0,%a1
    move.l      #0x55aa1188,%d7             |; get test pattern
    
    rol.l       #8,%d7                      |; rotate first byte into position
    move.b      %d7,%a0@+                   |; write first pattern byte
    rol.l       #8,%d7                      |;
    move.b      %d7,%a0@+                   |;
    rol.l       #8,%d7                      |;
    move.b      %d7,%a0@+                   |;
    rol.l       #8,%d7                      |;
    move.b      %d7,%a0@+                   |;

    debugPrintStrInoram " ... "
    move.l      %a1@,%d6                    |; read back pattern
    debugPrintStrInoram "Read: 0x"
    move.l      %d6,%d0                     |; copy
    debugPrintHexLongNoRam
    cmp.l       %d7,%d6                     |; check if patterns match
    beq         1f
    debugPrintStrInoram ". FAIL\r\n"
    bra         _memTest3
1:
    debugPrintStrInoram ". PASS\r\n"

_memTest3:
    
|;    debugPrintHexLong %d0


|;    lea         ramBot,%a0                  |; get pointer to address 0
|;    move.l      #0x55aa55aa,%d0             |; get a test pattern
|;    move.l      %d0,%a0@                    |; try to write the test pattern
|;    cmp.l       %a0@,%d0                    |; read back and check for pattern match
|;    beq         _doWarm                     |; if pattern matches then skip to warm boot

_clearMainMem:
    debugPrintStrInoram  "Initializing Main Memory ... "
    lea         ramTop+1,%a0                |; get pointer to top of memory space
    lea         ramBot,%a1                  |; get pointer to bottom of memory space
    eor.l       %d0,%d0                     |; get 0 in a data register
1:
    move.l      %d0,%a0@-                   |; clear next longword of memory
    cmpa.l      %a0,%a1                     |; check if we're at the bottom of memory
    bne         1b                          |; loop until we are
    debugPrintStrInoram  "OK\r\n"

|; copy contents of ROM into RAM above highest ROM address
_shadowROMp1:
    debugPrintStrInoram "Loading ... "
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
    debugPrintStrInoram "OK\r\n"

|; verify copy was successful
_shadowROMp2:
    debugPrintStrInoram "Verifying ... "
    move.l      %a5,%a0                     |; get source pointer
    move.l      %a6,%a1                     |; get destination pointer
1:
    move.l      %a0@+,%d2                   |; read ROM byte
    move.l      %a1@+,%d3                   |; read RAM byte
    cmp.l       %d2,%d3                     |; check if they match
    bne         2f                          |; branch on error
    cmp.l       %d0,%a0                     |; loop until all of shadow verified
    blt.s       1b
    debugPrintStrInoram "OK\r\n"

    debugPrintStrInoram "Jumping to RAM ... "
    lea         %pc@(_shadowROMp3),%a3      |; get address for next function
    add.l       %d1,%a3                     |; add the offset to it
    move.l      %a3,%d0
    debugPrintHexLong %d0
    jmp         %a3@                        |; jump to the offset address

2:  |; verify error
    debugPrintStrInoram "ERROR: "
    move.l      %a0,%d0                     |; print source address
    debugPrintHexLong %d0
    debugPrintStrInoram ":"
    move.l      %d2,%d0                     |; print source longword
    debugPrintHexLong %d0
    debugPrintStrInoram " => "
    move.l      %a1,%d0                     |; print destination address
    debugPrintHexLong %d0
    debugPrintStrInoram ":"
    move.l      %d3,%d0                     |; print destination longword
    debugPrintHexLong %d0
    debugPrintStrInoram "\r\n\r\n"
    jmp COLDBOOT

_shadowROMp3:
    debugPrintStrInoram "OK\r\n"

|; disable the startup overlay. Since we just copied ROM to the same addresses in RAM
|; this should not disrupt execution.
|;_clearOverlay:
|;    debugPrintStrInoram "Disabling overlay ... "
|;    move.b      #0,overlayPort              |; disable startup overlay
|;    debugPrintStrInoram "OK\r\n"

|; copy contents of ROM to base of RAM
_shadowROMp4:
    debugPrintStrInoram "Shadowing ROM ... "
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
    debugPrintStrInoram "OK\r\n"

|; verify shadow
_shadowROMp5:
    debugPrintStrInoram "Verifying ROM shadow ... "
    subq.l      #1,%d1
1:
    move.l      %a5@+,%d2                   |; get source byte
    move.l      %a6@+,%d3                   |; get destination byte
    cmp.l       %d2,%d3                     |; check if matching
    bne.s       2f                          |; branch on error
    subq.l      #1,%d1                      |; decrement counter
    bne.s       1b                          |; loop until all verified
    debugPrintStrInoram "OK\r\n"

    debugPrintStrInoram "Starting Kernel ... \r\n"
    jmp         WARMBOOT

2:  |; verify error
    debugPrintStrInoram "ERROR: "
    move.l      %a5,%d0                     |; print source address
    debugPrintHexLong %d0
    debugPrintStrInoram ":"
    move.l      %d2,%d0                     |; print source longword
    debugPrintHexLong %d0
    debugPrintStrInoram " => "
    move.l      %a6,%d0                     |; print destination address
    debugPrintHexLong %d0
    debugPrintStrInoram ":"
    move.l      %d3,%d0                     |; print destination longword
    debugPrintHexLong %d0
    debugPrintStrInoram "\r\n\r\n"
    jmp COLDBOOT




/*
_copyVectors:
    debugPrintStrInoram  "Initializing Vectors ... "
    lea         romBot,%a1                  |; get pointer to bottom of ROM
    lea         ramBot,%a0                  |; get pointer to bottom of RAM
    move.l      #256,%d0                    |; prepare to copy 256 vectors
1:
    move.l      %a1@+,%a0@+                 |; copy vector
    dbra        %d0,1b                      |; copy all vectors
    debugPrintStrInoram  "OK\r\n"
    jmp         WARMBOOT
*/

    jmp         WARMBOOT                    |; go start the kernel

|; our cold/warm boot test clobbered the iniital stack pointer
|; restore it to avoid any potential problems in case of an unexpected reset
|; on cold boot this is redundant, but won't hurt anything
_doWarm:
    move.l      romBot,ramBot               |; copy vector 0
    debugPrintStrInoram  "\r\nWrap030 Warm Boot ... \r\n"
    jmp         WARMBOOT



    .section text,"ax"

    .global COLDBOOT
    .extern LoadBootBin
    .extern VECTORTABLE
    .extern printStr

    .equ        aciaSet, 0x15               |; 8N1,÷16 (38400),no interrupts


    bra     COLDBOOT

    .include "ldr_utility.inc"    

COLDBOOT:
    lea     SUPVSTACKINIT,%sp               |; set initial supervisor stack pointer

.initConsole:
    move.b  #3,acia1Com                     |; reset ACIA 1
    move.b  #aciaSet,acia1Com               |; configure ACIA 1
    lea     %pc@(strHeader),%a0             |; get pointer to header string
    ldrPrintStr                             |; print header string

.initVbr:
    lea     %pc@(strSetVbr),%a0             |; 
    ldrPrintStr                             |; 
    lea     VECTORTABLE,%a0                 |; get pointer to vector table
    movec   %a0,%vbr                        |; set VBR
    lea     %pc@(strOk),%a0                 |;
    ldrPrintStr                             |; 

.initOverlay:
    lea     %pc@(strClearOverlay),%a0       |;
    ldrPrintStr                             |; 
    move.b  #0,overlayPort                  |; disable startup overlay
    lea     %pc@(strOk),%a0                 |;
    ldrPrintStr                             |;


.testRamData:
    lea     %pc@(strTestRamData),%a0        |;
    ldrPrintStr                             |;
    lea     ramBot,%a0                      |; get pointer to RAM
    moveq   #1,%d0                          |; initialize pattern
1:  move.l  %d0,%a0@                        |; write pattern
    move.l  %a0@,%d1                        |; read back pattern
    cmp.l   %d0,%d1                         |; check pattern
    bne.s   2f                              |; memory error
    lsl.l   #1,%d0                          |; shift pattern
    bne.s   1b                              |;      until pattern is 0
    |; test complete passed
    lea     %pc@(strOk),%a0                 |;
    ldrPrintStr                             |;
    bra     .testRamAddr                    |; go to next test
2:  |; error
    move.l  %d0,%d6                         |; save test registers
    move.l  %d1,%d7                         |;
    lea     %pc@(strError),%a0              |; print error
    ldrPrintStr                             |;
    lea     %pc@(strExpected),%a0           |; print expected
    ldrPrintStr                             |;
    move.l  %d6,%d0                         |; get pattern
    ldrPrintHexLong                         |; print pattern
    lea     %pc@(strRead),%a0               |; print read
    move.l  %d7,%d0                         |; get read value
    ldrPrintHexLong                         |; print read value
    lea     %pc@(strCRLF),%a0               |; print CRLF
    ldrPrintStr                             |;
    bra     rebootWait                      |; go reboot




.testRamAddr:
/*    lea     %pc@(strTestRamAddr),%a0        |;
    ldrPrintStr                             |;
   */ 




.initStack:
    lea     %pc@(strSetStack),%a0           |;
    ldrPrintStr                             |;
    lea     IRQSTACKINIT,%a0                |; get interrupt stack pointer
    movec.l %a0,%isp                        |;
    lea     SUPVSTACKINIT,%a0               |; get supervisor stack pointer
    movec.l %a0,%msp                        |; 
    lea     %pc@(strOk),%a0                 |;
    ldrPrintStr


.testStack:
    lea     %pc@(strTestSub),%a0            |; 
    ldrPrintStr                             |; 
    bsr     testSubroutine                  |; test subroutine branch
    lea     %pc@(strOk),%a0                 |;
    ldrPrintStr                             |;

.initRuntimeVbr:
    lea     %pc@(strSetVbrRuntime),%a0      |;
    ldrPrintStr                             |;
    lea     VECTORSRUNTIME,%a0              |;
    movec   %a0,%vbr                        |;
    lea     %pc@(strOk),%a0                 |;
    ldrPrintStr


.testC:
    lea     %pc@(strTestC),%a0              |;
    ldrPrintStr
    pea     %pc@(strOk)                     |; push OK string to stack
    bsr     printStr                        |; call C print function
    add.l   #4,%sp                          |; pop parameter off stack



.loadBoot:
    lea     %pc@(strLoading),%a0            |;
    ldrPrintStr                             |;
    bsr     LoadBootBin                     |; load BOOT.BIN into RAM at 0
    tst.b   %d0                             |; check return value
    bne     loadErr                         |; err if return not 0
    lea     %pc@(strOk),%a0                 |;
    ldrPrintStr                             |;
    jmp     0                               |; jump into boot at 0
    bra     .loadBoot                       |; reload if program returns

loadErr:
    lea     %pc@(strError),%a0              |; 
    ldrPrintStr                             |; 
    bra     rebootWait                      |; 


rebootWait:
    move.l  #0x00010000,%d0                 |; initialize counter
1:  subq.l  #1,%d0                          |; decrement counter
    bne.s   1b                              |; loop until count expired
    bra     COLDBOOT                        |; reboot.


testSubroutine:
    lea     %pc@(strTestDots),%a0           |;
    ldrPrintStr
    rts



strHeader:
    .ascii  "\r\n"
    .ascii  "\r\n                                ______ _____ ______"
    .ascii  "\r\n _      __ _____ ____ _ ______ / __  //_   // __  /"
    .ascii  "\r\n| | /| / // ___// __ `// __  // / / / /_ < / / / / "
    .ascii  "\r\n| |/ |/ // /   / /_/ // /_/ // /_/ /___/ // /_/ /  "
    .ascii  "\r\n|__/|__//_/   /___,_// .___//_____//____//_____/   "
    .ascii  "\r\n------------------- /_/ -----------------------    "
    .ascii  "\r\n\r\n\0"

strOk:
    .ascii  "OK\r\n\0"

strError:
    .ascii  "Error.\r\n\0"

strSetVbr:
    .ascii  "Setting initial vector base register ... \0"

strSetVbrRuntime:
    .ascii  "Setting runtime VBR ... \0"

strClearOverlay:
    .ascii  "Disabling overlay ... \0"

strLoading:
    .ascii  "Loading ... \0"

strTestRamData:
    .ascii  "Testing RAM data bus ... \0"

strTestRamAddr:
    .ascii  "Testing RAM address bus ... \0"

strSetStack:
    .ascii  "Configuring stack ... \0"

strTestC:
    .ascii  "Testing C interface ... \0"

strTestSub:
    .ascii  "Testing stack return ... \0"

strTestDots:
    .ascii  " ... \0"

strExpected:
    .ascii  "Expected: 0x\0"

strRead:
    .ascii  " Read: 0x\0"

strCRLF:
    .ascii  "\r\n\0"

    .even

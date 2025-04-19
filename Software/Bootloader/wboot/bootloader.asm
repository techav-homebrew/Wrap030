
    .section text,"ax"

    .global COLDBOOT
    .extern LoadBootBin
    .extern VECTORTABLE

    .include "ldr_utility.inc"

    .equ        aciaSet, 0x15               |; 8N1,÷16 (38400),no interrupts

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

.loadBoot:
    lea     %pc@(strLoading),%a0            |;
    ldrPrintStr                             |;
    bsr     LoadBootBin                     |; load BOOT.BIN into RAM at 0
    tst.b   %d0                             |; check return value
    bne     .loadErr                        |; err if return not 0
    lea     %pc@(strOk),%a0                 |;
    ldrPrintStr                             |;
    jmp     0                               |; jump into boot at 0
    bra     .loadBoot                       |; reload if program returns

.loadErr:
    lea     %pc@(strError),%a0              |; 
    ldrPrintStr                             |; 
    bra     COLDBOOT                        |; 




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
    .ascii  "Setting vector base register ... \0"

strClearOverlay:
    .ascii  "Disabling overlay ... \0"

strLoading:
    .ascii  "Loading ... \0"


    .even

|; initial boot vectors

    .section    text,"ax"
    |;.include    "kmacros.inc"
    .extern STACKINIT
    .extern RESETVECTOR
    .extern WARMBOOT
    .extern timerFlag

vector:
    bra.w   WARMBOOT
    dc.l    WARMBOOT
    .dcb.l  254,printException

    .include    "kmacros.inc"

    .macro  exceptPrintStrS strRef
    lea     %pc@(\strRef),%a0               |; get string pointer
    bsr     exceptPrintStr                  |; and print it
    .endm

exceptPrintStr:
    move.b  %a0@+,%d0                       |; get next string byte
    beq.s   2f                              |; end print if null
1:  btst    #1,acia1Com                     |; check tx ready bit
    beq.s   1b                              |; wait until ready
    move.b  %d0,acia1Dat                    |; print byte
    bra     exceptPrintStr                  |; loop until done
2:  rts

    .macro  exceptPrintNyb
    andi.b  #0x0f,%d0                       |; mask off nybble
    cmpi.b  #0x0a,%d0                       |; check if number or letter
    blt.s   L\@num                          |; branch if number
    addi.b  #0x37,%d0                       |; make ascii letter
    bra.s   L\@prt                          |; jump to print
L\@num:
    addi.b  #0x30,%d0                       |; make ascii number
L\@prt:
    btst    #1,acia1Com                     |; check if ready
    beq.s   L\@prt                          |; wait until ready
    move.b  %d0,acia1Dat                    |; print byte
    .endm

exceptPrintWord:
    debugPrintHexWord
    rts

exceptPrintLong:
    debugPrintHexLong
    rts
    


printException:
    move.w  #0x2700,%sr                     |; disable interrupts (not needed?)
    link    %a6,#-8                         |; space for local vars
    move.l  %d0,%a6@(-4)                    |; save working registers
    move.l  %a0,%a6@(-8)                    |;

    exceptPrintStrS strHead

    move.w  %a6@(10),%d0                    |; get vector offset
    andi.w  #0x0fff,%d0                     |; mask off format bits
    movea.l %pc@(vectorNameTable,%d0:w:1),%a0 |; get pointer to exception name
    bsr     exceptPrintStr                  |; print exception name

    exceptPrintStrS strRegPC                |; print PC
    move.l  %a6@(6),%d0                     |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegSR                |; print SR
    move.w  %a6@(4),%d0                     |;
    bsr     exceptPrintWord                 |;

    exceptPrintStrS strRegD0                |; print D0
    move.l  %a6@(-4),%d0                    |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegA0                |; print A0
    move.l  %a6@(-8),%d0                    |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegD1                |; print D1
    move.l  %d1,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegA1                |; print A1
    move.l  %a1,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegD2                |; print D2
    move.l  %d2,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegA2                |; print A2
    move.l  %a2,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegD3                |; print D3
    move.l  %d3,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegA3                |; print A3
    move.l  %a3,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegD4                |; print D4
    move.l  %d4,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegA4                |; print A4
    move.l  %a4,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegD5                |; print D5
    move.l  %d5,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegA5                |; print A5
    move.l  %a5,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegD6                |; print D6
    move.l  %d6,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegA6                |; print A6
    move.l  %a6,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegD7                |; print D7
    move.l  %d7,%d0                         |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strRegA1                |; print A7
    move.l  %a6,%d0                         |;
    addq.l  #4,%d0                          |;
    bsr     exceptPrintLong                 |;

    exceptPrintStrS strPCTrace              |; print last few instructions
    move.l  %a6@(6),%a0                     |; get current PC
    move.l  %a0@-,%sp@-
    move.l  %a0@-,%sp@-
    move.l  %a0@-,%sp@-
    move.l  %a0@-,%sp@-
    move.l  %a0@-,%sp@-
    move.l  %a0@-,%sp@-
    move.l  %a0@-,%sp@-
    move.l  %a0@-,%d0
    bsr     exceptPrintLong
    exceptPrintStrS strPCSpace
    move.l  %sp@+,%d0
    bsr     exceptPrintLong
    exceptPrintStrS strPCSpace
    move.l  %sp@+,%d0
    bsr     exceptPrintLong
    exceptPrintStrS strPCSpace
    move.l  %sp@+,%d0
    bsr     exceptPrintLong
    exceptPrintStrS strPCTrac1
    bsr     exceptPrintLong
    exceptPrintStrS strPCSpace
    move.l  %sp@+,%d0
    bsr     exceptPrintLong
    exceptPrintStrS strPCSpace
    move.l  %sp@+,%d0
    bsr     exceptPrintLong
    exceptPrintStrS strPCSpace
    move.l  %sp@+,%d0
    bsr     exceptPrintLong


    move.w  %a6@(10),%d0                    |; get frame format
    move.w  %d0,%d1                         |; duplicate
    andi.w  #0x0fff,%d1                     |; get vector number
    cmpi.w  #0x070,%d1                      |; is this IRQ 4?
    beq.s   exceptTimer                     |; make the timer shut up
    rol.w   #4,%d0                          |; move into position
    andi.w  #0x0f,%d0                       |; mask out vector offset
    cmpi.w  #0x0a,%d0                       |; check if fault frame 
    bge.s   exceptFault                     |;
    cmpi.w  #0x02,%d0                       |; check if trap frame
    bge.s   exceptTrap                      |;

exceptPrintEnd:
    exceptPrintStrS strFoot                 |; print footer
    move.l  %a6@(-8),%a0                    |; restore registers
    move.l  %a6@(-4),%d0                    |;
    unlk    %a6                             |; unlink stack frame
    move.w  #0x2000,%sr                     |; enable interrupts (not needed?)
    rte                                     |; return from exception

exceptTrap:
    exceptPrintStrS strInstr
    move.l  %a6@(12),%d0                    |; get instruction pointer
    bsr     exceptPrintLong                 |;
    bra     exceptPrintEnd                  |; done.

exceptFault:
    exceptPrintStrS strFault
    move.l  %a6@(14),%d0                    |; get data cycle fault address
    bsr     exceptPrintLong                 |;
    andi.w  #0xCEFF,%a6@(14)                |; clear retry bits

    bra     exceptPrintEnd                  |; done

exceptTimer:
    exceptPrintStrS strTimer                |;
    move.l  #-1,timerFlag                   |; set flag
    move.b  #0,timerBase                    |; disable timer
    bra     exceptPrintEnd                  |; done



|; table of pointers to friendly name strings for all vectors
vectorNameTable:
    dc.l    strUnused       |;  0   000
    dc.l    strUnused       |;  1   004
    dc.l    strBusErr       |;  2   008
    dc.l    strAddrErr      |;  3   00c
    dc.l    strIllIns       |;  4   010
    dc.l    strDivZero      |;  5   014
    dc.l    strChk          |;  6   018
    dc.l    strTrapV        |;  7   01c
    dc.l    strPrivViol     |;  8   020
    dc.l    strTrace        |;  9   024
    dc.l    strALine        |; 10   028
    dc.l    strFLine        |; 11   02c
    dc.l    strUnused       |; 12   030
    dc.l    strCoproViol    |; 13   034
    dc.l    strFormatErr    |; 14   038
    dc.l    strUninitIrq    |; 15   03c
    .dcb.l  8,strUnused     |; 16-23    040-05c
    dc.l    strSpurIrq      |; 24   060
    dc.l    strIrq1         |; 25   064
    dc.l    strIrq2         |; 26   068
    dc.l    strIrq3         |; 27   06c
    dc.l    strIrq4         |; 28   070
    dc.l    strIrq5         |; 29   074
    dc.l    strIrq6         |; 30   078
    dc.l    strIrq7         |; 31   07c
    dc.l    strTrap0        |; 32   080
    dc.l    strTrap1        |; 33   084
    dc.l    strTrap2        |; 34   088
    dc.l    strTrap3        |; 35   08c
    dc.l    strTrap4        |; 36   090
    dc.l    strTrap5        |; 37   094
    dc.l    strTrap6        |; 38   098
    dc.l    strTrap7        |; 39   09c
    dc.l    strTrap8        |; 40   0a0
    dc.l    strTrap9        |; 41   0a4
    dc.l    strTrapA        |; 42   0a8
    dc.l    strTrapB        |; 43   0ac
    dc.l    strTrapC        |; 44   0b0
    dc.l    strTrapD        |; 45   0b4
    dc.l    strTrapE        |; 46   0b8
    dc.l    strTrapF        |; 47   0bc
    dc.l    strFpuBSUC      |; 48   0c0
    dc.l    strFpuInexact   |; 49   0c4
    dc.l    strFpuDivZero   |; 50   0c8
    dc.l    strFpuUnderflow |; 51   0cc
    dc.l    strFpuOperand   |; 52   0d0
    dc.l    strFpuOverflow  |; 53   0d4
    dc.l    strFpuNaN       |; 54   0d8
    dc.l    strUnused       |; 55   0dc
    dc.l    strMmuConfigErr |; 56   0e0
    dc.l    strMmuUnused    |; 57   0e4
    dc.l    strMmuUnused    |; 58   0e8
    .dcb.l  5,strUnused     |; 59-63    0ec-0fc
    .dcb.l  64,strUnused    |; 64-127   100-1fc User-defined
    .dcb.l  128,strUnused   |; 128-255  200-3fc


strHead:    .ascii  "\r\n\r\n!!!!!!!!!! EXCEPTION: \0"
strUser:    .ascii  " !!!!!!!!!!\r\n  User: \0"
strRegPC:   .ascii  "\r\n  PC: 0x\0"
strRegD0:   .ascii  "\r\n  D0: 0x\0"
strRegD1:   .ascii  "\r\n  D1: 0x\0"
strRegD2:   .ascii  "\r\n  D2: 0x\0"
strRegD3:   .ascii  "\r\n  D3: 0x\0"
strRegD4:   .ascii  "\r\n  D4: 0x\0"
strRegD5:   .ascii  "\r\n  D5: 0x\0"
strRegD6:   .ascii  "\r\n  D6: 0x\0"
strRegD7:   .ascii  "\r\n  D7: 0x\0"
strRegSR:   .ascii  " SR: 0x\0"
strRegA0:   .ascii  " A0: 0x\0"
strRegA1:   .ascii  " A1: 0x\0"
strRegA2:   .ascii  " A2: 0x\0"
strRegA3:   .ascii  " A3: 0x\0"
strRegA4:   .ascii  " A4: 0x\0"
strRegA5:   .ascii  " A5: 0x\0"
strRegA6:   .ascii  " A6: 0x\0"
strRegA7:   .ascii  " A7: 0x\0"
strPCTrace: .ascii  "\r\n  Program:\r\n    0x\0"
strPCSpace: .ascii  " 0x\0"
strPCTrac1: .ascii  "\r\n    0x\0"
strFault:   .ascii  "\r\n  Fault Address: 0x\0"
strInstr:   .ascii  "\r\n  Instruction Pointer: 0x\0"
strFoot:    .ascii  "\r\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\r\n\r\n> \0"
strTimer:   .ascii  "\r\n  Disabling Timer\0"

|; table of friendly name strings for all vectors
vectorNames:
strBusErr:      .ascii  "Bus Error\0"
strAddrErr:     .ascii  "Address Error\0"
strIllIns:      .ascii  "Illegal Instruction\0"
strDivZero:     .ascii  "Div by Zero\0"
strChk:         .ascii  "CHK Trap\0"
strTrapV:       .ascii  "TRAPV\0"
strPrivViol:    .ascii  "Privilege Violation\0"
strTrace:       .ascii  "Trace IRQ\0"
strALine:       .ascii  "A-Trap\0"
strFLine:       .ascii  "F-Trap\0"
strUnused:      .ascii  "Unused Vector\0"
strCoproViol:   .ascii  "Coprocessor Err\0"
strFormatErr:   .ascii  "Format Err\0"
strUninitIrq:   .ascii  "Uninitialized IRQ\0"
strSpurIrq:     .ascii  "Spurious IRQ\0"
strIrq1:        .ascii  "IRQ 1\0"
strIrq2:        .ascii  "IRQ 2\0"
strIrq3:        .ascii  "IRQ 3\0"
strIrq4:        .ascii  "IRQ 4\0"
strIrq5:        .ascii  "IRQ 5\0"
strIrq6:        .ascii  "IRQ 6\0"
strIrq7:        .ascii  "IRQ 7\0"
strTrap0:       .ascii  "Trap #0\0"
strTrap1:       .ascii  "Trap #1\0"
strTrap2:       .ascii  "Trap #2\0"
strTrap3:       .ascii  "Trap #3\0"
strTrap4:       .ascii  "Trap #4\0"
strTrap5:       .ascii  "Trap #5\0"
strTrap6:       .ascii  "Trap #6\0"
strTrap7:       .ascii  "Trap #7\0"
strTrap8:       .ascii  "Trap #8\0"
strTrap9:       .ascii  "Trap #9\0"
strTrapA:       .ascii  "Trap #10\0"
strTrapB:       .ascii  "Trap #11\0"
strTrapC:       .ascii  "Trap #12\0"
strTrapD:       .ascii  "Trap #13\0"
strTrapE:       .ascii  "Trap #14\0"
strTrapF:       .ascii  "Trap #15\0"
strFpuBSUC:     .ascii  "FPU Error\0"
strFpuInexact:  .ascii  "FPU Inexact\0"
strFpuDivZero:  .ascii  "FPU Div by Zero\0"
strFpuUnderflow: .ascii "FPU Underflow\0"
strFpuOperand:  .ascii  "FPU Operand Err\0"
strFpuOverflow: .ascii  "FPU Overflow\0"
strFpuNaN:      .ascii  "FPU NaN Err\0"
strMmuConfigErr: .ascii "MMU Config Err\0"
strMmuUnused:   .ascii  "MMU Err\0"
    .even


|; initial boot vectors

    .section    text,"ax"
    .include    "kmacros.inc"
    .extern STACKINIT
    .extern COLDBOOT
    .extern SysTrap
    .extern USERTABLE
    .extern USERNUM
    .extern kUserTblInit
    .extern NextUser

vector:
    dc.l    STACKINIT           |;  0   000
    dc.l    COLDBOOT            |;  1   004
    dc.l    exceptionType2      |;  2   008 bus error
    dc.l    exceptionType2      |;  3   00c address error
    dc.l    exceptionType2      |;  4   010 illegal instruction
    dc.l    exceptionType2      |;  5   014 divide by zero
    dc.l    exceptionType1      |;  6   018 CHK/CHK2
    dc.l    exceptionType1      |;  7   01c TRAPcc/TRAPV
    dc.l    exceptionType2      |;  8   020 privilege violation
    dc.l    exceptionType1      |;  9   024 trace
    dc.l    exceptionType2      |; 10   028 A-trap
    dc.l    exceptionType2      |; 11   02c F-trap
    dc.l    exceptionType1      |; 12   030 reserved
    dc.l    exceptionType2      |; 13   034 coprocessor protocol violation
    dc.l    exceptionType2      |; 14   038 format error
    dc.l    exceptionType1      |; 15   03c uninitialized interrupt
    .dcb.l  8,exceptionType1    |; 16-23    040-05c reserved
    dc.l    exceptionType1      |; 24   060 spurious interrupt
    dc.l    exceptionType1      |; 25   064 autovector 1
    dc.l    exceptionType1      |; 26   068 autovector 2
    dc.l    exceptionType1      |; 27   06c autovector 3
    dc.l    exceptionType1      |; 28   070 autovector 4
    dc.l    exceptionType1      |; 29   074 autovector 5
    dc.l    exceptionType1      |; 30   078 autovector 6
    dc.l    exceptionType1      |; 31   07c autovector 7
    dc.l    SysTrap             |; 32   080 trap 0
    dc.l    exceptionType1      |; 33   084 trap 1
    dc.l    exceptionType1      |; 34   088 trap 2
    dc.l    exceptionType1      |; 35   08c trap 3
    dc.l    exceptionType1      |; 36   090 trap 4
    dc.l    exceptionType1      |; 37   094 trap 5
    dc.l    exceptionType1      |; 38   098 trap 6
    dc.l    exceptionType1      |; 39   09c trap 7
    dc.l    exceptionType1      |; 40   0a0 trap 8
    dc.l    exceptionType1      |; 41   0a4 trap 9
    dc.l    exceptionType1      |; 42   0a8 trap 10
    dc.l    exceptionType1      |; 43   0ac trap 11
    dc.l    exceptionType1      |; 44   0b0 trap 12
    dc.l    exceptionType1      |; 45   0b4 trap 13
    dc.l    exceptionType1      |; 46   0b8 trap 14
    dc.l    exceptionType1      |; 47   0bc trap 15
    dc.l    exceptionType2      |; 48   0c0 FPU branch or set on unordered condition
    dc.l    exceptionType2      |; 49   0c4 FPU inexact result
    dc.l    exceptionType2      |; 50   0c8 FPU divide by zero
    dc.l    exceptionType2      |; 51   0cc FPU underflow
    dc.l    exceptionType2      |; 52   0d0 FPU operand error
    dc.l    exceptionType2      |; 53   0d4 FPU overflow
    dc.l    exceptionType2      |; 54   0d8 FPU NaN
    dc.l    exceptionType1      |; 55   0dc reserved
    dc.l    exceptionType2      |; 56   0e0 MMU configuration error
    dc.l    exceptionType2      |; 57   0e4 68851 reserved
    dc.l    exceptionType2      |; 58   0e8 68851 reserved
    .dcb.l  5,exceptionType1    |; 59-63    0ec-0fc reserved
    .dcb.l  64,exceptionType1   |; 64-127   100-1fc User-defined
    .dcb.l  128,exceptionType1  |; 128-255  200-3fc User-defined


|; type 1 exception will be exceptions we can recover from
|; and return to the current user without issue
exceptionType1:
    movem.l %a0/%d0,%sp@-                   |; save registers
    move.w  %sp@(14),%d0                    |; get vector offset
    bsr     printVector                     |; print vector name string
    movem.l %sp@+,%a0/%d0                   |; restore registers
    rte                                     |; return to current user

|; type 2 exception will be exceptions we cannot recover from
|; and the user will need to be reinitialized
exceptionType2:
    move.w  %sp@(14),%d0                    |; get vector offset
    bsr     printVector                     |; print vector name string

    lea     USERTABLE,%a0                   |; get pointer to user table
    move.l  USERNUM,%d0                     |; get current user number
    jsr     kUserTblInit                    |; reinitialize current user

    jmp     NextUser                        |; skip to the next user

|; print the exception name for vector offset in D0
printVector:
    andi.w  #0x0fff,%d0                     |; mask vector number
    lea     vectorNameTable,%a0             |; get pointer to string pointer table
    move.l  %a0@(%d0.w),%a0                 |; get string pointer
    debugPrintStr                           |; kernel printstring macro
    rts

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



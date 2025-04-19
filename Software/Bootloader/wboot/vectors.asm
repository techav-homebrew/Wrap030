|; initial boot vectors
|; these vectors are used by the bootloader and are intended to operate prior
|; to ROM being confirmed online.
|; ideally, the booted program would load its own vector table. 

    .section text,"ax"

coldVectors:
    dc.l    STACKINIT           |;  0   000 reset interrupt stack pointer
    dc.l    RESETVECTOR         |;  1   004 reset vector
    dc.l    vecBusError         |;  2   008 bus error
    dc.l    vecAddrError        |;  3   00c address error
    dc.l    vecIllegalInstr     |;  4   010 illegal instruction
    dc.l    vecDivideZero       |;  5   014 divide by zero
    dc.l    vecCHK              |;  6   018 CHK/CHK2
    dc.l    vecTRAPcc           |;  7   01C TRAPcc/TRAPV
    dc.l    vecPrivViol         |;  8   020 privilege violation
    dc.l    vecTrace            |;  9   024 trace
    dc.l    vecATrap            |; 10   028 A-Trap
    dc.l    vecFTrap            |; 11   02c F-Trap
    dc.l    vecReserved         |; 12   030 reserved
    dc.l    vecCoproProto       |; 13   034 coprocessor protocol violation
    dc.l    vecFormatErr        |; 14   038 format error
    dc.l    vecUninitIrq        |; 15   03c uninitialized interrupt
    .dcb.l  8,vecReserved       |; 16-23    040-05c reserved
    dc.l    vecSpurious         |; 24   060 spurious interrupt
    dc.l    vecAuto1            |; 25   064 autovector1
    dc.l    vecAuto2            |; 26   068 autovector2
    dc.l    vecAuto3            |; 27   06c autovector3
    dc.l    vecAuto4            |; 28   070 autovector4
    dc.l    vecAuto5            |; 29   074 autovector5
    dc.l    vecAuto6            |; 30   078 autovector6
    dc.l    vecAuto7            |; 31   07c autovector7
    dc.l    vecTrap0            |; 32   080 trap 0
    dc.l    vecTrap1            |; 33   084 trap 1
    dc.l    vecTrap2            |; 34   088 trap 2
    dc.l    vecTrap3            |; 35   08c trap 3
    dc.l    vecTrap4            |; 36   090 trap 4
    dc.l    vecTrap5            |; 37   094 trap 5
    dc.l    vecTrap6            |; 38   098 trap 6
    dc.l    vecTrap7            |; 39   09c trap 7
    dc.l    vecTrap8            |; 40   0a0 trap 8
    dc.l    vecTrap9            |; 41   0a4 trap 9
    dc.l    vecTrap10           |; 42   0a8 trap 10
    dc.l    vecTrap11           |; 43   0ac trap 11
    dc.l    vecTrap12           |; 44   0b0 trap 12
    dc.l    vecTrap13           |; 45   0b4 trap 13
    dc.l    vecTrap14           |; 46   0b8 trap 14
    dc.l    vecTrap15           |; 47   0bc trap 15
    dc.l    vecFpuBranch        |; 48   0c0 FPU branch or set unordered
    dc.l    vecFpuInexact       |; 49   0c4 FPU inexact result
    dc.l    vecFpuDivZero       |; 50   0c8 FPU divide by zero
    dc.l    vecFpuUnderflow     |; 51   0cc FPU underflow
    dc.l    vecFpuOpError       |; 52   0d0 FPU operand error
    dc.l    vecFpuOverflow      |; 53   0d4 FPU overflow
    dc.l    vecFpuNaN           |; 54   0d8 FPU NaN
    dc.l    vecReserved         |; 55   0dc reserved
    dc.l    vecMmuConfErr       |; 56   0e0 MMU config error
    dc.l    vecMmuReserved      |; 57   0e4 MMU reserved
    dc.l    vecMmuReserved      |; 58   0e8 MMU reserved
    .dcb.l  5,vecReserved       |; 59-63    0ec-0fc reserved
    .dcb.l  64,vecUndefined     |; 64-127   100-1fc user-defined
    .dcb.l  128,vecUndefined    |; 128-255  200-3fc user-defined

vecBusError:
    lea     %pc@(strBusErr),%a1
    bra     handleException
vecAddrError:
    lea     %pc@(strAddrErr),%a1
    bra     handleException
vecIllegalInstr:
    lea     %pc@(strIllIns),%a1
    bra     handleException
vecDivideZero:
    lea     %pc@(strDivZero),%a1
    bra     handleException
vecCHK:
    lea     %pc@(strChk),%a1
    bra     handleException
vecTRAPcc:
    lea     %pc@(strTrapV),%a1
    bra     handleException
vecPrivViol:
    lea     %pc@(strPrivViol),%a1
    bra     handleException
vecTrace:
    lea     %pc@(strTrace),%a1
    bra     handleException
vecATrap:
    lea     %pc@(strALine),%a1
    bra     handleException
vecFTrap:
    lea     %pc@(strFLine),%a1
    bra     handleException
vecReserved:
    lea     %pc@(strReserved),%a1
    bra     handleException
vecCoproProto:
    lea     %pc@(strCoproViol),%a1
    bra     handleException
vecFormatErr:
    lea     %pc@(strFormatErr),%a1
    bra     handleException
vecUninitIrq:
    lea     %pc@(strUninitIrq),%a1
    bra     handleException
vecSpurious:
    lea     %pc@(strSpurIrq),%a1
    bra     handleException
vecAuto1:
    lea     %pc@(strIrq1),%a1
    bra     handleException
vecAuto2:
    lea     %pc@(strIrq2),%a1
    bra     handleException
vecAuto3:
    lea     %pc@(strIrq3),%a1
    bra     handleException
vecAuto4:
    lea     %pc@(strIrq4),%a1
    bra     handleException
vecAuto5:
    lea     %pc@(strIrq5),%a1
    bra     handleException
vecAuto6:
    lea     %pc@(strIrq6),%a1
    bra     handleException
vecAuto7:
    lea     %pc@(strIrq7),%a1
    bra     handleException
vecTrap0:
    lea     %pc@(strTrap0),%a1
    bra     handleException
vecTrap1:
    lea     %pc@(strTrap1),%a1
    bra     handleException
vecTrap2:
    lea     %pc@(strTrap2),%a1
    bra     handleException
vecTrap3:
    lea     %pc@(strTrap3),%a1
    bra     handleException
vecTrap4:
    lea     %pc@(strTrap4),%a1
    bra     handleException
vecTrap5:
    lea     %pc@(strTrap5),%a1
    bra     handleException
vecTrap6:
    lea     %pc@(strTrap6),%a1
    bra     handleException
vecTrap7:
    lea     %pc@(strTrap7),%a1
    bra     handleException
vecTrap8:
    lea     %pc@(strTrap8),%a1
    bra     handleException
vecTrap9:
    lea     %pc@(strTrap9),%a1
    bra     handleException
vecTrap10:
    lea     %pc@(strTrapA),%a1
    bra     handleException
vecTrap11:
    lea     %pc@(strTrapB),%a1
    bra     handleException
vecTrap12:
    lea     %pc@(strTrapC),%a1
    bra     handleException
vecTrap13:
    lea     %pc@(strTrapD),%a1
    bra     handleException
vecTrap14:
    lea     %pc@(strTrapE),%a1
    bra     handleException
vecTrap15:
    lea     %pc@(strTrapF),%a1
    bra     handleException
vecFpuBranch:
    lea     %pc@(strFpuBSUC),%a1
    bra     handleException
vecFpuInexact:
    lea     %pc@(strFpuInexact),%a1
    bra     handleException
vecFpuDivZero:
    lea     %pc@(strFpuDivZero),%a1
    bra     handleException
vecFpuUnderflow:
    lea     %pc@(strFpuUnderflow),%a1
    bra     handleException
vecFpuOpError:
    lea     %pc@(strFpuOperand),%a1
    bra     handleException
vecFpuOverflow:
    lea     %pc@(strFpuOverflow),%a1
    bra     handleException
vecFpuNaN:
    lea     %pc@(strFpuNaN),%a1
    bra     handleException
vecMmuConfErr:
    lea     %pc@(strMmuConfigErr),%a1
    bra     handleException
vecMmuReserved:
    lea     %pc@(strMmuUnused),%a1
    bra     handleException
vecUndefined:
    lea     %pc@(strUnused),%a1
    bra     handleException


    .include "ldr_utility.inc"

handleException:
    lea     %pc@(strExceptHead),%a0
    ldrPrintStr
    movea.l %a1,%a0
    ldrPrintStr
    lea     %pc@(strExceptFoot),%a0
    ldrPrintStr
    |; delay loop
    move.l  #0x000fffff,%d0
1:  subq.l  #1,%d0
    bne.s   1b
    jmp     RESETVECTOR

strExceptHead:  
    .ascii  "\r\n\r\n"
    .ascii  "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    .ascii  "\r\nException: \0"
strExceptFoot:  
    .ascii  "\r\n"
    .ascii  "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    .ascii  "\r\n\r\n\0"

|; table of friendly name strings for all vectors
vectorNames:
strBusErr:      .ascii  "Bus Error\0"
strAddrErr:     .ascii  "Address Error\0"
strIllIns:      .ascii  "Illegal Instruction\0"
strDivZero:     .ascii  "Divide by Zero\0"
strChk:         .ascii  "CHK Trap\0"
strTrapV:       .ascii  "TRAPV\0"
strPrivViol:    .ascii  "Privilege Violation\0"
strTrace:       .ascii  "Trace IRQ\0"
strALine:       .ascii  "A-Line Error\0"
strFLine:       .ascii  "F-Fline Error\0"
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
strFpuDivZero:  .ascii  "FPU Divide by Zero\0"
strFpuUnderflow: .ascii "FPU Underflow\0"
strFpuOperand:  .ascii  "FPU Operand Err\0"
strFpuOverflow: .ascii  "FPU Overflow\0"
strFpuNaN:      .ascii  "FPU NaN Err\0"
strMmuConfigErr: .ascii "MMU Config Err\0"
strMmuUnused:   .ascii  "MMU Err\0"
strReserved:    .ascii  "Reserved\0"
    .even




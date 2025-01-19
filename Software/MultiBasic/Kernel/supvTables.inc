|; supervisor data tables
    .section text,"ax"

    .even
supvOpTable:
    dc.l    supvMain
    dc.l    supvPopChar
    dc.l    supvPutChar
    dc.l    supvGetChar
    dc.l    supvPutStr
    dc.l    supvPutStrLoop
    dc.l    supvPutCharBS
    dc.l    supvPutCharCR
    dc.l    supvPutCharLF
    dc.l    supvGetStr
    dc.l    supvParseLine
supvOpTableEnd:
    dc.l    supvMain


supvComTable:
    dc.b    4,4
    .ascii  "BAUD"
    dc.l    supvCmdBaud

    dc.b    10,4
    .ascii  "HANDSHAKE"
    dc.l    supvCmdHandshake

    dc.b    6,3
    .ascii  "PARITY"
    dc.l    supvCmdParity

    dc.b    8,4
    .ascii  "WORDSIZE"
    dc.l    supvCmdWordsize

    dc.b    8,4
    .ascii  "STOPBITS"
    dc.l    supvCmdStopbits

    dc.b    4,4
    .ascii  "HELP"
    dc.l    supvCmdHelp

    dc.b    8,4
    .ascii  "KILLUSER"
    dc.l    supvCmdKill

    dc.b    10,10
    .ascii  "WARMREBOOT"
    dc.l    supvCmdWarmReboot

    dc.b    0,0

supvBaudDivisor:
    dc.w       1    |; 115200    0
    dc.w       2    |;  57600    1
    dc.w       3    |;  38400    2
    dc.w       4    |;  28800    3
    dc.w       6    |;  19200    4
    dc.w       8    |;  14400    5 
    dc.w       9    |;  12800    6
    dc.w      12    |;   9600    7
    dc.w      24    |;   4800    8
    dc.w      48    |;   2400    9
    dc.w      64    |;   1800    a
    dc.w      96    |;   1200    b
    dc.w     192    |;    600    c
    dc.w     384    |;    300    d
    dc.w     576    |;    200    e
    dc.w     768    |;    150    f
    dc.w     860    |;    134*  10
    dc.w    1047    |;    110*  11
    dc.w    1536    |;     75   12
    dc.w    2304    |;     50   13



    .global     WARMBOOT
    .global     timerFlag
    .include    "kmacros.inc"


WARMBOOT:
    debugPrintStrI  "\r\n\r\n========== Timer test ==========\r\n\r\n"
    lea     timerBase,%a5
    debugPrintStrI  "Setting VBR\r\n"
    move.l  #0,%a0
    movec   %a0,%vbr
    debugPrintStrI  "Clearing timer\r\n"
    move.b  #0,%a5@
    debugPrintStrI  "Enabling interupts\r\n"
    move.w  #0x2000,%sr
2:  move.l  #0,timerFlag
    debugPrintStrI  "Setting timer to 0x7fff. Waiting ...\r\n"
    move.b  #0,%a5@(0x00007fff)
1:  tst.l   timerFlag
    beq.s   1b
    debugPrintStrI  "Timer changed!\r\n"
    bra     2b



    .section    bss,"w"

timerFlag:  ds.l    1

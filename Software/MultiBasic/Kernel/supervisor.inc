/* this is a very minimal supervisor console
 * the intention is that every command will be a single ASCII character
 *
 * command format:
 *  7  6  5  4  3  2  1  0 
 * [0][1][ baud  ][  user ] - set user buad rate
 * [0][0][1][ fmt][  user ] - set user size/parity
 * [0][0][0][1][s][  user ] - set user stop bits
 * [0][0][0][0][1][  user ] - reset user
 * [0][0][0][0][0][1][1][1] - 
 * [0][0][0][0][0][1][1][0] - 
 * [0][0][0][0][0][1][0][1] - 
 * [0][0][0][0][0][1][0][0] - 
 * [0][0][0][0][0][0][1][1] - 
 * [0][0][0][0][0][0][1][0] - 
 * [0][0][0][0][0][0][0][1] - warm start
 * [0][0][0][0][0][0][0][0] - cold start
 */

supvConsole:
    |; start by checking supervisor UART to see if it has received data
    btst    #0,acia1Com                     |; check status bit
    beq     _supvExit                       |; if no byte, then exit
    move.b  acia1Dat,%d0                    |; read byte

    |; parse
    btst    #7,%d0                          |; ignore any above 127
    bne     _supvExit
    btst    #6,%d0                          |; set baud command if set
    bne     _supvSetBaud
    btst    #5,%d0                          |; set size/parity if set
    bne     _supvSetFormat
    btst    #4,%d0                          |; set stop bits if set
    bne     _supvSetStopBits
    btst    #3,%d0                          |; reset user if set
    bne     _supvResetUser
    cmp.b   #0,%d0                          |; check cold restart command
    beq     _supvCold
    cmp.b   #1,%d0                          |; check warm restart command
    beq     _supvWarm

_supvExit:
    rts

_supvCold:
    debugPrintStrI " => COLD REBOOT NOW\r\n"
    jmp     _initKernelConsole

_supvWarm:
    debugPrintStrI " => WARM REBOOT NOW\r\n"
    lea     %sp@(4),%sp                     |; pop return address off stack
    jmp     kInit

_supvResetUser:
    debugPrintStrI " => Resetting user "
    and.b   #0x07,%d0                       |; mask off user number
    debugPrintHexByte %d0
    lea     USERTABLE,%a0                   |; get pointer to user table
    bsr     kUserTblInit                    |; reset user table entry
    debugPrintStrI "\r\n> "
    rts

_supvSetStopBits:
    move.b  %d0,%d1                         |; copy byte
    and.b   #0x07,%d1                       |; mask off user number
    eor.l   %d2,%d2                         |; clear a register
    add.b   %d1,%d2                         |; long user number
    lsl.l   #2,%d2                          |; shift to longword offset
    lea     tblUserConIn,%a0                |; get pointer to console table
    add.l   %d2,%a0                         |; get pointer to user IO pointer
    move.l  %a0@,%a0                        |; get user IO pointer
    move.b  %a0@(comRegLCR),%d3             |; get current LCR register value

    and.b   #0xfb,%d3                       |; mask relevant bits

    btst    #3,%d0                          |; check stop bit setting
    beq.s   1f                              |; branch for 0
    debugPrintStrI " => Setting 2 stop bits for user "
    or.b    0x04,%d3                        |; set bit for 2 stop 
    
    bra.s   2f
1:
    debugPrintStrI " => Setting 1 stop bit for user "
2: 
    move.b  %d3,%a0@(comRegLCR)             |; write back new value to register
    debugPrintHexByte %d1
    debugPrintStrI "\r\n> "
    rts

_supvSetFormat:
    move.b  %d0,%d1                         |; copy command
    and.b   #0x07,%d1                       |; mask user number
    extb.l  %d1                             |; sign-extend to longword

    move.b  %d0,%d2                         |; copy command
    lsr.b   #3,%d2                          |; shift format into position
    and.b   #0x03,%d2                       |; mask format bits
    extb.l  %d2                             |; sign-extend to longword

    lea     tblSupvFormat,%a1               |; format data table pointer
    add.l   %d2,%a1                         |; pointer to table entry
    move.b  %a1@,%d3                        |; get table entry

    lea     tblUserConIn,%a1                |; get user console table
    move.l  %d1,%d4                         |; copy user number
    lsl.l   #2,%d4                          |; shift to longword offset
    add.l   %d4,%a1                         |; pointer to table entry
    move.l  %a1@,%a1                        |; pointer to user console

    move.b  %a1@(comRegLCR),%d5             |; get current setting
    and.b   #0xE4,%d5                       |; mask out format bits
    or.b    %d3,%d5                         |; apply new settings
    move.b  %d5,%a1@(comRegLCR)             |; save new settings

    lea     tblSupvFormatStr,%a1            |; get pointer to string pointer table
    add.l   %d4,%a1                         |; get pointer to entry
    move.l  %a1@,%a0                        |; get pointer from table
    debugPrintStr                           |; print string from table
    debugPrintHexByte %d1                   |; print user number
    debugPrintStrI "\r\n> "
    rts

_supvSetBaud:
    move.b  %d0,%d1                         |; copy command
    and.b   #0x07,%d1                       |; mask user number
    extb.l  %d1                             |; sign-extend to longword

    move.b  %d0,%d2                         |; copy command
    lsr.b   #3,%d2                          |; shift baudrate into position
    and.b   #0x07,%d2                       |; mask baudrate bits
    extb.l  %d2                             |; sign-extend to longword

    lea     tblSupvBaudDivisor,%a1          |; baudrate divisor table pointer
    add.l   %d2,%a1                         |; pointer to table entry
    move.w  %a1@,%d3                        |; get table entry (divisor)

    lea     tblUserConIn,%a1                |; get user console table
    move.l  %d1,%d4                         |; copy user number
    lsl.l   #2,%d4                          |; shift to longword offset
    add.l   %d4,%a1                         |; pointer to table entry
    move.l  %a1@,%a1                        |; pointer to user console

    ori.b   #0x80,%a1@(comRegLCR)           |; enable divisor registers
    move.b  %d3,%a1@(comRegDivLo)           |; set divisor low byte
    lsl.w   #8,%d3                          |; get divisor high byte
    move.b  %d3,%a1@(comRegDivHi)           |; set divisor high byte
    andi.b  #0x7f,%a1@(comRegLCR)           |; disable divisor registers

    lea     tblSupvBaudStr,%a1              |; get pointer to string pointer table
    add.l   %d4,%a1                         |; get pointer to entry
    move.l  %a1@,%a0                        |; get pointer from table
    debugPrintStr                           |; print string from table
    debugPrintHexByte %d1                   |; print user number
    debugPrintStrI "\r\n> "
    rts


tblSupvFormat:
    dc.b    0x03
    dc.b    0x02
    dc.b    0x18
    dc.b    0x12

tblSupvFormatStr:
    dc.l    strSupvFormat0                  |; 8bit No parity
    dc.l    strSupvFormat1                  |; 7bit No parity
    dc.l    strSupvFormat2                  |; 7bit Even parity
    dc.l    strSupvFormat3                  |; 7bit Odd parity


tblSupvBaudDivisor:
    dc.w    384                             |;    300
    dc.w    192                             |;    600
    dc.w    96                              |;   1200
    dc.w    48                              |;   2400
    dc.w    24                              |;   4800
    dc.w    12                              |;   9600
    dc.w    3                               |;  38400
    dc.w    1                               |; 115200

tblSupvBaudStr:
    dc.l    strSupvBaud0
    dc.l    strSupvBaud1
    dc.l    strSupvBaud2
    dc.l    strSupvBaud3
    dc.l    strSupvBaud4
    dc.l    strSupvBaud5
    dc.l    strSupvBaud6
    dc.l    strSupvBaud7

strSupvFormat0: .ascii  " => Setting 8N for user \0"
strSupvFormat1: .ascii  " => Setting 7N for user \0"
strSupvFormat2: .ascii  " => Setting 7E for user \0"
strSupvFormat3: .ascii  " => Setting 7O for user \0"
strSupvBaud0:   .ascii  " => Setting 300 baud for user \0"
strSupvBaud1:   .ascii  " => Setting 600 baud for user \0"
strSupvBaud2:   .ascii  " => Setting 1200 baud for user \0"
strSupvBaud3:   .ascii  " => Setting 2400 baud for user \0"
strSupvBaud4:   .ascii  " => Setting 4800 baud for user \0"
strSupvBaud5:   .ascii  " => Setting 9600 baud for user \0"
strSupvBaud6:   .ascii  " => Setting 38400 baud for user \0"
strSupvBaud7:   .ascii  " => Setting 115200 baud for user \0"

    .even


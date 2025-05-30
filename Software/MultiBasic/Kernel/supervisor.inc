/* this is a very minimal supervisor console
 * the intention is that every command will be a single ASCII character
 *
 * command format:
 *  7  6  5  4  3  2  1  0 
 * [0][1][ baud  ][  user ] - set user buad rate
 * [0][0][1][ fmt][  user ] - set user size/parity
 * [0][0][0][1][s][  user ] - set user stop bits
 * [0][0][0][0][1][  user ] - reset user
 * [0][0][0][0][0][  user ] - toggle modem mode
 */

supvConsole:
    |; start by checking supervisor UART to see if it has received data
    btst    #0,acia1Com                     |; check status bit
    beq     _supvExitQuiet                  |; if no byte, then exit
    move.b  acia1Dat,%d0                    |; read byte

    cmp.b   #0x20,%d0                       |; check for control char
    blt.s   1f                              |; branch for control char
    debugPrintChar %d0                      |; print received char
    bra.s   2f
1:
    debugPrintStrI "^"
    move.b  %d0,%d1                         |; copy command byte
    addi.b  #0x40,%d1                       |; shift up to printable
    debugPrintChar %d1                      |; print received char
2:
    |; parse
    btst    #7,%d0                          |; ignore any above 127
    bne     _supvExitQuiet
    btst    #6,%d0                          |; set baud command if set
    bne     _supvSetBaud
    btst    #5,%d0                          |; set size/parity if set
    bne     _supvSetFormat
    btst    #4,%d0                          |; set stop bits if set
    bne     _supvSetStopBits
    btst    #3,%d0                          |; reset user if set
    bne     _supvResetUser
    bra     _supvUserMode                   |; else, toggle user mode
    /*
    cmp.b   #0,%d0                          |; check cold restart command
    beq     _supvCold
    cmp.b   #1,%d0                          |; check warm restart command
    beq     _supvWarm
    */

_supvExit:
    debugPrintStrI "\r\n> "
_supvExitQuiet:
    rts

/*
_supvCold:
    debugPrintStrI " => COLD REBOOT NOW\r\n"
    |; make sure we're jumping into ROM not RAM
    lea     romOffset,%a0
    lea     %a0@(COLDBOOT),%a0
    jmp     %a0@


_supvWarm:
    debugPrintStrI " => WARM REBOOT NOW\r\n"
    lea     %sp@(4),%sp                     |; pop return address off stack
    jmp     WARMBOOT
*/

_supvResetUser:
    debugPrintStrI " => Resetting user "
    and.b   #0x07,%d0                       |; mask off user number
    extb.l  %d0                             |; sign-extend user number to long
    |; debugPrintHexByte %d0
    bsr     _supvPrintHexByte
    lea     USERTABLE,%a0                   |; get pointer to user table
    bsr     kUserTblInit                    |; reset user table entry
    bra     _supvExit


_supvSetStopBits:
    move.b  %d0,%d1                         |; copy command byte
    
    and.b   #0x07,%d1                       |; mask off user number
    extb.l  %d1                             |; sign-extend to longword

    lea     %pc@(tblUserConIn),%a0          |; get pointer to console table
    move.l  %a0@(%d1.l*4),%a0               |; get pointer to user console

    btst    #3,%d0                          |; check requested setting
    beq.s   1f                              |; branch if clear
    ori.b   #0x04,%a0@(comRegLCR)           |; set bit
    debugPrintStrI " => Setting 2 stop bits for user "
    bra.s   2f
1:
    andi.b  #0xfb,%a0@(comRegLCR)           |; clear bit
    debugPrintStrI " => Setting 1 stop bit for user "
2:
    |;debugPrintHexByte %d1
    move.b  %d1,%d0
    bsr     _supvPrintHexByte
    bra     _supvExit


_supvSetFormat:
    move.b  %d0,%d1                         |; copy command byte

    and.b   #0x07,%d1                       |; mask user number
    extb.l  %d1                             |; sign-extend to longword

    lsr.b   #3,%d0                          |; shift format into position
    and.b   #0x03,%d0                       |; mask format bits
    extb.l  %d0                             |; sign-extend to longword

    lea     %pc@(tblSupvFormat),%a1         |; get format table pointer
    move.b  %a1@(%d0.l),%d2                 |; get format byte

    lea     %pc@(tblUserConIn),%a0          |; get pointer to console table
    move.l  %a0@(%d1.l*4),%a0               |; get pointer to user console

    move.b  %a0@(comRegLCR),%d3             |; get current LCR byte
    andi.b  #0xc4,%d3                       |; mask off settings bits
    or.b    %d2,%d3                         |; apply new settings
    move.b  %d3,%a0@(comRegLCR)             |; apply new settings

    lea     tblSupvFormatStr,%a0            |; get pointer to string table
    move.l  %a0@(%d0.L*4),%a0               |; get pointer to string

    debugPrintStr
    |;debugPrintHexByte %d1
    move.b  %d1,%d0
    bsr     _supvPrintHexByte
    bra     _supvExit


_supvSetBaud:
    move.b  %d0,%d1                         |; copy command byte

    and.b   #0x07,%d1                       |; mask user number
    extb.l  %d1                             |; sign-extend to longword

    lsr.b   #3,%d0                          |; shift baudrate into position
    andi.b  #0x07,%d0                       |; mask baudrate bits
    extb.l  %d0                             |; sign-extend to longword

    lea     %pc@(tblSupvBaudDivisor),%a1    |; get baudrate table pointer
    move.w  %a1@(%d0.l*2),%d2               |; get baudrate divisor

    lea     %pc@(tblUserConIn),%a0          |; get pointer to console table
    move.l  %a0@(%d1.l*4),%a0               |; get pointer to user console

    ori.b   #0x80,%a0@(comRegLCR)           |; enable divisor registers
    move.b  %d2,%a0@(comRegDivLo)           |; set divisor low byte
    lsr.l   #8,%d2                          |; get divisor high byte
    move.b  %d2,%a0@(comRegDivHi)           |; set divisor high byte
    andi.b  #0x7f,%a0@(comRegLCR)           |; disable divisor registers

    lea     %pc@(tblSupvBaudStr),%a1        |; get pointer to string table
    move.l  %a1@(%d0.l*4),%a0               |; get pointer to string
    debugPrintStr
    |;debugPrintHexByte %d1
    move.b  %d1,%d0
    bsr     _supvPrintHexByte
    bra     _supvExit

_supvUserMode:
    andi.b  #0x07,%d1                       |; mask user number
    extb.l  %d1                             |; sign-extend to longword
    move.l  %d1,%d0                         |; copy user number

    mulu    #utbl_size,%d1                  |; get table offset
    lea     USERTABLE,%a0                   |; get pointer to user table
    add.l   %d1,%a0                         |; get user table entry
    cmpi.b  #uModeModem,%a0@(utblUsrMode)   |; check current user mode
    beq     1f
    |; user mode is not uModeModem. set it to uModeModem
    move.b  #uModeModem,%a0@(utblUsrMode)

    |; send modem configuration string
    move.l  %a0@(utblConOut),%a0            |; get pointer to user com port
    lea     %pc@(strSupvModemAT),%a1        |; get pointer to command string
2:  move.b  %a1@+,%d1                       |; get next string byte
    beq.s   3f                              |; exit loop if byte is null
4:  btst    #5,%a0@(comRegLSR)              |; check TX ready bit
    beq.s   4b                              |; loop until TX ready
    move.b  %d1,%a0@(comRegTX)              |; print byte
    bra.s   2b                              |; loop until string printed

3:  debugPrintStrI " => Setting Modem Mode for user "
    |;debugPrintHexByte %d0
    bsr     _supvPrintHexByte
    bra     _supvExit
1:
    |; user mode is uModeModem. set it to uModeTerminal
    move.b  #uModeTerminal,%a0@(utblUsrMode)
    debugPrintStrI " => Setting Terminal Mode for user "
    |;debugPrintHexByte %d0
    bsr     _supvPrintHexByte
    bra     _supvExit






|; print hex byte in d0 (wrapper for kernel macro)
_supvPrintHexByte:
    debugPrintHexByte %d0
    rts




tblSupvFormat:
    dc.b    0x03                            |; 8bit No parity
    dc.b    0x02                            |; 7bit No parity
    dc.b    0x1a                            |; 7bit Even parity
    dc.b    0x0a                            |; 7bit Odd parity

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

strSupvModemAT: .ascii  "ATE0\rATV0\rATQ0\rAT&D0\rAT&S1\rATS0=1\r\0"

    .even

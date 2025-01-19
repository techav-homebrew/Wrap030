|; supervisor console functions


/******************************************************************************
 *  THEORY OF OPERATION:
 *
 *  Setup function is called to initialize the supervisor program.
 *  Main is the main program loop and is called by the kernel task switch ISR
 *  after one user context is saved but before the next user is restored.
 *  
 *  The program maintains two stacks in memory, an operation stack and a data
 *  stack. The data stack stores strings to/from the console. The operation 
 *  stack stores queued operations. 
 *  At the start of the main loop, the most recent operation is popped off of 
 *  the operation stack and then it jumps to the appropriate handler for that
 *  operation. If an operation is not able to complete its work (e.g. while
 *  waiting on the UART to be ready to transmit), then the operation handler
 *  will push its own operation back onto the stack so that it is the next
 *  operation to be called when the main loop returns at the next ISR.
 *  
 *  The intention is for each operation to be a single small task that can be
 *  completed as quickly as possible. 
 *
 *****************************************************************************/
    
    .include "supervisor.inc"

    .section text,"ax"

|******************************************************************************
|* setup & main loop

|; macro to quickly push op to op stack
    .macro  mPushOp op
    moveq   #\op,%d0                        |; load op value
    bsr     supvPushOp                      |; and push to stack
    .endm

|; macro to quickly push op to op stack and fall through
    .macro  mNextOp op
    moveq   #\op,%d0
    bra     supvPushOp
    .edn

|; initial setup for supervisor console
supvSetup:
    movea.l opStackStart,%a0                |; get pointer to start of op stack
    movea.l %a0,ptrOpStack                  |; save initial op stack pointer
    move.l  #0x3F,%d0                       |; loop counter for 256 bytes
    moveq.l #0,%d1                          |; for clearing memory quickly
1:
    move.l  %d1,%a0@+                       |; clear next four bytes
    dbra    %d0,1b                          |; loop until done
    
    movea.l datStackStart,%a0               |; get pointer to start of dat stack
    movea.l %a0,ptrDatStack                 |; save initial dat stack pointer
    move.l  #0x0ff,%d0                      |; loop counter for 1024 bytes
2:
    move.l  %d1,%a0@+                       |; clear next four bytes
    dbra    %d0,2b                          |; loop until done
    rts

|; supervisor console main loop
supvMain:
    |; here is where the magic will happen
    bsr     supvPopOp                       |; pop the latest op from stack
    cmp.b   #0,%d0                          |; check for no op
    beq.s   1f
    extb.l  %d0                             |; sign-extend op to 32-bits
    lsl.l   #2,%d0                          |; shift to table offset

    lea     %pc@(supvOpTable),%a0           |; get pointer to start of op table
    lea     %pc@(supvOpTableEnd),%a1        |; get pointer to end of op table
    move.l  %a0,%d2                         |; get size of table
    move.l  %a1,%d1
    cmp.l   %d1,%d2                         |; check if command in range
    blt     2f                              |; branch if in range
1:  |; handle no or invalid op
    mPushOp supvOpParseLine
    mPushOp supvOpGetStr
    mPushOp supvOpPutLF
    bra     supvPutCharCR
    rts
2:  |; table jump
    bra     %a0@(%d0.l)                     |; jump to function from table
    rts


|******************************************************************************
|* supervisor stack push/pop functions

|; push byte to the op stack
supvPushOp:
    movea.l ptrOpStack,%a0                  |; fetch current op stack pointer
    cmpa.l  #opStackEnd,%a0                 |; check if we're at end of stack
    beq.s   1f                              |; stack full error
    addq.l  #1,%a0                          |; pre-increment stack pointer
    move.b  %d0,%a0@                        |; save byte to stack
    movea.l %a0,ptrOpStack                  |; save new stack pointer
    rts                                     |; we're done here
1:  |; op stack full error
    moveq   #supvErrOpStackFull,%d0         |; get error code
    bra     supvError                       |; run error handler routine

|; pop byte from the op stack
supvPopOp:
    movea.l ptrOpStack,%a0                  |; fetch current op stack pointer
    cmpa.l  #opStackStart,%a0               |; check if we're at the start of stack
    beq.s   1f                              |; stack empty error
    move.b  %a0@,%d0                        |; pop byte from stack
    subq.l  #1,%a0                          |; post-decrement stack pointer
    movea.l %a0,ptrOpStack                  |; save new stack pointer
    rts                                     |; we're done here
1:  |; op stack empty. return 0
    moveq   #0,%d0                          |; return no operation
    rts
    |;moveq   #supvErrOpStackEmpty,%d0        |; get error code
    |;bra     supvError                       |; run error handler routine

|; push byte to the op stack
supvPushDat:
    movea.l ptrDatStack,%a0                 |; fetch current dat stack pointer
    cmpa.l  #datStackEnd,%a0                |; check if we're at end of stack
    beq.s   1f                              |; stack full error
    addq.l  #a,%a0                          |; pre-increment stack pointer
    move.b  %d0,%a0@                        |; save byte to stack
    movea.l %a0,ptrDatStack                 |; save new stack pointer
1:  |; dat stack full error
    moveq   #supvErrDatStackFull,%d0        |; get error code
    bra     supvError                       |; run error handler routing

|; pop byte from the dat stack
supvPopDat:
    movea.l ptrDatStack,%a0                 |; fetch current dat stack pointer
    cmpa.l  #opStackEnd,%a0                 |; check if we're at the start of stack
    beq.s   1f                              |; stack empty error
    move.b  %a0@,%d0                        |; pop byte from stack
    subq.l  #1,%a0                          |; post-decrement stack pointer
    movea.l %a0,ptrDatStack                 |; save new stack pointer
    rts                                     |; we're done here
1:  |; dat stack empty error
    moveq   #supvErrDatStackEmpty,%d0       |; get error code
    bra     supvError                       |; run error handler routine


|******************************************************************************
|* serial operations

|; pop a character from the data stack and print it
supvPopChar:
    btst    #1,acia1Com                     |; check ACIA txrdy bit
    beq.s   1f                              |; branch if not ready
    bsr     supvPopDat                      |; pop byte off supervisor stack
    move.b  %d0,acia1Dat                    |; print it
    rts                                     |; and we're done
1:  |; ACIA not ready for Tx
    mNextOp supvOpPopChar                   |; push next op to stack & return

|; read the current character from the data stack and print it
supvPutChar:
    btst    #1,acia1Com                     |; check ACIA txrdy bit
    beq.s   1f                              |; branch if not ready
    movea.l ptrDatStack,%a0                 |; get pointer to data stack
    move.b  %a0@,acia1Dat                   |; print current byte
    rts                                     |; and we're done
1:  |; ACIA not ready for Tx
    mNextOp supvOpPutChar                   |; push next op to stack & return

|; echo a backspace character
supvPutCharBS:
    btst    #1,acia1Com                     |; check ACIA txrdy bit
    beq.s   1f                              |; branch if not ready
    move.b  #charBackspace,acia1Dat         |; print backspace character
    rts                                     |; and we're done
1:  |; ACIA not ready for Tx
    mNextOp supvOpPutBS                     |; push next op to stack & return

|; echo a carriage return character
supvPutCharCR:
    btst    #1,acia1Com                     |; check ACIA txrdy bit
    beq.s   1f                              |; branch if not ready
    move.b  #charCR,acia1Dat                |; print CR character
    rts                                     |; and we're done
1:  |; ACIA not ready for Tx
    mNextOp supvOpPutCR                     |; push next op to stack & return

|; echo a linefeed character
supvPutCharLF:
    btst    #1,acia1Com                     |; check ACIA txrdy bit
    beq.s   1f                              |; branch if not ready
    move.b  #charLF,acia1Dat                |; print LF character
    rts                                     |; and we're done
1:  |; ACIA not ready for Tx
    mNextOp supvOpPutLF                     |; push next op to stack & return

|; read a character from ACIA and push to stack
supvGetChar:
    btst    #0,acia1Com                     |; check ACIA rxrdy bit
    beq.s   1f                              |; branch if no char available
    move.b  acia1Dat,%d0                    |; read byte from ACIA
    |; we need to check some special cases with the byte we just read
    
    |; delete the last character
    cmpi.b  #charBackspace,%d0              |; 
    beq.s   2f
    cmpi.b  #charDelete,%d0                 |;
    beq.s   2f

    |; cancel this line
    cmpi.b  #charCtrlC,%d0                  |;
    beq.s   3f
    cmpi.b  #charEscape,%d0                 |;
    beq.s   3f

    |; check for carriage return
    cmpi.b  #charCR,%d0                     |;
    beq.s   7f

    |; non-printable characters
    cmpi.b  #charSpace,%d0                  |;
    blt.s   4f
    cmpi.b  #charTilde,%d0                  |;
    bgt.s   4f

    |; and all else just push to stack & print
5:
    bsr     supvPushDat                     |; push to stack
    mNextOp supvOpPutChar                   |; push next op to stack & return

2:  |; handle backspace
    movea.l ptrDatStack,%a0                 |; get dat stack pointer
    cmpa.l  #opStackStart,%a0               |; check if already at the start
    bgt.s   6f                              |; skip ahead if not at start
    rts                                     |; if at start, nothing to do
6:  |; handle backspace not at start of stack
    subq.l  #1,%a0                          |; decrement stack pointer
    movea.l %a0,ptrDatStack                 |; save updated stack pointer
    mNextOp supvOpPutBS                     |; push next op to stack & return

3:  |; cancel the current line
    movea.l #datStackStart,ptrDatStack      |; reset stack pointer to beginning
    moveq   #charCR,%d0                     |; put a carriage return on stack
    bsr     supvPushDat
    moveq   #charLF,%d0                     |; put a linefeed on the stack
    bsr     supvPushDat
    moveq   #0,%d0                          |; null terminate stack
    bsr     supvPushDat
    mNextOp supvOpPutStr                    |; push next op to stack & return

4:  |; skip over non-printable characters
    rts

1:  |; ACIA not ready for Rx
    mNextOp supvOpGetChar                   |; push next op to stack & return

7:  |; on CR, always follow with LF
    bsr     supvPushDat                     |; push CR to stack
    moveq   #charLF,%d0                     |; push LF to stack
    bsr     supvPushDat                     |;
    mPushOp supvOpPutLF                     |; push print LF op to stack
    bra     supvPutCharCR                   |; go try to print CR


|******************************************************************************
|* string operations

|; print a null-terminated string at the start of the stack, then reset stack
supvPutStr:
    move.l  #datStackStart,%a0              |; get start of data stack
    subq    #1,%a0                          |; decrement past start so the loop
                                            |; will work when we get to that
                                            |; point in just a few instructions
    move.l  %a0,ptrDatStack                 |; update pointer
|; fall through to the print string loop
supvPutStrLoop:
    move.l  ptrDatStack,%a0                 |; get data stack pointer
    addq    #1,%a0                          |; increment
    move.l  %a0,ptrDatStack                 |; save updated stack pointer
    cmp.b   #0,%a0@                         |; is this byte null?
    beq.s   1f                              |; branch if null
    mPushOp supvOpPutStrLoop                |; push op to continue loop
    bra     supvOpPutChar                   |; go try to print this byte
1:  |; byte is null, we're done with string printing
    move.l  #datStackStart,%a0              |; reset stack pointer
    move.b  #0,%a0@                         |; clear first byte
    move.l  %a0,ptrOpStack                  |; save updated stack pointer
    rts                                     |; and we're done

|; read a string from the console, looking for LF to terminate
supvGetStr:
    move.l  ptrDatStack,%a0                 |; get pointer to dat stack
    cmp.b   #charLF,%a0@                    |; check if last char is LF
    beq.s   1f                              |; branch if LF
    mPushOp supvOpGetStr                    |; push op for get string again
    bra     supvGetChar                     |; check for new char & return
1:  |; we've received a LF character, time to end this string read
    moveq   #0,%d0                          |; add null termination
    bra     supvPushDat                     |; push null to stack & return


|******************************************************************************
|* Command operations
|* 
|* The following functions for parsing & executing commands are taken from 
|* TSMON and modified to work within the limits of the supervisor console

|; parse & execute entered command
|; this is equivalent to TSMON "TIDY" & "EXECUTE" functions
supvParseLine:
|; start of TIDY
    lea     datStackStart,%a0               |; a0 points to line buffer
    lea     %a0,%a1                         |; a1 points to start of line buffer
1:  |; TIDY1
    move.b  %a0@+,%d0                       |; read char from line buffer
    cmp.b   #charSpace,%d0                  |; repeat until first non-space
    beq.s   1b                              |;      char is found
    lea     %a0@(-1),%a0                    |; move pointer back to first char
2:  |; TIDY2
    move.b  %a0@+.%d0                       |; move the string left to remove
    move.b  %d0,%a1@+                       |;      any leading spaces
    cmp.b   #charSpace,%d0                  |; test for embedded space
    bne.s   4f                              |; if not space, test for EOL
3:  |; TIDY3
    cmp.b   #charSpace,%a0@+                |; if space skip multiple embedded
    beq.s   3b                              |;      spaces
    lea     %a0@(-1),%a0                    |; move back pointer
4:  |; TIDY4
    cmp.b   #charCR,%d0                     |; test for EOL
    bne.s   2b                              |; if not EOL then read next char
    lea     datStackStart,%a0               |; restore buffer pointer
5:  |; TIDY5
    cmp.b   #charCR,%a0@                    |; test for EOL
    beq.s   6f                              |; if EOL then exit
    cmp.b   #charSpace,%a0@+                |; test for delimiter
    bne.s   5b                              |; repeat until delimiter or EOL
6:  |; TIDY6
    move.l  %a0,ptrBuf                      |; update buffer pointer

supvExecuteLine:
|; start of EXECUTE
|; EXEC1 (skip user table search)
    lea     %pc@(supvComTable),%a3          |; get pointer to command table
    bsr.s   supvCmdSearch                   |; look for command in table
    bcs.s   2f                              |; if found then execute command
    moveq   #supvErrBadCommand,%d0          |; else print invalid command error
    bra     supvError                       |;      and return
2:  |; EXEC2
    move.l  %a3@,%a3                        |; get the relative command address
    lea     %pc@(supvComTable),%a4          |;      pointed to at by a3 and add
    add.l   %a4,%a3                         |;      it to PC to get actuall cmd
    jmp     %a3@                            |;      address, then execute it

|; match the command in the line buffer with command table pointed at by A3
supvCmdSearch:
|; start of SEARCH
    eor.l   %d0,%d0                         |; clear working register
    move.b  %a3@,%d0                        |; get first char in current entry
    beq.s   7f                              |; if 0 then exit
    lea     %a3@(6,%d0:W),%a4               |; else get address of next entry
    move.b  %a3@(1),%d1                     |; get num chars to match
    lea     datStackStart,%a5               |; a5 points to command in line buf
    move.b  %a3@(2),%d2                     |; get first char in this entry
    cmp.b   %a5@+,%d2                       |;      from table & match with buf
    beq.s   3f                              |; if match then continue
2:  |; SRCH2
    move.l  %a4,%a3                         |; else get address of next entry
    bra     supvCmdSearch                   |;      & try next entry in table
3:  |; SRCH3
    sub.b   #1,%d1                          |; one less char to match
    beq.s   6f                              |; if match counter then all done
    lea     %a3@(3),%a3                     |; else point to next char in table
4:  |; SRCH4
    move.b  %a3@+,%d2                       |; now match pair of chars
    cmp.b   %a5@+,%d2                       |; 
    bne     2b                              |; if no match then try next
    sub.b   #1,%d1                          |; else decrement match counter
    bne.s   4b                              |;      & repeat until done
6:  |; SRCH6
    lea     %a4@(-4),%a3                    |; get address of cmd entry point
    or.b    #1,%ccr                         |; mark carry as success & return
    rts
7:  |; SRCH7
    and.b   #0xfe,%ccr                      |; no match; clear carry for error
    rts


|******************************************************************************
|* Command parsing utility functions

|; read parameter from line buffer into D0 & supvParam
|; bit 1 of D7 set on error
supvParseParam:
    move.l  %d1,%a7@-                       |; save D1
    eor.l   %d1,%d1                         |; clear input accumulator
    move.l  supvParam,%a0                   |; get pointer to param in buffer
1:  |; PARAM1
    move.b  %a0@+,%d0                       |; read char from line buffer
    cmp.b   #charSpace,%d0                  |; test for delimiter
    beq.s   4f                              |;      (either space or CR)
    cmp.b   #charCR,%d0                     |;
    beq.s   4f
    asl.l   #4,%d1                          |; shift accumulated result by 4
    sub.b   #0x30,%d0                       |; convert char to hex
    bmi.s   5f                              |; if <$30 then not hex
    cmp.b   #0x09,%d0                       |; if less than 10
    ble.s   3f                              |; then continue
    sub.b   #0x07,%d0                       |; else assume $A-$F
    cmp.b   #0x0f,%d0                       |; if more than $f
    bgt.s   5f                              |; then not hex
3:  |; PARAM3
    add.b   %d0,%d1                         |; add latest nybble to d1
    bra     1b                              |; repeat until delimiter found
4:  |; PARAM4
    move.l  %a0,ptrBuf                      |; save pointer
    move.l  %d1,supvParam                   |; save parameter
    move.l  %d1,%d0                         |; return param in d0
    and.b   #0xfd,%d7                       |; clear error flag
    bra.s   6f                              |; return without error
5:  |; PARAM5
    or.b    #2,%d7                          |; set error flag before return
6:  |; PARAM 6
    move.l  %a7@+,%d1                       |; restore D1
    rts

|; read user number as parameter
|; returns user number or 0
supvParseUserNum:
    bsr     supvParseParam                  |; read parameter
    tst.b   %d7                             |; check for input error
    bne.s   1f
    tst.b   %d0                             |; check for 0
    beq.s   1f
    cmp.b   #MAXUSERS,%d0                   |; check for user in range
    bgt.s   1f
    rts                                     |; return user number
1:
    moveq   #0,%d0                          |; return 0 on error
    rts


|******************************************************************************
|* Supervisor commands

|; set baud rate for a user terminal
supvCmdBaud:
    bsr     supvParseUserNum                |; read user number parameter
    tst.l   %d0                             |; check for error
    beq.s   1f
    move.l  %d0,%d1                         |; save user number
    bsr     supvParseParam                  |; get divisor
    tst.l   %d7                             |; check for error
    bne.s   1f
    tst.l   %d0                             |; lower bounds check
    beq.s   1f
    cmp.l   #0x13,%d0                       |; upper bounds check
    bgt.s   1f
    lsl.l   #1,%d0                          |; shift to table position
    lea     %pc@(supvBaudDivisor),%a0       |; get pointer to divisor table
    move.w  %a0@(%d0.L),%d0                 |; get divisor

    lea     tblUserConIn,%a0                |; get pointer to user console pointer table
    subq.l  #1,%d1                          |; decrement user number to 0-based
    lsl.l   #2,%d1                          |; shift user number to table offset
    move.l  %a0@(%d1.L),%a0                 |; get pointer to user console device

    move.b  %a0@(comRegLCR),%d0             |; read current LCR value
    move.b  %d0,%d2                         |; copy it
    or.b    #0x80,%d2                       |; enable divisor registers
    move.b  %d2,%a0(comRegLCR)              |;
    move.b  %d1,%a0@(comRegDivLo)           |; set divisor low byte
    ror.b   #4,%d1                          |; get divisor high byte
    move.b  %d1,%a0@(comRegDivHi)           |; set divisor high byte
    move.b  %d0,%a0@(comRegLCR)             |; restore LCR
    rts
1f: |; parameter error
    moveq   supvErrBadParam,%d0             |; 
    bra     supvError




|******************************************************************************
|* data tables

    .include "supvTables.inc"
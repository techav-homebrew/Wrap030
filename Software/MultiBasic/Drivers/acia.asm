|; 6850 ACIA driver

    .global drvACIAin
    .global drvACIAout
    .extern aciaRegDat
    .extern aciaRegCom

    .section text,"ax"

|; given pointer in A0, check if device has Rx data
|; return 0 in D0 if no data ready, or char
drvACIAin:
    btst    #0,%a0@(aciaRegCom)             |; read rxrdy status bit
    bne.s   1f                              |; if set, jump to RXRDY
    move.b  #0,%d0                          |; return 0 if no char ready
    rts
1:
    move.b  %a0@(aciaRegDat),%d0            |; read char
    rts

|; given pointer in A0 & char in D0, try to Tx
|; return carry set on success, clear on not ready
drvACIAout:
    btst    #1,%a0@(aciaRegCom)             |; read txrdy status bit
    beq.s   1f                              |; branch if not read
    move.b  %d0,%a0@(aciaRegDat)            |; write char
    ori.b   #0x01,%ccr                    |; set carry on success
    rts
1:
    andi.b  #0xfe,%ccr                    |; clear carry on not ready
    rts

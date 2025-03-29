|; 16C55x driver for Octocom board

    .global drvOctocomIn
    .global drvOctocomOut
    .extern comRegLSR
    .extern comRegRX
    .extern comRegTX

    .section text,"ax"

|; given pointer in A0, check if device has Rx data
|; return 0 in D0 if no data ready, or char
drvOctocomIn:
    btst    #0,%a0@(comRegLSR)              |; read rxrdy status bit
    bne     1f                              |; if set, jump to RXRDY
    move.b  #0,%d0                          |; return 0 if no char ready
    rts
1:
    move.b  %a0@(comRegRX),%d0              |; read char
    rts

|; given pointer in A0 & char in D0, try to Tx
|; return carry set on success, clear on not ready
drvOctocomOut:
    btst    #5,%a0@(comRegLSR)              |; read txrdy status bit
    beq     1f                              |; branch if not ready
    move.b  %d0,%a0@(comRegTX)              |; write char
    ori.b   #0x01,%ccr                    |; set carry on success
    rts
1:
    andi.b  #0xfe,%ccr                    |; clear carry on not ready
    rts

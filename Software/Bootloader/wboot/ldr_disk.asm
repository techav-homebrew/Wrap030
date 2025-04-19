|;*****************************************************************************
|; Boot loader disk functions
|;*****************************************************************************
|; these functions will follow C calling convention


|; check if disk is present.
|; RETURNS:
|;  D0.b:
|;      0:      no disk found
|;      [else]: disk present
|; C PRIMITIVE:
|;      uint8_t ideCheck();
ideCheck:
    move.b  ideStatusRO,%d0                 |; get status byte
    rts


|; read a disk sector
|; C PRIMITIVE:    uint32_t ideReadSect(uint8_t * buffer, uint32_t LBA)
|; PARAMETERS:
|;  uint8_t * buffer        pointer to memory buffer to read into
|;  uint32_t  LBA           disk logical block address to read from
|; RETURNS:
|;  D0.l:
|;      0:      error
|;      512:    success
ideReadSect:
    |; initialize read sector command
    move.l  %sp@(8),%d0                     |; get LBA from stack frame
    andi.l  #0x0fffffff,%d0                 |; mask 28-bit LBA
    ori.l   #0xe0000000,%d0                 |; set enable LBA mode flag
    move.b  %d0,ideLBALLRW                  |; write first byte of LBA
    ror.l   #8,%d0                          |; shift in next byte
    move.b  %d0,ideLBALHRW                  |; write next byte
    ror.l   #8,%d0                          |;
    move.b  %d0,ideLBAHLRW                  |;
    ror.l   #8,%d0                          |;
    move.b  %d0,ideLBAHHRW                  |;
    move.b  #1,ideSectorCountRW             |; set sector read count to 1
    move.b  #0x20,ideCommandWO              |; send read sector command

    |; wait for disk not busy, ready, & data ready
    lea     ideStatusRO,%a0                 |; get pointer to status register
    move.l  #0x00007fff,%d1                 |; set up timeout counter
1:  |; ideReadSectLp1
    move.b  %a0@,%d0                        |; read status byte
    btst.b  #7,%d0                          |; check busy bit
    bne.s   2f                              |; busy if set
    btst.b  #6,%d0                          |; check disk ready bit
    beq.s   2f                              |; not ready if clear
    btst.b  #3,%d0                          |; check data ready bit
    beq.s   2f                              |; not ready if clear
    btst.b  #0,%d0                          |; check error bit
    bne.s   .ideReadSectErr                 |; error if set
    bra     3f                              |; ready to read if we get here
2:  |; ideReadSectLp1count
    subq.l  #1,%d1                          |; decrement counter
    beq.s   .ideReadSectErr                 |; timeout if 0
    bra.s   1b                              |; continue check ready loop

3:  |; ideReadSectReady
    move.w  #255,%d1                        |; set up loop counter
    lea     ideDataRW,%a1                   |; get IDE read port
    move.l  %sp@(4),%a0                     |; get pointer from stack frame
4:  |; ideSectReadLp
    move.w  %a1,%a0@+                       |; read word into buffer
    dbra    %d1,4b                          |; loop until sector read

    |; read sector complete
    move.l  #512,%d0                        |; set success
    rts

.ideReadSectErr:
    eor.l   %d0,%d0                         |; clear D0 on error
    rts

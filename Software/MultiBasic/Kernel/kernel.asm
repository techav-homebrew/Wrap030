

    .include    "kglobals.inc"
    .include    "syscalls.inc"
    .include    "kmacros.inc"
    .global     kUserTblInit
    .global     NextUser

    .section text,"ax"

WARMBOOT:
    |; enable CPU cache
kEnableCache:
    move.l  #0x00000101,%d0                 |; enable data & instruction cache
    movec   %d0,%cacr                       |; write to cache control register
    debugPrintStrI "Cache enabled\r\n"

kInitConsoles:
    |; initialize user console ports
    debugPrintStrI "Initializing user console ports ... "
    lea     tblUserConIn,%a0                |; get pointer to user console pointer table
    move.l  MAXUSERS-1,%d0                  |; get number of users
1:
    move.l  %a0@(%d0.l:4),%a1               |; get pointer to console device
    move.b  #0x07,%a1@(comRegFCR)           |; enable FIFO
    move.b  #0x03,%a1@(comRegLCR)           |; set 8N1
    move.b  #0x00,%a1@(comRegIER)           |; disable interrupts
    move.b  #0x83,%a1@(comRegLCR)           |; enable divisor registers
    move.b  #0x0c,%a1@(comRegDivLo)         |; set divisor for 9600bps from 1.8432MHz oscillator
    move.b  #0x00,%a1@(comRegDivHi)         |;
    move.b  #0x03,%a1@(comRegLCR)           |; disable divisor registers
    dbra    %d0,1b                          |; initialize all users' console ports
    debugPrintStrI "OK\r\n"

    |; load BASIC into RAM
kBasicLoader:
    debugPrintStrI "Loading BASIC from ROM ... "
    lea     ROMBASIC,%a0                    |; get pointer to BASIC in ROM
    lea     RAMBASIC,%a1                    |; get pointer to where BASIC will go in RAM
    move.l  #SIZEBASIC,%d0                  |; get size of BASIC in bytes
    lsr.l   #2,%d0                          |; convert to count of longwords
1:
    move.l  %a0@+,%a1@+                     |; copy BASIC into RAM one longword at a time
    dbra    %d0,1b                          |; keep copying until finished
    debugPrintStrI "OK\r\n"

    |; initialize user data table
kInit:
    debugPrintStrI "Initializing user data table ... "
    move.l  #MAXUSERS-1,%d0                 |; start at end of user numbers
    lea     USERTABLE,%a0                   |; pointer to user table
1:
    bsr     kUserTblInit                    |; initialize user
    dbra    %d0,1b                          |; initialize all users
    debugPrintStrI "OK\r\n"

    |; initialize MMU?

    |; jump execution to first user program
    debugPrintStrI "Starting execution at user 0\r\n"
    move.w  #0x0080,%sp@-                   |; push TRAP0 vector to system stack
    move.l  #BASICENTRY,%sp@-               |; push BASIC entry point to stack as return address
    move.w  #0,%sp@-                        |; push clear CCR to stack
    moveq.l #0,%d0                          |; start by loading user 0
    move.l  %d0,%d1                         |; clear syscall to make it past context restore
    bra     RestoreUserContext              |; load user context & start execution




|; initialize user table in A0 for user number in D0
kUserTblInit:
    move.l  %d0,%d1                         |; copy user number
    mulu    #utbl_size,%d1                  |; multiply by table entry size to get offset
    lea     %a0@(%d1.l),%a1                 |; get pointer to this user's table entry
    move.w  #15,%d2                         |; set loop counter for 16 registers
    eor.l   %d3,%d3                         |; clear D3 for initializing table entries
    lea     %a1@(utblRegD0),%a2             |; set up incrementable pointer for this
1:
    move.l  %d3,%a2@+                       |; clear register store in user table entry
    dbra    %d2,1b                          |; loop until all 16 gp registers cleared

    move.l  %d0,%d2                         |; copy user number
    lsl.l   #2,%d2                          |; word size shift

    move.l  %d3,%a1@(utblRegCCR)            |; clear user CCR
    lea     tblUserConIn,%a2                |; set user console in device address
    move.l  %a2@(%d2.L),%a1@(utblConIn)     |;
    lea     tblUserConOut,%a2               |; set user console out device address
    move.l  %a2@(%d2.L),%a1@(utblConOut)    |;

    lea     tblUserMem,%a2                  |; set user memory start address
    move.l  %a2@(%d2.L),%d4                 |;
    move.l  %d4,%a1@(utblMemPtr)            |;
    move.l  %d4,%a1@(utblRegA0)             |; 
    lea     tblUserMemSize,%a2              |; set user memory size
    move.l  %a2@(%d2.L),%d5                 |;
    move.l  %d5,%a1@(utblMemLen)            |;
    move.l  %d5,%a1@(utblRegD0)             |;

    add.l   %d5,%d4                         |; calculate initial user stack pointer
    move.l  %d4,%a1@(utblRegA7)             |; 

    lea     BASICENTRY,%a2                  |; set initial user PC to BASIC entry point
    move.l  %a2,%a1@(utblRegPC)             |;

    rts






|; system traps end up here
SysTrap:
    |; cmp.b   #0,%d1                          |; check for syscall 0
    |; all system calls start with implicit yield
    beq     doSysTrapYield
SysTrapTbl:
    cmp.b   #SysTrapConRead,%d1                          |;
    beq     doSysTrapConRead
    cmp.b   #SysTrapConWrite,%d1
    beq     doSysTrapConWrite

    rte


|; task switch 
doSysTrapYield:


|; save user state to user table
SaveUserContext:
    movem.l %a0/%d0,%sp@-                   |; save A0 & D0 to system stack
    lea     USERTABLE,%a0                   |; get pointer to user table
    move.l  #USERNUM,%d0                    |; get current user number
    mulu    #utbl_size,%d0                  |; mult by table size to get offset
    adda.l  %d0,%a0                         |; get pointer to specific user table entry
    move.l  %a0,%sp@-                       |; save pointer to system stack for later use
    adda.l  #utblRegStore,%a0               |; get pointer to next address past data store
    movem.l %a0-%a7/%d0-%d7,%sp@-           |; save all registers to data store
    move.l  %sp@+,%a0                       |; restore pointer to start of user table entry
    move.l  %sp@+,%a0@(utblRegD0)           |; save register D0 to user table
    move.l  %sp@+,%a0@(utblRegA0)           |; save register A0 to user table
    move.w  %sp@(0),%a0@(utblRegCCR)        |; save status register
    move.l  %sp@(2),%a0@(utblRegPC)         |; save user program counter
    move.l  %usp,%a1                        |; fetch user stack pointer
    move.l  %a1,%a0@(utblRegA7)             |; save user stack pointer to user table


NextUser:
    |; get user number
    move.l  USERNUM,%d0                     |;
    addq.l  #1,%d0                          |; increment user number
    cmp.l   #MAXUSERS,%d0                   |; is this the last user?
    blt.s   1f
    moveq.l #0,%d0                          |; loop back around to first user
1:
    move.l  %d0,USERNUM                     |; save new user number


|; restore context for user in D0
RestoreUserContext:
    mulu    #utbl_size,%d0                  |; shift user number to table offset
    lea     USERTABLE,%a0                   |; get user table pointer again
    add.l   %d0,%a0                         |; add user offset
    move.l  %a0,%sp@-                       |; save pointer

    |; update MMU table

    |; restore user status
    lea     %a0@(utblRegA7),%a0             |; start by pointing to A7
    move.l  %a0@,%a1                        |; get user stack pointer
    move.l  %a1,%usp                        |; restore user stack pointer
    lea     %a0@(utblRegD0-utblRegA7),%a0   |; point to beginning of user registers
    movem.l %a0@+,%d0-%D7                   |; restore data registers
    add.l   #4,%a0                          |; skip past A0
    movem.l %a0@+,%a1-%a6                   |; restore A1-A6
    move.l  %sp@+,%a0                       |; revert pointer back to beginning of table

    move.w  %a0@(utblRegCCR),%sp@(0)        |; restore status register to exception frame
    move.l  %a0@(utblRegPC),%sp@(2)         |; restore user PC to exception frame

    move.l  %a0@(utblRegA0),%a0             |; restore A0 last and we're done

    |; at the end of all this, check D1 to see if we have a pending syscall
    cmp.b   #0,%d1                          |; if not 0 then jump to syscall table
    bne     SysTrapTbl

    |; if D1 was 0 we'll end up here. time to return from exception using the
    |; user PC we restored to exception frame
    rte





doSysTrapConRead:
    movem.l %a0/%d0,%sp@-                   |; save working registers
    lea     USERTABLE,%a0                   |; get pointer to user table
    move.l  USERNUM,%d0                     |; get user number
    lsl.l   #7,%d0                          |; shift to offset in table
    add.l   %d0,%a0                         |; pointer to user table entry
    move.l  %a0@(utblConIn),%a0             |; get pointer to console device

    |; this is where we should be using device drivers, but for now we'll just
    |; hard code a driver for 16c550
    btst    #0,%a0@(comRegLSR)              |; read com port status bit
    bne     1f                              |; jump ahead to RXREADY
    
    movem.l %sp@+,%a0/%d0                   |; restore working registers
    andi.w  #0xfffe,%sp@(0)                 |; clear carry on saved status register
    rte
1:                                          |; RXREADY
    movem.l %sp@+,%a0/%d0                   |; restore working registers
    ori.w   #0x0001,%sp@(0)                 |; set carry on saved status register
    rte

doSysTrapConWrite:
    movem.l %a0/%d2,%sp@-                   |; save working registers
    lea     USERTABLE,%a0                   |; get pointer to user table
    move.l  USERNUM,%d2                     |; get user number
    lsl.l   #7,%d2                          |; shift to offset in table
    add.l   %d2,%a0                         |; pointer to user table entry
    move.l  %a0@(utblConOut),%a0            |; get pointer to console device

    |; this is where we should be using device drivers, but for now we'll just
    |; hard code a driver for 16c550
    btst    #5,%a0@(comRegMSR)              |; check if terminal ready (DTR)
    beq     1f                              |; jump ahead to TXNOTREADY
    btst    #5,%a0@(comRegLSR)              |; check if ready to transmit
    beq     1f                              |; jump ahead to TXNOTREADY
    move.b  %d0,%a0@(comRegTX)              |; write character to com port
    movem.l %sp@+,%a0/%d2                   |; restore working registers
    rte
1:                                          |; TXNOTREADY
    movem.l %sp@+,%a0/%d2                   |; restore working registers to
                                            |; clear the stack frame
    bra     NextUser                        |; yield to next user
    rte





KernelTables:


tblUserConIn:
    dc.l    ioCom0
    dc.l    ioCom1
    dc.l    ioCom2
    dc.l    ioCom3
    dc.l    ioCom4
    dc.l    ioCom5
    dc.l    ioCom6
    dc.l    ioCom7

tblUserConOut:
    dc.l    ioCom0
    dc.l    ioCom1
    dc.l    ioCom2
    dc.l    ioCom3
    dc.l    ioCom4
    dc.l    ioCom5
    dc.l    ioCom6
    dc.l    ioCom7

tblUserMem:
    dc.l    uMemStart0
    dc.l    uMemStart1
    dc.l    uMemStart2
    dc.l    uMemStart3
    dc.l    uMemStart4
    dc.l    uMemStart5
    dc.l    uMemStart6
    dc.l    uMemStart7

tblUserMemSize:
    dc.l    uMemSize0
    dc.l    uMemSize1
    dc.l    uMemSize2
    dc.l    uMemSize3
    dc.l    uMemSize4
    dc.l    uMemSize5
    dc.l    uMemSize6
    dc.l    uMemSize7



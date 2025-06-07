

    .include    "kglobals.inc"
    .include    "syscalls.inc"
    .include    "kmacros.inc"
    .global     kUserTblInit
    .global     NextUser
    .global     doSysTrapYield
    .extern     STACKINIT
    .extern     diskInit

    .section text,"ax"

WARMBOOT:
    lea     SUPVSTACKINIT,%a0               |; reset supv stack pointer
    movec   %a0,%msp                        |;
    lea     STACKINIT,%a0                   |; reset irq stack pointer
    movec   %a0,%isp                        |;
    lea     0,%a0                           |; reset VBR
    movec   %a0,%vbr                        |; 
    debugPrintStrI "\r\n~~~~ Wrap030 Multibasic ~~~~\r\n"

    debugPrintStrI "\r\nClearing Timer\r\n"
    move.b  #0,timerBase                    |; disable timer
    move.w  #0x2700,%sr                     |; disable interrupts
    clr.w   kPreempt                        |; clear preempted task flag

    |; enable CPU cache
kEnableCache:
.ifndef     SIMULATE
|;    move.l  #0x00000101,%d0                 |; enable data & instruction cache
    move.l  #0x00002909,%d0                 |; clear & enable cache
    movec   %d0,%cacr                       |; write to cache control register
    debugPrintStrI "Cache enabled\r\n"
.endif

    |; initialize user number
    clr.l   USERNUM                         |;

kInitDiskIO:
    bsr.l   diskInit                        |; initialize & mount disk

kInitConsoles:
    |; initialize user console ports
    debugPrintStrI "Initializing user console ports ... "
.ifndef     SIMULATE
    lea     %pc@(tblUserConIn),%a0          |; get pointer to user console pointer table
    move.l  #MAXUSERS-1,%d0                 |; get number of users
1:
    |;move.l  %a0@(%d0.l:4),%a1               |; get pointer to console device
    move.l  %d0,%d1                         |; copy current user number
    lsl.l   #2,%d1                          |; offset to a longword count
    move.l  %a0@(%d1.L),%a1                 |; read pointer from table
    |;move.b  #0x07,%a1@(comRegFCR)           |; enable FIFO
    move.b  #0x06,%a1@(comRegFCR)           |; disable FIFO
    move.b  #0x03,%a1@(comRegLCR)           |; set 8N1
    move.b  #0x00,%a1@(comRegIER)           |; disable interrupts
    move.b  #0x03,%a1@(comRegMCR)           |; assert DTR/RTS
    move.b  #0x83,%a1@(comRegLCR)           |; enable divisor registers
    move.b  #0x0C,%a1@(comRegDivLo)         |; set divisor for 9600bps from 1.8432MHz oscillator
    move.b  #0x00,%a1@(comRegDivHi)         |;
    move.b  #0x03,%a1@(comRegLCR)           |; disable divisor registers
    dbra    %d0,1b                          |; initialize all users' console ports
.endif
    debugPrintStrI "OK\r\n"

    |; initialize user data table
kInit:
    debugPrintStrI "Initializing user data table ... "
    move.l  #MAXUSERS-1,%d0                 |; start at end of user numbers
    lea     USERTABLE,%a0                   |; pointer to user table
1:
    bsr     kUserTblInit                    |; initialize user
    move.b  #uModeTerminal,%a1@(utblUsrMode)    |; initialize user mode to Terminal
    dbra    %d0,1b                          |; initialize all users
    debugPrintStrI "OK\r\n"

    |; initialize MMU?
    debugPrintStrI "Initializing MMU ... "
    bsr     initMMU                         |;
    debugPrintStrI "OK\r\n"

    |; jump execution to first user program
    debugPrintStrI "Starting execution at user 0\r\n\r\n> "
    move.w  #0x0080,%sp@-                   |; push TRAP0 vector to system stack
    move.l  #BASICENTRY,%sp@-               |; push BASIC entry point to stack as return address
    move.w  #0,%sp@-                        |; push clear CCR to stack
    moveq.l #0,%d0                          |; start by loading user 0
    move.l  %d0,USERNUM                     |; save initial user number
    move.l  %d0,%d1                         |; clear syscall to make it past context restore
    bra     RestoreUserContext              |; load user context & start execution




|; initialize user table in A0 for user number in D0.L
kUserTblInit:
    move.l  %d0,%d1                         |; copy user number
    mulu    #utbl_size,%d1                  |; multiply by table entry size to get offset
    lea     %a0@(%d1.l),%a1                 |; get pointer to this user's table entry

    move.w  %a1@(utblUsrMode),%sp@-         |; save user mode, it's set elsewhere

    move.w  #15,%d2                         |; set loop counter for 16 registers
    eor.l   %d3,%d3                         |; clear D3 for initializing table entries
    lea     %a1@(utblRegD0),%a2             |; set up incrementable pointer for this
1:
    move.l  %d3,%a2@+                       |; clear register store in user table entry
    dbra    %d2,1b                          |; loop until all 16 gp registers cleared

    move.l  %d0,%d2                         |; copy user number
    lsl.l   #2,%d2                          |; word size shift

    move.l  %d3,%a1@(utblRegCCR)            |; clear user CCR
    lea     %pc@(tblUserConIn),%a2          |; set user console in device address
    move.l  %a2@(%d2.L),%a1@(utblConIn)     |;
    lea     tblUserConOut,%a2               |; set user console out device address
    move.l  %a2@(%d2.L),%a1@(utblConOut)    |;

    lea     %pc@(tblUserFSbuf),%a2          |; set user filesystem buffer pointer
    move.l  %a2@(%d2.L),%a1@(utblFilePtr)   |; 
    lea     %pc@(tblUserFilBuf),%a2         |; set user file buffer pointer
    move.l  %a2@(%d2.L),%a1@(ubtlDiskBuf)   |;

    lea     %pc@(tblUserMem),%a2            |; set user memory start address
    move.l  %a2@(%d2.L),%d4                 |;
    move.l  %d4,%a1@(utblMemPtr)            |;
|;    move.l  %d4,%a1@(utblRegA0)             |; 
    move.l  #0,%a1@(utblRegA0)              |; logical memory start address for BASIC start parameter

    lea     %pc@(tblUserMemSize),%a2        |; set user memory size
    move.l  %a2@(%d2.L),%d5                 |;
    move.l  %d5,%a1@(utblMemLen)            |;
    move.l  %d5,%a1@(utblRegD0)             |;

|;    add.l   %d5,%d4                         |; calculate initial user stack pointer
|;    move.l  %d4,%a1@(utblRegA7)             |; 
    move.l  %d5,%a1@(utblRegA7)             |; set end of logical memory for user initial SP

|;    lea     RAMBASIC,%a2                    |; get pointer to BASIC in RAM
|;    move.l  %a2,%a1@(utblRegPC)             |;
    move.l  %d5,%a1@(utblRegPC)             |; logical start address for BASIC is just past vmemory

    move.w  %sp@+,%a1@(utblUsrMode)         |; restore user mode

    rts



kRAMstart:


|; system traps end up here
SysTrap:
    |; cmp.b   #0,%d1                          |; check for syscall 0
    |; all system calls start with implicit yield
    |;debugPrintStrI  "T"
    |;debugPrintHexByte %d0
    |;debugPrintStrI ","
    |;debugPrintHexByte %d1
    |;debugPrintStrI ";"
    bra     doSysTrapYield
SysTrapTbl:
    |;debugPrintStrI  "t"
    |;debugPrintHexByte %d0
    |;debugPrintStrI ","
    |;debugPrintHexByte %d1
    |;debugPrintStrI ";"
    cmp.b   #SysTrapConRead,%d1                          |;
    beq     doSysTrapConRead
    cmp.b   #SysTrapConWrite,%d1
    beq     doSysTrapConWrite
    cmp.b   #SysTrapFileOpen,%d1
    beq     doSysTrapFileOpen
    cmp.b   #SysTrapFileClose,%d1
    beq     doSysTrapFileClose
    cmp.b   #SysTrapFileRead,%d1
    beq     doSysTrapFileRead

    rte


|; task switch 
doSysTrapYield:
    move.b  #0,timerBase                    |; clear timer

|; save user state to user table
SaveUserContext:
    movem.l %a0/%d0,%sp@-                   |; save A0 & D0 to system stack
    |;debugPrintStrI  "S"
    lea     USERTABLE,%a0                   |; get pointer to user table
    move.l  USERNUM,%d0                     |; get current user number
    mulu    #utbl_size,%d0                  |; mult by table size to get offset
    adda.l  %d0,%a0                         |; get pointer to specific user table entry

    move.l  %a1,%a0@(utblRegA1)             |; the verbose way of saving all registers
    move.l  %a2,%a0@(utblRegA2)
    move.l  %a3,%a0@(utblRegA3)
    move.l  %a4,%a0@(utblRegA4)
    move.l  %a5,%a0@(utblRegA5)
    move.l  %a6,%a0@(utblRegA6)
    move.l  %d1,%a0@(utblRegD1)
    move.l  %d2,%a0@(utblRegD2)
    move.l  %d3,%a0@(utblRegD3)
    move.l  %d4,%a0@(utblRegD4)
    move.l  %d5,%a0@(utblRegD5)
    move.l  %d6,%a0@(utblRegD6)
    move.l  %d7,%a0@(utblRegD7)
    movem.l %sp@+,%a1/%d0                   |; fetch A0 & D0 saved to stack earlier
    move.l  %a1,%a0@(utblRegA0)
    move.l  %d0,%a0@(utblRegD0)
    move.l  %usp,%a1
    move.l  %a1,%a0@(utblRegA7)
    move.w  %sp@,%a0@(utblRegCCR)
    move.l  %sp@(2),%a0@(utblRegPC)

    bsr     supvConsole                     |; check in on supervisor console

NextUser:
    |; get user number
    |;debugPrintStrI  "N"
    move.l  USERNUM,%d0                     |;
    addq.l  #1,%d0                          |; increment user number
    cmp.l   #MAXUSERS,%d0                   |; is this the last user?
    blt.s   1f
    moveq.l #0,%d0                          |; loop back around to first user
1:
    move.l  %d0,USERNUM                     |; save new user number
    |;debugPrintStrI  "\r\nU:"
    |;debugPrintHexByte %d0
    |;debugPrintHexNyb    %d0
    |;move.l  USERNUM,%d0

    |; check user mode
    move.l  %d0,%d1
    mulu    #utbl_size,%d1                  |; shift user number to table offset
    lea     USERTABLE,%a0                   |; get uesr table pointer
    add.l   %d1,%a0                         |; add user offset
    cmpi    #uModeModem,%a0@(utblUsrMode)   |; check user mode
    bne     RestoreUserContext              |; if not modem mode, go restore user
    |; user is in modem mode; check modem status register
    move.l  %a0@(utblConIn),%a1             |; get pointer to user console device
    move.b  %a1@(comRegMSR),%d1             |; get modem status register
    andi.b  #0x22,%d1                       |; mask off DSR bits
    cmpi.b  #0x22,%d1                       |; check for start of new call
    bne.s   RestoreUserContext              |; no new call, go restore user
    |; re-initialize the user on start of new call, but don't immediately
    |; restore that user; wait until the user loop has completed and wrapped 
    |; wrapped around to this user
    pea     NextUser                        |; push NexUser as return address
    bra     kUserTblInit                    |; call user table init subroutine
    |; not reached
    nop


|; restore context for user in D0
RestoreUserContext:
    |;debugPrintStrI  "R"
    move.l  USERNUM,%d0
    mulu    #utbl_size,%d0                  |; shift user number to table offset
    lea     USERTABLE,%a0                   |; get user table pointer again
    add.l   %d0,%a0                         |; add user offset
    
    pmove   %a0@(utblMmuReg),%crp           |; set user mmu root pointer
    pflusha                                 |; this shouldn't be necessary
    move.l  #0x00002909,%d0                 |; clear cache
    movec   %d0,%cacr                       |; 
    move.l  %a0@(utblRegA7),%a1             |; restore all registers
    move.l  %a1,%usp
    move.w  %a0@(utblRegCCR),%sp@
    move.l  %a0@(utblRegPC),%sp@(2)
    move.l  %a0@(utblRegA1),%a1
    move.l  %a0@(utblRegA2),%a2
    move.l  %a0@(utblRegA3),%a3
    move.l  %a0@(utblRegA4),%a4
    move.l  %a0@(utblRegA5),%a5
    move.l  %a0@(utblRegA6),%a6
    move.l  %a0@(utblRegD0),%d0
    move.l  %a0@(utblRegD1),%d1
    move.l  %a0@(utblRegD2),%d2
    move.l  %a0@(utblRegD3),%d3
    move.l  %a0@(utblRegD4),%d4
    move.l  %a0@(utblRegD5),%d5
    move.l  %a0@(utblRegD6),%d6
    move.l  %a0@(utblRegD7),%d7
    move.l  %a0@(utblRegA0),%a0             |; restore A0 last since it's our table pointer


    |; at the end of all this, check D1 to see if we have a pending syscall

    |;debugPrintStrI "r"
    |;debugPrintHexByte %d1
    |;debugPrintStrI ","
    tst.w   kPreempt                        |; check if task was preempted
    bne     .RestorePreempt                 |;

    cmp.b   #0,%d1                          |; if not 0 then jump to syscall table
    bne     SysTrapTbl

    |; if D1 was 0 we'll end up here. time to return from exception using the
    |; user PC we restored to exception frame
    bra     .RestoreExit

.RestorePreempt:
    |; skip the SysTrap jump because process was preempted
    clr.w   kPreempt                        |; clear the flag

.RestoreExit:
    move.b  #0,KTIMER                       |; set interval timer
    pflusha
    rte


doSysTrapConRead:
    move.l  %a0,%sp@-                       |; save working registers
    |;debugPrintStrI  "rx"
    lea     USERTABLE,%a0                   |; get pointer to user table
    move.l  USERNUM,%d0                     |; get user number
    mulu    #utbl_size,%d0                  |; shift to offset in table
    add.l   %d0,%a0                         |; pointer to user table entry
    move.l  %a0@(utblConIn),%a0             |; get pointer to console device

    |; this is where we should be using device drivers, but for now we'll just
    |; hard code a driver for 16c550
    btst    #0,%a0@(comRegLSR)              |; read com port status bit
    bne     1f                              |; jump ahead to RXREADY
    
    move.l  %sp@+,%a0                       |; restore working registers
    move.b  #0,%d0                          |; clear d0
    |; andi.w  #0xfffe,%sp@(0)                 |; clear carry on saved status register
    bra     .RestoreExit
    |;rte
1:                                          |; RXREADY
    move.b  %a0@(comRegRX),%d0              |; read byte from console
    |;debugPrintStrI "$"
    |;debugPrintHexByte %d0
    |;debugPrintStrI ";"
    move.l  %sp@+,%a0                       |; restore working registers
    |; ori.w   #0x0001,%sp@(0)                 |; set carry on saved status register
    bra     .RestoreExit
    |;rte

doSysTrapConWrite:
    movem.l %a0/%d2,%sp@-                   |; save working registers
    |;debugPrintStrI  "tx"
    lea     USERTABLE,%a0                   |; get pointer to user table
    move.l  USERNUM,%d2                     |; get user number
    mulu    #utbl_size,%d2                  |; shift to offset in table
    add.l   %d2,%a0                         |; pointer to user table entry
    move.l  %a0@(utblConOut),%a0            |; get pointer to console device

    |; this is where we should be using device drivers, but for now we'll just
    |; hard code a driver for 16c550
    |;btst    #5,%a0@(comRegMSR)              |; check if terminal ready (DTR)
    |;beq     1f                              |; jump ahead to TXNOTREADY
    btst    #5,%a0@(comRegLSR)              |; check if ready to transmit
    beq     1f                              |; jump ahead to TXNOTREADY
    move.b  %d0,%a0@(comRegTX)              |; write character to com port
    |;debugPrintStrI "$"
    |;debugPrintHexByte %d0
    |;debugPrintStrI ";"
    movem.l %sp@+,%a0/%d2                   |; restore working registers
    bra     .RestoreExit
    |;rte
1:                                          |; TXNOTREADY
    movem.l %sp@+,%a0/%d2                   |; restore working registers to
                                            |; clear the stack frame
    bra     NextUser                        |; yield to next user
    bra     .RestoreExit
    |;rte


|; syscall wrapper for libff function:
|; FRESULT f_open(FIL * fp, const TCHAR* path, BYTE mode)
|; requires pointer to filename in A0.L
|; requires mode in D0.L
|; returns FRESULT in D0.L
doSysTrapFileOpen:
    movem.l %a1-%a6/%d1-%d7,%sp@-           |; just ... go ahead and save all
    move.l  %d0,%sp@-                       |; push mode parameter to stack

    lea     USERTABLE,%a1                   |; get user table pointer
    move.l  USERNUM,%d0                     |;
    mulu    #utbl_size,%d0                  |;
    add.l   %d0,%a1                         |;
    add.l   %a1@(utblMemPtr),%a0            |; add user base mem addr to ptr
    move.l  %a0,%sp@-                       |; push path parameter to stack
    move.l  %a1@(utblFilePtr),%d0           |; get user filesystem pointer
    move.l  %d0,%sp@-                       |; push filesystem parameter

    bsr.l   f_open                          |; do file open

    add.l   #12,%sp                         |; clear parameters from stack
    
    movem.l %sp@+,%a1-%a6/%d1-%d7           |; restore all
    bra     .RestoreExit

|; syscall wrapper for libff function:
|; FRESULT f_close(FIL * fp)
|; returns FRESULT in D0.L
doSysTrapFileClose:
    movem.l %a0-%a6/%d0-%d7,%sp@-           |; save all before C call

    lea     USERTABLE,%a0                   |; get user table pointer
    move.l  USERNUM,%d0                     |; 
    mulu    #utbl_size,%d0                  |;
    add.l   %d0,%a0                         |;
    move.l  %a0@(utblFilePtr),%d0           |; get user filesystem pointer
    move.l  %d0,%sp@-                       |; push filesystem parameter

    bsr.l   f_close                         |; do file close

    add.l   #4,%sp                          |; clear parameters from stack

    movem.l %sp@+,%a0-%a6/%d0-%d7           |;
    bra     .RestoreExit


|; syscall wrapper for libff function:
|; FRESULT f_read(FIL * fp, void * buff, UINT btr, UINT * br)
|; requires bytes to read in D0.L
|; requires buffer pointer in A0.L
|; returns FRESULT in D0.L
|; returns bytes read count in D1.L
|; clobbers A0
doSysTrapFileRead:
    movem.l %a1-%a6/%d2-%d7,%sp@-           |; save before calling C function

    move.l  #0,%sp@-                        |; make space for bytes read
    move.l  %sp,%sp@-                       |; push parameter *br
    move.l  %d0,%sp@-                       |; push parameter btr

    lea     USERTABLE,%a1                   |; get user table pointer
    move.l  USERNUM,%d0                     |;
    mulu    #utbl_size,%d0                  |;
    add.l   %d0,%a1                         |;
    add.l   %a1@(utblMemPtr),%a0            |; add base mem pointer
    move.l  %a0,%sp@-                       |; push parameter *buff
    move.l  %a1@(utblFilePtr),%sp@-         |; push parameter *fp

    bsr.l   f_read

    add.l   #16,%sp                         |; clear parameters from stack
    move.l  %sp@+,%d1                       |; get bytes read

    movem.l %sp@+,%a1-%a6/%d2-%d7           |; restore registers
    bra     .RestoreExit


    .even

    .include "mmutables.inc"
    .include "supervisor.inc"


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

tblUserFSbuf:
    dc.l    uFSBuf0
    dc.l    uFSBuf1
    dc.l    uFSBuf2
    dc.l    uFSBuf3
    dc.l    uFSBuf4
    dc.l    uFSBuf5
    dc.l    uFSBuf6
    dc.l    uFSBuf7

tblUserFilBuf:
    dc.l    uFilBuf0
    dc.l    uFilBuf1
    dc.l    uFilBuf2
    dc.l    uFilBuf3
    dc.l    uFilBuf4
    dc.l    uFilBuf5
    dc.l    uFilBuf6
    dc.l    uFilBuf7

    .even
kRAMend:
    dc.l    0
    


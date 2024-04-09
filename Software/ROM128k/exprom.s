|******************************************************************************
|* Wrap030 TSMON Expansion ROM
|* techav
|* 2021-12-26
|******************************************************************************
|* Provides additional commands for TSMON ROM monitor
|*****************************************************************************/

    .include "TSMON_Constants.INC"
    .include "TSMON_FAT.INC"
    .include "macros.inc"

|    .equ ROMBASIC, romSector1       | address for BASIC in ROM
|    .equ RAMBASIC, ramBot+startHeap | above vector table & TSMON globals
|    .equ HEAPBASIC, RAMBASIC+0x4000 | above BASIC program in RAM
|    .equ SIZBASIC, 0x4000            | total size of BASIC to copy from ROM (~16kB)

|******************************************************************************
| HEADER & INITIALIZATION
|******************************************************************************
|    .org	expROM
| This is loaded by TSMON on startup to confirm an expansion ROM is installed
    .section text,"ax"
    .global EXTROM
EXTROM:	
    DC.L	0x524f4d32	        |Expansion ROM identification ('ROM2')
    DC.L	0

    .even
| This is called by TSMON on startup to allow the expansion ROM to initialize
| anything it may need to initialize on startup.
RM2INIT:	
    lea	    DATA,%a6	        | A6 points to RAM heap
    lea	    UCOM,%a5	        | A5 points to User Command Table
    move.l  %a5,%a6@(UTAB)	    | Copy User Com Table ptr
    lea	    %pc@(sBNR),%a4      | Get pointer to banner string
    callSYS trapPutString
    callSYS trapNewLine

|; Add custom trap handler
    bsr     trapInit

|; Check if video installed & intialize
    bsr     vidInit             | initialize video

|; Check if FPU installed
    BSR     ucFPUCHK

|; Enable L1 cache
    BSR     ucCEnable           | enable cache by default

|; Return to monitor
    lea     %pc@(sROM2end),%a4  | get final banner message pointer
    callSYS trapPutString       | print it
    callSYS trapNewLine         | and finish with a newline
    RTS

|;User Command Table
UCOM:	
    DC.B	4,4
    .ascii "HELP"
    DC.L	ucHELP
    DC.B	6,3
    .ascii "BASIC "
    DC.L	ucLoadBasic
    DC.B    8,3
    .ascii "CENABLE "
    DC.L    ucCEnable
    DC.B    8,4
    .ascii "CDISABLE"
    DC.L    ucCDisable
    DC.b    4,4
    .ascii "CHKD"
    DC.l    ucCHKD
    DC.B    6,4
    .ascii "SECTOR"
    dc.L    ucSECT
    dc.B    6,3
    .ascii "FPUCHK"
    dc.L    ucFPUCHK
    dc.B    4,4
    .ascii "BOOT"
    dc.L    ucBOOT
    dc.b    6,4
    .ascii  "DSKRST"
    dc.l    ucDRST
    DC.B	0,0
|;String Constants
sBNR:	.ascii "Initializing ROM 2\0\0"
sROM2end:   .ascii "ROM2 Init Complete.\0"

    .even

|******************************************************************************
|; CUSTOM TRAPS
|******************************************************************************

|; add trap vector to vector table
trapInit:
    sub.l   %a4,%a4                         |; get ptr to vector table start
    move.l  #trap1Handler,%a4@(0x84)        |; set TRAP #1 vector
    rts

trap1Handler:
usys0:                                      |; Cache Enable
    cmp.b   #0,%d1
    bne.s   usys1
    bsr     cacheDisable
    rte
usys1:                                      |; Cache Disable
    cmp.b   #1,%d1
    bne.s   usys2
    bsr     cacheDisable
    rte
usys2:                                      |; FPU Check
    cmp.b   #2,%d1
    bne.s   usys3
    bsr     fpuCheck
    rte
usys3:                                      |; Disk Check
    cmp.b   #3,%d1
    bne.s   usys4
    bsr     ideCheck
    rte
usys4:                                      |; Load Disk Sector
    cmp.b   #4,%d1
    bne.s   usys5
    bsr     ideCheck
    rte
usys5:

usysErr:
    rte


|******************************************************************************
|; VIDEO INITIALIZATION
|******************************************************************************
vidInit:
    eor.b   %d0,%d0                     | clear D0
    lea     vidReg,%a0                  | get pointer to settings register
    move.l  0x8,%sp@-                   | save BERR vector
    move.l  #vidVect,0x8                | load temporary BERR vector
    move.b  %d0,%a0@                    | try applying video settings: $00
                                        | ouput enabled, Mode 0, buffer 0
    cmpi.b  #0,%d0                      | is D0 still clear or did we BERR?
    bne     vidNone                     | skip video init if not installed
    move.l  %sp@+,0x8                   | restore BERR vector

| Initialize video
    lea     %pc@(sVIDstart),%a4         | get pointer to VRAM init start message
    callSYS trapPutString               | and print it
    lea     vidBase,%a0                 | get pointer to top of VRAM
    move.l  #0x0FFFE,%d0                | set up loop counter
    EOR.B   %d1,%d1                     | clear a register to use for clearing VRAM
vidInitLp:
    MOVE.B  %d1,%a0@(0,%d0.L)           |clear VRAM byte
    MOVE.B  %d1,%a0@(0,%d0.L)           |make sure it is clear
    DBRA    %d0,vidInitLp               |loop until complete

    lea     %pc@(sVIDend),%a4           | get pointer to VRAM init end message
    callSYS trapPutString               | and print it.
    callSYS trapNewLine

    rts

vidNone:
    move.l  %sp@+,0x8                   | restore BERR vector
    lea     %pc@(sVIDnone),%a4          | load pointer to no video string
    callSYS trapPutString               | print string
    rts

vidVect:
    moveq   #1,%d0                      | set no video flag
    rte                                 | return from exception

sVIDnone:   .ascii  "Video not installed.\0"
sVIDstart:  .ascii "Initializing Video Memory ... \0"
sVIDend:    .ascii "Done.\0"
    .even

|******************************************************************************
| FPU FUNCTIONS
|******************************************************************************
| check for presence of FPU
| RETURNS:
|   D0 - 1: FPU present| 0: FPU not present
fpuCheck:
    move.l  0x8,%sp@-                   | save bus error vector
    move.l  0x34,%sp@-                  | save coprocessor protocol violation vector
    move.l  #fpuVect,0x8                | load temporary vectors
    move.l  #fpuVect,0x34
    move.b  #1,%d0                      | set flag
    fnop                                | test an FPU instruction
    move.l  %sp@+,0x34                  | restore vectors
    move.l  %sp@+,0x8
    rts                                 | and return
fpuVect:
    move.b  #0,%d0                      | clear flag
    rte

ucFPUCHK:
| Check FPU status
    BSR     fpuCheck                    |Check if FPU is installed
    CMP.b   #0,%d0                      |Check returned flag
    BNE     .initFPUy                   |
    lea     %pc@(sFPUn),%a4             |Get pointer to FPU not installed string
    BRA     .initFPUmsg                 |Jump ahead to print string
.initFPUy:
    lea     %pc@(sFPUy),%a4             |Get pointer to FPU installed string
.initFPUmsg:
    callSYS trapPutString               |Print FPU status string
    callSYS trapNewLine
    rts

sFPUy:  .ascii "FPU Installed.\0\0"
sFPUn:  .ascii "FPU Not Installed.\0\0"

    .even

|******************************************************************************
| HELP FUNCTION
|******************************************************************************
| This is our Help function which prints out a list of commands supported by 
| TSMON and this expansion ROM
ucHELP:	
    lea	    %pc@(sHELP),%a4	            | Get pointer to help text string
    callSYS trapPutString               | print it
    callSYS trapGetChar                 | wait for user
    lea     %pc@(sHELP2),%a4            | Get pointer to HELP2 string
    callSYS trapPutString               | print it
    callSYS trapNewLine
    RTS

sHELP:	
    .ascii "Available Commands:\r\n"
    .ascii "JUMP <ADDRESS>                 - Run from address\r\n"
    .ascii "MEMory <ADDRESS>               - Display & Edit memory\r\n"
    .ascii "LOAD <SRECORD>                 - Load SRecord into memory\r\n"
    .ascii "DUMP <START> <END> [<STRING>]  - Dump SRecord to aux\r\n"
    .ascii "TRAN                           - Transparent mode\r\n"
    .ascii "NOBR <ADDRESS>                 - Remove breakpoint\r\n"
    .ascii "DISP                           - Print register contents\r\n"
    .ascii "GO <ADDRESS>                   - Run from address w/Registers\r\n"
    .ascii "BRGT <ADDRESS>                 - Add breakpoint to table\r\n"
    .ascii "PLAN                           - Insert breakpoints\r\n"
    .ascii "KILL                           - Remove breakpoints\r\n"
    .ascii "GB [<ADDRESS>]                 - Set breakpoints & go\r\n"
    .ascii "REG <REG> <VALUE>              - Set register contents\r\n"
    .ascii "--press any key to continue--\r\n\0"
sHELP2:
    .ascii "--EXPANSION ROM--\r\n"
    .ascii "HELP                           - Print this message\r\n"
    .ascii "BASic                          - Load BASIC\r\n"
    .ascii "CENable                        - Enable L1 cache\r\n"
    .ascii "CDISable                       - Disable L1 cache\r\n"
    .ascii "CHKD                           - Check if disk inserted\r\n"
    .ascii "SECTor <ADDRESS>               - Print disk sector contents\r\n"
    .ascii "FPUchk                         - Check if FPU is installed\r\n"
    .ascii "BOOT                           - Execute boot block from disk\r\n"
    .ascii "DSKRST                         - Reset IDE disk\r\n"
    DC.B	0,0

    .even

|******************************************************************************
| BASIC LOADER
|******************************************************************************
| This function will load BASIC from ROM into RAM and jump to it.
ucLoadBasic:                | load BASIC into RAM and execute
    MOVEM.L %a0-%a6/%d0-%d7,%a7@-   | save all registers in case we make it back here
    .ifdef  debug
    debugPrint '0'
    .endif
    lea     %pc@(sBAS1a),%a4    | get pointer to header text string
    callSYS trapPutString
.startCopy:
    .ifdef  debug
    debugPrint '1'
    .endif
    lea     ROMBASIC,%a0                | get pointer to BASIC in ROM
    move.l  %a0,%d0                     | copy pointer for printing
    callSYS trapPutHexLong              | print pointer
    lea     %pc@(sBAS1b),%a4            | get pointer to next header string
    callSYS trapPutString               | print string
    lea     RAMBASIC,%a1                | get pointer to RAM above vector table
    move.l  %a1,%d0                     | copy pointer for printing
    callSYS trapPutHexLong              | print pointer
    lea     %pc@(sBAS1c),%a4            | get pointer to final header string
    callSYS trapPutString               | print string
    .ifdef  debug
    debugPrint '2'
    .endif
    lea     ROMBASIC,%a0                | re-load pointers because I dont know
    lea     RAMBASIC,%a1                | if they get clobbered by string print
    .ifdef  debug
    debugPrint '3'
    .endif
|    move.l  #(SIZBASIC>>2),%d0         | number of longwords to copy 
    move.l  #SIZBASIC,%d0               | number of bytes to copy
    .ifdef  debug
    movem.l %a0-%a6/%d0-%d7,%sp@-
    debugPrint '4'
    debugPrint '$'
    callSYS trapPutHexLong
    debugPrint 0xd
    debugPrint 0xa
    movem.l %sp@+,%a0-%a6/%d0-%d7
    .endif
    lsr.l   #2,%d0                      | number of longwords to copy
                                        | (NEED BETTER WAY TO GET THIS NUMBER)
    .ifdef  debug
    movem.l %a0-%a6/%d0-%d7,%sp@-
    debugPrint '5'
    debugPrint '$'
    callSYS trapPutHexLong
    debugPrint 0xd
    debugPrint 0xa
    movem.l %sp@+,%a0-%a6/%d0-%d7
    .endif
copyLoop:
    move.l  %a0@+,%a1@+                 | copy BASIC into RAM, one Longword at a time
    dbra    %d0,copyLoop                | keep copying until finished
    .ifdef  debug
    debugPrint '6'
    .endif
    lea     %pc@(sBAS2),%a4             | get pointer to verifying string
    .ifdef  debug
    debugPrint '7'
    .endif
    callSYS trapPutString               | print verifying string
.startVerify:
    .ifdef  debug
    debugPrint '8'
    .endif
    lea     ROMBASIC,%a0
    lea     RAMBASIC,%a1
    move.l  #SIZBASIC,%d0               | size of BASIC provided by linker
    lsr.l   #2,%d0
verifyLoop:
    move.l  %a0@+,%d1
    move.l  %a1@+,%d2
    CMP.L   %d1,%d2
    bne     vErrrr
    dbra    %d0,verifyLoop
.verifyGood:
    .ifdef  debug
    debugPrint '9'
    .endif
    lea     %pc@(sBAS3a),%a4            | get pointer to verify good string
    callSYS trapPutString
    move.l  startBasic,%d0              | start address provided by linker
    andi.l  #0x0000FFFF,%d0             | we only need the low word of this address
    lea     RAMBASIC,%a1                | pointer to start of BASIC in RAM
    lea     %a1@(0,%d0.l),%a1           | pointer to start of BASIC program
| we need base heap address in A0 and free RAM in D0
    lea     HEAPBASIC,%a0               | get bottom free memory after BASIC program
    move.l  %sp,%d0                     | get current stack pointer (top of free RAM)
    SUBI.L  #4,%d0                      | make room for our return address
    SUB.L   %a0,%d0                     | get current RAM free
| print some helpful information about what we are doing
    move.l  %a1,%sp@-                   | first, save the three parameters we need
    move.l  %d0,%sp@-
    move.l  %a0,%sp@-
    move.l  %sp@,%d0                    | get heap pointer
    callSYS trapPutHexLong              | print the heap pointer
    lea     %pc@(sBAS3b),%a4            | get the next header string
    callSYS trapPutString               | print it too
    move.l  %sp@(4),%d0                 | get the free memory size
    callSYS trapPutHexLong              | print it
    lea     %pc@(sBAS3c),%a4            | get the next header string
    callSYS trapPutString               | print it as well
    move.l  %sp@(8),%d0                 | finally get the program pointer
    callSYS trapPutHexLong              | print it
    lea     %pc@(sBAS3d),%a4            | now the last header string
    callSYS trapPutString               | print it
    move.l  %a0,%sp@+                   | restore the saved parameters
    move.l  %d0,%sp@+
    move.l  %a1,%sp@+
| enough printing stuff, jump to BASIC already
    jsr     %a1@                        | jump to BASIC in RAM
    MOVEM.L %a7@+,%a0-%a6/%d0-%d7       | by some miracle we have come back.
    RTS                                 | Restore registers and return

vErrrr:
| BASIC in RAM does not match BASIC in ROM
    lea     %pc@(sBASerr),%a4           | get pointer to error string
    callSYS trapPutString
    MOVEM.L %a7@+,%a0-%a7/%d0-%d7       | restore saved registers
    RTS                                 | and return to TSMON

sBAS1a:
    .ascii "Copying BASIC from $\0"
sBAS1b:
    .ascii " to $\0"
sBAS1c:
    .ascii " ... \0"
sBAS3a:
    .ascii "OK.\r\n"
    .ascii "Heap Pointer: $\0"
sBAS3b:
    .ascii ".\r\nFree Mem: $\0"
sBAS3c:
    .ascii ".\r\nBASIC Pointer: $\0"
sBAS3d:
    .ascii ".\r\nStarting BASIC ... \r\n\0"

|sBAS1:
|    .ascii "Loading BASIC ... \0\0"
sBAS2:
    .ascii "OK.\r\nVerifying BASIC ... \0\0"
|sBAS3:
|    .ascii "OK.\r\nStarting BASIC ... \r\n\0\0"
sBASerr:
    .ascii "Failed.\r\nUnable to run BASIC.\r\n\0\0"

    .even

|******************************************************************************
| 68030 CACHE FUNCTIONS
|******************************************************************************
| Enable 68030 cache

|; enable CPU cache
cacheEnable:
    move.l  %d0,%sp@-                       |; save working register
    move.l  #0x00000101,%d0                 |; enable data & instruction cache
    movec   %d0,%cacr                       |; write to cache control register
    move.l  %sp@+,%d0                       |; restore register
    rts

|; disable CPU cache
cacheDisable:
    move.l  %d0,%sp@-                       |; save working register
    moveq.l #0,%d0                          |; disable data & instruction cache
    movec   %d0,%cacr                       |; write to cache control register
    move.l  %sp@+,%d0                       |; restore register
    rts

|; user command for CPU cache enable
ucCEnable:
    move.l  %a4,%sp@-
    bsr     cacheEnable
    sysPrnt sCEN
    callSYS trapNewLine
    move.l  %sp@+,%a4
    rts

|; user command for CPU cache disable
ucCDisable:
    move.l  %a4,%sp@-
    bsr     cacheDisable
    sysPrnt sCDIS
    callSYS trapNewLine
    move.l  %sp@+,%a4
    rts

|; ucCEnable:
|;     MOVEM.L %a4/%d0,%a7@-     |; save working registers
|;     move.l  #0x00000101,%d0    |; enable data & instruction cache
|; |;    DC.L    $4e7b0002       |; movec D0,CACR
|;     movec   %d0,%cacr
|;     lea     %pc@(sCEN),%a4     |; get pointer to feedback string
|;     callSYS trapPutString
|;     callSYS trapNewLine
|;     MOVEM.L %a7@+,%d0/%a4     |; restore working registers
|;     RTS

|; |; Disable 68030 cache
|; ucCDisable:
|;     MOVEM.L %a4/%d0,%a7@-     |; save working registers
|;     EOR.L   %d0,%d0           |; disable data & instruction cache
|; |;    DC.L    $4e7b0002       |; movec %d0,CACR
|;     movec   %d0,%cacr
|;     lea     %pc@(sCDIS),%a4    |; get pointer to feedback string
|;     callSYS trapPutString
|;     callSYS trapNewLine
|;     MOVEM.L %a7@+,%d0/%a4     |; restore working registers
|;     RTS

sCEN:
    .ascii "CPU L1 Cache Enabled.\0\0"
sCDIS:
    .ascii "CPU L1 Cache Disabled.\0\0"

    .even

|******************************************************************************
| IDE+FAT DISK FUNCTIONS
|******************************************************************************
|;    .include    "ide.s"

|; check if disk is present.
|; return %d0.l = 0: no disk | 1: disk found
ideCheck:
    lea     ideStatusRO,%a0                 |; get status port pointer
    move.b  %a0@,%d0                        |; get status byte
    tst.b   %d0                             |; is it 0?
    bne     .ideCheckYes
    rts
.ideCheckYes:
    moveq.l #1,%d0
    rts

|; read a disk sector
|; parameters:
|;  d0.l:   LBA
|;  a0.l:   buffer pointer
|; returns:
|;  d0.l    0: error | 512: success
ideReadSect:
    movem.l %a0-%a2/%d1-%d4,%sp@-
    bsr     cacheDisable                    |; disable cache before reading disk
    |; debug print stuff
    movem.l %a0/%d0,%sp@-                   |; save parameters
    sysPrnt sReadSectSectHead
    move.l  %sp@(0),%d0
    callSYS trapPutHexLong
    callSYS trapNewLine
    sysPrnt sReadSectBufHead
    move.l  %sp@(4),%d0
    callSYS trapPutHexLong
    callSYS trapNewLine
    movem.l %sp@+,%a0/%d0                   |; restore parameters

    |; initialize read sector command
    move.l  %d0,%d1                         |; copy LBA to work with it
    andi.l  #0x0fffffff,%d1                 |; mask 28-bit LBA
    ori.l   #0xe0000000,%d1                 |; enable LBA mode
    lea     ideLBALLRW,%a1                  |; get first LBA reg pointer
    move.b  %d1,%a1@                        |; send first byte of LBA
    ror.l   #8,%d1                          |; shift in next byte
    lea     ideLBALHRW,%a1                  |; get next LBA reg pointer
    nop                                     |; enforce IDE PIO 0 cycle timing
    nop
    move.b  %d1,%a1@
    ror.l   #8,%d1
    lea     ideLBAHLRW,%a1
    nop
    nop
    move.b  %d1,%a1@
    ror.l   #8,%d1
    lea     ideLBAHHRW,%a1
    nop
    nop
    move.b  %d1,%a1@
    lea     ideSectorCountRW,%a1            |; get sector count reg pointer
    nop                                     |; enforce IDE cycle timing
    nop
    nop
    move.b  #1,%a1@                         |; set transfer size to 1 sector
    lea     ideCommandWO,%a1                |; get command reg pointer
    nop                                     |; enforce IDE cycle timing
    nop
    nop
    move.b  #0x20,%a1@                      |; send read command

    |; wait for disk not busy, ready, & data ready
    |; debug print stuff
    movem.l %a0/%d0,%sp@-                   |; save parameters
    sysPrnt sReadSectWaitReady
    callSYS trapNewLine
    movem.l %sp@+,%a0/%d0                   |; restore parameters

    lea     ideStatusRO,%a1                 |; get pointer to status
    lea     ideDataRW,%a2                   |; get pointer to IDE data port
.ideReadSectLp1Setup:
    move.l  #0x000007ff,%d2                 |; set up wait limit
.ideReadSectLp1:
    move.b  %a1@,%d1                        |; check status
    btst.b  #7,%d1                          |; check busy bit
    bne     .ideReadSectLp1count            |; if busy set, goto limit
    btst.b  #6,%d1                          |; check disk ready bit
    beq     .ideReadSectLp1count            |; if not set, goto limit
    btst.b  #3,%d1                          |; check data ready bit
    beq     .ideReadSectLp1count            |; if not set, goto limit
    btst.b  #0,%d1                          |; check error bit
    bne     .ideReadSectErrorSet            |; if set, goto disk error
    bra     .ideReadSectReady               |; ready to read
.ideReadSectLp1count:
    subq.l  #1,%d2                          |; decrement counter
    cmp.l   #0,%d2
    ble     .ideReadSectLp1Expired          |; loop expired
    bra     .ideReadSectLp1                 |; else continue loop

.ideReadSectReady:                          |; main read loop
    move.w  #255,%d3                        |; set up sector word counter
.ideReadSectReadLp:
    move.w  %a2@,%d0                        |; read word from disk
    move.w  %d0,%a0@+                       |; save word to buffer & incr ptr
    dbra    %d3,.ideReadSectReadLp          |; loop until entire sector read

.ideReadSectDone:
    sysPrnt sReadSectDone
    callSYS trapNewLine
    move.l  #512,%d0                        |; set success

.ideReadSectEnd:                            |; clean up and return
    bsr     cacheEnable                     |; re-enable cache
    movem.l %sp@+,%a0-%a2/%d1-%d4           |; restore registers
    rts

.ideReadSectLp1Expired:
    move.l  %d1,%sp@-                       |; save status byte
    sysPrnt sReadSectTimeout
    move.l  %sp@+,%d0                       |; retrieve status byte
    callSYS trapPutHexByte
    callSYS trapNewLine
.ideReadSectPrintErrByte:
    sysPrnt sReadSectErrorByte
    lea     ideErrorRO,%a1                  |; get pointer to error reg
    move.b  %a1@,%d0
    callSYS trapPutHexByte
    callSYS trapNewLine
    moveq.l #0,%d0                          |; return 0 on error
    bra     .ideReadSectEnd                 |; end 

.ideReadSectErrorSet:                       |; print header for disk error
    sysPrnt sReadSectErrorHead
    callSYS trapNewLine
    bra     .ideReadSectPrintErrByte        |; then print error byte & end

sReadSectSectHead:  .ascii  "Reading sector: \0\0"
sReadSectBufHead:   .ascii  "Using buffer: \0\0"
sReadSectWaitReady: .ascii  "Waiting for disk ... \0\0"
sReadSectTimeout:   .ascii  "Timeout waiting for disk. Status byte: \0\0"
sReadSectErrorByte: .ascii  "Disk error byte: \0\0"
sReadSectErrorHead: .ascii  "Disk reported error: \0\0"
sReadSectDone:      .ascii  "Disk read complete.\0\0"

    .even

|; user command to check for disk presence
ucCHKD:
    bsr     ideCheck
    tst.b   %d0
    bne     .ucCHKDyes
    sysPrnt sDskChkNo
    rts
.ucCHKDyes:
    sysPrnt sDskChkYes
    rts

sDskChkYes: .ascii "Disk present.\r\n?\0\0"
sDskChkNo:  .ascii "Disk not found.\r\n?\0\0"
    .even

|; user command to reset IDE disk
ucDRST:
    lea     ideDevControlWO,%a0             |; get pointer to control port
    move.b  #0x0E,%a0@                      |; reset & disable interrupts
    move.w  0x7f,%d0                        |; set up delay
.ucDRSTlp:
    dbra    %d0,.ucDRSTlp                   |; reset delay loop
    move.b  #0x0A,%a0@                      |; finish reset
    sysPrnt sDskRst
    callSYS trapNewLine
    rts

sDskRst:    .ascii "Disk reset complete.\0\0"
    .even

|; user command to print disk sector contents to console
ucSECT:
    movem.l %a0-%a1/%d0-%d3/%d7,%sp@-       |; save working registers
    callSYS trapGetParam                    |; get sector number as parameter
    tst.b   %d7                             |; test for input error
    bne     .ucSECTerr1                     |; exit if error

    lea     DATA,%a0                        |; get heap pointer
    lea     %a0@(dskBUF),%a0                |; get pointer to disk buffer
    
    move.l  %d0,%sp@-                       |; save sector number
    |; %d0.l = LBA
    |; %a0.l = buffer
    bsr     ideReadSect                     |; read sector

    tst.l   %d0                             |; 0 on error
    beq     .ucSECTerr2

    move.l  %sp@+,%d0                       |; restore sector number
    move.l  %d0,%d3                         |; copy sector number
    clr.b   %d2                             |; clear line count
    lea     DATA,%a1                        |; get heap pointer again
    lea     %a1@(dskBUF),%a1                |; get disk buffer pointer
.ucSECT1:
    clr.b   %d1                             |; clear word count
    callSYS trapNewLine                     |;
.ucSECT2:
    move.l  %d3,%d0                         |; copy sector to working reg
    lsl.l   #1,%d0                          |; divide sector by 2 to get base address
    btst    #4,%d2                          |; check if second half of buffer
    beq     .ucSECT3                        |; if no, then skip ahead
    ori.l   #1,%d0                          |; if second half, set low bit of base address
.ucSECT3:
    callSYS trapPutHexLong                  |; print base address
    move.b  %d2,%d0                         |; copy line count to working register
    lsl.b   #4,%d0                          |; shift by 4 to get low byte of address
    callSYS trapPutHexByte                  |; print low byte of base address
.ucSECT4:
    callSYS trapPutSpace                    |;
    move.w  %a1@+,%d0                       |; get next word from buffer
    callSYS trapPutHexWord                  |; and print it
    addi.b  #1,%d1                          |; increment word counter
    cmp.b   #8,%d1                          |; check for end of line
    bne     .ucSECT4                        |; continue line
    addi.b  #1,%d2                          |; else increment line counter
    cmp.b   #0x20,%d2                       |; check for end of buffer
    bne     .ucSECT1                        |; if not end, start new line
.ucSECTend:
    movem.l %sp@+,%a0-%a1/%d0-%d3/%d7       |; restore working registers
    rts

.ucSECTerr1:
    lea     %pc@(sINPUTerr),%a4             |; input error string pointer
    callSYS trapPutString                   |; print error
    bra     .ucSECTend                      |; exit function
.ucSECTerr2:
    add.l   #4,%sp                          |; pop off previously saved d0
    lea     %pc@(sDSKRDerr),%a4             |; unknown error string pointer
    callSYS trapPutString
    bra     .ucSECTend


|; user command to load disk sector 0 into memory & attempt to run it
ucBOOT:
    movem.l %a0-%a6/%d0-%d7,%sp@-           |; save all registers before 
                                            |; jumping to user program
    sysPrnt sBootStart
    lea     DATA,%a0                        |; get bss pointer
    move.l  %sp,%a0@(STACK_SAVE)            |; save stack pointer
    lea     %a0@(dskBUF),%a0                |; get disk buffer pointer
    clr.l   %d0                             |; set D0 for sector 0
    bsr     ideReadSect                     |; read boot sector
    cmp.l   #0,%d0                          |; check for error
    beq     .ucBOOTerr                      |; jump on read error
    jsr     %a0@                            |; else jump to user program
    |; this is where we'll end up if the user program returns
    lea     DATA,%a0                        |; get bss pointer
    move.l  %a0@(STACK_SAVE),%sp            |; restore stack pointer
    movem.l %sp@+,%a0-%a6/%d0-%d7           |; restore registers
    rts                                     |; return to monitor
.ucBOOTerr:
    sysPrnt sBootErr
    callSYS trapNewLine
    movem.l %sp@+,%a0-%a6/%d0-%d7           |; restore registers
    rts

sBootStart: .ascii  "Booting from disk ...\r\n\0\0"
sBootErr:   .ascii  "Error reading disk boot sector.\0\0"
    .even

|; check disk error and print helpful message
|; PARAMETERS
|;   D0 - IDE error register
dskErr:
    btst    #7,%d0
    bne     .dskErr6
    lea     %pc@(sDSKerr7),%a4              | get address of error message
    bra     .dskErrEnd                      | and jump to end
.dskErr6:
    btst    #6,%d0
    bne     .dskErr5
    lea     %pc@(sDSKerr6),%a4              | get address of error message
    bra     .dskErrEnd                      | and jump to end
.dskErr5:
    btst    #5,%d0
    bne     .dskErr4
    lea     %pc@(sDSKerr5),%a4              | get address of error message
    bra     .dskErrEnd                      | and jump to end
.dskErr4:
    btst    #4,%d0
    bne     .dskErr3
    lea     %pc@(sDSKerr4),%a4              | get address of error message
    bra     .dskErrEnd                      | and jump to end
.dskErr3:
    btst    #3,%d0
    bne     .dskErr2
    lea     %pc@(sDSKerr3),%a4              | get address of error message
    bra     .dskErrEnd                      | and jump to end
.dskErr2:
    btst    #2,%d0
    bne     .dskErr1
    lea     %pc@(sDSKerr2),%a4              | get address of error message
    bra     .dskErrEnd                      | and jump to end
.dskErr1:
    btst    #1,%d0
    bne     .dskErr0
    lea     %pc@(sDSKerr1),%a4              | get address of error message
    bra     .dskErrEnd                      | and jump to end
.dskErr0:
    btst    #0,%d0
    bne     .dskErrN
    lea     %pc@(sDSKerr0),%a4              | get address of error message
    bra     .dskErrEnd                      | and jump to end
.dskErrN:
    lea     %pc@(sDSKRDerr),%a4
.dskErrEnd:
    callSYS trapPutString                   | print selected error message
    rts                                     | and return

sCHKDy:	    .ascii "Disk found.\r\n\0\0"
sCHKDn:	    .ascii "No disk inserted.\r\n\0\0"
sLISTsp:    .ascii "     \0\0"
sLISThead:	.ascii "File Name        Cluster  File Size\0\0"
sINPUTerr:	.ascii "Input error.\r\n\0\0"
sDSKRDerr:	.ascii "Unknown disk read error.\r\n\0\0"
sDSKRdToErr: .ascii "Timeout waiting for disk.\r\n\0\0"
sDSKRDend:  .ascii "Disk read complete.\r\n\0\0"

sDSKerr7:	.ascii "Bad block in requested disk sector.\r\n\0\0"
sDSKerr6:	.ascii "Uncorrectable data error in disk.\r\n\0\0"
sDSKerr3:
sDSKerr5:	.ascii "Unspecified Removable Media error.\r\n\0\0"
sDSKerr4:	.ascii "Requested disk sector could not be found.\r\n\0\0"
sDSKerr2:	.ascii "Disk command aborted.\r\n\0\0"
sDSKerr1:	.ascii "Disk track 0 not found.\r\n\0\0"
sDSKerr0:	.ascii "Disk data address mark not found.\r\n\0\0"

sUsectRd:   .ascii "Reading Sector: \0\0"
sUsectErr1: .ascii "Sector read was not successful.\r\n\0\0"
sUsectErr2: .ascii "Timed out reading from disk.\r\n\0\0"

sBOOTret:   .ascii "\r\n\r\nProgram Exited\r\n\0\0"

    .even


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

|;***************************************************************************
|; global variables (BSS section) in memory
    .section bss,"w"

    |; some global variables for holding boot sector data for easy reference
    |; these are all reserved as longwords to make it easier to load them for
    |; the kind of maths we'll need to do with them later
globFat:                                    |; use to init a ptr to this table
    |; these are from the boot block itself
globFatValid:               ds.l    1       |; set to 0xAA55 when table loaded
globFatBpbBytesPerSect:     ds.l    1       |; word
globFatBpbSectPerClust:     ds.l    1       |; byte
globFatBpbReservedSects:    ds.l    1       |; word
globFatBpbNumFats:          ds.l    1       |; byte
globFatBpbRootDirEntries:   ds.l    1       |; word
globFatBpbTotalSectors:     ds.l    1       |; long
globFatBpbSectPerFat:       ds.l    1       |; word
globFatBpbSectPerTrack:     ds.l    1       |; word
globFatBpbNumHiddenSect:    ds.l    1       |; long
    |; these are calculated, but used frequently
globFatRootDirLBA:          ds.l    1       |; SectPerFat*NumFats+ReservedSects
globFatRootDirSize:         ds.l    1       |; RootDirEntries*32
globFatDataStartLBA:        ds.l    1       |; RootDirLBA+((RootDirSize+511)>>9)
globFatFATsizeInSects:             ds.l    1       |; SectPerFat+ReservedSects




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

    dc.B    8,5
    .ascii "BOOTRAW "
    dc.L    ucBOOT

    dc.b    8,5
    .ascii  "BOOTFILE"
    dc.l    ucBOOTFILE

    dc.b    8,3
    .ascii  "EXECUTE "
    dc.l    ucEXECFILE

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
    .ascii "BOOTRaw                        - Execute boot block from disk\r\n"
    .ascii "BOOTFile                       - Run \"BOOT.BIN\" from FAT16 Disk\r\n"
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
| IDE DISK FUNCTIONS
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
    |;bsr     cacheDisable                    |; disable cache before reading disk

    |; debug print stuff
    |; movem.l %a0/%d0,%sp@-                   |; save parameters
    |; sysPrntI "ideReadSect: Sector: "
    |; move.l  %sp@(0),%d0
    |; callSYS trapPutHexLong
    |; sysPrntI "; Buffer: "
    |; move.l  %sp@(4),%d0
    |; callSYS trapPutHexLong
    |; callSYS trapNewLine
    |; movem.l %sp@+,%a0/%d0                   |; restore parameters
    |; end debug print stuff

    |; initialize read sector command
    move.l  %d0,%d1                         |; copy LBA to work with it
    andi.l  #0x0fffffff,%d1                 |; mask 28-bit LBA
    ori.l   #0xe0000000,%d1                 |; enable LBA mode
    lea     ideLBALLRW,%a1                  |; get first LBA reg pointer
    move.b  %d1,%a1@                        |; send first byte of LBA
    ror.l   #8,%d1                          |; shift in next byte
    lea     ideLBALHRW,%a1                  |; get next LBA reg pointer
    move.b  %d1,%a1@
    ror.l   #8,%d1
    lea     ideLBAHLRW,%a1
    move.b  %d1,%a1@
    ror.l   #8,%d1
    lea     ideLBAHHRW,%a1
    move.b  %d1,%a1@
    lea     ideSectorCountRW,%a1            |; get sector count reg pointer
    move.b  #1,%a1@                         |; set transfer size to 1 sector
    lea     ideCommandWO,%a1                |; get command reg pointer
    move.b  #0x20,%a1@                      |; send read command

    |; wait for disk not busy, ready, & data ready
    |; debug print stuff
    movem.l %a0/%d0,%sp@-                   |; save parameters
    |; sysPrntI "ideReadSect: Waiting for disk ... \r\n"
    movem.l %sp@+,%a0/%d0                   |; restore parameters

    lea     ideStatusRO,%a1                 |; get pointer to status
    lea     ideDataRW,%a2                   |; get pointer to IDE data port
.ideReadSectLp1Setup:
    move.l  #0x00007fff,%d2                 |; set up wait limit
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
    |; sysPrntI "ideReadSect: Disk sector read complete.\r\n"
    move.l  #512,%d0                        |; set success

.ideReadSectEnd:                            |; clean up and return
    |;bsr     cacheEnable                     |; re-enable cache
    movem.l %sp@+,%a0-%a2/%d1-%d4           |; restore registers
    rts

.ideReadSectLp1Expired:
    sysPrntIreg "ideReadSect: Timeout waiting for disk. Status: " %d1
    moveq.l #0,%d0                          |; return 0 on error
    bra     .ideReadSectEnd                 |; end 

.ideReadSectErrorSet:
    move.b  ideErrorRO,%d0
    sysPrntIreg "ideReadSect: Disk reported error: " %d0
    moveq.l #0,%d0                          |; return 0 on error
    bra     .ideReadSectEnd                 |; end 

    .even

|; read multiple disk sectors
|; parameters:
|;  d0.l:   LBA
|;  d1.l:   number of sectors to read
|;  a0.l:   buffer pointer
|; returns:
|;  d0.l    0: error | bytes read: success
ideReadSectMult:
    |; debug print
    movem.l %a0/%d0-%d1,%sp@-
    exg     %d0,%d1                         |; swap param registers
    sysPrntI "ideReadSectMult: Reading "
    callSYS  trapPutHexLong
    exg     %d0,%d1                         |; swap them back
    sysPrntIreg " sectors starting at LBA: " %d0
    movem.l %sp@+,%a0/%d0-%d1
    |; end debug print
    movem.l %a0/%d1-%d3,%sp@-               |; save working registers
    eor.l   %d3,%d3                         |; clear byte count register
    move.l  %d0,%d2                         |; save initial LBA
.ideReadMultLp:
    subq.l  #1,%d1                          |; decrement counter
    cmp.l   #0,%d1                          |; check for end of loop
    beq     .ideReadMultEnd                 |; exit loop when done
    bsr     ideReadSect                     |; read a sector of data
    tst.l   %d0                             |; check for read error
    beq     .ideReadMultReadErr             |; exit on error
    add.l   %d0,%d3                         |; increment byte count
    add.l   %d0,%a0                         |; increment pointer
    addq.l  #1,%d2                          |; increment LBA
    move.l  %d2,%d0                         |; get LBA ready for next read
    bra     .ideReadMultLp                  |; continue loop
.ideReadMultEnd:
    sysPrntIreg "ideReadSectMult: Done reading from disk. Total bytes read: " %d3
    move.l  %d3,%d0                         |; set return value
.ideReadMultExit:
    movem.l %sp@+,%a0/%d1-%d3               |; restore registers
    rts

.ideReadMultReadErr:
    sysPrntI "ideReadSectMult: Error reading multiple disk sectors.\r\n"
    eor.l   %d0,%d0                         |; return 0 on error
    bra     .ideReadMultExit                |; jump to end


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
sINPUTerr:	.ascii "Input error.\r\n\0\0"
sDSKRDerr:	.ascii "Unknown disk read error.\r\n\0\0"
    .even

    .even


|;*****************************************************************************
|; UTILITY FUNCTIONS
|;*****************************************************************************

|; Memory Compare
|; Compares two blocks of memory to see if they match
|;  Parameters:
|;      %a0.l   pointer to memory block 1
|;      %a1.l   pointer to memory block 2
|;      %d0.l   number of bytes to compare
|;  Returns:
|;      %d0.l   0: match
memCmp:
    movem.l %a0-%a1/%d1,%sp@-               |; save the pointers
    cmp.l   #0,%d0                          |; if count is 0, then return
    beq.s   .memCmpYes                      |;
    subq.l  #1,%d0                          |; pre-decr counter so no overflow
.memCmpLp:
    cmp.l   #0,%d0                          |; check for end of loop
    beq.s   .memCmpYes                      |; jump to end if done
    move.b  %a0@+,%d1                       |; get first byte, incr ptr
    cmp.b   %a1@+,%d1                       |; compare 2nd byte, incr ptr
    bne.s   .memCmpNo                       |; end loop if no match
    subq.l  #1,%d0                          |; decrement byte counter
    bra.s   .memCmpLp

.memCmpYes:
    moveq.l #0,%d0                          |; return 0 for match
    movem.l %sp@+,%a0-%a1/%d1               |; restore registers
    rts

.memCmpNo:
    |; debug print
    |; sysPrntI "memCmp: Mismatch at: "
    |; callSYS trapPutHexLong
    |; sysPrntI "; Pointer 1: "
    |; move.l  %a0,%d0
    |; callSYS trapPutHexLong
    |; sysPrntI "; Pointer 2: "
    |; move.l  %a1,%d0
    |; callSYS trapPutHexLong
    |; callSYS trapNewLine
    |; end debug print

    move.l  %a0@,%d0                        |; return difference
    sub.l   %a1@,%d0                        |; between nonmatching values
    movem.l %sp@+,%a0-%a1/%d1               |; restore registers
    rts



|;*****************************************************************************
|; FAT16 TRAVERSING
|;*****************************************************************************

|; structure of the boot block
    .equ    fatBpbJmp,               0
    .equ    fatBpbOem,               3
    .equ    fatBpbBytesPerSect,     11
    .equ    fatBpbSectPerClust,     13
    .equ    fatBpbResvSect,         14
    .equ    fatBpbNumFats,          16
    .equ    fatBpbRootDirEntries,   17
    .equ    fatBpbTotalSectors16,   19
    .equ    fatBpbMediaDesc,        21
    .equ    fatBpbSectPerFat,       22
    .equ    fatBpbSectPerTrack,     24
    .equ    fatBpbNumHeads,         26
    .equ    fatBpbNumHiddenSect,    28
    .equ    fatBpbTotalSectors32,   32
    .equ    fatBpbDriveNum,         36
    .equ    fatBpbReserved,         37
    .equ    fatBpbSignature,        38
    .equ    fatBpbVolumeID,         39
    .equ    fatBpbVolumeLabel,      43
    .equ    fatBpbSysIdStr,         54
    .equ    fatBpbBootLoader,       62
    .equ    fatBpbMagicNum,        510

|; structure of a root directory entry
    .equ    fatRootFilename,         0
    .equ    fatRootExtension,        8
    .equ    fatRootAttribute,        9
    .equ    fatRootStartCluster,    26
    .equ    fatRootFilesize,        28


|; globFat:                                    |; use to init a ptr to this table
|;     |; these are from the boot block itself
|; globFatValid                ds.l    1       |; set to 0xAA55 when table loaded
|; globFatBpbBytesPerSect:     ds.l    1       |; word
|; globFatBpbSectPerClust:     ds.l    1       |; byte
|; globFatBpbReservedSects:    ds.l    1       |; word
|; globFatBpbNumFats:          ds.l    1       |; byte
|; globFatBpbRootDirEntries:   ds.l    1       |; word
|; globFatBpbTotalSectors:     ds.l    1       |; long
|; globFatBpbSectPerFat:       ds.l    1       |; word
|; globFatBpbSectPerTrack:     ds.l    1       |; word
|; globFatBpbNumHiddenSect:    ds.l    1       |; long
|;     |; these are calculated, but used frequently
|; globFatRootDirLBA:          ds.l    1       |; SectPerFat*NumFats+ReservedSects
|; globFatRootDirSize:         ds.l    1       |; RootDirEntries*32
|; globFatDataStartLBA:        ds.l    1       |; RootDirLBA+((RootDirSize+511)>>9)
|; globFatFATsizeInSects:      ds.l    1       |; SectPerFat+ReservedSects


|; parse FAT header and save to global variables for later use
|; checks magic number and system ID string to confirm FAT16
|;  Parameters:
|;      %a0.l   pointer to boot block in memory
fatParseHeader:
    movem.l %a0-%a1/%d0-%d1,%sp@-           |; save registers
    move.l  %a0,%sp@-                       |; save our pointer
    sysPrntI "fatParseHeader: Parsing FAT16 filesystem header ...\r\n"
    lea     globFat,%a2                     |; get global var ptr
    eor.l   %d0,%d0                         |; clear regs
    move.l  %d0,%d1                         |; 
    move.w  %a0@(fatBpbMagicNum),%d0        |; get magic number
    cmp.w   #0x55AA,%d0                     |; check for match
    bne     .fatParseHeaderBadVolMag        |; no match
    move.l  %d0,globFatValid                |; temp store in RAM
    lea     %a0@(fatBpbSysIdStr),%a0        |; get pointer to sys id
    lea     sFatSysId,%a1                   |; get pointer to match
    moveq.l #8,%d0                          |; check 8 bytes
    bsr     memCmp                          |; compare strings
    tst     %d0                             |; check for match
    bne     .fatParseHeaderBadVolF16        |; exit if no match
    move.l  %sp@+,%a0                       |; restore pointer

    ldWordLittle %a0, fatBpbBytesPerSect    |; 
    move.l  %d0,globFatBpbBytesPerSect
    sysPrntIreg "fatParseHeader: FAT Bytes per Sector: " %d0

    move.l  %d1,%d0                         |; clear reg d0
    move.b  %a0@(fatBpbSectPerClust),%d0
    move.l  %d0,globFatBpbSectPerClust
    sysPrntIreg "fatParseHeader: FAT Sectors per Cluster: " %d0

    ldWordLittle %a0, fatBpbResvSect
    move.l  %d0,globFatBpbReservedSects
    sysPrntIreg "fatParseHeader: FAT Reserved Sectors: " %d0

    move.l  %d1,%d0
    move.b  %a0@(fatBpbNumFats),%d0
    move.l  %d0,globFatBpbNumFats
    sysPrntIreg "fatParseHeader: FAT Number of FATS: " %d0

    ldWordLittle %a0, fatBpbRootDirEntries
    move.l  %d0,globFatBpbRootDirEntries
    sysPrntIreg "fatParseHeader: FAT Number of Root Directory Entries: " %d0

    tst.w   %a0@(fatBpbTotalSectors16)
    beq.s   .fatParseHeadTotSectLong
    ldWordLittle %a0, fatBpbTotalSectors16
    move.l  %d0,globFatBpbTotalSectors
    bra     .fatParseHeadTotSectDone
.fatParseHeadTotSectLong:
    ldLongLittle %a0, fatBpbTotalSectors32
    move.l  %d0,globFatBpbTotalSectors
.fatParseHeadTotSectDone: 
    sysPrntIreg "fatParseHeader: FAT Total Sectors: " %d0

    ldWordLittle %a0, fatBpbSectPerFat
    move.l  %d0,globFatBpbSectPerFat
    sysPrntIreg "fatParseHeader: FAT Sectors per FAT: " %d0

    ldWordLittle %a0, fatBpbSectPerTrack
    move.l  %d0,globFatBpbSectPerTrack
    sysPrntIreg "fatParseHeader: FAT Sectors per Track: " %d0

    ldLongLittle %a0, fatBpbNumHiddenSect
    move.l  %d0,globFatBpbNumHiddenSect
    sysPrntIreg "fatParseHeader: FAT Number of Hidden Sectors: " %d0

    |; now move on to the values that need to be calculated

    |; globFatFATsizeInSects:             SectPerFat*NumFats
    move.l  globFatBpbSectPerFat,%d0
    move.l  globFatBpbNumFats,%d1
    mulu.w  %d1,%d0
    move.l  %d0,globFatFATsizeInSects
    sysPrntIreg "fatParseHeader: FAT Calculated Sector Size of FAT: " %d0

    |; globFatRootDirLBA:          ReservedSects+FATsize
    move.l  globFatFATsizeInSects,%d0
    add.l   globFatBpbReservedSects,%d0
    move.l  %d0,globFatRootDirLBA
    sysPrntIreg "fatParseHeader: FAT Calculated LBA of Root Directory: " %d0

    |; globFatRootDirSize:         RootDirEntries*32
    move.l  globFatBpbRootDirEntries,%d0
    lsl.l   #5,%d0
    move.l  %d0,globFatRootDirSize
    sysPrntIreg "fatParseHeader: FAT Calculated Root Directory Size: " %d0

    |; globFatDataStartLBA:        RootDirLBA+RootDirSize
    move.l  globFatRootDirSize,%d0          |; root dir size in bytes
    lsr.l   #8,%d0                          |; divide by 512 to get root dir
    lsr.l   #1,%d0                          |; root dir size in sectors
    add.l   globFatRootDirLBA,%d0           |; add to root dir start LBA
    move.l  %d0,globFatDataStartLBA
    sysPrntIreg "fatParseHeader: FAT Calculated Start of Data LBA: " %d0

    |; clean up and exit
    move.l  globFatValid,%d0                |; get data valid marker
    rol.w   #8,%d0                          |; mark header data as valid
    move.l  %d0,globFatValid                |; save data valid marker

    sysPrntI "fatParseHeader: Done.\r\n"

    movem.l %sp@+,%a0-%a1/%d0-%d1           |; restore registers
    rts
    
.fatParseHeaderBadVolMag:
    sysPrntIreg "fatParseHeader: Bad magic number: " %d0
    bra     .fatParseHeaderBadVol
.fatParseHeaderBadVolF16:
    sysPrntIreg "fatParseHeader: Bad system ID. Pointer: " %a0
.fatParseHeaderBadVol:
    addq.l  #4,%sp                          |; remove ptr from stack
    move.l  #0,globFatValid                 |; clear valid word
    sysPrnt sFatBadVol                      |; print error
    callSYS trapNewLine
    movem.l %sp@+,%a0-%a1/%d0-%d1           |; restore registers
    rts

sFatBadVol:             .ascii  "Unknown disk format\0"
sFatSysId:              .ascii  "FAT16   \0"
    .even


|; read FAT header block, and parse for later user
|;  Parameters:
|;      --
|;  Returns:
|;      %d0.l   0: Success | else: error
|;      %a0.l   pointer to dskBuf if successful, else 0
fatReadHeader:

    sysPrntI "fatReadHeader: Checking for disk ... "
    bsr     ideCheck                        |; check if disk present
    tst.l   %d0                             |; returns 1 if disk found
    beq     .fatReadHeaderErrNoDisk         |; exit if no disk
    sysPrntI "Disk found.\r\n"

    sysPrntI "fatReadHeader: Reading disk header sector ... \r\n"
    lea     dskBUF,%a0                      |; get disk buffer pointer
    moveq.l #0,%d0                          |; get sector 0
    bsr     ideReadSect                     |; read sector 0
    sysPrntIreg "fatReadHeader: Reading disk header sector returned status " %d0
    tst.l   %d0                             |; returns 0 on error
    beq     .fatReadHeaderErrRead           |; exit if read error
    sysPrntI "fatReadHeader: Finished reading disk header sector.\r\n"

    sysPrntI "fatReadHeader: Sending disk header for parsing ... \r\n"
    bsr     fatParseHeader                  |; parse header
    move.l  globFatValid,%d0                |; check for valid header data
    sysPrntIreg "fatReadHeader: Got back header: " %d0
    cmp.w   #0xaa55,%d0                     |; compare with magic number
    bne     .fatReadHeaderErrBadVol         |; exit if not FAT16 volume
    sysPrntI "fatReadHeader: Disk header parsing completed successfully.\r\n"

    moveq.l #0,%d0
    rts

.fatReadHeaderErrNoDisk:
    sysPrntI "fatReadHeader: No disk found.\r\n"
    moveq.l #1,%d0
    movea.l #0,%a0
    rts

.fatReadHeaderErrRead:
    sysPrntI "fatReadHeader: Error reading disk header sector.\r\n"
    moveq.l #2,%d0
    movea.l #0,%a0
    rts

.fatReadHeaderErrBadVol:
    sysPrntI "fatReadHeader: Could not find FAT16 signature in disk header.\r\n"
    moveq.l #3,%d0
    movea.l #0,%a0
    rts


|; Search root directory for a file
|; loads disk sector 0 into dskBUF and parses disk header data
|; then loads the root directory & FATs into ram starting at RAMBASIC
|;  Parameters:
|;      %a0.l   pointer to filename string
|;  Returns:
|;      %d0.l   cluster if found | 0 on error
|;      %d1.l   filesize if found | 0 on error
|;      %a0.l   pointer to filesystem data if successful, else 0
fatFindFileStart:
    sysPrntI "fatFindFileStart: Starting file search function ...\r\n"
    move.l  %a0,%sp@-                       |; save filename pointer
    bsr     fatReadHeader                   |; read disk header data
    tst.l   %d0                             |; returns 0 on success
    bne     .fatFindFileErrHeader           |; exit on error

    |; next we're going to read the entire root directory & FAT into memory
    sysPrntI "fatFindFileStart: File system header read & parsed.\r\n"
    sysPrntI "fatFindFileStart: Loading root directory & File Allocation Table.\r\n"
                                            |; d0 should already be 0
    move.l  globFatDataStartLBA,%d1         |; number of sectors to load
    lea     RAMBASIC,%a0                    |; pointer to data buffer
    bsr     ideReadSectMult                 |; read file system
    tst.l   %d0                             |; returns 0 on error
    beq     .fatFindFileErrFileSystem       |; exit on error

    sysPrntI "fatFindFileStart: Directory & FAT loaded. Searching directory for file.\r\n"
    |; a0 points to start of buffer we just loaded file system into
    |; root directory starts at the end of the ReservedSectors & FATs region
    |; (RootDirLBA*512)+BufferPointer
    move.l  globFatRootDirLBA,%d0           |;
    lsl.l   #8,%d0                          |;
    lsl.l   #1,%d0                          |;
    add.l   %a0,%d0                         |;
    move.l  %d0,%a2                         |; pointer to root dir table

    |; search the root directory
    eor.l   %d2,%d2                         |; d2 is directory entry offset

    move.l  globFatBpbRootDirEntries,%d3    |; number of root dir entries
    sub.l   #1,%d3
    eor.l   %d1,%d1                         |; d1 is loop counter
    move.l  %d1,%d4                         |; clear d4 also

    move.l  %sp@+,%a1                       |; get search filename pointer

    sysPrntIreg "fatFindFileStart: Max number of directory entries:         " %d3
    sysPrntIreg "fatFindFileStart: Directory search filename pointer:       " %a1
    sysPrntIreg "fatFindFileStart: Directory search pointer to buffer:      " %a0
    sysPrntIreg "fatFindFileStart: Directory search pointer to directory:   " %a2

.fatFindFileStartSearchLp:
    moveq.l #11,%d0                         |; filename+extension length
    lea     %a2@(fatRootFilename,%d2.l),%a0 |; get pointer to entry's filename

    move.b  %a0@,%d4                        |; check first byte

    |; debug print
    |; sysPrntI "fatFindFileStart: Directory entry "
    |; exg     %d0,%d1
    |; callSYS trapPutHexLong
    |; exg     %d0,%d1
    |; exg     %d0,%a0
    |; sysPrntI " base pointer: "
    |; callSYS trapPutHexLong
    |; exg     %d0,%a0
    |; sysPrntIreg "; filename first byte: " %d4
    |; debug print

    cmp.b   #0,%d4                          |; #0 is end of search and means
    beq     .fatFindFileErrNotFound         |; the file is not here

    cmp.b   #0xE5,%d4                       |; #0xE5 means this entry is free
    beq     .fatFindFileStartSearchLpNext   |; skip to next entry
    
    bsr     memCmp                          |; check for filename match
    tst.l   %d0                             |; returns 0 on success
    beq     .fatFindFileStartFound          |; end loop if found

.fatFindFileStartSearchLpNext:
    add.l   #0x20,%d2                       |; point to next root dir entry
    add.l   #1,%d1                          |; increment loop counter
    |; sysPrntIreg "fatFindFileStart: Search loop: " %d1
    cmp.l   %d1,%d3                         |; compare with limit
    bne     .fatFindFileStartSearchLp       |; loop until max entry

    |; if we've made it to here, then the file was not found
    bra     .fatFindFileErrNotFound         |;

.fatFindFileStartFound:
    sysPrntI "fatFindFileStart: File found!\r\n"
    add.l   %d2,%a2                         |; update ptr to dir entry
    eor.l   %d0,%d0                         |; clear reg
    ldLongLittle %a2 fatRootFilesize        |; get filesize
    move.l  %d0,%d1                         |; return filesize in d1
    ldWordLittle %a2 fatRootStartCluster    |; get file start cluster
    lea     RAMBASIC,%a0                    |; return pointer to filesystem
    rts

.fatFindFileErrHeader:                      |; return existing error in d0
    sysPrntI "fatFindFileStart: Error searching for file.\r\n"
    addq.l  #4,%sp                          |; discard saved pointer
    movea.l #0,%a0                          |; return null pointer
    move.l  %a0,%d1
    rts

.fatFindFileErrFileSystem:
    sysPrntI "fatFindFileStart: File system error.\r\n"
    addq.l  #4,%sp                          |; discard saved pointer
    movea.l #0,%a0                          |; return null pointer
    moveq.l #4,%d0                          |; return error number
    move.l  %a0,%d1
    rts

.fatFindFileErrNotFound:
    sysPrntI "Specified file could not be found.\r\n"
    movea.l #0,%a0                          |; return null pointer
    moveq.l #5,%d0                          |; return error number
    move.l  %a0,%d1
    rts

|; Read file into memory
|; Calls all other fat file functions to find the specified file and read it
|; into memory 
|;  Parameters:
|;      %a0.l   pointer to filename string
|;  Returns:
|;      %d0.l   0: Success | Else error
|;      %d1.l   0: Error | Else byte size of file
|;      %a0.l   pointer to start of file buffer | 0 on error
fatLoadFile:
    sysPrntI "fatLoadFile: Starting file load operation ...\r\n"
    movem.l %a1-%a3/%d2-%d3,%sp@-           |; save working registers
    |; start by finding the file, if it exists
    bsr     fatFindFileStart                |; search for file start
    tst.l   %d0                             |; returns first cluster on success
    beq     .fatLoadFileErr                 |; returns 0 on error
    |; d0 has the file's starting cluster
    |; d1 has the filesize in bytes
    |; a0 has the filesystem buffer
    move.l  %d0,%d2                         |; copy starting cluster
    move.l  %d1,%d3                         |; copy filesize
    movea.l %a0,%a1                         |; copy filesystem pointer
    sysPrntIreg "fatLoadFile: Found starting cluster for file: " %d0

    |; get pointer to where file can be loaded into memory. This will follow
    |; the file system data, including header, FATs, and root directory
    move.l  globFatRootDirLBA,%d1           |; get Root Dir sector address
    lsl.l   #8,%d1                          |; mult by 512 to get bytesize
    lsl.l   #1,%d1
    add.l   globFatRootDirSize,%d1          |; add total size of root dir
    add.l   %d1,%a0                         |; add to filesystem pointer
    |; now a0 holds pointer to where file will be loaded into memory

    movea.l %a0,%a2                         |; copy start of file pointer
    move.l  globFatBpbSectPerClust,%d1      |; get number of sectors to copy

    move.l  globFatBpbReservedSects,%d0     |; number of reserved sectors
    lsl.l   #8,%d0                          |; mult by 512 to get byte ptr
    lsl.l   #1,%d0                          |;
    lea     %a1@(%d0.l),%a3                 |; pointer to start of FAT
    |; in this loop:
    |;  d0: starting LBA for the current cluster
    |;  d1: number of sectors per cluster (do not change)
    |;  d2: current cluster
    |;  d3: filesize (do not change)
    |;  a0: pointer to load this cluster's data into
    |;  a1: pointer to start of file system data (do not change)
    |;  a2: pointer to start of file data (do not change)
    |;  a3: pointer to start of FAT (do not change)
    sysPrntI "fatLoadFile: Traversing FAT to load all file clusters.\r\n"
    |;sysPrntIreg "fatLoadFile: Starting LBA for first cluster: " %d0
    sysPrntIreg "fatLoadFile: Number of sectors per cluster:  " %d1
    sysPrntIreg "fatLoadFile: Starting cluster for file:      " %d2
    sysPrntIreg "fatLoadFile: File size in bytes:             " %d3
    sysPrntIreg "fatLoadFile: File buffer pointer:            " %a0
    sysPrntIreg "fatLoadFile: Filesystem data pointer:        " %a1
    sysPrntIreg "fatLoadFile: File Allocation Table pointer:  " %a3
    
.fatLoadFileLp:
    |; check cluster to see if we're at end of file
    eor.l   %d0,%d0                         |; clear register
    move.w  %d2,%d0                         |; get cluster
    cmp.l   #1,%d0                          |; check for invalid cluster
    ble     .fatLoadFileBadClust            |; exit if invalid
    cmp.l   #0x0000fff8,%d0                 |; check for end of file
    bge     .fatLoadFileDone                |; end loop if done
    
    |; now get starting LBA for this cluster
    subq.l  #2,%d0                          |; required for FAT reasons
    move.l  globFatBpbSectPerClust,%d4
    mulu.w  %d4,%d0                         |; mult clust by sectPerClust
    add.l   globFatDataStartLBA,%d0         |; add start of data region on disk
    |; now d0 has the starting LBA for this cluster
    |; we can finally read this cluster
    |; d0: starting lba
    |; d1: number of sectors
    |; a0: buffer pointer
    |; returns # of bytes read on success
    bsr     ideReadSectMult
    tst.l   %d0                             |; returns 0 on error
    beq     .fatLoadFileErrRead             |; exit on read error
    add.l   %d0,%a0                         |; add bytes read to buffer ptr

    |; find the next cluster
    move.w  %a3@(%d2.w),%d2                 |; get next sector
    ror.w   #8,%d2                          |; endian swap
    sysPrntIreg "fatLoadFile: Next cluster: " %d2
    bra     .fatLoadFileLp                  |; continue load loop

.fatLoadFileDone:
    |; hurrah!
    sysPrntI "fatLoadFile: Reached end of file.\r\n"
    sysPrntIreg "fatLoadFile: File loaded to memory at: " %a2
    eor.l   %d0,%d0                         |; return 0 on success
    move.l  %d3,%d1                         |; return filesize on success
    movea.l %a2,%a0                         |; return ptr to start of file
    movem.l %sp@+,%a1-%a3/%d2-%d3           |; restore working registers
    rts
           
.fatLoadFileBadClust:
    sysPrntI "fatLoadFile: Invalid file cluster. Should be greater than 1.\r\n"
    moveq.l #6,%d0                          |; return error code in d0
    bra.s   .fatLoadFileErrorExit

.fatLoadFileErrRead:
    sysPrntI "fatLoadFile: Error reading file data.\r\n"
    moveq.l #7,%d0                          |; return error code in d0
    bra     .fatLoadFileErrorExit

.fatLoadFileErr:
    |; return existing error number in d0
.fatLoadFileErrorExit:
    eor.l   %d1,%d1                         |; return 0 in d1 on error
    move.l  %d1,%a0                         |; return 0 in ptr a0 on error
    movem.l %sp@+,%a1-%a3/%d2-%d3           |; restore working registers
    rts

    .even

|; look for a "BOOT.BIN" on a FAT16-formatted disk and try to boot it
ucBOOTFILE:
    sysPrntI "Attempting to boot from \"BOOT.BIN\" ... \r\n?"
    lea     sBootFileName,%a0               |; get pointer to filename
    bsr     exeFile                         |; execute
    tst.l   %d0                             |; returns 0 on success
    bne     .ucBOOTerr                      |; print error message
    sysPrntI "OS returned to monitor.\r\n?"
    rts
|; ucBOOTFILE:
|;     sysPrntI "Attempting to boot from \"BOOT.BIN\" ... \r\n"
|;     lea     sBootFileName,%a0               |; get pointer to filename
|;     bsr     fatLoadFile                     |; try to load file
|;     tst.l   %d0                             |; returns 0 on success
|;     bne     .ucBOOTFerr                     |; exit if error
|;     |; for now, we're just going to jump straight into the file.
|;     |; in the future, it might be nice to add a function to parse 
|;     |; an ELF header and properly load the file into memory

|;     |; save all registers before jumping to user program
|;     movem.l %a0-%a6/%d0-%d7,%sp@-           |; save registers
|;     sysPrntI "BOOT.BIN loaded successfully ... booting.\r\n"
|;     move.l  %sp,STACK_SAVE                  |; save stack pointer
|;     sysPrntIreg "ucBOOTFILE: jumping execution to " %a0
|;     jsr     %a0@                            |; jump to user program
|;     |; this is where we'll end up if user program exits cleanly
|;     sysPrntI "BOOT.BIN returned execution to monitor.\r\n"
|;     move.l  STACK_SAVE,%sp                  |; restore stack pointer
|;     movem.l %sp@+,%a0-%a6/%d0-%d7           |; restore registers
|;     rts                                     |; return to monitor

.ucBOOTFerr:
    |; It would be useful to actually parse the error returned in d0,
    |; but for now, we'll just print it.
    sysPrntI "Disk error loading BOOT.BIN: "
    callSYS trapPutHexWord
    callSYS trapNewLine
    rts

sBootFileName:  .ascii  "BOOT    BIN"
    .even


|; loads a file from disk and executes it
|;  parameters:
|;      %a0.l   pointer to filename
|;  returns:
|;      %d0.l   0 on success
exeFile:
    bsr     fatLoadFile                     |; try to load file
    tst.l   %d0                             |; returns 0 on success
    bne     .exeFileErr                     |; exit on error

    |; save all registers before jumping to user program
    movem.l %a0-%a6/%d0-%d7,%sp@-           |; save all registers
    move.l  %sp,STACK_SAVE                  |; save stack pointer
    jsr     %a0@                            |; jump to user program
    move.l  STACK_SAVE,%sp                  |; restore stack pointer
    movem.l %sp@+,%a0-%a6/%d0-%d7           |; restore registers
    moveq   #0,%d0                          |; return 0 on success
    rts                                     |; return to monitor

.exeFileErr:
    rts


|; reformats a filename in "8.3" format as an 11-character string
|; uses stack frame for temporary storage
|;  Parameters:
|;      %a0.l   pointer to filename in 8.3 format
|;  Returns:
|;      %d0.l   returns 0 on success
|;      %a0.l   pointer to cleaned up string (same pointer)
formatFilename:
    move.l  %a0,%a1                         |; copy pointer
    eor.l   %d0,%d0                         |; clear counter
    move.l  %d0,%d1                         |; d1 = dot position
    move.l  %d0,%d2                         |; d2 = end of line
    move.l  %d0,%d3                         |; d3 = char temp

.formatFilenameSearchLp:
    move.b  %a0@(%d0.w),%d3                 |; read byte

    |; sysPrntIreg "formatFilename: Checking char: " %d3

    cmp.b   #'.',%d3                        |; is it dot?
    beq     .formatFilenameSearchDot        |; found dot

    cmp.b   #0,%d3                          |; is it null? 
    beq     .formatFilenameSearchNul        |; unexpected null

    cmp.b   #0x0D,%d3                       |; is it end of line?
    beq     .formatFilenameSearchEoL        |; found end of line

    cmp.b   #0x7f,%d3                       |; is it too high?
    bge     .formatFilenameSearchNP         |; unexpected nonprint

    cmp.b   #' ',%d3                        |; is it non-print?
    blt     .formatFilenameSearchNP         |; unexpected nonprint

.formatFilenameSearchNext:
    addq    #1,%d0                          |; increment counter
    cmp.w   #13,%d0                         |; limit 12 char name.ext+EoL
    blt     .formatFilenameSearchLp         |; loop until done

    |; end of the loop
.formatFilenameSearchEnd:
    |; check if we found dot & end of line
    tst.w   %d1                             |; check for dot found
    beq     .formatFilenameErrNoDot         |; exit if no dot
    tst.w   %d2                             |; check for end of line
    beq     .formatFilenameErrTooLong       |; string too long 

    sysPrntI "formatFilename: Found dot & EoL. Copying to temp string\r\n?"

    |; we have dot & end of line, time to start copying
    lea     %sp@(-14),%sp                   |; make some room on stack
    eor.l   %d0,%d0                         |; clear counter
.formatFilenameCopyNameLp:
    move.b  %a0@(%d0.w),%sp@(%d0.w)         |; copy name byte
    addq    #1,%d0                          |; increment counter
    cmp.w   %d1,%d0                         |; are we at dot?
    blt     .formatFilenameCopyNameLp       |; loop until name copied

.formatFilenamePadLp:
    cmp.w   #8,%d0                          |; is more padding needed?
    bge     .formatFilenamePadDone          |; nope
    move.b  #' ',%sp@(%d0.w)                |; add pad space
    addq    #1,%d0                          |; increment counter
    bra     .formatFilenamePadLp            |; loop until pad complete

.formatFilenamePadDone:
    |; unrolled loop for extension since it's only 3 chars.
    |; d1 will now be our pointer to the original string
    |; and d0 will be the pointer to the new string
    addq    #1,%d1                          |; increment past dot
    move.b  %a0@(0,%d1.w),%sp@(0,%d0.w)     |; copy first byte
    move.b  %a0@(1,%d1.w),%sp@(1,%d0.w)     |; copy second byte
    move.b  %a0@(2,%d1.w),%sp@(2,%d0.w)     |; copy third byte
    move.b  #0,%sp@(3,%d0.w)                |; add null terminator

    sysPrntI "formatFilename: Reformatting complete. Copying return string\r\n?"

    |; now we need to copy the new string to the original position
    eor.l   %d0,%d0                         |; clear pointer offset
    moveq   #11,%d1                         |; set loop counter
.formatFilenameEndCopyLp:
    move.b  %sp@(%d0.w),%d2                 |; read char from stack
    cmp.b   #' ',%d2                        |; one last nonprint check
    blt     .formatFilenameEndCopyNP        |; change nonprint to space
.formatFilenameEndCopyCopy:
    move.b  %d2,%a0@(%d0.w)                 |; copy to return string
    addq    #1,%d0                          |; increment offset
    dbra    %d1,.formatFilenameEndCopyLp    |; loop until done

    |; copy loop is done. clean up & exit
    move.b  #0,%a0@(%d0.w)                  |; add final null terminator
    lea     %sp@(14),%sp                    |; clear stack frame
    eor.l   %d0,%d0                         |; return 0 on success
    rts                                     |; return

.formatFilenameEndCopyNP:
    moveq   #' ',%d2                        |; change nonprint to space
    bra     .formatFilenameEndCopyCopy      |; return to copy loop

.formatFilenameSearchDot:
    move.w  %d0,%d1                         |; save dot position
    sysPrntIreg "formatFilename: Found dot: " %d1
    bra     .formatFilenameSearchNext       |; continue loop

.formatFilenameSearchEoL:
    move.w  %d0,%d2                         |; save EoL position
    sysPrntIreg "formatFilename: Found EoL: " %d2
    bra     .formatFilenameSearchEnd        |; end loop

.formatFilenameSearchNP:
.formatFilenameSearchNul:
    sysPrntI "formatFilename: Unexpected character.\r\n?"
    moveq   #1,%d0
    rts

.formatFilenameErrNoDot:
    sysPrntI "formatFilename: Couldn't find extension terminator.\r\n?"
    moveq   #2,%d0
    rts

.formatFilenameErrTooLong:
    sysPrntI "formatFilename: Filename too long.\r\n?"
    moveq   #3,%d0
    rts



|; look for a user-specified file on a FAT16-formatted disk and try to run it
ucEXECFILE:
    lea     %a6@(LNBUFF),%a0                |; get pointer to line buffer
.ucEXEFILEfindParam:
    move.b  %a0@+,%d0                       |; get next char from buffer
    cmp.b   #' ',%d0                        |; look for first space
    beq     .ucEXEFILEfoundParam            |; continue when found
    cmp.b   #0x0D,%d0                       |; check for end of line
    beq     .ucEXECFILEfilenameErr          |; exit if no param found
    bra     .ucEXEFILEfindParam             |; loop until param or EoL

.ucEXEFILEfoundParam:
    bsr     formatFilename                  |; format for FAT16
    tst.w   %d0                             |; returns 0 on success
    bne     .ucEXECFILEfilenameErr          |; exit on error

    sysPrntI "Executing file: "
    move.l  %a0,%a4
    callSYS trapPutString
    callSYS trapNewLine

    bsr     exeFile                         |; load & execute file
    tst.l   %d0                             |; returns 0 on success
    bne     .ucEXECFILEerr                  |; print error

    rts

.ucEXECFILEfilenameErr:
    sysPrntI "Please enter valid 8.3 filename.\r\n?"
    rts

.ucEXECFILEerr:
    sysPrntI "Disk error loading file: "
    callSYS trapPutHexLong
    callSYS trapNewLine
    rts


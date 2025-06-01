

    .extern RAMBASIC
    .extern SIZEBASIC
    .extern MMUTABLES
    .extern MMUTABLEU
    .equ    MMU_DT_INVALID, 0
    .equ    MMU_DT_PAGE,    1
    .equ    MMU_DT_TBL4,    2
    .equ    MMU_DT_TBL8,    3
    .equ    MMU_WP,         4
    .equ    MMU_CI,         (1 << 6)

    .equ    PAGESIZE,       32768


|; void initSupvMMU(void)
initSupvMMU:
    move.l  #PAGESIZE,%d3                   |; D3 = MMU Page size
    move.l  #ramTop,%d0                     |; 
    addq.l  #1,%d0                          |; 
    move.l  #ramBot,%d1                     |; D1 = bottom of RAM
    sub.l   %d1,%d0                         |; 
    divu.l  %d3,%d0                         |; D0 = size of RAM in pages
    subq.l  #1,%d0                          |; make loop counter of D0
    lea     MMUTABLES,%a0                   |; A0 = pointer to mmu table
1:  move.l  %d1,%d2                         |; 
    ori.l   #MMU_DT_PAGE,%d2                |; apply MMU flags
    move.l  %d2,%a0@+                       |; write to table
    add.l   %d3,%d1                         |; increment phys address
    dbra    %d0,1b                          |; loop until done
    rts


|; void initUserMMU(int user)
|;  (parameter passed via stack)
|;  Register utilization:
|;      A0: tbl*
|;      A1: USERTABLE[user]
|;      D2: uMem
|;      D3: uMemPages
|;      D4: tblEnd
initUserMMU:
    |; int tableSize = ((ramTop + 1 - ramBot) / pageSize) >> 2;
    move.l  #ramTop,%d0                     |;
    addq.l  #1,%d0                          |;
    sub.l   #ramBot,%d0                     |;
    divu.l  #PAGESIZE,%d0                   |;
    lsl.l   #2,%d0                          |; D0 = tableSize
    
    |; int * tbl = (int*)(MMUTABLEU + (user * tableSize));
    move.l  %sp@(4),%d1                     |; D1 = user
    mulu    %d0,%d1                         |; D1 = user * tableSize
    lea     @(MMUTABLEU,%d1:l:1),%a0        |; A0 = tbl*

    |; int * tblEnd = tblStart + tblSize
    move.l  %d0,%d4                         |; D4 = tableSize
    add.l   %a0,%d4                         |; D4 = tblEnd    

    |; int uMemPages = (USERTABLE[user].utblMemLen)/pageSize;
    move.l  %sp@(4),%d0                     |; D0 = user
    mulu    #utbl_size,%d0                  |; D0 = user table offset
    lea     @(USERTABLE,%d0:l:1),%a1        |; A1 = user table pointer
    move.l  %a1@(utblMemLen),%d3            |; D3 = USERTABLE[user].utblMemLen
    divu.l  #PAGESIZE,%d3                   |; D3 = uMemPages

    |; int uMem = USERTABLE[user].utblMemPtr;
    move.l  %a1@(utblMemPtr),%d2            |; D2 = uMem

    |; USERTABLE[user].utblMmuRoot = tbl;
    move.l  %a0,%a1@(utblMmuRoot)           |;

    |; USERTABLE[user].utblMmuReg = 0x80000002
    move.l  #0x80000002,%a1@(utblMmuReg)    |;

    |; do{
    |;      *tbl++ = uMem;
1:  move.l  %d2,%d0                         |; D0 = uMem
    ori.l   #MMU_DT_PAGE,%d0                |; D0 = uMem | MMU_DT_PAGE
    move.l  %d0,%a0@+                       |; *tbl++ = uMem
    |;      uMem += pageSize
    add.l   #PAGESIZE,%d2                   |; 
    |; } while(--uMemPages)
    subq.l  #1,%d3                          |; --uMemPages
    bne.s   1b

    debugPrintStrI "."

    |; uMemPages = ((SIZEBASIC + (pageSize-1)) & ~(pageSize-1)) /  pageSize
    move.l  #SIZEBASIC,%d3                  |; D3 = SIZEBASIC
    move.l  #PAGESIZE,%d0                   |; D0 = pageSize
    move.l  %d0,%d1                         |; D1 = pageSize
    subq.l  #1,%d1                          |; D1 = pageSize - 1
    add.l   %d1,%d3                         |; D3 = SIZEBASIC + (pageSize - 1)
    not.l   %d1                             |; D1 = ~(pageSize - 1)
    and.l   %d1,%d3                         |; D3 = SIZEBASIC rounded to page
    divu.l  %d0,%d3                         |; D3 = num pages for BASIC

    |; uMem = RAMBASIC
    move.l  #RAMBASIC,%d2                   |; D2 = uMem

    |; do {
    |;      *tbl++ = uMem | MMU_DT_PAGE | MMU_WP;
2:  move.l  %d2,%d0                         |; D0 = uMem
    ori.l   #(MMU_DT_PAGE + MMU_WP),%d0     |; D0 = uMem | MMU_DT_PAGE + MMU_WP
    move.l  %d0,%a0@+                       |; *tbl++ = uMem
    |;      uMem += pageSize
    add.l   #PAGESIZE,%d2                   |;
    |; } while(--uMemPages)
    subq.l  #1,%d3
    bne.s   2b

    debugPrintStrI "."

    |; while(tbl < tblEnd)
    move.l  #MMU_DT_INVALID,%d0             |; speed up writing table a bit
3:  cmp.l   %d4,%a0                         |; 
    beq.s   4f                              |; 
    |;      *tbl++ = MMU_DT_INVALID
    move.l  %d0,%a0@+                       |;
    bra.s   3b

4:  debugPrintStrI ","
    rts                                     |;


|; initialize MMU tables & registers
initMMU:
    |; initialize MMU tables
    debugPrintStrI "Supv; "
    bsr     initSupvMMU                     |; initialize supervisor MMU table
    debugPrintStrI "Users; "
    move.l  #MAXUSERS,%d7                   |;
    subq.l  #1,%d7                          |; set loop counter
1:  move.l  %d7,%d0
    debugPrintHexByte %d0
    move.l  %d7,%sp@-
    bsr     initUserMMU                     |; initialize user MMU table
    move.l  %sp@+,%d7
    dbra    %d7,1b                          |; 

debugPrintStrI "\r\nSupervisor Table:\r\n"
    debugPrintStrI "address: 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f\r\n"
    debugPrintStrI "--------------------------------------------------------\r\n"
    |;              00000000 
    lea     MMUTABLES,%a0
    move.l  #127,%d7
2:  move.l  %a0,%d0
    debugPrintHexLong %d0
    debugPrintStrI " "
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    debugPrintCharI 0x0d
    debugPrintCharI 0x0a
    dbra    %d7,2b

    debugPrintStrI "\r\nUser Table:\r\n"
    debugPrintStrI "address: 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f\r\n"
    debugPrintStrI "--------------------------------------------------------\r\n"
    |;              00000000 
    lea     MMUTABLEU,%a0
    move.l  #1023,%d7
3:  move.l  %a0,%d0
    debugPrintHexLong %d0
    debugPrintStrI " "
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    move.b  %a0@+,%d0
    debugPrintHexByte
    debugPrintCharI 0x20
    debugPrintCharI 0x0d
    debugPrintCharI 0x0a
    dbra    %d7,3b


    lea     kScratchMMU,%a0

    |; set up transparent translation control registers
    debugPrintStrI "TT0; "
    move.l  #0x807f8543,%a0@                |; transparent Supv access above 2GB
    pmove   %a0@,%tt0                       |;

    |; set up supervisor root pointer register
    debugPrintStrI "SRP; "
    move.l  #0x80000202,%a0@                |; no limit, 4-byte table entries
    move.l  #MMUTABLES,%d0                  |;
    and.l   #0xfffffff0,%d0                 |;
    move.l  %d0,%a0@(4)                     |;
    pmove   %a0@,%srp                       |;

    |; set up initial user root pointer register
    |; we'll do this later

    |; flush MMU cache
    debugPrintStrI "ATC; "
    pflusha                                 |;

    |; set up translation control register
    debugPrintStrI "Enabling ... "
    move.l  #0x82f89000,%a0@                |; 32kB page, 8b shift, TIA 9b
    pmove   %a0@,%tc                        |; 

    rts

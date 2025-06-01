

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

|; void initUserMMU(reg int user)           D0
|;  int ramSize;                            SP@(0)
|;  void * tptr;                            A0
|;  int uRamPages;                          SP@(4)
|;  int pagesize;                           D1
|;  struct utbl * userTable                 A1
initUserMMU:
    link    %a6,#-8                         |; set up stack frame
    
    |; calculate total ram size
    move.l  #ramTop,%d2                     |;
    addq.l  #1,%d2                          |;
    sub.l   #ramBot,%d2                     |;
|;    move.l  %d2,%sp@(0)                     |;

    |; calculate number of pages of total ram
    move.l  #PAGESIZE,%d1                   |;
    divu.l  %d1,%d2                         |;
    move.l  %d2,%d3                         |; save total num pages of RAM

    |; calculate pointer to user MMU table
    mulu    %d0,%d2                         |; ramPages * user
    lea     MMUTABLEU,%a0                   |;
    add.l   %d2,%a0                         |;
    add.l   %a0,%d3                         |; this is the top mmu table addr
    move.l  %d3,%sp@(0)                     |;

    |; calculate pointer to user table
    lea     USERTABLE,%a1                   |; pointer to base table
    move.l  %d0,%d2                         |; 
    mulu    #utbl_size,%d2                  |;
    add.l   %d2,%a1                         |;

    |; save user MMU table pointer to user table
    move.l  %a0,%a1@(utblMmuRoot)           |; 
    move.l  #0x80000002,%a1@(utblMmuReg)    |; for root table

    |; calculate number of user memory pages
    move.l  %a1@(utblMemLen),%d2            |; user memory size in bytes
    divu.l  %d1,%d2                         |; user memory size in pages
    move.l  %d2,%sp@(4)                     |;

    |; get user physical memory start address
    move.l  %a1@(utblMemPtr),%d2            |;

    |; start copy loop
    move.l  %sp@(4),%d4                     |; set up loop counter
    subq.l  #1,%d4
1:  move.l  %d2,%d3                         |;
    ori.l   #MMU_DT_TBL4,%d3                |; apply MMU flags
    move.l  %d3,%a0@+                       |; write to table
    add.l   %d1,%d2                         |; increment page
    dbra    %d4,1b

    |; calculate number of pages for BASIC, rounded to full page
    move.l  #RAMBASIC,%d4                   |;
    move.l  #SIZEBASIC,%d2                  |;
    move.l  %d1,%d3                         |; 
    subq.l  #1,%d3                          |; (PAGESIZE - 1)
    add.l   %d3,%d2                         |; (basicsize + pagesize-1)
    not.l   %d3                             |; invert pagesize-1
    and.l   %d3,%d2                         |; round to page size
    divu.l  %d1,%d2                         |; number of pages

    |; start copy loop
    subq.l  #1,%d2                          |; loop counter
2:  move.l  %d4,%d3                         |; 
    ori.l   #(MMU_WP + MMU_DT_TBL4),%d3     |; apply MMU flags
    move.l  %d3,%a0@+                       |; write to table
    add.l   %d1,%d4                         |; increment page
    dbra    %d2,2b                          |;

    |; start copy loop to mark remainder of vmem as invalid
    move.l  %sp@(0),%a2                     |; total memory size
3:  move.l  #MMU_DT_INVALID,%a0@+           |; write invalid to table
    cmpa.l  %a2,%a0                         |; 
    blt.s   3b                              |;

    |; wrap up
    unlk    %a6                             |;
    |; debugPrintStrI ","
    rts


|; initialize MMU tables & registers
initMMU:
    |; initialize MMU tables
    debugPrintStrI "Supv; "
    bsr     initSupvMMU                     |; initialize supervisor MMU table
    debugPrintStrI "Users; "
    move.l  #MAXUSERS,%d7                   |;
    subq.l  #1,%d7                          |; set loop counter
1:  move.l  %d7,%d0
    |; debugPrintHexByte %d0
    move.l  %d7,%d0
    bsr     initUserMMU                     |; initialize user MMU table
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
    move.l  #255,%d7
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

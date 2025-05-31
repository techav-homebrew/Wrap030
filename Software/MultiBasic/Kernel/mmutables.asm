

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
    lea     kmmutable,%a0                   |; A0 = pointer to mmu table
1:  move.l  %d1,%d2                         |; 
    ori.l   #MMU_DT_PAGE,%d2                |; apply MMU flags
    move.l  %d2,%a0@+                       |; write to table
    add.l   %d3,%d1                         |; increment phys address
    dbra    1b,%d0                          |; loop until done
    rts

|; void initUserMMU(reg int user)           D0
|;  int ramSize;                            SP@(0)
|;  void * tptr;                            A0
|;  int uRamPages;                          SP@(4)
|;  int pagesize;                           D1
|;  struct utbl * userTable                 A1
initUserMMU:
    link    %a6,-8                          |; set up stack frame
    
    |; calculate total ram size
    move.l  #ramTop,%d2                     |;
    addq.l  #1,%d2                          |;
    sub.l   #ramBot,%d2                     |;
    move.l  %d2,%sp@(0)                     |;

    |; calculate number of pages of total ram
    move.l  #PAGESIZE,%d1                   |;
    divu.l  %d1,%d2                         |;

    |; calculate pointer to user MMU table
    mulu    %d0,%d2                         |; ramPages * user
    lea     kmmutable,%a0                   |;
    add.l   %d2,%a0                         |;

    |; calculate pointer to user table
    lea     USERTABLE,%a1                   |; pointer to base table
    move.l  %d0,%d2                         |; 
    mulu    #utbl_size,%d2                  |;
    add.l   %d2,%a1                         |;

    |; save user MMU table pointer to user table
    move.l  %a0,%a1@(utblMmuRoot)           |; 

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
    dbra    1b,%d4

    |; calculate number of pages for BASIC, rounded to full page
    move.l  #basicEnd,%d2                   |;
    move.l  #basicStart,%d4                 |;
    sub.l   %d4,%d2                         |; (basicEnd - basicStart)
    move.l  %d1,%d3                         |; 
    subq.l  #1,%d3                          |; (PAGESIZE - 1)
    add.l   %d3,%d2                         |; (basicsize + pagesize-1)
    not.l   %d3                             |; invert pagesize-1
    and.l   %d3,%d2                         |; round to page size
    divu.l  %d1,%d2                         |; number of pages

    |; start copy loop
    subq.l  #1,%d2                          |; loop counter
2:  move.l  %d4,%d3                         |; 
    ori.l   #(MMU_WP | MMU_DT_TBL4),%d3     |; apply MMU flags
    move.l  %d3,%a0@+                       |; write to table
    add.l   %d1,%d4                         |; increment page
    dbra    2b,%d2                          |;

    |; start copy loop to mark remainder of vmem as invalid
    move.l  %sp@(0),%a2                     |; total memory size
3:  move.l  #MMU_DT_INVALID,%a0@+           |; write invalid to table
    cmpa.l  %a2,%a0                         |; 
    blt.s   3b                              |;

    |; wrap up
    unlk    %a6                             |;
    rts


|; initialize MMU tables & registers
initMMU:
    |; initialize MMU tables
    bsr     initSupvMMU                     |; initialize supervisor MMU table
    move.l  MAXUSERS,%d0                    |;
    subq.l  #1,%d0                          |; set loop counter
1:  bsr     initUserMMU                     |; initialize user MMU table
    dbra    1b,%d0                          |; 

    |; set up transparent translation control registers

    |; set up supervisor root pointer register

    |; set up initial user root pointer register

    |; set up translation control register

    rts


|; update MMU CPU root pointer for next user (in D0.L)
updateUserMMU:

    rts

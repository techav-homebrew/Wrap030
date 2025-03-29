
    
    .global PROCTABLE
    .global PROCNUM
    .global WARMBOOT
    .global SysTrap
    .global SaveUserContext
    .global NextUser
    .global RestoreUserContext



MAXPROCS = 16

    .struct 0
utbl:
utblRegD0:  .space  4                       |; user register D0 store
utblRegD1:  .space  4                       |; D1
utblRegD2:  .space  4                       |; D2
utblRegD3:  .space  4                       |; D3
utblRegD4:  .space  4                       |; D4
utblRegD5:  .space  4                       |; D5
utblRegD6:  .space  4                       |; D6
utblRegD7:  .space  4                       |; D7
utblRegA0:  .space  4                       |; A0
utblRegA1:  .space  4                       |; A1
utblRegA2:  .space  4                       |; A2
utblRegA3:  .space  4                       |; A3
utblRegA4:  .space  4                       |; A4
utblRegA5:  .space  4                       |; A5
utblRegA6:  .space  4                       |; A6
utblRegA7:  .space  4                       |; A7
utblRegStore:
utblRegCCR: .space  4                       |; user status register
utblRegPC:  .space  4                       |; user program counter
utblMemPtr: .space  4                       |; user main memory pointer
utblMemLen: .space  4                       |; user main memory size
utblConInDev:   .space  4                   |; pointer to console in device
utblConOutDev:  .space  4                   |; pointer to console out device
utblConInDrv:   .space  4                   |; pointer to console in driver
utblConOutDrv:  .space  4                   |; pointer to console out driver
utblPrintHead:  .space  4                   |; pointer to start of print buffer
utblPrintTail:  .space  4                   |; pointer to end of print buffer
utblFileHead:   .space  4                   |; pointer to start of file buffer
utblFileTail:   .space  4                   |; pointer to end of file buffer
utblFilePos:    .space  4                   |; pointer to current file position
utblUndefined:  .space 12                   |; pad table to 32 longwords
utbl_size = . - utbl                        |; size of this table


|; kernel global variables
    .section bss,"w"
PROCNUM:    ds.l    1                       |; current active process number



|; kernel process table
    .section proc,"w"

PROCTABLE:

proc0:                                      |; process 0 table (user 0)
    dc.l    uMemSize0                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart0                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    RAMBASIC                        |; PC
    dc.l    uMemStart0                      |; user memory pointer
    dc.l    uMemSize0                       |; user memory size
    dc.l    ioCom0                          |; console in port
    dc.l    ioCom0                          |; console out port
    dc.l    drvOctocomIn                    |; console in driver pointer
    dc.l    drvOctocomOut                   |; console out driver pointer
    dc.l    uBufStart0                      |; print buffer start pointer
    dc.l    uBufStart0                      |; print buffer end pointer
    dc.l    uFileStart0                     |; file buffer start pointer
    dc.l    uFileStart0                     |; file buffer end pointer
    dc.l    uFileStart0                     |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc1:                                      |; process 1 table (user 1)
    dc.l    uMemSize1                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart1                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    RAMBASIC                        |; PC
    dc.l    uMemStart1                      |; user memory pointer
    dc.l    uMemSize1                       |; user memory size
    dc.l    ioCom1                          |; console in port
    dc.l    ioCom1                          |; console out port
    dc.l    drvOctocomIn                    |; console in driver pointer
    dc.l    drvOctocomOut                   |; console out driver pointer
    dc.l    uBufStart1                      |; print buffer start pointer
    dc.l    uBufStart1                      |; print buffer end pointer
    dc.l    uFileStart1                     |; file buffer start pointer
    dc.l    uFileStart1                     |; file buffer end pointer
    dc.l    uFileStart1                     |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc2:                                      |; process 2 table (user 2)
    dc.l    uMemSize2                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart2                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    RAMBASIC                        |; PC
    dc.l    uMemStart2                      |; user memory pointer
    dc.l    uMemSize2                       |; user memory size
    dc.l    ioCom2                          |; console in port
    dc.l    ioCom2                          |; console out port
    dc.l    drvOctocomIn                    |; console in driver pointer
    dc.l    drvOctocomOut                   |; console out driver pointer
    dc.l    uBufStart2                      |; print buffer start pointer
    dc.l    uBufStart2                      |; print buffer end pointer
    dc.l    uFileStart2                     |; file buffer start pointer
    dc.l    uFileStart2                     |; file buffer end pointer
    dc.l    uFileStart2                     |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc3:                                      |; process 3 table (user 3)
    dc.l    uMemSize3                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart3                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    RAMBASIC                        |; PC
    dc.l    uMemStart3                      |; user memory pointer
    dc.l    uMemSize3                       |; user memory size
    dc.l    ioCom3                          |; console in port
    dc.l    ioCom3                          |; console out port
    dc.l    drvOctocomIn                    |; console in driver pointer
    dc.l    drvOctocomOut                   |; console out driver pointer
    dc.l    uBufStart3                      |; print buffer start pointer
    dc.l    uBufStart3                      |; print buffer end pointer
    dc.l    uFileStart3                     |; file buffer start pointer
    dc.l    uFileStart3                     |; file buffer end pointer
    dc.l    uFileStart3                     |; file position pointer
    dc.l    0,0,0                           |; pad to 33 longwords

proc4:                                      |; process 4 table (user 4)
    dc.l    uMemSize4                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart4                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    RAMBASIC                        |; PC
    dc.l    uMemStart4                      |; user memory pointer
    dc.l    uMemSize4                       |; user memory size
    dc.l    ioCom4                          |; console in port
    dc.l    ioCom4                          |; console out port
    dc.l    drvOctocomIn                    |; console in driver pointer
    dc.l    drvOctocomOut                   |; console out driver pointer
    dc.l    uBufStart4                      |; print buffer start pointer
    dc.l    uBufStart4                      |; print buffer end pointer
    dc.l    uFileStart4                     |; file buffer start pointer
    dc.l    uFileStart4                     |; file buffer end pointer
    dc.l    uFileStart4                     |; file position pointer
    dc.l    0,0,0                           |; pad to 34 longwords

proc5:                                      |; process 5 table (user 5)
    dc.l    uMemSize5                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart5                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    RAMBASIC                        |; PC
    dc.l    uMemStart5                      |; user memory pointer
    dc.l    uMemSize5                       |; user memory size
    dc.l    ioCom5                          |; console in port
    dc.l    ioCom5                          |; console out port
    dc.l    drvOctocomIn                    |; console in driver pointer
    dc.l    drvOctocomOut                   |; console out driver pointer
    dc.l    uBufStart5                      |; print buffer start pointer
    dc.l    uBufStart5                      |; print buffer end pointer
    dc.l    uFileStart5                     |; file buffer start pointer
    dc.l    uFileStart5                     |; file buffer end pointer
    dc.l    uFileStart5                     |; file position pointer
    dc.l    0,0,0                           |; pad to 35 longwords

proc6:                                      |; process 6 table (user 6)
    dc.l    uMemSize6                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart6                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    RAMBASIC                        |; PC
    dc.l    uMemStart6                      |; user memory pointer
    dc.l    uMemSize6                       |; user memory size
    dc.l    ioCom6                          |; console in port
    dc.l    ioCom6                          |; console out port
    dc.l    drvOctocomIn                    |; console in driver pointer
    dc.l    drvOctocomOut                   |; console out driver pointer
    dc.l    uBufStart6                      |; print buffer start pointer
    dc.l    uBufStart6                      |; print buffer end pointer
    dc.l    uFileStart6                     |; file buffer start pointer
    dc.l    uFileStart6                     |; file buffer end pointer
    dc.l    uFileStart6                     |; file position pointer
    dc.l    0,0,0                           |; pad to 36 longwords

proc7:                                      |; process 7 table (user 7)
    dc.l    uMemSize7                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart7                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    RAMBASIC                        |; PC
    dc.l    uMemStart7                      |; user memory pointer
    dc.l    uMemSize7                       |; user memory size
    dc.l    ioCom7                          |; console in port
    dc.l    ioCom7                          |; console out port
    dc.l    drvOctocomIn                    |; console in driver pointer
    dc.l    drvOctocomOut                   |; console out driver pointer
    dc.l    uBufStart7                      |; print buffer start pointer
    dc.l    uBufStart7                      |; print buffer end pointer
    dc.l    uFileStart7                     |; file buffer start pointer
    dc.l    uFileStart7                     |; file buffer end pointer
    dc.l    uFileStart7                     |; file position pointer
    dc.l    0,0,0                           |; pad to 37 longwords

proc8:                                      |; process 8 table (print spooler)
    dc.l    uMemSize8                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart8                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    spoolEntry                      |; PC
    dc.l    uMemStart8                      |; user memory pointer
    dc.l    uMemSize8                       |; user memory size
    dc.l    acia2Dat                        |; console in port
    dc.l    acia2Dat                        |; console out port
    dc.l    drvACIAin                       |; console in driver pointer
    dc.l    drvACIAout                      |; console out driver pointer
    dc.l    0                               |; print buffer start pointer
    dc.l    0                               |; print buffer end pointer
    dc.l    0                               |; file buffer start pointer
    dc.l    0                               |; file buffer end pointer
    dc.l    0                               |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc9:                                      |; process 9 table
    dc.l    uMemSize9                       |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart9                      |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    0                               |; PC
    dc.l    uMemStart9                      |; user memory pointer
    dc.l    uMemSize9                       |; user memory size
    dc.l    0                               |; console in port
    dc.l    0                               |; console out port
    dc.l    0                               |; console in driver pointer
    dc.l    0                               |; console out driver pointer
    dc.l    0                               |; print buffer start pointer
    dc.l    0                               |; print buffer end pointer
    dc.l    0                               |; file buffer start pointer
    dc.l    0                               |; file buffer end pointer
    dc.l    0                               |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc10:                                     |; process 10 table
    dc.l    uMemSize10                      |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart10                     |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    0                               |; PC
    dc.l    uMemStart10                     |; user memory pointer
    dc.l    uMemSize10                      |; user memory size
    dc.l    0                               |; console in port
    dc.l    0                               |; console out port
    dc.l    0                               |; console in driver pointer
    dc.l    0                               |; console out driver pointer
    dc.l    0                               |; print buffer start pointer
    dc.l    0                               |; print buffer end pointer
    dc.l    0                               |; file buffer start pointer
    dc.l    0                               |; file buffer end pointer
    dc.l    0                               |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc11:                                     |; process 11 table
    dc.l    uMemSize11                      |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart11                     |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    0                               |; PC
    dc.l    uMemStart11                     |; user memory pointer
    dc.l    uMemSize11                      |; user memory size
    dc.l    0                               |; console in port
    dc.l    0                               |; console out port
    dc.l    0                               |; console in driver pointer
    dc.l    0                               |; console out driver pointer
    dc.l    0                               |; print buffer start pointer
    dc.l    0                               |; print buffer end pointer
    dc.l    0                               |; file buffer start pointer
    dc.l    0                               |; file buffer end pointer
    dc.l    0                               |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc12:                                     |; process 12 table
    dc.l    uMemSize12                      |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart12                     |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    0                               |; PC
    dc.l    uMemStart12                     |; user memory pointer
    dc.l    uMemSize12                      |; user memory size
    dc.l    0                               |; console in port
    dc.l    0                               |; console out port
    dc.l    0                               |; console in driver pointer
    dc.l    0                               |; console out driver pointer
    dc.l    0                               |; print buffer start pointer
    dc.l    0                               |; print buffer end pointer
    dc.l    0                               |; file buffer start pointer
    dc.l    0                               |; file buffer end pointer
    dc.l    0                               |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc13:                                     |; process 13 table
    dc.l    uMemSize13                      |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart13                     |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    0                               |; PC
    dc.l    uMemStart13                     |; user memory pointer
    dc.l    uMemSize13                      |; user memory size
    dc.l    0                               |; console in port
    dc.l    0                               |; console out port
    dc.l    0                               |; console in driver pointer
    dc.l    0                               |; console out driver pointer
    dc.l    0                               |; print buffer start pointer
    dc.l    0                               |; print buffer end pointer
    dc.l    0                               |; file buffer start pointer
    dc.l    0                               |; file buffer end pointer
    dc.l    0                               |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc14:                                     |; process 14 table
    dc.l    uMemSize14                      |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart14                     |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    0                               |; PC
    dc.l    uMemStart14                     |; user memory pointer
    dc.l    uMemSize14                      |; user memory size
    dc.l    0                               |; console in port
    dc.l    0                               |; console out port
    dc.l    0                               |; console in driver pointer
    dc.l    0                               |; console out driver pointer
    dc.l    0                               |; print buffer start pointer
    dc.l    0                               |; print buffer end pointer
    dc.l    0                               |; file buffer start pointer
    dc.l    0                               |; file buffer end pointer
    dc.l    0                               |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords

proc15:                                     |; process 15 table
    dc.l    uMemSize15                      |; D0 (user memory size, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; D1..7
    dc.l    uMemStart15                     |; A0 (user memory pointer, for BASIC)
    dc.l    0,0,0,0,0,0,0                   |; A1..7
    dc.l    0                               |; CCR
    dc.l    0                               |; PC
    dc.l    uMemStart15                     |; user memory pointer
    dc.l    uMemSize15                      |; user memory size
    dc.l    0                               |; console in port
    dc.l    0                               |; console out port
    dc.l    0                               |; console in driver pointer
    dc.l    0                               |; console out driver pointer
    dc.l    0                               |; print buffer start pointer
    dc.l    0                               |; print buffer end pointer
    dc.l    0                               |; file buffer start pointer
    dc.l    0                               |; file buffer end pointer
    dc.l    0                               |; file position pointer
    dc.l    0,0,0                           |; pad to 32 longwords
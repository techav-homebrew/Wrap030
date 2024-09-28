MAXUSERS = 8

    .global USERTABLE
    .global USERNUM
    .global WARMBOOT
    .global SysTrap
    .global SaveUserContext
    .global NextUser
    .global RestoreUserContext

    .extern ioCom0
    .extern ioCom1
    .extern ioCom2
    .extern ioCom3
    .extern ioCom4
    .extern ioCom5
    .extern ioCom6
    .extern ioCom7

    .extern ioCom0
    .extern ioCom1
    .extern ioCom2
    .extern ioCom3
    .extern ioCom4
    .extern ioCom5
    .extern ioCom6
    .extern ioCom7

    .extern uMemStart0
    .extern uMemStart1
    .extern uMemStart2
    .extern uMemStart3
    .extern uMemStart4
    .extern uMemStart5
    .extern uMemStart6
    .extern uMemStart7

    .extern uMemSize0
    .extern uMemSize1
    .extern uMemSize2
    .extern uMemSize3
    .extern uMemSize4
    .extern uMemSize5
    .extern uMemSize6
    .extern uMemSize7

    .extern USERTABLE

    .struct 0
utbl:
utblConIn:  .space  4                       |; pointer to console in device
utblConOut: .space  4                       |; pointer to console out device
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
utblUndefined:  .space  40                  |; pad table to 32 longwords
utbl_size = . - utbl                        |; size of this table


|; kernel global variables
    .section bss,"w"

|; USERTABLE:  ds.b utbl_size*MAXUSERS         |; reserve space for the user table

USERNUM:    ds.l 1                          |; current user number


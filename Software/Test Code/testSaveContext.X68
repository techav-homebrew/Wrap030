*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------

CODE    EQU 0
DATA    EQU 1

    SECTION DATA
    ORG     $2000

MAXUSERS:   EQU 8

utblConIn:  EQU 0
utblConOut: EQU 4
utblRegD0:  EQU 8
utblRegD1:  EQU 12
utblRegD2:  EQU 16
utblRegD3:  EQU 20
utblRegD4:  EQU 24
utblRegD5:  EQU 28
utblRegD6:  EQU 32
utblRegD7:  EQU 36
utblRegA0:  EQU 40
utblRegA1:  EQU 44
utblRegA2:  EQU 48
utblRegA3:  EQU 52
utblRegA4:  EQU 56
utblRegA5:  EQU 60
utblRegA6:  EQU 64
utblRegA7:  EQU 68
utblRegStore:   EQU 72
utblRegCCR: EQU 72
utblRegPC:  EQU 76
utblMemPtr: EQU 80
utblMemLen: EQU 84
utblUndefined:  EQU 88
utblSize:   EQU 128

USERTABLE:  ds.l    32*8
USERNUM:    ds.l    1

    SECTION CODE
    ORG     0

initSP:     dc.l    $2000
initPC:     dc.l    $1000

    ORG     $1000
START:                          ; first instruction of program
    MOVE.L  initSP,SP           ; initialize stack pointer

    ; initialize user data table
    MOVE.L  #MAXUSERS-1,D0      ; start at end of user numbers
    LEA     USERTABLE,A0        ; load pointer to user table
.1:
    BSR     kUserTblInit        ; initialize user
    DBRA    D0,.1               ; initialize all users
    
    ; jump execution to first user program
    MOVE.W  #$0080,-(SP)        ; push TRAP0 vector to system stack
    MOVE.L  #BASICENTRY,-(SP)   ; push BASIC entry point to stack
    MOVE.W  #0,-(SP)            ; push clear CCR to stack
    MOVEQ.L #0,D0               ; start by loading user 0
    BRA     RestoreUserContext  ; load user context & start execution
    

; initialize user table in A0 for user number in D0
kUserTblInit:
    MOVE.L  D0,D1               ; copy user number
    MULU    #utblSize,D1        ; multiply by table entry size to get offset
    LEA     (A0,D1.L),A1        ; get pointer to this user's table entry
    MOVE.W  #15,D2              ; set loop counter for 16 registers
    EOR.L   D3,D3               ; clear D3 for initializing table entries
    LEA     utblRegD0(A1),A2
.1:
    MOVE.L  D3,(A2)+            ; clear register store in user table entry
    DBRA    D2,.1               ; loop until all 16 gp registers cleared
    
    MOVE.L  D0,D2               ; copy user number
    LSL.L   #2,D2               ; word shift
    
    MOVE.L  D3,utblRegCCR(A1)   ; clear user CCR
    LEA     tblUserConIn,A2     ; set user console in device address
    MOVE.L  (A2,D2.L),utblConIn(A1)
    LEA     tblUserConOut,A2    ; set user console out device address
    MOVE.L  (A2,D2.L),utblConOut(A2)
    
    LEA     tblUserMem,A2       ; set user memory start address
    MOVE.L  (A2,D2.L),D4        ;
    MOVE.L  D4,utblMemPtr(A1)   ;
    MOVE.L  D4,utblRegA0(A1)    ;
    LEA     tblUserMemSize,A2   ; set user memory size
    MOVE.L  (A2,D2.L),D5        ;
    MOVE.L  D5,utblMemLen(A1)   ;
    MOVE.L  D5,utblRegD0(A1)    ;
    
    ADD.L   D5,D4               ; calculate initial user stack pointer
    MOVE.L  D4,utblRegA7(A1)    ;
    
    LEA     BASICENTRY,A2       ; set initial user PC to BASIC entry point
    MOVE.L  A2,utblRegPC(A1)    ;
    
    RTS


      
SaveUserContext:
    MOVEM.L A0/D0,-(SP)         ; save A0 & D0 to system stack
    LEA     USERTABLE,A0        ; get pointer to user table
    MOVE.L  USERNUM,D0          ; get current user number
    MULU    #utblSize,D0        ; mult by table size to get offset
    ADD.L   D0,A0               ; get pointer to specific user entry
    MOVE.L  A0,-(SP)            ; save pointer to system stack for later use
    ADDA.L  #utblRegStore,A0    ; get pointer to next address past data store
    MOVEM.L A0-A7/D0-D7,-(A0)   ; save all registers to data store
    MOVE.L  (SP)+,A0            ; restore pointer to start of user table
    MOVE.L  (SP)+,utblRegD0(A0) ; save D0 to user table
    MOVE.L  (SP)+,utblRegA0(A0) ; save A0 to user table
    MOVE.W  (SP),utblRegCCR(A0) ; save status register to user table
    MOVE.L  2(SP),utblRegPC(A0) ; save user program counter
    MOVE.L  USP,A1              ; get user stack pointer
    MOVE.L  A1,utblRegA7(A0)    ; save user stack pointer to user table
    
NextUser:
    MOVE.L  USERNUM,D0          ; get current user number
    ADDQ.L  #1,D0               ; increment user number
    CMP.L   #MAXUSERS,D0        ; is this the last user?
    BLT     .1                  ; branch if no
    MOVEQ.L #0,D0               ; loop back around to 0
.1:
    MOVE.L  D0,USERNUM          ; save new user number   
   
    ; restore context for user in D0
RestoreUserContext:
    MULU    #utblSize,D0        ; shift user number to table offset
    LEA     USERTABLE,A0        ; get user table pointer
    ADD.L   D0,A0               ; add user offset to pointer
    MOVE.L  A0,-(SP)            ; save pointer for later
    
    LEA     utblRegA7(A0),A0    ; start by pointing to A7
    MOVE.L  (A0),A1             ; get user stack pointer from data store
    MOVE.L  A1,USP              ; restore user stack pointer
    LEA     utblRegD0-utblRegA7(A0),A0  ; point to beginning of registers
    MOVEM.L (A0)+,D0-D7         ; restore data registers
    ADD.L   #4,A0               ; skip past A0
    MOVEM.L (A0)+,A1-A6         ; restore A1-A6
    MOVE.L  (SP)+,A0            ; revert pointer back to beginning of table
    
    MOVE.W  utblRegCCR(A0),0(SP)    ; restore status register to exception frame
    MOVE.L  utblRegPC(A0),2(SP)     ; restore user PC to exception frame
    MOVE.L  utblRegA0(A0),A0    ; restore A0 last
    
    NOP
    RTE
    NOP
    
tblUserConIn:
    DC.L    $80800000
    DC.L    $80800020
    DC.L    $80800040
    DC.L    $80800060
    DC.L    $80800080
    DC.L    $808000A0
    DC.L    $808000C0
    DC.L    $808000E0

tblUserConOut:
    DC.L    $80800000
    DC.L    $80800020
    DC.L    $80800040
    DC.L    $80800060
    DC.L    $80800080
    DC.L    $808000A0
    DC.L    $808000C0
    DC.L    $808000E0

tblUserMem:
    DC.L    $00100000
    DC.L    $00120000
    DC.L    $00140000
    DC.L    $00160000
    DC.L    $00180000
    DC.L    $001A0000
    DC.L    $001C0000
    DC.L    $001E0000

uMemSize:   EQU $00100000
tblUserMemSize:
    DC.L    uMemSize
    DC.L    uMemSize
    DC.L    uMemSize
    DC.L    uMemSize
    DC.L    uMemSize
    DC.L    uMemSize
    DC.L    uMemSize
    DC.L    uMemSize
    

    ORG $5000
BASICENTRY:
    NOP
    NOP
    MOVE.L  SP,A0
    NOP
    NOP
    MOVE.W  #$2000,SR
    NOP
    NOP

* Put program code here

    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

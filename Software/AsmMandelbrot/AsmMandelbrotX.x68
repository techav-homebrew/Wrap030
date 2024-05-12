
width:      equ 160
height:     equ 200
vidAddr:    equ $80800000

loops:      equ 32              ; how many loops before starting over

; use https://mandel.gart.nz/ to find center values

initCenterR:    fequ.x  -1.500000000
initCenterI:    fequ.x   0.000000000

endCenterR:     fequ.x  -0.5
endCenterI:     fequ.x   0.0

initWidth:      fequ.x   0.000000000000003
initHeight:     fequ.x   0.000000000000002

endWidth:       fequ.x   3.0
endHeight:      fequ.x   2.0

initR1:         fequ.x  initCenterR-(initWidth/2)
initR2:         fequ.x  initCenterR+(initWidth/2)
initI1:         fequ.x  initCenterI-(initHeight/2)
initI2:         fequ.x  initCenterI+(initHeight/2)

endR1:          fequ.x  endCenterR-(endWidth/2)
endR2:          fequ.x  endCenterR+(endWidth/2)
endI1:          fequ.x  endCenterI-(endHeight/2)
endI2:          fequ.x  endCenterI+(endHeight/2)




; deltas below are added to extents each cycle to zoom & recenter
deltaR1:    fequ.x 0-((initR1-endR1)/(loops))
deltaR2:    fequ.x 0-((initR2-endR2)/(loops))
deltaI1:    fequ.x 0-((initI1-endI1)/(loops))
deltaI2:    fequ.x 0-((initI2-endI2)/(loops))

; deltaR1:    equ  0.010
; deltaR2:    equ -0.020
; deltaI1:    equ  0.015
; deltaI2:    equ -0.005



acia1ComStat:   equ $00380000
acia1ComData:   equ $00380004

; Generic macro for system calls
    MACRO callSYS
    move.l  D1,-(SP)            ; save the working register
    move.b  \1,D1               ; load syscall number
    trap    #0                  ; call syscall handler
    move.l  (SP)+,D1            ; restore the working register
    ENDM

sysGETCHAR  equ 0
sysPUTCHAR  equ 1
sysNEWLINE  equ 2
sysPSTRING  equ 4
sysPBYTE    equ 9
sysPWORD    equ 10
sysPLONG    equ 11
sysPSPACE   equ 12


;    text
    org     $00004000
start:
;    link    A6,#0-B         ; set up stack frame for local variables
    lea     variables(PC),A1    ; get pointer to variables region
    lea     vidAddr,A0      ; get address to video frame buffer
    move.l  #$0FFFF,D0      ; video register address offset
    move.b  #0,0(A0,D0.l)   ; enable video generator & set mode 0
    move.l  #$7fff,D0       ; set up loop counter
    eor.l   D1,D1           ; clear D1 to quickly clear VRAM with
clearVram:
    move.b  D1,0(A0,D0.L)   ; clear each VRAM address
    move.b  D1,0(A0,D0.L)   ; do it now
    dbra    D0,clearVram    ; loop until all VRAM cleared

; initializations
; Register-resident variables:
;   X1  -   D0
;   Y1  -   D1
;   X   -   D2
;   Y   -   D3
;   N   -   D4
varInit:
    move.w  #loops,LP(A1)   ; initialize loop counter
    move.l  #width-1,D0     ; X1=width-1
    fmove.l D0,FP0
    fmove.x FP0,X1(A1)
    move.l  #height-1,D1    ; Y1=height-1
    fmove.l D1,FP0
    fmove.x FP0,Y1(A1)
    fmove.x #initI1,FP0       ; I1=-1.0
    fmove.x FP0,I1(A1)
    fmove.x #initI2,FP0        ; I2=1.0
    fmove.x FP0,I2(A1)
    fmove.x #initR1,FP0       ; R1=-2.0
    fmove.x FP0,R1(A1)
    fmove.x #initR2,FP0        ; R2=1.0
    fmove.x FP0,R2(A1)

calcLoop:
    ; 30 S1=(R2-R1)/X1:S2=(I2-I1)/Y1

    ; S1=(R2-R1)/X1
    fmove.x R2(A1),FP0      ; FP0=R2
    fsub.x  R1(A1),FP0      ; FP0=FP0-R1=R2-R1
    fdiv.x  X1(A1),FP0      ; FP0=FP0/X1=(R2-R1)/X1
    fmove.x FP0,S1(A1)      ; S1=FP0

    ; S2=(I2-I1)/Y1
    fmove.x I2(A1),FP0      ; FP0=I2
    fsub.x  I1(A1),FP0      ; FP0=FP0-I1=I2-I1
    fdiv.x  Y1(A1),FP0      ; FP0=FP0/Y1=(I2-I1)/Y1
    fmove.x FP0,S2(A1)      ; S2=FP0

    ; FOR Y=0 TO Y1 STEP 2
    move.l  #0,D3           ; Y=0

nextY:
    bsr     cancelCheck     ; start of each line, check for Ctrl-C
    ; I3=I1+S2*Y
    fmove.l D3,FP0          ; FP0=Y
    fmul.x  S2(A1),FP0      ; FP0=FP0*S2=Y*S2
    fadd.x  I1(A1),FP0      ; FP0=FP0+I1=(S2*Y)+I1
    fmove.x FP0,I3(A1)      ; I3=FP0

    ; FOR X=0 TO X1
    move.l  #0,D2           ; X=0

nextX:
    ; 70 R3=R1+S1*X:Z1=R3:Z2=I3

    ; R3=R1+S1*X
    fmove.l D2,FP0          ; FP0=X
    fmul.x  S1(A1),FP0      ; FP0=FP0*S1=X*S1
    fadd.x  R1(A1),FP0      ; FP0=FP0+R1=(X*S1)+R1
    fmove.x FP0,R3(A1)      ; R3=FP0

    ; Z1=R3
    fmove.x FP0,Z1(A1)      ; Z1=FP0=R3

    ; Z2=I3
    fmove.x I3(A1),FP0      ; FP0=I3
    fmove.x FP0,Z2(A1)      ; Z2=FP0=I3

    ; FOR N=0 TO 15
    move.w  #0,D4           ; N=0

nextN:
    ; 90 A=Z1*Z1:B=Z2*Z2

    ; A=Z1*Z1
    fmove.x Z1(A1),FP0      ; FP0=Z1
    fmul.x  FP0,FP0         ; FP0=FP0*FP0=Z1*Z1
    fmove.x FP0,vA(A1)      ; A=FP0

    ; B=Z2*Z2
    fmove.x Z2(A1),FP0      ; FP0=Z2
    fmul.x  FP0,FP0         ; FP0=FP0*FP0=Z2*Z2
    fmove.x FP0,vB(A1)      ; B=FP0

    ; 100 IF A+B>4.0 THEN GOTO 130

    fmove.x vA(A1),FP0      ; FP0=A
    fadd.x  vB(A1),FP0      ; FP0=A+B
    fcmp.x  #4.0,FP0        ; FP0-4.0
    fbgt    drawPixel       ; if FP0>4.0, goto [drawPixel]

    ; 110 Z2=2*Z1*Z2+I3:Z1=A-B+R3

    ; Z2=2*Z1*Z2+I3
    fmove.x Z1(A1),FP0      ; FP0=Z1
    fadd.x  FP0,FP0         ; FP0=FP0+FP0=Z1+Z1=Z1*2
    fmul.x  Z2(A1),FP0      ; FP0=FP0*Z2
    fadd.x  I3(A1),FP0      ; FP0=FP0+I3
    fmove.x FP0,Z2(A1)      ; Z2=FP0

    ; Z1=A-B+R3
    fmove.x vA(A1),FP0
    fsub.x  vB(A1),FP0
    fadd.x  R3(A1),FP0
    fmove.x FP0,Z1(A1)

    ; NEXT N
    addi.w  #1,D4           ; increment N
    cmpi.w  #255,D4         ; compare to loop limit
    ble     nextN           ; if less than limit then continue N loop

    ; GOSUB [drawPixel]
    bra     drawPixel

drawRet:
    ; NEXT X
    addi.l  #1,D2           ; increment X
    cmp.l   D0,D2           ; compare X to X1
    ble     nextX           ; if X<X1, then continue X loop

    ; NEXT Y
    addi.l  #2,D3           ; increment Y
    cmp.l   D1,D3           ; compare Y to Y1
    ble     nextY           ; if Y<Y1, then continue Y loop




; end of calculation loop.
; this would be a good place to update the initial parameters to zoom in on a
; region of the fractal and start drawing again
    move.w  LP(A1),D7       ; get loop counter
    subi.w  #1,D7           ; decrement loop counter
    beq     varInit         ; start over if loop counter = 0
    move.w  D7,LP(A1)       ; store updated loop counter

    fmove.x R1(A1),FP0      ; R1=R1+deltaR1
    fadd.x  #deltaR1,FP0
    fmove.x FP0,R1(A1)

    fmove.x R2(A1),FP0      ; R2=R2+deltaR2
    fadd.x  #deltaR2,FP0
    fmove.x FP0,R2(A1)

    fmove.x I1(A1),FP0      ; I1=I1+deltaR1
    fadd.x  #deltaI1,FP0
    fmove.x FP0,I1(A1)

    fmove.x I2(A1),FP0      ; I2=I2+deltaI2
    fadd.x  #deltaI2,FP0
    fmove.x FP0,I2(A1)

    bsr     cancelCheck         ; check for user Ctrl-C

    bra     calcLoop            ; run next loop

; draw the pixel we just calculated
drawPixel:
    move.l  D3,D5           ; get a copy of Y
    mulu.l  #160,D5         ; multiply by 160 to get row address
    add.l   D2,D5           ; add X to get pixel address
    ; move.w  D4,D6           ; get a copy of N
    ; and.w   #$F,D6          ; mask out high bits
    ; move.b  D6,D7           ; get a copy
    ; lsl.b   #4,D7           ; shift the copy
    ; or.b    D7,D6           ; both pixels will be the same color
    move.w  D4,D6
    and.w   #$FF,D6
    move.b  D6,0(A0,D5.l)   ; write the first half of the chunky pixel
    move.b  D6,0(A0,D5.l)   ; do it now
    add.l   #160,D5         ; increment address for second half of chunky pixel
    rol.b   #4,D6           ; swap colors for second half of chunky pixel
    move.b  D6,0(A0,D5.l)   ; write the second half of the chunky pixel
    move.b  D6,0(A0,D5.l)   ; do it 
    bra     drawRet         ; return to calculation loop

cancelCheck:
    btst    #0,acia1ComStat     ; check com port data received bit
    bne.s   .cancelComRead      ; branch if com port has received data
    rts                         ; return if no data
.cancelComRead:
    cmp.b   #3,acia1ComData     ; check for Ctrl-C
    beq     .cancelComExit      ; if Ctrl-C then exit to monitor
    rts                         ; else return
.cancelComExit:
    add.l   4,SP                ; remove return pointer from stack
    rts                         ; and return to monitor

;    bss
; variables stored at end of code
variables:
X1: ds.x    1
Y1: ds.x    1
I1: ds.x    1
I2: ds.x    1
I3: ds.x    1
R1: ds.x    1
R2: ds.x    1
R3: ds.x    1
S1: ds.x    1
S2: ds.x    1
Z1: ds.x    1
Z2: ds.x    1
vA: ds.x    1
vB: ds.x    1
LP: ds.w    1               ; loop counter
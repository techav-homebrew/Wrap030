
width:      equ 160
height:     equ 200
vidAddr:    equ $80800000

loops:      equ 8              ; how many loops before starting over

; use https://mandel.gart.nz/ to find center values
initCenterR:    fequ.d -0.5
initCenterI:    fequ.d  0.0

endCenterR:     fequ.d -0.374004139
endCenterI:     fequ.d  0.659792175

endZoom:        fequ.d 50000000.0

initWidth:      fequ.d 3.0
initHeight:     fequ.d 2.0

; use above to calculate starting extents:
; R1 < X < R2
; I1 < Y < I2
initR1:     fequ.d initCenterR-(initWidth/2)
initR2:     fequ.d initCenterR+(initWidth/2)
initI1:     fequ.d initCenterI-(initHeight/2)
initI2:     fequ.d initCenterI+(initHeight/2)

; calculate end zoom:
endWidth:   fequ.d initWidth/endZoom
endHeight:  fequ.d initHeight/endZoom

; calculate end extents:
endR1:      fequ.d endCenterR-(endWidth/2)
endR2:      fequ.d endCenterR+(endWidth/2)
endI1:      fequ.d endCenterI-(endHeight/2)
endI2:      fequ.d endCenterI+(endHeight/2)

; deltas below are added to extents each cycle to zoom & recenter
deltaR1:    fequ.d 0-((initR1-endR1)/(loops))
deltaR2:    fequ.d 0-((initR2-endR2)/(loops))
deltaI1:    fequ.d 0-((initI1-endI1)/(loops))
deltaI2:    fequ.d 0-((initI2-endI2)/(loops))

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
    fmove.d FP0,X1(A1)
    move.l  #height-1,D1    ; Y1=height-1
    fmove.l D1,FP0
    fmove.d FP0,Y1(A1)
    fmove.d #initI1,FP0       ; I1=-1.0
    fmove.d FP0,I1(A1)
    fmove.d #initI2,FP0        ; I2=1.0
    fmove.d FP0,I2(A1)
    fmove.d #initR1,FP0       ; R1=-2.0
    fmove.d FP0,R1(A1)
    fmove.d #initR2,FP0        ; R2=1.0
    fmove.d FP0,R2(A1)

calcLoop:
    ; 30 S1=(R2-R1)/X1:S2=(I2-I1)/Y1

    ; S1=(R2-R1)/X1
    fmove.d R2(A1),FP0      ; FP0=R2
    fsub.d  R1(A1),FP0      ; FP0=FP0-R1=R2-R1
    fdiv.d  X1(A1),FP0      ; FP0=FP0/X1=(R2-R1)/X1
    fmove.d FP0,S1(A1)      ; S1=FP0

    ; S2=(I2-I1)/Y1
    fmove.d I2(A1),FP0      ; FP0=I2
    fsub.d  I1(A1),FP0      ; FP0=FP0-I1=I2-I1
    fdiv.d  Y1(A1),FP0      ; FP0=FP0/Y1=(I2-I1)/Y1
    fmove.d FP0,S2(A1)      ; S2=FP0

    ; FOR Y=0 TO Y1 STEP 2
    move.l  #0,D3           ; Y=0

nextY:
    bsr     cancelCheck     ; start of each line, check for Ctrl-C
    ; I3=I1+S2*Y
    fmove.l D3,FP0          ; FP0=Y
    fmul.d  S2(A1),FP0      ; FP0=FP0*S2=Y*S2
    fadd.d  I1(A1),FP0      ; FP0=FP0+I1=(S2*Y)+I1
    fmove.d FP0,I3(A1)      ; I3=FP0

    ; FOR X=0 TO X1
    move.l  #0,D2           ; X=0

nextX:
    ; 70 R3=R1+S1*X:Z1=R3:Z2=I3

    ; R3=R1+S1*X
    fmove.l D2,FP0          ; FP0=X
    fmul.d  S1(A1),FP0      ; FP0=FP0*S1=X*S1
    fadd.d  R1(A1),FP0      ; FP0=FP0+R1=(X*S1)+R1
    fmove.d FP0,R3(A1)      ; R3=FP0

    ; Z1=R3
    fmove.d FP0,Z1(A1)      ; Z1=FP0=R3

    ; Z2=I3
    fmove.d I3(A1),FP0      ; FP0=I3
    fmove.d FP0,Z2(A1)      ; Z2=FP0=I3

    ; FOR N=0 TO 15
    move.w  #0,D4           ; N=0

nextN:
    ; 90 A=Z1*Z1:B=Z2*Z2

    ; A=Z1*Z1
    fmove.d Z1(A1),FP0      ; FP0=Z1
    fmul.x  FP0,FP0         ; FP0=FP0*FP0=Z1*Z1
    fmove.d FP0,vA(A1)      ; A=FP0

    ; B=Z2*Z2
    fmove.d Z2(A1),FP0      ; FP0=Z2
    fmul.x  FP0,FP0         ; FP0=FP0*FP0=Z2*Z2
    fmove.d FP0,vB(A1)      ; B=FP0

    ; 100 IF A+B>4.0 THEN GOTO 130

    fmove.d vA(A1),FP0      ; FP0=A
    fadd.d  vB(A1),FP0      ; FP0=A+B
    fcmp.d  #4.0,FP0        ; FP0-4.0
    fbgt    drawPixel       ; if FP0>4.0, goto [drawPixel]

    ; 110 Z2=2*Z1*Z2+I3:Z1=A-B+R3

    ; Z2=2*Z1*Z2+I3
    fmove.d Z1(A1),FP0      ; FP0=Z1
    fadd.x  FP0,FP0         ; FP0=FP0+FP0=Z1+Z1=Z1*2
    fmul.d  Z2(A1),FP0      ; FP0=FP0*Z2
    fadd.d  I3(A1),FP0      ; FP0=FP0+I3
    fmove.d FP0,Z2(A1)      ; Z2=FP0

    ; Z1=A-B+R3
    fmove.d vA(A1),FP0
    fsub.d  vB(A1),FP0
    fadd.d  R3(A1),FP0
    fmove.d FP0,Z1(A1)

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

    fmove.d R1(A1),FP0      ; R1=R1+deltaR1
    fadd.d  #deltaR1,FP0
    fmove.d FP0,R1(A1)

    fmove.d R2(A1),FP0      ; R2=R2+deltaR2
    fadd.d  #deltaR2,FP0
    fmove.d FP0,R2(A1)

    fmove.d I1(A1),FP0      ; I1=I1+deltaR1
    fadd.d  #deltaI1,FP0
    fmove.d FP0,I1(A1)

    fmove.d I2(A1),FP0      ; I2=I2+deltaI2
    fadd.d  #deltaI2,FP0
    fmove.d FP0,I2(A1)

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
X1: ds.d    1
Y1: ds.d    1
I1: ds.d    1
I2: ds.d    1
I3: ds.d    1
R1: ds.d    1
R2: ds.d    1
R3: ds.d    1
S1: ds.d    1
S2: ds.d    1
Z1: ds.d    1
Z2: ds.d    1
vA: ds.d    1
vB: ds.d    1
LP: ds.w    1               ; loop counter
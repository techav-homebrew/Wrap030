|; supervisor global variables
    .section bss,"w"

supvGlobals:

datStackStart:  ds.l    1024                |; supervisor dat stack
datStackEnd:

datBuffer:      ds.l    1024                |; supervisor working buffer
datBufferEnd:

opStackStart:   ds.l    256                 |; supervisor op stack
opStackEnd:

ptrOpStack:     ds.l    1                   |; save pointer to op stack
ptrDatStack:    ds.l    1                   |; save pointer to dat stack

ptrBuf          ds.l    1                   |; tsmon pointer to line buffer
supvParam       ds.l    1                   |; tsmon last parameter



|; supervisor constants

    .equ    supvErrGeneric          0
    .equ    supvErrOpStackFull      1
    .equ    supvErrOpStackEmpty     2
    .equ    supvErrDatStackFull     3
    .equ    supvErrDatStackEmpty    4
    .equ    supvErrBadCommand       5
    .equ    supvErrBadParam         6


|; supervisor operation codes

    .equ    supvOpNone              0
    .equ    supvOpPopChar           1
    .equ    supvOpPutChar           2
    .equ    supvOpGetChar           3
    .equ    supvOpPutStr            4
    .equ    supvOpPutStrLoop        5
    .equ    supvOpPutBS             6
    .equ    supvOpPutCR             7
    .equ    supvOpPutLF             8
    .equ    supvOpGetStr            9
    .equ    supvOpParseLine         10


|; special character codes

    .equ    charCR                  0x0d
    .equ    charLF                  0x0a
    .equ    charBackspace           0x08
    .equ    charDelete              0x7f
    .equ    charCtrlC               0x03
    .equ    charEscape              0x1b
    .equ    charSpace               0x20
    .equ    charTilde               0x7e


|; print character at specific screen location
|;  Parameters:
|;      %d0.b   character to print
|;      %d1.w   X coordinate (0<=X<80)
|;      %d2.w   Y coordinate (0<=Y<50)
|;  Returns:
|;      None
|;  Clobbers:
|;      None
vidPrintCharAt:
    movem.l %a0-%a1/%d3-%d4,%sp@-       |; save working registers
    lea     fonttable,%a0               |; get pointer to font data table
    lea     %a0@(%d0.b*8)               |; get pointer to char font data
    lea     vidBase,%a1                 |; get pointer to start of video
    lea     %a1@(%d2.w*8)               |; get pointer to start of where char
                                        |; will be drawn on screen
    moveq   #7,%d3                      |; initialize loop counter
    move.w  %d2,%d4
.vidPrintCharAtLp:
    bsr     vidBMexpand2bpp             |; expand bitmap data
    ror.w   #8,%d0                      |; rotate first bitmap byte to position
    move.b  %d0,%a1@(%d4.w*2)           |; write first bitmap byte
    ror.w   #8,%d0                      |; rotate second bitmap byte to position
    move.b  %d0,%a1@(1,%d4.w*2)         |; write second bitmap byte
    adda.l  #160,%a1                    |; increment pointer to next line
    dbra    %d3,.vidPrintCharAtLp
    movem.l %sp@+,%a0-%a1/%d3-%d4       |; restore working registers
    rts



|; scroll video up 8 lines
|;  Parameters:
|;      None
|;  Returns:
|;      None
|;  Clobbers:
|;      None
vidScrollUp8px:
    movem.l %a0/%d0-%d1,%sp@-           |; save working registers
    lea     vidBase,%a0                 |; get pointer to base of memory
    move.l  #30399,%d0                  |; initialize loop counter
    move.w  #1600,%d1                   |; load offset between lines
.vidScrollUp8Loop:
    move.b  %a0@(%d1.w),%a0@+           |; copy byte from 8 lines ahead
    dbra    %d0,.vidScrollUp8Loop       |; loop 
    movem.l %sp@+,%a0/%d0-%d1           |; restore working registers
    rts


|; expand a byte of 1bpp bitmap data into a word of 2bpp bitmap data
|; using only black and white 
|;  Parameters:
|;      %d0.b   input 1bpp bitmap data
|;  Returns:
|;      %d0.w   output 2bpp bitmap data
|;  Clobbers:
|;      %d1.l   general working register
|;      %d2.l   loop counter
vidBMexpand2bpp:
    and.l   #0x000000ff,%d0             |; clear upper 24 bits
    moveq   #1,%d1                      |; lots of shifting by 1 will follow
    ror.l   #7,%d0                      |; isolate highest bit in low word
    lsl.w   %d1,%d0                     |; shift up by one so it can be copied
    moveq   #6,%d2                      |; repeat 7 times
.vidBMexpand2CopyLoop:
    rol.l   %d1,%d0                     |; get next bit
    lsl.w   %d1,%d0                     |; shift it up so it can be copied
    dbra    %d2,.vidBMexpand2CopyLoop   |; repeat for the remaining bytes
    |; at this point, the one byte of video data should be expanded to one word
    |; with a one-bit space between each bit of video data.
    |; copy the word, shift right by one, then OR with itself so that every 1
    |; in the original bitmap data will be 11 in the output
    move.w  %d0,%d2                     |; copy
    lsr.w   %d1,%d2                     |; shift right by 1
    or.w    %d2,%d0                     |; or with result
    rts

|; expand a byte of 1bpp bitmap data into a longword of 4bpp bitmap data
|; using foreground & background colors
|;  Parameters:
|;      %d0.b   input 1bpp bitmap data
|;      %d1.b   foreground color in lower 4 bits
|;      %d2.b   background color in lower 4 bits
|;  Returns:
|;      %d0.b   original input 1bpp bitmap data
|;      %d4.l   output 4bpp bitmap data
|;  Clobbers:
|;      %d1.l   upper 28 bits cleared
|;      %d2.l   upper 28 bits cleared
|;      %d4.l   working register for building output longword
|;      %d5.l   loop counter
vidBMexpand4bpp:
    eor.l   %d4,%d4                     |; clear working register
    and.l   #0x0f,%d1                   |; mask out all but the color data from
    and.l   #0x0f,%d2                   |;  our color input parameters
    moveq   #7,%d5                      |; initialize loop counter
.vidBMexpand4CopyLoop:
    btst.b  %d5,%d0                     |; check bit
    bne.s   .vidBMexpand4bkg
    or.l    %d1,%d4                     |; copy foreground color to next position
    beq.s   .vidBMexpand4next
.bidBMexpand4bkg:
    or.l    %d2,%d4                     |; copy foreground color to next position
.vidBMexpand4next:
    rol.l   #4,%d4                      |; shift into next position
    dbra    %d5,.vidBMexpand4CopyLoop   |; continue loop for all 8 bits
    ror.l   #4,%d4                      |; undo the last rotate
    rts
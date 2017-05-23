*      
* GRLIB -- hires bitmap graphics library
*
* Basically just a modified BLARG
*
* SLJ 5/20/00
*
         * $C000

* Constants

CHROUT   = $FFD2

X1       = $02
Y1       = $04
X2       = $06
Y2       = $08
DX       = $0A
DY       = $0C
ROW      = $0D            ;Bitmap row
COL      = $0E            ;and column
INRANGE  = $0F            ;Range check flag

RADIUS   = $10

CHUNK1   = $11            ;Circle routine stuff
OLDCH1   = $12
CHUNK2   = $13
OLDCH2   = $14
CX       = DX
CY       = DY
X        = $15
Y        = $16
LCOL     = $17            ;Left column
RCOL     = $18
TROW     = $19            ;Top row
BROW     = $1A            ;Bottom row
RANGE1   = $1B
RANGE2   = INRANGE

POINT    = $1C
TEMP2    = $1E
TEMP     = $20            ;1 byte


*
* Jump table
*
         JMP InitGr
         JMP SetOrg
         JMP GRON
         JMP GROFF
         JMP SETCOLOR
         JMP MODE
         JMP BUFFER
         JMP SWAPBUF
         JMP PLOT
         JMP PLOTABS
         JMP LINE
         JMP CIRCLE

         TXT 'judd-o-rama'

*
* Initialize stuff
*
InitGr   
         LDA #00
         STA ORGX
         STA ORGY

         STA BANK
         LDA #$E0
         STA BASE

         LDA #$FF
         STA DONTPLOT
         STA BITMASK

         LDA #17
         STA MODENUM
         RTS

*
* Set center of screen
* .X = x-coord, .Y = y-coord
*

ORGX     DFB 00
ORGY     DFB 00

SetOrg   
         STX ORGX
         STY ORGY
         RTS

*
* PLOT -- plot the point in x1,y1
*
* Note that x1 and y1 are 16-bit!
*
* Out of range values are allowed and
* computed, so that pointer updates
* will work correctly.  ROW and COL are
* computed for reference by other
* routines.
*
* INRANGE is set to 0 if point is on screen
*

DONTPLOT DFB 01           ;0=Don't plot point, just compute
                          ;coordinates (used by e.g. circles)
PLOT     
         LDA Y1
         SEC
         SBC ORGY
         STA Y1
         BCS :C1
         DEC Y1+1
         SEC
:C1      LDA X1
         SBC ORGX
         STA X1
         BCS PLOTABS
         DEC X1+1

PLOTABS  
         LDA Y1
         STA ROW
         AND #7
         TAY
         LDA Y1+1
         LSR              ;Neg is possible
         ROR ROW
         LSR
         ROR ROW
         LSR
         ROR ROW

         LDA #00
         STA POINT
         LDA ROW
         CMP #$80
         ROR
         ROR POINT
         CMP #$80
         ROR
         ROR POINT        ;row*64
         ADC ROW          ;+row*256
         CLC
         ADC BASE         ;+bitmap base
         STA POINT+1

         LDA X1
         TAX
         STA COL
         LDA X1+1
         LSR
         ROR COL
         LSR
         ROR COL
         LSR
         ROR COL

         TXA
         AND #$F8
         CLC
         ADC POINT        ;+(X AND #$F8)
         STA POINT
         LDA X1+1
         ADC POINT+1
         STA POINT+1
         TXA
         AND #7
         TAX

         LDA ROW
         CMP #25
         BCS :rts
         LDA COL
         CMP #40
         BCS :rts

         LDA DONTPLOT
         BEQ :rts
         SEI              ;Get underneath ROM
         LDA $01
         PHA
         LDA #$34
         STA $01

         LDA (POINT),Y
         EOR BITMASK
         AND BITTAB,X
         EOR (POINT),Y
         STA (POINT),Y

         PLA
         STA $01
         CLI
         LDA #00
:rts     STA INRANGE
         RTS

*-------------------------------
         DO 0
SETPOINT                  ;Alternative entry point
                          ;X=y-coord, LINNUM=x-coord
                          ;On exit, X,Y are AND #$07
                          ;i.e. are set up correctly.
         TXA
         AND #248
         STA POINT
         LSR
         LSR
         LSR
         ADC BASE         ;Base of bitmap
         STA POINT+1
         LDA #00
         ASL POINT
         ROL
         ASL POINT
         ROL
         ASL POINT
         ROL
         ADC LINNUM+1
         ADC POINT+1
         STA POINT+1
         TXA
         AND #7
         TAY
         LDA LINNUM
         AND #248
         CLC              ;Overflow is possible!
         ADC POINT
         STA POINT
         BCC SETPIXEL
         INC POINT+1
SETPIXEL 
         LDA LINNUM
         AND #$07
         TAX
         LDA DONTPLOT
         BEQ :RTS
         LDA POINT+1
         SEC
         SBC BASE         ;Overflow check
         CMP #$20
         BCS :RTS
         SEI              ;Get underneath ROM
         LDA #$34
         STA $01

         LDA (POINT),Y
         EOR BITMASK
         AND BITTAB,X
         EOR (POINT),Y
         STA (POINT),Y

         LDA #$37
         STA $01
         CLI
* LDX TEMP2
* LDY TEMP2+1
                          ;On exit, X,Y are AND #$07
                          ;i.e. are set up correctly.
                          ;for more plotting
:RTS     RTS
         FIN
*-------------------------------

BITMASK  DFB #$FF         ;Set point
BITTAB   DFB $80,$40,$20,$10,$08,$04,$02,$01


*-------------------------------
* Drawin' a line.  A fahn lahn.
*
* To deal with off-screen coordinates, the current row
* and column (40x25) is kept track of.  These are set
* negative when the point is off the screen, and made
* positive when the point is within the visible screen.

* Little bit position table
BITCHUNK HEX FF7F3F1F0F070301
CHUNK    EQU X2
OLDCHUNK EQU X2+1

* DOTTED -- Set to $01 if doing dotted draws (diligently)
* X1,X2 etc. are set up above (x2=LINNUM in particular)
* Format is LINE x2,y2,x1,y1

LINE     

:CHECK   LDA X2           ;Make sure x1<x2
         SEC
         SBC X1
         TAX
         LDA X2+1
         SBC X1+1
         BPL :CONT
         LDA Y2           ;If not, swap P1 and P2
         LDY Y1
         STA Y1
         STY Y2
         LDA Y2+1
         LDY Y1+1
         STA Y1+1
         STY Y2+1
         LDA X1
         LDY X2
         STY X1
         STA X2
         LDA X2+1
         LDY X1+1
         STA X1+1
         STY X2+1
         BCC :CHECK

:CONT    STA DX+1
         STX DX

         LDX #$C8         ;INY
         LDA Y2           ;Calculate dy
         SEC
         SBC Y1
         TAY
         LDA Y2+1
         SBC Y1+1
         BPL :DYPOS       ;Is y2>=y1?
         LDA Y1           ;Otherwise dy=y1-y2
         SEC
         SBC Y2
         TAY
         LDX #$88         ;DEY

:DYPOS   STY DY           ;8-bit DY -- FIX ME?
         STX YINCDEC
         STX XINCDEC

         LDA #00
         STA DONTPLOT
         JSR PLOT         ;Set up .X,.Y,POINT, and INRANGE
         INC DONTPLOT
         LDA BITCHUNK,X
         STA OLDCHUNK
         STA CHUNK

         SEI              ;Get underneath ROM
         LDA #$34
         STA $01

         LDX DY
         CPX DX           ;Who's bigger: dy or dx?
         BCC STEPINX      ;If dx, then...
         LDA DX+1
         BNE STEPINX

*
* Big steps in Y
*
*   To simplify my life, just use PLOT to plot points.
*
*   No more!
*   Added special plotting routine -- cool!
*
*   X is now counter, Y is y-coordinate
*
* On entry, X=DY=number of loop iterations, and Y=
*   Y1 AND #$07
STEPINY  
         LDA #00
         STA OLDCHUNK     ;So plotting routine will work right
         LDA CHUNK
         LSR              ;Strip the bit
         EOR CHUNK
         STA CHUNK
         TXA
         BNE :CONT        ;If dy=0 it's just a point
         INX
:CONT    LSR              ;Init counter to dy/2
*
* Main loop
*
YLOOP    STA TEMP

         LDA INRANGE      ;Range check
         BNE :SKIP

         LDA (POINT),Y    ;Otherwise plot
         EOR BITMASK
         AND CHUNK
         EOR (POINT),Y
         STA (POINT),Y
:SKIP    
YINCDEC  INY              ;Advance Y coordinate
         CPY #8
         BCC :CONT        ;No prob if Y=0..7
         JSR FIXY
:CONT    LDA TEMP         ;Restore A
         SEC
         SBC DX
         BCC YFIXX
YCONT    DEX              ;X is counter
         BNE YLOOP
YCONT2   LDA (POINT),Y    ;Plot endpoint
         EOR BITMASK
         AND CHUNK
         EOR (POINT),Y
         STA (POINT),Y
YDONE    
         LDA #$37
         STA $01
         CLI
         RTS

YFIXX                     ;x=x+1
         ADC DY
         LSR CHUNK
         BNE YCONT        ;If we pass a column boundary...
         ROR CHUNK        ;then reset CHUNK to $80
         STA TEMP2
         LDA COL
         BMI :C1          ;Skip if column is negative
         CMP #39          ;End if move past end of screen
         BCS YDONE
:C1      
         LDA POINT        ;And add 8 to POINT
         ADC #8
         STA POINT
         BCC :CONT
         INC POINT+1
:CONT    INC COL          ;Increment column
         BNE :C2
         LDA ROW          ;Range check
         CMP #25
         BCS :C2
         LDA #00          ;Passed into col 0
         STA INRANGE
:C2      LDA TEMP2
         DEX
         BNE YLOOP
         BEQ YCONT2

*
* Big steps in X direction
*
* On entry, X=DY=number of loop iterations, and Y=
*   Y1 AND #$07

COUNTHI  DFB 00           ;Temporary counter
                          ;only used once
STEPINX  
         LDX DX
         LDA DX+1
         STA COUNTHI
         CMP #$80
         ROR              ;Need bit for initialization
         STA Y1           ;High byte of counter
         TXA
         BNE :CONT        ;Could be $100
         DEC COUNTHI
:CONT    ROR
*
* Main loop
*
XLOOP    
         LSR CHUNK
         BEQ XFIXC        ;If we pass a column boundary...
XCONT1   SBC DY
         BCC XFIXY        ;Time to step in Y?
XCONT2   DEX
         BNE XLOOP
         DEC COUNTHI      ;High bits set?
         BPL XLOOP
XDONE    
         LSR CHUNK        ;Advance to last point
         JSR LINEPLOT     ;Plot the last chunk
EXIT     LDA #$37
         STA $01
         CLI
         RTS
*
* CHUNK has passed a column, so plot and increment pointer
* and fix up CHUNK, OLDCHUNK.
*
XFIXC    
         STA TEMP
         JSR LINEPLOT
         LDA #$FF
         STA CHUNK
         STA OLDCHUNK
         LDA COL
         BMI :C1          ;Skip if column is negative
         CMP #39          ;End if move past end of screen
         BCS EXIT
:C1      
         LDA POINT
         ADC #8
         STA POINT
         BCC :CONT
         INC POINT+1
:CONT    INC COL
         BNE :C2
         LDA ROW
         CMP #25
         BCS :C2
         LDA #00
         STA INRANGE
:C2      LDA TEMP
         SEC
         BCS XCONT1
*
* Check to make sure there isn't a high bit, plot chunk,
* and update Y-coordinate.
*
XFIXY    
         DEC Y1           ;Maybe high bit set
         BPL XCONT2
         ADC DX
         STA TEMP
         LDA DX+1
         ADC #$FF         ;Hi byte
         STA Y1

         JSR LINEPLOT     ;Plot chunk
         LDA CHUNK
         STA OLDCHUNK

         LDA TEMP
XINCDEC  INY              ;Y-coord
         CPY #8           ;0..7 is ok
         BCC XCONT2
         STA TEMP
         JSR FIXY
         LDA TEMP
         JMP XCONT2

*
* Subroutine to plot chunks/points (to save a little
* room, gray hair, etc.)
*
LINEPLOT                  ;Plot the line chunk

         LDA INRANGE
         BNE :SKIP

         LDA (POINT),Y    ;Otherwise plot
         EOR BITMASK
         ORA CHUNK
         AND OLDCHUNK
         EOR CHUNK
         EOR (POINT),Y
         STA (POINT),Y
:SKIP    
         RTS

*
* Subroutine to fix up pointer when Y decreases through
* zero or increases through 7.
*
FIXY     CPY #255         ;Y=255 or Y=8
         BEQ :DECPTR
:INCPTR                   ;Add 320 to pointer
         LDY #0           ;Y increased through 7
         LDA ROW
         BMI :C1          ;If negative, then don't update
         CMP #24
         BCS :TOAST       ;If at bottom of screen then quit
:C1      
         LDA POINT
         ADC #<320
         STA POINT
         LDA POINT+1
         ADC #>320
         STA POINT+1
:CONT1   INC ROW
         BNE :RTS
         LDA COL
         BMI :RTS
         LDA #00
         STA INRANGE
:RTS     RTS
:DECPTR                   ;Okay, subtract 320 then
         LDY #7           ;Y decreased through 0
         LDA POINT
         SEC
         SBC #<320
         STA POINT
         LDA POINT+1
         SBC #>320
         STA POINT+1
:CONT2   DEC ROW
         BMI :TOAST
         LDA ROW
         CMP #24
         BNE :RTS
         LDA COL
         BMI :RTS
         LDA #00
         STA INRANGE
         RTS
:TOAST   PLA              ;Remove old return address
         PLA
         JMP EXIT         ;Restore interrupts, etc.

*
* CIRCLE draws a circle of course, using my
* super-sneaky algorithm.
*
* Center of circle is at x1,y1
* Radius of circle in RADIUS
*

CIRCLE   
         LDA RADIUS
         STA Y
         BNE :c1
         JMP PLOT         ;Plot as a point
:c1      
         CLC
         ADC Y1
         STA Y1
         BCC :c2
         INC Y1+1
:c2      LDA #00
         STA DONTPLOT
         JSR PLOT         ;Compute XC, YC+R

         LDA INRANGE      ;Track row/col separately
         STA RANGE1
         LDA ROW
         STA BROW
         LDA COL
         STA LCOL
         STA RCOL

         STY Y2           ;Y AND 07
         LDA BITCHUNK,X
         STA CHUNK1       ;Forwards chunk
         STA OLDCH1
         LSR
         EOR #$FF
         STA CHUNK2       ;Backwards chunk
         STA OLDCH2
         LDA POINT
         STA TEMP2        ;TEMP2 = forwards high pointer
         STA X2           ;X2 = backwards high pointer
         LDA POINT+1
         STA TEMP2+1
         STA X2+1

* Next compute CY-R

         LDA Y1
         SEC
         SBC RADIUS
         BCS :C3
         DEC Y1+1
         SEC
:C3      SBC RADIUS
         BCS :C4
         DEC Y1+1
:C4      STA Y1

         JSR PLOTABS      ;Compute new coords
         STY Y1
         LDA POINT
         STA X1           ;X1 will be the backwards
         LDA POINT+1      ;low-pointer
         STA X1+1         ;POINT will be forwards
         LDA ROW
         STA TROW
* LDA INRANGE
* STA RANGE2 ;RANGE2=INRANGE

         INC DONTPLOT

         SEI              ;Get underneath ROM
         LDA #$34
         STA $01

         LDA RADIUS
         LSR              ;A=r/2
         LDX #00
         STX X            ;y=0

* Main loop

:LOOP    
         INC X            ;x=x+1

         LSR CHUNK1       ;Right chunk
         BNE :CONT1
         JSR UPCHUNK1     ;Update if we move past a column
:CONT1   ASL CHUNK2
         BNE :CONT2
         JSR UPCHUNK2
:CONT2                    ;LDA TEMP
         SEC
         SBC X            ;a=a-x
         BCS :LOOP

         ADC Y            ;if a<0 then a=a+y; y=y-1
         TAX
         JSR PCHUNK1
         JSR PCHUNK2
         LDA CHUNK1
         STA OLDCH1
         LDA CHUNK2
         STA OLDCH2
         TXA

         DEC Y            ;(y=y-1)

         DEC Y2           ;Decrement y-offest for upper
         BPL :CONT3       ;points
         JSR DECYOFF
:CONT3   LDY Y1
         INY
         STY Y1
         CPY #8
         BCC :CONT4
         JSR INCYOFF
:CONT4   
         LDY X
         CPY Y            ;if y<=x then punt
         BCC :LOOP        ;Now draw the other half
*
* Draw the other half of the circle by exactly reversing
* the above!
*
NEXTHALF 
         LSR OLDCH1       ;Only plot a bit at a time
         ASL OLDCH2
         LDA RADIUS       ;A=-R/2-1
         LSR
         EOR #$FF
:LOOP    
         TAX
         JSR PCHUNK1      ;Plot points
         JSR PCHUNK2
         TXA
         DEC Y2           ;Y2=bottom
         BPL :CONT1
         JSR DECYOFF
:CONT1   INC Y1
         LDY Y1
         CPY #8
         BCC :CONT2
         JSR INCYOFF
:CONT2   
         LDX Y
         BEQ :DONE
         CLC
         ADC Y            ;a=a+y
         DEC Y            ;y=y-1
         BCC :LOOP

         INC X
         SBC X            ;if a<0 then x=x+1; a=a+x
         LSR CHUNK1
         BNE :CONT3
         TAX
         JSR UPCH1        ;Upchunk, but no plot
:CONT3   LSR OLDCH1       ;Only the bits...
         ASL CHUNK2       ;Fix chunks
         BNE :CONT4
         TAX
         JSR UPCH2
:CONT4   ASL OLDCH2
         BCS :LOOP
:DONE    
CIRCEXIT                  ;Restore interrupts
         LDA #$37
         STA $01
         CLI
         LDA #1           ;Re-enable plotting
         STA DONTPLOT
         RTS
*
* Decrement lower pointers
*
DECYOFF  
         TAY
         LDA #7
         STA Y2

         LDA X2           ;If we pass through zero, then
         SEC
         SBC #<320        ;subtract 320
         STA X2
         LDA X2+1
         SBC #>320
         STA X2+1
         LDA TEMP2
         SEC
         SBC #<320
         STA TEMP2
         LDA TEMP2+1
         SBC #>320
         STA TEMP2+1

         TYA
         DEC BROW
         BMI EXIT2
         RTS
EXIT2    PLA              ;Grab return address
         PLA
         JMP CIRCEXIT     ;Restore interrupts, etc.

* Increment upper pointers
INCYOFF  
         TAY
         LDA #00
         STA Y1
         LDA X1
         CLC
         ADC #<320
         STA X1
         LDA X1+1
         ADC #>320
         STA X1+1
         LDA POINT
         CLC
         ADC #<320
         STA POINT
         LDA POINT+1
         ADC #>320
         STA POINT+1
:ISKIP   
         INC TROW
         BMI :RTS
         LDA TROW
         CMP #25
         BCS EXIT2
:RTS     TYA
         RTS

*
* UPCHUNK1 -- Update right-moving chunk pointers
*             Due to passing through a column
*
UPCHUNK1 
         TAX
         JSR PCHUNK1
UPCH1    LDA #$FF         ;Alternative entry point
         STA CHUNK1
         STA OLDCH1
         LDA TEMP2
         CLC
         ADC #8
         STA TEMP2
         BCC :CONT
         INC TEMP2+1
         CLC
:CONT    LDA POINT
         ADC #8
         STA POINT
         BCC :DONE
         INC POINT+1
:DONE    TXA
         INC RCOL
         RTS

*
* UPCHUNK2 -- Update left-moving chunk pointers
*
UPCHUNK2 
         TAX
         JSR PCHUNK2
UPCH2    LDA #$FF
         STA CHUNK2
         STA OLDCH2
         LDA X2
         SEC
         SBC #8
         STA X2
         BCS :CONT
         DEC X2+1
         SEC
:CONT    LDA X1
         SBC #8
         STA X1
         BCS :DONE
         DEC X1+1
:DONE    TXA
         DEC LCOL
         RTS
*
* Plot right-moving chunk pairs for circle routine
*
PCHUNK1  

         LDA RCOL         ;Make sure we're in range
         CMP #40
         BCS :SKIP2
         LDA CHUNK1       ;Otherwise plot
         EOR OLDCH1
         STA TEMP
         LDA TROW         ;Check for underflow
         BMI :SKIP
         LDY Y1
         LDA (POINT),Y
         EOR BITMASK
         AND TEMP
         EOR (POINT),Y
         STA (POINT),Y

:SKIP    LDA BROW         ;If CY+Y >= 200...
         CMP #25
         BCS :SKIP2
         LDY Y2
         LDA (TEMP2),Y
         EOR BITMASK
         AND TEMP
         EOR (TEMP2),Y
         STA (TEMP2),Y
:SKIP2   
         RTS

*
* Plot left-moving chunk pairs for circle routine
*
PCHUNK2  

         LDA LCOL         ;Range check in X
         CMP #40
         BCS :SKIP2
         LDA CHUNK2       ;Otherwise plot
         EOR OLDCH2
         STA TEMP
         LDA TROW         ;Check for underflow
         BMI :SKIP
         LDY Y1
         LDA (X1),Y
         EOR BITMASK
         AND TEMP
         EOR (X1),Y
         STA (X1),Y

:SKIP    LDA BROW         ;If CY+Y >= 200...
         CMP #25
         BCS :SKIP2
         LDY Y2
         LDA (X2),Y
         EOR BITMASK
         AND TEMP
         EOR (X2),Y
         STA (X2),Y
:SKIP2   
         RTS

*
* GRON -- turn graphics on.
*
* .A = 0 -> Turn bitmap on
*
* Otherwise, initialize colomap to .A
* and clear bitmap.
*

BASE     DFB $E0          ;Address of bitmap, hi byte
BANK     DFB 0            ;Bank 3=default
OLDBANK  DFB $FF          ;VIC old bank
OLDD018  DFB 00

GRON     
         TAX
         LDA $D011        ;Skip if bitmap is already on.
         AND #$20
         BNE CLEAR
         LDA $DD02        ;Set the data direction regs
         ORA #3
         STA $DD02
         LDA $DD00
         PHA
         AND #$03
         STA OLDBANK
         PLA
         AND #252
         ORA BANK
         STA $DD00

         LDA $D018
         STA OLDD018
         LDA #$38         ;Set color map to base+$1C00
         STA $D018        ;bitmap to 2nd 8k

         LDA $D011        ;And turn on bitmap
         ORA #$20
         STA $D011

CLEAR    TXA
         BEQ GRONDONE
CLEARCOL 
         LDY #$00
         LDA BASE         ;Colormap is at base-$14
         CMP #$A0
         BNE ClearE000
:A000    TXA
:l1      STA $8C00,Y
         STA $8D00,Y
         STA $8E00,Y
         STA $8F00,Y
         INY
         BNE :l1
         TYA
:l2      STA $A000,Y
         STA $A100,Y
         STA $A200,Y
         STA $A300,Y
         STA $A400,Y
         STA $A500,Y
         STA $A600,Y
         STA $A700,Y
         STA $A800,Y
         STA $A900,Y
         STA $AA00,Y
         STA $AB00,Y
         STA $AC00,Y
         STA $AD00,Y
         STA $AE00,Y
         STA $AF00,Y
         STA $B000,Y
         STA $B100,Y
         STA $B200,Y
         STA $B300,Y
         STA $B400,Y
         STA $B500,Y
         STA $B600,Y
         STA $B700,Y
         STA $B800,Y
         STA $B900,Y
         STA $BA00,Y
         STA $BB00,Y
         STA $BC00,Y
         STA $BD00,Y
         STA $BE00,Y
         STA $BF00,Y
         INY
         BNE :l2
GRONDONE RTS

ClearE000
         SEI
         LDA $01
         PHA
         AND #$FC
         STA $01
:l0      LDA $FFFA,Y
         STA :temp,Y
         INY
         CPY #6
         BNE :l0
         PLA
         STA $01
         CLI

         LDY #$00
         TXA
:l1      STA $CC00,Y
         STA $CD00,Y
         STA $CE00,Y
         STA $CF00,Y
         INY
         BNE :l1
         TYA
:l2      STA $E000,Y
         STA $E100,Y
         STA $E200,Y
         STA $E300,Y
         STA $E400,Y
         STA $E500,Y
         STA $E600,Y
         STA $E700,Y
         STA $E800,Y
         STA $E900,Y
         STA $EA00,Y
         STA $EB00,Y
         STA $EC00,Y
         STA $ED00,Y
         STA $EE00,Y
         STA $EF00,Y
         STA $F000,Y
         STA $F100,Y
         STA $F200,Y
         STA $F300,Y
         STA $F400,Y
         STA $F500,Y
         STA $F600,Y
         STA $F700,Y
         STA $F800,Y
         STA $F900,Y
         STA $FA00,Y
         STA $FB00,Y
         STA $FC00,Y
         STA $FD00,Y
         STA $FE00,Y
         STA $FF00,Y
         INY
         BNE :l2
:l3      LDA :temp,Y
         STA $FFFA,Y
         INY
         CPY #6
         BNE :l3
         RTS

:temp    ds 6


* GROFF -- Restore old values if graphics are on.
GROFF    
         LDA $D011
         AND #$20
         BEQ GDONE
GSET     LDA $DD02        ;Set the data direction regs
         ORA #3
         STA $DD02
         LDA $DD00
         AND #$7C
         ORA OLDBANK
         STA $DD00

         LDA OLDD018
         STA $D018

         LDA $D011
         AND #$FF-$20
         STA $D011
GDONE    RTS

*
* SETCOLOR -- Set drawing color
*   .A = 0 -> background color
*   .A = 1 -> foreground color
*
SETCOLOR 
COLENT   CMP #00          ;MODE enters here
         BEQ :C2
:C1      CMP #01
         BNE :RTS
         LDA #$FF
:C2      STA BITMASK
:RTS     RTS

*
* MODE -- catch-all command.
*
* .X contains mode:
*
*   $10  SuperCPU mode -- screen -> A000, etc.
*   $11  Normal mode
*   $12  Double buffer mode
*
*  Anything else -> BITMASK
*
MODENUM  DFB 17           ;Current mode
MODE     
         CPX #16
         BNE :C18
         STX MODENUM
:SET16   LDA #$A0         ;Bitmap -> $A000
         STA BASE
         LDA #01
         STA BANK         ;Bank 2
         STA OLDBANK
         LDA #$FF         ;End of BASIC memory
         STA $37
         STA $33
         LDA #$87
         STA $38
         STA $34
         LDA #$24         ;Screen mem -> $8800
         STA OLDD018
         JSR GSET         ;Part of GROFF
         LDA #$88
         STA 648          ;Tell BASIC where the screen is
         STA $D07E        ;Enable SuperCPU regs
         STA $D074        ;Bank 2 optimization
         STA $D07F        ;Disable regs
         RTS
:C18     CPX #18          ;Double-buffer mode!
         BNE :C17
         STX MODENUM
         JSR :SET16       ;Set up mode 16
         STA $D07E
         STA $D077        ;Turn off optimization
         STA $D07F
         RTS
:C17     CPX #17
         BNE MODEDONE
MODE17   STX MODENUM
         LDA #$E0
         STA BASE
         LDA #00          ;Bank 3
         STA BANK
         LDA #3           ;Bank 0 == normal bank
         STA OLDBANK
         LDA #$FF
         STA $37
         STA $33
         LDA #$9F
         STA $38
         STA $34
         LDA #$14         ;Screen mem -> $0400
         STA OLDD018
         JSR GSET         ;Part of GROFF
         LDA #$04
         STA 648          ;Tell BASIC where the screen is
         STA $D07E
         STA $D077        ;No optimization
         STA $D07F
         RTS
MODEDONE STX BITMASK
         RTS


*
* BUFFER -- Sets the current drawing buffer to 1 or 2,
*
* .X = 0 Swap draw buffer
* .X = 1 Buffer 1 ($E000)
* .X = 2 Buffer 2 ($A000)
*

BUFFER   
         LDA MODENUM
         CMP #18
         BNE :PUNT
         LDY #$A0
         TXA
         BNE :CONT
         CPY BASE
         BNE :CONT
         LDA #1
:CONT    LSR
         BCC :LOW         ;even = low buffer
         LDY #$E0         ;odd = high buffer
:LOW     STY BASE
:PUNT    RTS

*
* SWAP -- Swap *displayed* buffers.  MODE 18 must
*   be enabled first.
*
SWAPBUF  
         LDA MODENUM
         CMP #18
         BNE :PUNT
         LDA $DD00        ;Ooooooohhh, real tough!
         EOR #$01
         STA $DD00
:PUNT    RTS
*=$4000 ;sys16384
;incbin "grtest.l.o",2 ;has 2 byte load address

;      
; A simple grlib test program
;
; SLJ 5/21/00
;

;
; grlib jump table
;
#region "Constants"
InitGr   = $C000
SetOrg   = InitGr+3
GRON     = SetOrg+3
GROFF    = GRON+3
SETCOLOR = GROFF+3
RESMODE     = SETCOLOR+3
SETBUF   = RESMODE+3 ;MODE appears to be reserved word
SWAPBUF  = SETBUF+3
PLOT     = SWAPBUF+3
PLOTABS  = PLOT+3
LINE     = PLOTABS+3
CIRCLE   = LINE+3

;
; grlib constants
;

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

POINT    = $FD            ;Bitmap pointer
#endregion

PlotTest 
         JSR InitGr

         LDA #00
         STA X1
         STA X1+1
         STA Y1
         STA Y1+1

         LDA #16          ;Init/turn on bitmap
         JSR GRON

PlotLoop    JSR PLOTABS      ;Don't bother with ORGX/ORGY
         LDA #5
         CLC
         ADC X1
         STA X1
         BCC PlotLoop
         INC X1+1
         LDA X1+1
         CMP #2           ;Overflow test
         BNE PlotLoop

         LDA #00
         STA X1+1

         LDA Y1
         CLC
         ADC #5
         STA Y1
         BCC PlotLoop

         JSR WAIT

LineTest                  ;Simple Moire pattern
         LDA #$1E
         JSR GRON         ;re-init bitmap

         LDA #00
         STA Color
         STA Direction
         LDA #$FF
         STA XC
         STA XC+1
         STA YC
         STA YC+1

LineLoop    LDA XC
         STA X1
         LDA XC+1
         STA X1+1
         LDA YC
         STA Y1
         LDA YC+1
         STA Y1+1

         LDA #00
         STA X2+1
         STA Y2+1
         LDA #77
         STA X2
         LDA #90
         STA Y2

         JSR LINE

         LDA Color
         EOR #1
         STA Color
         JSR SETCOLOR     ;Alternate draw/erase

         LDX Direction
         BEQ posx
         DEX
         BEQ posy
         DEX
         BEQ negx
negy    
         DEC YC
         BNE LineLoop

         JSR Wait
         JMP LineDone

negx                     ;   LDA XC
                          ;  ORA XC+1
                          ; BNE @dex
                          ;INC Direction
                          ;BNE @negy
@dex     LDA XC
         BNE @d1
         DEC XC+1
         BPL @d1
         DEC XC
         INC Direction
         BNE negy
@d1      DEC XC
jump     JMP LineLoop

posy    
         LDA YC
         CMP #210
         BNE @iny
         INC Direction
         BNE negx
@iny     INC YC
         BNE LineLoop
         INC YC+1
         JMP LineLoop

posx    
         LDA XC
         CMP #<330
         LDA XC+1
         SBC #>330
         BMI @inx
         INC Direction
         BNE posy
@inx     INC XC
         BNE jump
         INC XC+1
         JMP LineLoop
LineDone 
         LDA #$1E         ;Second test
         JSR GRON
         LDA #1
         JSR SetColor

         LDA #$01
         STA X1
         LDA #$00
         STA X1+1
         LDA #40
         STA X2
         STA Y2
         LDA #00
         STA X2+1
         STA Y2+1
         STA Y1+1
         LDA #70
         STA Y1
         JSR LINE
         JSR Wait


CircTest                  ;Simple circle stuff
         LDA #1
         JSR SETCOLOR

         LDA #$34
         JSR GRON

         LDA #00
         STA XC
         STA XC+1
         STA YC+1
         LDA #100
         STA YC

CircLoop    LDA XC
         STA X1
         LDA XC+1
         STA X1+1
         LDA YC
         STA Y1
         LDA YC+1
         STA Y1+1

         LDA X1
         LSR
         STA RADIUS

         JSR CIRCLE

         LDA XC
         CLC
         ADC #21
         STA XC
         BCC CircLoop
         INC XC+1
         LDA XC+1
         CMP #2
         BNE CircLoop

         JSR Wait

AllDone  
         JSR GROFF
         RTS

WAIT     JSR $FFE4
         BEQ WAIT
         RTS

XC       BYTE 00
YC       BYTE 00
Color    BYTE 00
Direction BYTE 00

*=$c000
incbin "grlib.r.o",2 ;has 2 byte load address
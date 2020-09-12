org &E00

tmp              = &70
title_ptr        = &72
title_page       = &74
screen           = &75
cursor           = &76
tmpy             = &78
mode             = &79
num_screens      = &7A
num_titles       = &7B
num              = &7D
pad              = &80
jump             = &81

saved_title_ptr  = &C00
saved_title_page = &C20
uart_mcr         = &FC34

OSRDCH           = &FFE0
OSASCI           = &FFE3
OSNEWL           = &FFE7
OSWRCH           = &FFEE
OSBYTE           = &FFF4
OSCLI            = &FFF7

LINES_PER_SCREEN = 21

.start_addr
{

    JSR print_string
    EQUS "Loading title data", 13

    ;; Load title data into &FDxx paged RAM
    LDX #<oscli_load_titles
    LDY #>oscli_load_titles
    JSR OSCLI

    ;; Select bank 1 in pages RAM, which is where titles have been loaded to
    LDA uart_mcr
    ORA #&08
    STA uart_mcr

    ;; Work out number of titles
    JSR count_titles

    ;; Start on screen 1
    LDA #1
    STA screen

    ;; Disable cursor editing so keys can be used to navigate
    LDA #4
    LDX #1
    JSR OSBYTE

    ;; Initialize screen
    JSR init_screen

    ;; Set update mode to slow
    LDA #0
    STA mode

.loop1

    LDA #&FF
    STA jump

    JSR disable_screen

    JSR update_screen_number

    ;; Search through the list title until screen N is reached
    ;; (this is potentially slow, but could be accelerated with an index)
    JSR skip_to_screen

    ;; Set "fast printing" cursor to line 2
    LDA #<(&4000 + 2 * 640)
    STA cursor
    LDA #>(&4000 + 2 * 640)
    STA cursor + 1

    ;; Display a screen full of titles
    LDX #0

.loop2
    ;; Save a pointer to this entry
    LDA title_ptr
    STA saved_title_ptr, X
    LDA title_page
    STA saved_title_page, X
    STA &FCFF

    ;; Read the first byte of the title
    LDY #0
    LDA (title_ptr), Y

    ;; End of titles?
    CMP #&FF
    BEQ process_done

    ;; End of page
    CMP #&FE
    BNE process_title

    ;; Skip to the next page
    INC title_page
    LDA #0
    STA title_ptr
    BEQ loop2

.process_title

    JSR print_title

    TYA
    CLC
    ADC title_ptr
    STA title_ptr

    INX
    CPX #LINES_PER_SCREEN
    BNE loop2

.process_done

    JSR enable_screen

.wait_for_key

    JSR OSRDCH

    CMP #'0'
    BCC not_0_9
    CMP #'9' +1
    BCS not_0_9
    JSR jump_to_screen
    BCS wait_for_key
    BCC loop1

.not_0_9
    CMP #&0D
    BNE not_return
    ;; Toggle fast mode bit
    LDA mode
    EOR #&80
    STA mode
    JMP loop1

.not_return
    CMP #&8A ;; Up arrow
    BNE not_screen_next
    JSR next_screen
    BCS wait_for_key
    BCC loop1

.not_screen_next
    CMP #&8B ;; Down arrow
    BNE not_screen_prev
    JSR prev_screen
    BCS wait_for_key
    BCC loop1

.not_screen_prev
    AND #&DF

    CMP #'A'+LINES_PER_SCREEN
    BCS wait_for_key
    CMP #'A'
    BCC wait_for_key

    ;; Get the address of the title in &FDxx paged RAM
    SBC #'A'
    TAX
    LDA saved_title_ptr, X
    STA title_ptr
    LDA saved_title_page, X
    STA title_page
    STA &FCFF

    ;; Construct the URL
    LDX #0

    ;; Get pointer to directory
    LDY #0
    LDA (title_ptr), Y
    TAY
    LDA dirlo,Y
    STA tmp
    LDA dirhi,Y
    STA tmp+1

    ;; Copy directory
    LDY #0
    JSR copy_tmp_string

    ;; Path sep
    LDA #'/'
    STA url, X
    INX

    ;; Copy Filename
    LDA title_ptr
    STA tmp
    LDA title_ptr+1
    STA tmp+1
    LDY #1
    JSR copy_tmp_string

    ;; A = suffix with bit set
    AND #&7F
    TAY
    LDA suflo,Y
    STA tmp
    LDA sufhi,Y
    STA tmp+1

    ;; Copy Suffix
    LDY #0
    JSR copy_tmp_string

    ;; Term
    LDA #13
    STA url, X

    ;; Mode 6
    LDA #22
    JSR OSWRCH
    LDA #6
    JSR OSWRCH

    ;; Enable cursor editing
    LDA #4
    LDX #0
    JSR OSBYTE

    ;; print *WGET for debugging
    LDX #0
.testloop
    LDA oscli_wget, X
    JSR OSASCI
    INX
    CMP #&0D
    BNE testloop

    ;; *WGET ...
    LDX #<oscli_wget
    LDY #>oscli_wget
    JSR OSCLI

    ;; *WICFS ...
    LDX #<oscli_wicfs
    LDY #>oscli_wicfs
    JSR OSCLI

    ;; *KEY 0 ...
    LDX #<oscli_key0
    LDY #>oscli_key0
    JSR OSCLI

    ;; Insert Key0 into Kbd Buffer
    LDA #&99
    LDX #&00
    LDY #&C0
    JMP OSBYTE
}

.commands
    EQUB "PAGE=&E00", &0D
    EQUB "NEW", &0D
    EQUB "CHAIN ", &22, &22, &0D
    EQUB &00


.next_screen
{
    LDA screen
    CMP num_screens
    BCS skip
    INC screen
.skip
    RTS
}

.prev_screen
{
    LDA #1
    CMP screen
    BCS skip
    DEC screen
.skip
    RTS
}

.jump_to_screen
{
    AND #&0F
    BIT jump
    BMI first_digit
.second_digit
    CLC
    ADC jump
    BEQ zero
    CMP num_screens
    BCC done
    BEQ done
.zero
    LDA #&FF
    BNE reset
.first_digit
    STA jump
    LDX #10
    LDA #0
.loop_x10
    ADC jump
    DEX
    BNE loop_x10
.reset
    STA jump
    SEC
    RTS
.done
    STA screen
    CLC
    RTS
}

.copy_tmp_string
{
.loop
    LDA (tmp), Y
    BEQ done
    BMI done
    STA url, X
    INX
    INY
    BNE loop
.done
    RTS
}


.count_titles
{
    LDY #0
    STY title_page
    STY &FCFF
    STY num_titles
    STY num_titles + 1
    STY num_screens

.loop1
    LDX #LINES_PER_SCREEN

.loop2
    LDA &FD00, Y
    CMP #&FF
    BEQ done
    CMP #&FE
    BNE loop3

    LDY title_page
    INY
    STY title_page
    STY &FCFF
    LDY #&00
    BEQ loop2

.loop3
    INY
    LDA &FD00, Y
    BPL loop3
    INY
    INC num_titles
    BNE next_title
    INC num_titles + 1

.next_title
    DEX
    BNE loop2
    INC num_screens
    BNE loop1

.done
    RTS
}


.update_screen_number
{
    ;; Print the screen number in the top right corner
    LDA #31
    JSR OSWRCH
    LDA #7
    JSR OSWRCH
    LDA #0
    JSR OSWRCH
    LDA #'0'
    STA pad
    LDA screen
    STA num
    JMP PrDec4
}

.skip_to_screen
{
    LDY #0
    STY title_page
    STY &FCFF

    LDX screen
    DEX
    BEQ done
    STX tmp

.loop1
    LDX #LINES_PER_SCREEN

.loop2
    LDA &FD00, Y
    CMP #&FF
    BEQ done
    CMP #&FE
    BNE loop3

    ;; Skip to next page
    LDY title_page
    INY
    STY title_page
    STY &FCFF
    LDY #&00
    BEQ loop2

.loop3
    INY
    LDA &FD00, Y
    BPL loop3

    INY
    DEX
    BNE loop2

    DEC tmp
    BNE loop1

.done
    STY title_ptr

    LDA #&FD
    STA title_ptr+1

    RTS
}

;; (title_ptr) points to title entry
.print_title
{
    TXA
    PHA
    CLC
    ADC #'A'
    JSR fast_OSWRCH
    JSR fast_space
    LDA #'['
    JSR fast_OSWRCH
    LDY #0
    LDA (title_ptr), Y
    JSR print_dir
    LDA #']'
    JSR fast_OSWRCH

.loop1
    JSR fast_space
    INX
    CPX #24
    BCC loop1

    LDA title_ptr
    STA tmp
    LDA title_ptr+1
    STA tmp+1
    LDY #1
    JSR print_camel_string
    INY

.loop2
    JSR fast_space
    INX
    CPX #52
    BCC loop2

    PLA
    TAX
    RTS
}

;; A = directory id
.print_dir
{
    TAY
    LDA dirlo, Y
    STA tmp
    LDA dirhi, Y
    STA tmp+1
    LDY #0
    ;; Fall through to print_camel_string
}

;; Print Camel-Cased String, inserting spaces where appropriate
;; (tmp),y points to string
;; return number of characters
;;
.print_camel_string
{
    LDX #0
    LDA (tmp), Y
    JSR fast_OSWRCH
    INX
.loop
    INY
    LDA (tmp), Y
    BEQ done
    BMI done
    CMP #'-'
    BEQ loop
    CMP #'A'
    BCC not_caps
    CMP #'Z' + 1
    BCS not_caps
    PHA
    JSR fast_space
    INX
    PLA
.not_caps
    JSR fast_OSWRCH
    INX
    JMP loop
.done
    RTS
}

.fast_OSWRCH
{
    STY tmpy
    ;; Calculate the address of the character data
    ;; = &C000 + (A - &20) * 8
    ;; = (&1800 + A - &20) * 8
    ;; Self-modifying code
    SEC
    SBC #&20
    LDY #&18
    STY loop + 2
    ASL A
    ROL loop + 2
    ASL A
    ROL loop + 2
    ASL A
    ROL loop + 2
    STA loop + 1
    ;; Copy the character to the cursor
    LDY #7
.loop
    LDA &0000, Y
    STA (cursor), Y
    DEY
    BPL loop
    ;; Move cursor to the next character position
    LDA cursor
    CLC
    ADC #&08
    STA cursor
    BCC done
    INC cursor + 1
.done
    LDY tmpy
    RTS
}

.fast_space
{
    STY tmpy
    ;; Clear the 8 bytes at the cursor
    LDA #0
    TAY
    STA (cursor), Y
    INY
    STA (cursor), Y
    INY
    STA (cursor), Y
    INY
    STA (cursor), Y
    INY
    STA (cursor), Y
    INY
    STA (cursor), Y
    INY
    STA (cursor), Y
    INY
    STA (cursor), Y
    ;; Move cursor to the next character position
    LDA cursor
    CLC
    ADC #&08
    STA cursor
    BCC done
    INC cursor + 1
.done
    LDY tmpy
    RTS
}

.init_screen
{
    JSR print_string
    EQUB 22, 3, 19, 0, 4, 0, 0, 0
    EQUB 23, 1, 0, 0, 0, 0, 0, 0, 0, 0
    EQUB "Screen 00/"
    NOP
    LDA num_screens
    STA num
    LDA #'0'
    STA pad
    JSR PrDec4
    JSR print_string
    EQUB 31, 33, 0, "Elk Wifi Menu", 31, 70, 0
    NOP
    LDA num_titles
    STA num
    LDA num_titles + 1
    STA num + 1
    LDA #0
    STA pad
    JSR PrDec16
    JSR print_string
    EQUB " Titles"
    EQUB 31, 0, 24, "A-", 'A'+LINES_PER_SCREEN-1, ": Run Title; Up/Down: Prev/Next Screen; 01-"
    NOP
    LDA num_screens
    STA num
    LDA #'0'
    STA pad
    JSR PrDec4
    JSR print_string
    EQUB ": Jump to Screen"
    NOP
    RTS
}

.disable_screen
{
    ;; Test for the fast mode bit
    BIT mode
    BPL done
    ;; Set the FG colour to Blue
    ;; Same as VDU 19,7,4;0;
    LDA #&05
    STA &FE08
    LDA #&55
    STA &FE09
    ;; Switch to Mode 6
    LDA #&B0
    STA &FE07
.done
    RTS
}

.enable_screen
{
    ;; Test for the fast mode bit
    BIT mode
    BPL done
    ;; Wait for VSYNC
    LDA #&13
    JSR OSBYTE
    ;; Switch to Mode 3
    LDA #&98
    STA &FE07
    ;; Set the FG colour to White
    ;; Same as VDU 19,7,7;0;
    LDA #&01
    STA &FE08
    LDA #&11
    STA &FE09
.done
    RTS
}

.print_string
{
    PLA
    STA tmp
    PLA
    STA tmp+1
    LDY #&00
.loop
    INC tmp
    BNE load
    INC tmp+1
.load
    LDA (tmp), Y
    BMI done
    JSR OSASCI
    JMP loop
.done
    JMP (tmp)
}

;; ************************************************************
;; Print 16-bit decimal number
;; ************************************************************

;  On entry, num=number to print
;            pad=0 or pad character (eg '0' or ' ')
;  On entry at PrDec16Lp1,
;            Y=(number of digits)*2-2, eg 8 for 5 digits
;  On exit,  A,X,Y,num,pad corrupted
;  Size      69 bytes


.PrDec24
        LDY #24                  ; Offset to powers of ten
        BNE PrDec

.PrDec20
        LDY #20                  ; Offset to powers of ten
        BNE PrDec

.PrDec16
        LDA #0
        STA num + 2
        LDY #16                 ; Offset to powers of ten
        BNE PrDec

.PrDec12
        LDA #0
        STA num + 2
        LDY #12                 ; Offset to powers of ten
        BNE PrDec

.PrDec8
        LDA #0
        STA num + 1
        STA num + 2
        LDY #8                  ; Offset to powers of ten
        BNE PrDec

.PrDec4
        LDA #0
        STA num + 1
        STA num + 2
        LDY #4                  ; Offset to powers of ten
        BNE PrDec

.PrDec
{
.PrDecLp1
        LDX #&FF
        SEC                     ; Start with digit=-1
.PrDecLp2
        LDA num+0
        SBC PrDecTens+0,Y
        STA num+0               ; Subtract current tens
        LDA num+1
        SBC PrDecTens+1,Y
        STA num+1
        LDA num+2
        SBC PrDecTens+2,Y
        STA num+2
        INX
        BCS PrDecLp2            ; Loop until <0
        LDA num+0
        ADC PrDecTens+0,Y
        STA num+0               ; Add current tens back in
        LDA num+1
        ADC PrDecTens+1,Y
        STA num+1
        LDA num+2
        ADC PrDecTens+2,Y
        STA num+2
        TXA
        BNE PrDecDigit          ; Not zero, print it
        LDA pad
        BNE PrDecPrint
        BEQ PrDecNext           ; pad<>0, use it
.PrDecDigit
        LDX #'0'
        STX pad                 ; No more zero padding
        ORA #'0'                ; Print this digit
.PrDecPrint
        JSR OSWRCH
.PrDecNext
        DEY
        DEY
        DEY
        DEY
        BPL PrDecLp1            ; Loop for next digit
        RTS

.PrDecTens
        EQUD 1
        EQUD 10
        EQUD 100
        EQUD 1000
        EQUD 10000
        EQUD 100000
        EQUD 1000000
        EQUD 10000000
}


.oscli_load_titles
    EQUB "*WGET -U http://acornelectron.nl/uefarchive/TITLES", &0D

.oscli_wicfs
    EQUB "*WICFS", &0D

.oscli_key0
    EQUB "*KEY 0 *REWIND|MCHAIN ", &22, &22, "|M", &0D

.oscli_wget
    EQUB "*WGET -U http://acornelectron.nl/uefarchive/"

.url
    SKIP &40

include "tmp/suffixes.asm"

include "tmp/directories.asm"

.end_addr

SAVE "MENU", start_addr, end_addr

org &E00

tmp = &70

title_ptr = &72

title_page = &74

screen = &76

display = &78

uart_mcr = &FC34

OSRDCH = &FFE0
OSASCI = &FFE3
OSNEWL = &FFE7
OSWRCH = &FFEE
OSBYTE = &FFF4
OSCLI  = &FFF7

saved_title_ptr = &C00
saved_title_page = &C20

LINES_PER_SCREEN = 20

.start_addr
{

    ;; Load title data into &FDxx paged RAM
    LDX #<oscli_load_titles
    LDY #>oscli_load_titles
    JSR OSCLI

    ;; Select bank 1 in pages RAM, which is where titles have been loaded to
    LDA uart_mcr
    ORA #&08
    STA uart_mcr

    ;; Start on screen 0
    LDA #0
    STA screen

    ;; Disable cursor editing so keys can be used to navigate
    LDA #4
    LDX #1
    JSR OSBYTE


.loop1
    ;; Initialize screen
    JSR init_screen

    ;; Search through the list title until screen N is reached
    ;; (this is potentially slow, but could be accelerated with an index)
    JSR skip_to_screen

    ;; Display a screen full of titles
    LDX #0
.loop2

    ;; Clear current line
    ;;JSR clear_line

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
    BEQ wait_for_key

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

.wait_for_key

    JSR OSRDCH

    CMP #&8A ;; Up arrow
    BNE not_screen_next
    INC screen
    JMP loop1

.not_screen_next
    CMP #&8B ;; Down arrow
    BNE not_screen_prev
    LDA screen
    BEQ wait_for_key
    DEC screen
    JMP loop1

.not_screen_prev
    AND #&DF

    CMP #'Z' + 1
    BCS wait_for_key
    CMP #'A'
    BCC wait_for_key

    ;; Prepare to load the title....
    SBC #'A'
    TAX
    LDA saved_title_ptr, X
    STA title_ptr
    LDA saved_title_page, X
    STA title_page
    STA &FCFF

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

.skip_to_screen
{
    LDY #0
    STY title_page
    STY &FCFF

    LDA screen
    BEQ done
    STA tmp

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
    STA title_ptr + 1

    RTS
}

;; (title_ptr) points to title entry
.print_title
{
    TXA
    CLC
    ADC #'A'
    JSR OSWRCH
    LDA #' '
    JSR OSWRCH
    LDA #'['
    JSR OSWRCH
    LDY #0
    LDA (title_ptr), Y
    JSR print_dir
    LDA #']'
    JSR OSWRCH
    LDA #31
    JSR OSWRCH
    LDA #20
    JSR OSWRCH
    TXA
    CLC
    ADC #2
    JSR OSWRCH
    LDA title_ptr
    STA tmp
    LDA title_ptr + 1
    STA tmp + 1
    LDY #1
    JSR print_camel_string
    INY
    JMP OSNEWL
}

;; A = directory id
.print_dir
{
    TAY
    LDA dirlo, Y
    STA tmp
    LDA dirhi, Y
    STA tmp + 1
    LDY #0
    ;; Fall through to print_camel_string
}

;; Print Camel-Cased String, inserting spaces where appropriate
;; (tmp),y points to string
;;
.print_camel_string
{
    LDA (tmp), Y
    JSR OSWRCH
.loop
    INY
    LDA (tmp), Y
    BEQ done
    BMI done
    CMP #'-'
    BEQ loop
    CMP #'A'
    BCC not_caps
    CMP #'Z'+1
    BCS not_caps
    PHA
    LDA #' '
    JSR OSWRCH
    PLA
.not_caps
    JSR OSWRCH
    JMP loop
.done
    RTS
}

.init_screen
{
    LDX #0
.loop
    LDA clear_screen_data, X
    CMP #&FF
    BEQ done
    JSR OSASCI
    INX
    BNE loop
.done
    RTS
}

.clear_screen_data
    EQUB 22, 3, 19, 0, 4, 0, 0, 0
    EQUB 31, 31, 0, "Electron Wifi Menu"
    EQUB 31, 0, 2
    EQUB 23, 1, 0, 0, 0, 0, 0, 0, 0, 0
    EQUB &FF

.clear_line
{
    LDY #79
    LDA #32
.loop
    JSR OSWRCH
    DEY
    BNE loop
    LDA #13
    JMP OSWRCH
}

.oscli_load_titles
    EQUB "*WGET -U http://192.168.0.205/TITLES", &0D

.oscli_wicfs
    EQUB "*WICFS", &0D

.oscli_key0
    EQUB "*KEY 0 *REWIND|MCHAIN ", &22, &22, "|M", &0D

.oscli_wget
    EQUB "*WGET -U http://192.168.0.207/uefarchive/"

.url
    SKIP &40

include "tmp/suffixes.asm"

include "tmp/directories.asm"

.end_addr

SAVE "MENU", start_addr, end_addr

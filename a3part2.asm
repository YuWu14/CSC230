; a3part2.asm
; CSC 230: Summer 2019
;
; Student name:YUWU
; Student ID:V00917423
; Date of completed work:7/17/2019
;
; *******************************
; Code provided for Assignment #3
;
; Author: Mike Zastre (2019-Jul-04)
; 
; This skeleton of an assembly-language program is provided to help you
; begin with the programming tasks for A#3. As with A#2, there are 
; "DO NOT TOUCH" sections. You are *not* to modify the lines
; within these sections. The only exceptions are for specific
; changes announced on conneX or in written permission from the course
; instructor. *** Unapproved changes could result in incorrect code
; execution during assignment evaluation, along with an assignment grade
; of zero. ****
;
; I have added for this assignment an additional kind of section
; called "TOUCH CAREFULLY". The intention here is that one or two
; constants can be changed in such a section -- this will be needed
; as you try to test your code on different messages.
;


; =============================================
; ==== BEGINNING OF "DO NOT TOUCH" SECTION ====
; =============================================
;
; In this "DO NOT TOUCH" section are:
;
; (1) assembler directives setting up the interrupt-vector table
;
; (2) "includes" for the LCD display
;
; (3) some definitions of constants we can use later in the
;     program
;
; (4) code for initial setup of the Analog Digital Converter (in the
;     same manner in which it was set up for Lab #4)
;     
; (5) code for setting up our three timers (timer1, timer3, timer4)
;
; After all this initial code, your own solution's code may start.
;

.cseg
.org 0
	jmp reset

; location in vector table for TIMER1 COMPA
;
.org 0x22
	jmp timer1

; location in vector table for TIMER4 COMPA
;
.org 0x54
	jmp timer4

.include "m2560def.inc"
.include "lcd_function_defs.inc"
.include "lcd_function_code.asm"

.cseg

; These two constants can help given what is required by the
; assignment.
;
#define MAX_PATTERN_LENGTH 10
#define BAR_LENGTH 6

; All of these delays are in seconds
;
#define DELAY1 0.5
#define DELAY3 0.1
#define DELAY4 0.01


; The following lines are executed at assembly time -- their
; whole purpose is to compute the counter values that will later
; be stored into the appropriate Output Compare registers during
; timer setup.
;

#define CLOCK 16.0e6 
.equ PRESCALE_DIV=1024  ; implies CS[2:0] is 0b101
.equ TOP1=int(0.5+(CLOCK/PRESCALE_DIV*DELAY1))

.if TOP1>65535
.error "TOP1 is out of range"
.endif

.equ TOP3=int(0.5+(CLOCK/PRESCALE_DIV*DELAY3))
.if TOP3>65535
.error "TOP3 is out of range"
.endif

.equ TOP4=int(0.5+(CLOCK/PRESCALE_DIV*DELAY4))
.if TOP4>65535
.error "TOP4 is out of range"
.endif


reset:
	; initialize the ADC converter (which is neeeded
	; to read buttons on shield). Note that we'll
	; use the interrupt handler for timer4 to
	; read the buttons (i.e., every 10 ms)
	;
	ldi temp, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0)
	sts ADCSRA, temp
	ldi temp, (1 << REFS0)
	sts ADMUX, r16


	; timer1 is for the heartbeat -- i.e., part (1)
	;
    ldi r16, high(TOP1)
    sts OCR1AH, r16
    ldi r16, low(TOP1)
    sts OCR1AL, r16
    ldi r16, 0
    sts TCCR1A, r16
    ldi r16, (1 << WGM12) | (1 << CS12) | (1 << CS10)
    sts TCCR1B, temp
	ldi r16, (1 << OCIE1A)
	sts TIMSK1, r16

	; timer3 is for the LCD display updates -- needed for all parts
	;
    ldi r16, high(TOP3)
    sts OCR3AH, r16
    ldi r16, low(TOP3)
    sts OCR3AL, r16
    ldi r16, 0
    sts TCCR3A, r16
    ldi r16, (1 << WGM32) | (1 << CS32) | (1 << CS30)
    sts TCCR3B, temp

	; timer4 is for reading buttons at 10ms intervals -- i.e., part (2)
    ; and part (3)
	;
    ldi r16, high(TOP4)
    sts OCR4AH, r16
    ldi r16, low(TOP4)
    sts OCR4AL, r16
    ldi r16, 0
    sts TCCR4A, r16
    ldi r16, (1 << WGM42) | (1 << CS42) | (1 << CS40)
    sts TCCR4B, temp
	ldi r16, (1 << OCIE4A)
	sts TIMSK4, r16

    ; flip the switch -- i.e., enable the interrupts
    sei

; =======================================
; ==== END OF "DO NOT TOUCH" SECTION ====
; =======================================


; *********************************************
; **** BEGINNING OF "STUDENT CODE" SECTION **** 
; *********************************************


start:

	rcall lcd_init

	;****** Load symbols to memory address*******
	ldi r16, '<'
	sts CHAR_THREE, r16

	ldi r17, '>'
	sts CHAR_FOUR, r17

	ldi r18, ' '
	sts CHAR_ONE, r18

	ldi r19, ' '
	sts CHAR_TWO, r19

	;****** Load symbols to memory address*******
	ldi r20,0
	ldi r21,0

	sts BUTTON_COUNT,r20
	sts BUTTON_COUNT+1,r21

	
    rcall to_decimal_text ;convert the 16-bit BUTTON_COUNT in to its decimal representation ascharacters


	blink_loop:

		;******This is the heartbeat LED part*******
		ldi r16, 0 
		ldi r17, 14 
		push r16
		push r17
		rcall lcd_gotoxy
		pop r17
		pop r16

		lds r16, CHAR_THREE
		push r16
		rcall lcd_putchar
		pop r16

		lds r17,CHAR_FOUR
		push r17
		rcall lcd_putchar
		pop r17


		ldi r16, 1 
		ldi r17, 11 
		push r16
		push r17
		rcall lcd_gotoxy
		pop r17
		pop r16

		
	;******Using timer3 as the polling*******
	check_timer_3:
		in temp, TIFR3
		sbrs temp, OCF3A
		rjmp no_time1 ; If timer3 did not reach the top, do the polling loop
		ldi temp, 1<<OCF3A
		out TIFR3, temp

		; The following hex_to_decimal methods is from professor Zastre's suggestiong
		; URL: https://connex.csc.uvic.ca/access/content/group/a65af0f2-127a-4bfb-9216-c4a5c2122412/Other/hex_to_decimal.pdf
		lds r20, BUTTON_COUNT
		lds r21, BUTTON_COUNT+1
		push r20
		push r21

		ldi r20, high(COUNTER_TEXT)
		ldi r21, low(COUNTER_TEXT)
		push r20
		push r21

		rcall to_decimal_text ;convert the 16-bit BUTTON_COUNT in to its decimal representation ascharacters

		;******Printing the character to LED*******
		push r21
		push r20
		push ZH
		push ZL		
		ldi ZH, high(COUNTER_TEXT)
		ldi ZL, low(COUNTER_TEXT)	
		ldi r21, 5
		keep_1:
			ld r20,Z+
			push r20
			rcall lcd_putchar
			pop r20
			dec r21
			tst r21
			brne keep_1
		pop ZL
		pop ZH
		pop r20
		pop r21
		;=============================================

	no_time1:
		rjmp  blink_loop

	.equ MAX_POS = 5  
	 

	; The following hex_to_decimal methods is from professor Zastre's suggestiong
	; URL: https://connex.csc.uvic.ca/access/content/group/a65af0f2-127a-4bfb-9216-c4a5c2122412/Other/hex_to_decimal.pdf 
	to_decimal_text:
		.def countL=r20
		.def countH=r21
		.def factorL=r22
		.def factorH=r23
		.def multiple=r24
		.def pos=r25
		.def zero=r0
		;.def ascii_zero=r26
		push countH
		push countL
		push factorH
		push factorL
		push multiple
		push pos
		push zero
		push r16
		push YH
		push YL
		push ZH
		push ZL
		in YH, SPH
		in YL, SPL
		; fetch parameters from stack frame
		;
		.set PARAM_OFFSET = 16
		ldd countH, Y+PARAM_OFFSET+3
		ldd countL, Y+PARAM_OFFSET+2
		; this is only designed for positive
		; signed integers; we force a negative
		; integer to be positive.
		;
		andi countH, 0b01111111
		clr zero
		clr pos
		ldi r16, '0'
		; The idea here is to build the text representation
		; digit by digit, starting from the left-most.
		; Since we need only concern ourselves with final
		; text strings having five characters (i.e., our
		; text of the decimal will never be more than
		; five characters in length), we begin we determining
		; how many times 10000 fits into countH:countL, and
		; use that to determine what character (from ’0’ to
		; ’9’) should appear in the left-most position
		; of the string.
		;
		; Then we do the same thing for 1000, then
		; for 100, then for 10, and finally for 1.
		;
		; Note that for *all* of these cases countH:countL is
		; modified. We never write these values back onto
		; that stack. This means the caller of the function
		; can assume call-by-value semantics for the argument
		; passed into the function.
		;
		to_decimal_next:
			clr multiple
		to_decimal_10000:
			cpi pos, 0
			brne to_decimal_1000
			ldi factorL, low(10000)
			ldi factorH, high(10000)
			rjmp to_decimal_loop
		to_decimal_1000:
			cpi pos, 1
 			brne to_decimal_100
			ldi factorL, low(1000)
			ldi factorH, high(1000)
				rjmp to_decimal_loop
		to_decimal_100:
			cpi pos, 2
			brne to_decimal_10
			ldi factorL, low(100)
			ldi factorH, high(100)
			rjmp to_decimal_loop
		to_decimal_10:
			cpi pos, 3
			brne to_decimal_1
			ldi factorL, low(10)
			ldi factorH, high(10)
			rjmp to_decimal_loop
		to_decimal_1:
			mov multiple, countL
			rjmp to_decimal_write
		to_decimal_loop:
			inc multiple
			sub countL, factorL
			sbc countH, factorH
			brpl to_decimal_loop
			dec multiple
			add countL, factorL
			adc countH, factorH
		to_decimal_write:
			ldd ZH, Y+PARAM_OFFSET+1
			ldd ZL, Y+PARAM_OFFSET+0
			add ZL, pos
			adc ZH, zero
			add multiple, r16
			st Z, multiple
			inc pos
			cpi pos, MAX_POS
			breq to_decimal_exit
			rjmp to_decimal_next
		to_decimal_exit:
			pop ZL
			pop ZH
			pop YL
			pop YH
			pop r16
			pop zero
			pop pos
			pop multiple
			pop factorL
			pop factorH
			pop countL
			pop countH
			.undef countL
			.undef countH
			.undef factorL
			.undef factorH
			.undef multiple
			.undef pos
			.undef zero
			;.undef ascii_zero
			ret


stop:
    rjmp stop


timer1:
		push r16
		in r16, SREG

			push r16
			push r17
			push r18
			push r19
			;read CHAR_ONE into, say, r16 and 
			;read CHAR_TWO into, say r17
			;store r16 in CHAR_TWO
			;store r17 in CHAR_ONE <- now, they are swapped
			lds r16,CHAR_THREE
			lds r17,CHAR_FOUR
			lds r18,CHAR_ONE
			lds r19,CHAR_TWO

			sts CHAR_THREE,r18
			sts CHAR_FOUR,r19
			sts CHAR_ONE,r16
			sts CHAR_TWO,r17

			clr r20
			sts PULSE,r20
			;restore the status register and the registers that you used
			pop r19
			pop r18
			pop r17
			pop r16

		out SREG,r16
		pop r16
	reti


timer4:

	push r23
	push r25
	push r24
	push r1
	push r0
	push r16
	push r20
	push r21
	

	ldi r16,0x032
	sts RIGHT, r16

	; enable the ADC & slow down the clock from 16mHz to ~125kHz, 16mHz/128
	ldi r16, 0x87  ;0x87 = 0b10000111
	sts ADCSRA, r16

	ldi r16, 0x00
	sts ADCSRB, r16 ; combine with MUX4:0 in ADMUX_BTN to select ADC0 p282

	; bits 7:6(REFS1:0) = 01: AVCC with external capacitor at AREF pin p.281
	; bit  5 ADCL_BTNAR(ADC Left Adjust Result) = 0: right adjustment the result
	; bits 4:0 (MUX4:0) = 00000: combine with MUX5 in ADCSRB_BTN ->ADC0 channel is used.
	ldi r16, 0x40  ;0x40 = 0b01000000
	sts ADMUX, r16

	; detect if "RIGHT" button is pressed r1:r0 <- 0x032
	ldi r16, low(RIGHT);
	mov r0, r16
	ldi r16, high(RIGHT)
	mov r1, r16


	; start a2d
	lds	r16, ADCSRA	

	; bit 6 =1 ADSC (ADC Start Conversion bit), remain 1 if conversion not done
	; ADSC changed to 0 if conversion is done
	ori r16, 0x40 ; 0x40 = 0b01000000
	sts	ADCSRA, r16

	; wait for it to complete, check for bit 6, the ADSC bit
	wait:	
		lds r16, ADCSRA
		andi r16, 0x40
		brne wait

		; read the value, use XH:XL to store the 10-bit result
		lds r24, ADCL
		lds r25, ADCH

		clr r23
		sts BUTTON_CURRENT, r23
		; if DATAH:DATAL < BOUNDARY_H:BOUNDARY_L
		;     r23=1  "right" button is pressed
		; else
		;     r23=0
		cp r24, r0
		cpc r25, r1
		brsh skip		
		ldi r23,1
		sts BUTTON_CURRENT, r23
	
	;examine BUTTON_PREVIOUS and BUTTON_CURRENT to determine if the 
	; button press has just started

	;The only time to inc BUTTON_COUNT is when the BUTTON_PREVIOUS is 0
	;And at the same time the BUTTON_CURRENT is 1
	skip:
		lds r23,BUTTON_CURRENT
		tst r23
		breq do_nothing
		
		lds r20,BUTTON_PREVIOUS
		cpi r20,1
		breq do_nothing


		; When the 0:1 condition meet, inc the BUTTON_COUNT
		lds r20, BUTTON_COUNT
		lds r21, BUTTON_COUNT+1	
		inc r21
		cpi r21, 255
		brne not_full
		inc r20
		not_full:
			sts BUTTON_COUNT,r20
			sts BUTTON_COUNT+1,r21

		;==========================================
		

		do_nothing:
			lds r21,BUTTON_CURRENT ; Load the BUTTON_CURRENT value to BUTTON_PREVIOUS
			sts BUTTON_PREVIOUS, r21

			pop r21
			pop r20
			pop r16
			pop r0
			pop r1
			pop r24
			pop r25
			pop r23

    reti


; ***************************************************
; **** END OF FIRST "STUDENT CODE" SECTION ********** 
; ***************************************************


; ################################################
; #### BEGINNING OF "TOUCH CAREFULLY" SECTION ####
; ################################################

; The purpose of these locations in data memory are
; explained in the assignment description.
;

.dseg

CHAR_ONE: .byte 1
CHAR_TWO: .byte 1
CHAR_THREE: .byte 1
CHAR_FOUR: .byte 1

COUNTER_TEXT: .byte 6
COUNTER_VAL: .byte 2
RIGHT: .byte 1

PULSE: .byte 1
COUNTER: .byte 2
DISPLAY_TEXT: .byte 16
BUTTON_CURRENT: .byte 1
BUTTON_PREVIOUS: .byte 1
BUTTON_COUNT: .byte 2
BUTTON_LENGTH: .byte 1
DOTDASH_PATTERN: .byte MAX_PATTERN_LENGTH

; ##########################################
; #### END OF "TOUCH CAREFULLY" SECTION ####
; ##########################################

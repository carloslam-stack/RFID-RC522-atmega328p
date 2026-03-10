.equ SPI_DDR = DDRB 
.equ CS = PINB2 
.equ MOSI = PINB3 
.equ MISO = PINB4 
.equ SCK = PINB5 
.equ F_CPU = 16000000
.equ BAUD = 9600
.equ UBRR_VAL = 6        ; para 9600 baudios

.cseg 
.org 0x0000 
	rjmp reset 

reset: 
	LDI r16, (1 << CS) | (1 << MOSI) | (1 << SCK) | (1<<1) | (1<<0) 
	OUT DDRB, r16
	LDI r16, (1 << SPE) | (1 << MSTR) | (1 << SPR1)  ; Cambiado: fosc/16 es mejor
	OUT SPCR, r16
	LDI r16, 0xff 
	OUT DDRD, r16 
	OUT DDRC, r16
	SBI PORTB, 2  ; CS = HIGH

	; Configurar UART
	; Configurar UBRR para velocidad
    ldi r16, low(UBRR_VAL)
    sts UBRR0L, r16
    ldi r16, high(UBRR_VAL)
    sts UBRR0H, r16

    ; Habilitar TX
    ldi r16, (1<<TXEN0)
    sts UCSR0B, r16

    ; Modo asíncrono, 8 bits
    ldi r16, (1<<UCSZ01) | (1<<UCSZ00)
    sts UCSR0C, r16

	rjmp init 

init:
	; Hardware reset
	CBI PORTB, 1
	rcall delay_100ms
	SBI PORTB, 1
	rcall delay_100ms

	; Soft reset
	CBI PORTB, 2
	LDI r16, (0x01 << 1) & 0x7E  ; CommandReg
	rcall transmitir
	LDI r16, 0x0F  ; SoftReset
	rcall transmitir
	SBI PORTB, 2
	rcall delay_100ms

	; Verificar versión (debe ser 0x91 o 0x92)
	CBI PORTB, 2
	LDI r16, (0x37 << 1) | 0x80  ; VersionReg
	rcall transmitir
	LDI r16, 0x00
	rcall transmitir
	IN r17, SPDR
	SBI PORTB, 2

	; TxModeReg = 0x00
	CBI PORTB, 2
	LDI r16, (0x12 << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x00
	rcall transmitir
	SBI PORTB, 2

	; RxModeReg = 0x00
	CBI PORTB, 2
	LDI r16, (0x13 << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x00
	rcall transmitir
	SBI PORTB, 2

	; ModWidthReg = 0x26
	CBI PORTB, 2
	LDI r16, (0x24 << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x26
	rcall transmitir
	SBI PORTB, 2

	; TModeReg = 0x80 (TAuto=1)
	CBI PORTB, 2
	LDI r16, (0x2A << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x80
	rcall transmitir
	SBI PORTB, 2

	; TPrescalerReg = 0xA9
	CBI PORTB, 2
	LDI r16, (0x2B << 1) & 0x7E
	rcall transmitir
	LDI r16, 0xA9
	rcall transmitir
	SBI PORTB, 2

	; TReloadRegH = 0x03
	CBI PORTB, 2
	LDI r16, (0x2C << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x03
	rcall transmitir
	SBI PORTB, 2

	; TReloadRegL = 0xE8
	CBI PORTB, 2
	LDI r16, (0x2D << 1) & 0x7E
	rcall transmitir
	LDI r16, 0xE8
	rcall transmitir
	SBI PORTB, 2

	; TxASKReg = 0x40
	CBI PORTB, 2
	LDI r16, (0x15 << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x40
	rcall transmitir
	SBI PORTB, 2

	; ModeReg = 0x3D
	CBI PORTB, 2
	LDI r16, (0x11 << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x3D
	rcall transmitir
	SBI PORTB, 2

	rjmp prenderantena

prenderantena:
	; Leer TxControlReg
	CBI PORTB, 2
	LDI r16, (0x14 << 1) | 0x80
	rcall transmitir
	LDI r16, 0x00
	rcall transmitir
	SBI PORTB, 2

	; Hacer OR con 0x03 para encender TX1 y TX2
	mov r18, r17
	ORI r18, 0x03

	; Escribir TxControlReg
	CBI PORTB, 2
	LDI r16, (0x14 << 1) & 0x7E
	rcall transmitir
	mov r16, r18
	rcall transmitir
	SBI PORTB, 2

	CBI PORTB, 2
	LDI r16, (0x14 << 1) | 0x80
	rcall transmitir
	ldi r16, 0x00
	rcall transmitir
	SBI PORTB, 2

	out portd, r17

	rcall delay_100ms

	rjmp main_loop

main_loop:
    rcall picc_request
    cpi r17, 0
    brne main_loop   ; si no hubo tarjeta, seguir

    ; Ahora obtener UID
    rcall picc_anticoll
    cpi r17, 0
    brne main_loop   ; si falla anticollision, seguir

    rjmp tarjeta_detectada

tarjeta_detectada:
	; Indicador: ¡Tarjeta encontrada!
	; encender buzzer
	ldi r20, 1<<3
	out portc, r20

	rcall delay_100ms

	ldi r20, 0
	out portc, r20

    ; UID byte 0
	mov r18, r30
	rcall uart_send; enviar por uart

    ; UID byte 1
	mov r18, r31
	rcall uart_send; enviar por uart

    ; UID byte 2
	mov r18, r24
	rcall uart_send; enviar por uart

    ; UID byte 3
	mov r18, r25
	rcall uart_send; enviar por uart

	rjmp main_loop

picc_request:
	; Preparar para REQA
	; Limpiar CollReg bit 7
	CBI PORTB, 2
	LDI r16, (0x0E << 1) | 0x80
	rcall transmitir
	LDI r16, 0x00
	rcall transmitir
	SBI PORTB, 2

	ANDI r17, 0x7F  ; Clear bit 7
	mov r18, r17

	CBI PORTB, 2
	LDI r16, (0x0E << 1) & 0x7E
	rcall transmitir
	MOV r16, r18
	rcall transmitir
	SBI PORTB, 2

	; Idle
	CBI PORTB, 2
	LDI r16, (0x01 << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x00
	rcall transmitir
	SBI PORTB, 2

	; Limpiar interrupts
	CBI PORTB, 2
	LDI r16, (0x04 << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x7F
	rcall transmitir
	SBI PORTB, 2

	; Flush FIFO
	CBI PORTB, 2
	LDI r16, (0x0A << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x80
	rcall transmitir
	SBI PORTB, 2

	; Escribir REQA (0x26) al FIFO
	CBI PORTB, 2
	LDI r16, (0x09 << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x26
	rcall transmitir
	SBI PORTB, 2

	; BitFramingReg: TxLastBits=7, RxAlign=0
	CBI PORTB, 2
	LDI r16, (0x0D << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x07  ; Solo 7 bits válidos
	rcall transmitir
	SBI PORTB, 2

	; Transceive
	CBI PORTB, 2
	LDI r16, (0x01 << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x0C
	rcall transmitir
	SBI PORTB, 2

	; StartSend
	CBI PORTB, 2
	LDI r16, (0x0D << 1) & 0x7E
	rcall transmitir
	LDI r16, 0x87  ; StartSend=1, TxLastBits=7
	rcall transmitir
	SBI PORTB, 2

	; Esperar respuesta
	ldi r19, 200  ; Timeout counter

wait_response:
	CBI PORTB, 2
	LDI r16, (0x04 << 1) | 0x80
	rcall transmitir
	LDI r16, 0x00
	rcall transmitir
	SBI PORTB, 2

	; Revisar RxIRq o IdleIRq (bits 5 y 4)
	MOV r18, r17
	ANDI r18, 0x30
	CPI r18, 0
	BRNE response_ok

	; Revisar TimerIRq (bit 0)
	MOV r18, r17
	ANDI r18, 0x01
	CPI r18, 1
	BREQ response_timeout

	dec r19
	brne wait_response
	rjmp response_timeout

response_ok:
	; Leer ErrorReg
	CBI PORTB, 2
	LDI r16, (0x06 << 1) | 0x80
	rcall transmitir
	LDI r16, 0x00
	rcall transmitir
	SBI PORTB, 2

	; Revisar errores críticos
	MOV r18, r17
	ANDI r18, 0x13  ; BufferOvfl, ParityErr, ProtocolErr
	CPI r18, 0
	BRNE response_error

	; Leer FIFO Level
	CBI PORTB, 2
	LDI r16, (0x0A << 1) | 0x80
	rcall transmitir
	LDI r16, 0x00
	rcall transmitir
	SBI PORTB, 2

	ANDI r17, 0x7F  ; Mask FIFOLevel
	CPI r17, 2      ; ATQA debe ser 2 bytes
	BRNE response_error

	; ¡Éxito!
	ldi r17, 0  ; STATUS_OK
	ret

response_timeout:
	ldi r17, 3  ; STATUS_TIMEOUT
	ret

response_error:
	ldi r17, 1  ; STATUS_ERROR
	ret

picc_anticoll:
    ; Comando anticollision CL1: 0x93 0x20

    ; Flush FIFO
    CBI PORTB,2
    LDI r16, (0x0A << 1) & 0x7E
    rcall transmitir
    LDI r16, 0x80
    rcall transmitir
    SBI PORTB,2

    ; Escribir 0x93
    CBI PORTB,2
    LDI r16, (0x09 << 1) & 0x7E   ; FIFODataReg
    rcall transmitir
    LDI r16, 0x93
    rcall transmitir
    SBI PORTB,2

    ; Escribir 0x20 (NVB)
    CBI PORTB,2
    LDI r16, (0x09 << 1) & 0x7E
    rcall transmitir
    LDI r16, 0x20
    rcall transmitir
    SBI PORTB,2

    ; BitFramingReg = 0
    CBI PORTB,2
    LDI r16, (0x0D << 1) & 0x7E
    rcall transmitir
    LDI r16, 0x00
    rcall transmitir
    SBI PORTB,2

    ; Transceive command
    CBI PORTB,2
    LDI r16, (0x01 << 1) & 0x7E
    rcall transmitir
    LDI r16, 0x0C
    rcall transmitir
    SBI PORTB,2

    ; StartSend=1
    CBI PORTB,2
    LDI r16, (0x0D << 1) & 0x7E
    rcall transmitir
    LDI r16, 0x80
    rcall transmitir
    SBI PORTB,2

    ; Esperar respuesta
    ldi r19, 200
anticoll_wait:
    CBI PORTB,2
    LDI r16, (0x04 << 1) | 0x80   ; ComIrqReg
    rcall transmitir
    LDI r16, 0x00
    rcall transmitir
    SBI PORTB,2

    mov r18, r17
    andi r18, 0x30    ; RxIRq / IdleIRq
    cpi r18, 0
    brne anticoll_ok

    dec r19
    brne anticoll_wait
    ldi r17, 3
    ret

anticoll_ok:
    ; Leer FIFOLevel
    CBI PORTB,2
    LDI r16, (0x0A << 1) | 0x80
    rcall transmitir
    LDI r16, 0x00
    rcall transmitir
    SBI PORTB,2

    ; FIFOLevel en r17
    cpi r17, 5
    brlo anticoll_error

    ; UID byte 0 ? r30
    CBI PORTB,2
    LDI r16, (0x09 << 1) | 0x80
    rcall transmitir
    LDI r16, 0x00
    rcall transmitir
    mov r30, r17
    SBI PORTB,2

    ; UID byte 1 ? r31
    CBI PORTB,2
    LDI r16, (0x09 << 1) | 0x80
    rcall transmitir
    LDI r16, 0x00
    rcall transmitir
    mov r31, r17
    SBI PORTB,2

    ; UID byte 2 ? r24
    CBI PORTB,2
    LDI r16, (0x09 << 1) | 0x80
    rcall transmitir
    LDI r16, 0x00
    rcall transmitir
    mov r24, r17
    SBI PORTB,2

    ; UID byte 3 ? r25
    CBI PORTB,2
    LDI r16, (0x09 << 1) | 0x80
    rcall transmitir
    LDI r16, 0x00
    rcall transmitir
    mov r25, r17
    SBI PORTB,2

    ldi r17, 0   ; STATUS_OK
    ret

anticoll_error:
    ldi r17, 1
    ret


transmitir: 
	OUT SPDR, r16
Wait_SPIF: 
	IN r16, SPSR
	SBRS r16, SPIF
	RJMP Wait_SPIF 
	IN r17, SPDR
	RET

uart_send:
    ; Esperar que el buffer esté listo
uart_wait:
    lds r17, UCSR0A
    sbrs r17, UDRE0
    rjmp uart_wait

    ; Cargar
    sts UDR0, r18
    ret

delay_100ms:
	ldi r18, 10
delay_loop_10ms:
	ldi r19, 100
delay_loop_1ms:
	ldi r20, 250
delay_inner:
	dec r20
	brne delay_inner
	dec r19
	brne delay_loop_1ms
	dec r18
	brne delay_loop_10ms
	ret
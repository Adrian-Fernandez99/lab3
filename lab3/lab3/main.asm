/*

lab3.asm

Created: 2/21/2025 2:51:33 PM

Author : Adri�n Fern�ndez

Descripci�n:
	Se realiza un contador binario de 4 bits
	que se presentan en cuatro leds externas.
	Se deben utilizar interrupciones de tipo
	On-change.
*/
.include "M328PDEF.inc"		// Include definitions specific to ATMega328P

// Definiciones de registro, constantes y variables
.cseg
.org		0x0000
	JMP		START

.org		PCI0addr
	JMP		BOTONES

.org		OVF0addr
	JMP		OVERFLOW


TABLA7SEG: .DB	0x7E, 0x30, 0x6D, 0x79, 0x33, 0x5B, 0x5F, 0x70, 0x7F, 0x7B, 0x77, 0x7F, 0x4E, 0x7E, 0x4F, 0x47
//			  1,    2,    3,    4,    5,    6,    7,    8,    9,    A,    B,    C,    D,    F,    G,    H

// Configuraci�n de la pila
START:
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

// Configuraci�n del MCU
SETUP:
	// Desavilitamos interrupciones mientras seteamos todo
	CLI
	CALL	OVER

	// Configurar Prescaler "Principal"
	LDI		R16, (1 << CLKPCE)
	STS		CLKPR, R16		// Habilitar cambio de PRESCALER
	LDI		R16, 0x04
	STS		CLKPR, R16		// Configurar Prescaler a 16 F_cpu = 1MHz

	// Deshabilitar serial (esto apaga los demas LEDs del Arduino)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	// Interrupciones de botones
	// Habilitamos interrupcionees para el PCIE0
	LDI		R16, (1 << PCINT1) | (1 << PCINT0)
	STS		PCMSK0, R16
	// Habilitamos interrupcionees para cualquier cambio logico
	LDI		R16, (1 << PCIE0)
	STS		PCICR, R16

	// Interrupciones del timer
	// Habilitamos interrupcionees para el PCIE0
	LDI		R16, (1 << TOIE0)
	STS		TIMSK0, R16

	// PORTD como entrada con pull-up habilitado
	LDI		R16, 0x00
	OUT		DDRB, R16		// Setear puerto B como entrada
	LDI		R16, 0xFF
	OUT		PORTB, R16		// Habilitar pull-ups en puerto B

	// Configurar puerto C como una salida
	LDI		R16, 0xFF
	OUT		DDRC, R16		// Setear puerto C como salida

	// Configurar puerto D como una salida
	LDI		R16, 0xFF
	OUT		DDRD, R16		// Setear puerto D como salida

	// Realizar variables
	LDI		R16, 0x00		// Registro del contador
	LDI		R17, 0x00		// Registro de lectura de botones

	// Activamos las interrupciones
	SEI

// Main loop
MAIN_LOOP:
	OUT		PORTC, R16		// Se loopea la salida del puerto
	IN		R16, TIFR0		// Leer registro de interrupci�n de TIMER0
	SBRS	R16, TOV0		// Salta si el bit 0 est "set" (TOV0 bit)
	RJMP	MAIN_LOOP		// Reiniciar loop
	SBI		TIFR0, TOV0		// Limpiar bandera de "overflow"
	LDI		R16, 158
	OUT		TCNT0, R16		// Volver a cargar valor inicial en TCNT0
	INC		COUNTER
	CPI		COUNTER, 10		// Se necesitan hacer 10 overflows para 1s
	BRNE	MAIN_LOOP
	CLR		COUNTER			// Se reinicia el conteo de overflows
	CALL	SUMA			// Se llama al incremento del contador
	OUT		PORTD, R17		// Sale la se�al
	JMP		MAIN_LOOP

// NON-Interrupt subroutines
INIT_TMR0:
	LDI		R16, (1 << CS00) | (1 << CS02)
	OUT		TCCR0B, R16		// Setear prescaler del TIMER 0 a 1024
	LDI		R16, 158
	OUT		TCNT0, R16		// Cargar valor inicial en TCNT0
	RET

SUMA:						// Funci�n para el incremento del primer contador
	INC		R17				// Se incrementa el valor
	SBRC	R17, 4			// Se observa si tiene m�s de 4 bits
	LDI		R17, 0x00		// En ese caso es overflow y debe regresar a 0
	RET

OVER:
	LDI		ZL, LOW(TABLA7SEG << 1)				// Ingresa a Z los registros de la tabla m�s bajos
	LDI		ZH, HIGH(TABLA7SEG << 1)			
	RET

// Interrupt routines
INCREMENTO:
	IN		R17, PIND		// Se ingresa la configuraci�n del PIND
	CPI		R17, 0xFB		// Se compara para ver si el bot�n est� presionado
	BRNE	FINAL			// Si no esta preionado termina la interrupci�n
	INC		R16				// Si est� presionado incrementa
	SBRC	R16, 4			// Si genera overflow reinicia contador
	LDI		R16, 0x00
	FINAL:
	RETI					// Regreso de la interrupci�n

DECREMENTO:
	IN		R17, PIND		// Se ingresa la configuraci�n del PIND
	CPI		R17, 0xF7		// Se compara para ver si el bot�n est� presionado
	BRNE	FINAL2			// Si no esta preionado termina la interrupci�n
	DEC		R16				// Si est� presionado decrementa
	SBRC	R16, 4			// Si genera underflow reinicia contador
	LDI		R16, 0x0F
	FINAL2: 
	RETI					// Regreso de la interrupci�n


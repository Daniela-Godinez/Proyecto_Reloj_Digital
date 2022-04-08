; Archivo:     main.S
; Dispositivo: PIC16F887
; Autor:       Daniela Godinez
; Compilador:  pic-as (v2.30), MPLABX V5.40
;
; Programa:    Reloj Digital 
; Hardware:    4 Displays 7 seg., Push-Buttons, LEDs
;
; Creado: 06 mar, 2022
; Última modificación: 21 mar, 2022

PROCESSOR 16F887
#include <xc.inc>

;CONFIGURACIÓN WORD 1
CONFIG FOSC=INTRC_NOCLKOUT // Oscillador Interno sin salidas
CONFIG WDTE=OFF   //WDT disabled (reinicio repetitivo del pic)
CONFIG PWRTE=OFF   //PWRT enabled (espera de 72ms al iniciar)
CONFIG MCLRE=OFF  //El pin de MCLR se utiliza como I/O
CONFIG CP=OFF     //Sin protección de código
CONFIG CPD=OFF    //Sin protección de datos
    
CONFIG BOREN=OFF  //Sin reinicio cuando el voltaje de alimentación baja de 4V
CONFIG IESO=OFF   //Reinicio sin cambio de reloj de interno a externo
CONFIG FCMEN=OFF  //Cambio de reloj externo a interno en caso de fallo
CONFIG LVP=OFF     //Programación en bajo voltaje permitida

;CONFIGURACIÓN WORD 2
CONFIG WRT=OFF       //Protección de autoescritura por el programa desactivada
CONFIG BOR4V=BOR40V  //Reinicio abajo de 4V, (BOR21V=2.1V)

;VARIABLES
PSECT udata_bank0 ;common memory/memoria compartida
    W_Temp:	    DS 1        ;guardar el valor de w antes de ejetutar la rutina de interrupcion
    Status_Temp:    DS 1        ;guardar el valor de status antes de ejetutar la rutina de interrupcion
    estado:	    DS 1	;Variable para incrementar el estado del botón MODO
    valor_display:  DS 4	;Variable para valor_display
    banderas:	    DS 1	;Variable de banderas
    segundo:	    DS 1	;Variable del tiempo
    hora_decena:    DS 1	;Variable para las decenas de horas
    hora_unidad:    DS 1	;Variable para las unidades de horas
    minuto_decena:  DS 1	;Variable para las decenas de minuto
    minuto_unidad:  DS 1	;Variable para las unidades de horas
    contador_TMR2:  DS 1	;Contador de TMR2 para LEDS intermitentes
    minuto:	    DS 1	;Incremento de minutos
    hora:	    DS 1	;Incremento de hora
    dia:	    DS 1	;Incremento de dia
    mes:	    DS 1	;Incremento de mes
    mes_unidad:	    DS 1	;Variable para las unidades de mes
    mes_decena:	    DS 1	;Variable para las decenas de mes
    dia_unidad:	    DS 1	;Variable para las unidades de dia
    dia_decena:	    DS 1	;Variable para las decenas de dia
    segt_unidad:    DS 1	;Variable para las unidades de mes
    segt_decena:    DS 1	;Variable para las decenas de mes
    mint_unidad:    DS 1	;Variable para las unidades de dia
    mint_decena:    DS 1	;Variable para las decenas de dia
    activar:	    DS 1	;Varibale para activar el modo activar del Timer
    segundo_t:	    DS 1	;Variable para los segundos del timer
    minuto_t:	    DS 1	;Variable para los minutos del timer
    segt_unidad_c:  DS 1	;Variable para las unidades de mes
    segt_decena_c:  DS 1	;Variable para las decenas de mes
    mint_unidad_c:  DS 1	;Variable para las unidades de dia
    mint_decena_c:  DS 1	;Variable para las decenas de dia
    
;MACROS
limite_max macro var, limite, var_incrementar
    movf    var, W
    sublw   limite
    btfsc   STATUS, 0
    return
    clrf    var
    incf    var_incrementar
    endm
    
division_m macro dividendo_f, divisor_l, resultado, residuo_f 
    clrf    resultado	    ;Se limpia el resultado
    movf    dividendo_f, W  ;copiar dividendo a residuo
    movwf   residuo_f
    incf    resultado, F    ;incremento el resultado
    movlw   divisor_l	    ;Se mueve la literal a W
    subwf   residuo_f, F    ;Se le resta 10 al residuo
    btfsc   STATUS, 0	    ;Si CARRY esta en 0 saltarse la siguiente instruccion
    goto    $-4
    decf    resultado, F	    ;
    movlw   divisor_l	    ;Se mueve la literal 100 a W
    addwf   residuo_f, F    ;Se le suma division a 100
    endm
    
reset_tmr0 macro
    banksel PORTD
    movlw 246	    ;Mueve la 246 a W, 5ms que es menor a 2ms
    movwf TMR0	    ;Se mueve W a TMR0
    bcf	  T0IF	    ;Se limpia la bandera
    endm 
    
reset_tmr1 macro
    movlw   0x0B	;Mover 0xB a W
    movwf   TMR1H	;Mover W a TMR1H
    movlw   0xDC	;Mover 0xDC a W
    movwf   TMR1L	;Mover W a TMR1L	
    bcf	    TMR1IF	;Habilitar bandera
    endm
    
;INSTRUCCIONES
PSECT resVect, class=CODE, abs, delta=2
;--------------vector reset----------------
ORG 00h        ;posición 0000h para el reset
resetVec:
    PAGESEL main
    goto main
    
PSECT intVect, class=CODE, abs, delta=2    
;----------- vector interrupciones ----------------
ORG 04h        ;posición para el interrupciones	
PUSH:				    ;Guardamos valores de los 2 registros
    movwf   W_Temp		    ;Guardar W al W_Temp
    swapf   STATUS, W		    ;Pasar el valor del vector Status a W, para después guardarlo en la variable
    movwf   Status_Temp		    ;Guardar status al registro Status_Temp
    
ISR:				    ;subrutina de interrupción
    btfsc   RBIF		    ;Verificacion de bandera de PORTB
    call    interrupcion_ioc_PORTB  ;Llamamos interrupcion PORTB
    btfsc   T0IF		    ;Verificacion de bandera de TMR0
    call    interrupcion_TMR0	    ;Llamamos interrupcion TMR0
    btfsc   TMR1IF		    ;Verificacion de bandera de TMR1
    call    interrupcion_TMR1	    ;Llamamos interrupcion TMR1
    btfsc   TMR2IF		    ;Verificacion de bandera de TMR2
    call    interrupcion_TMR2	    ;Llamamos interrupcion TMR2
POP:				    ;Recuperamos valores de los 2 registros
    swapf   Status_Temp, W	    ;Status_Temp lo guardamos en el W
    movwf   STATUS		    ;Se mueve W al registro de STATUS
    swapf   W_Temp, F
    swapf   W_Temp, W
    RETFIE			    ;regresamos a la posición en la que estabamos antes de que sucediera la interrupción
    
;--------Subrutina de interrupcion-------
interrupcion_ioc_PORTB:
    banksel PORTB
    btfss   PORTB, 0	    ;verifica si el boton esta apachado
    incf    estado	    ;incrementa estado

    movlw   1		    ;Se mueve 1 a W
    subwf   estado, W	    ;Se le resta estado a W
    btfsc   ZERO	    ;Si es 0 se salta la siguiente línea
    goto    S0_Hora	    ;Ir a S0_Hora
    
    movlw   2		    ;Se mueve 2 a W
    subwf   estado, W	    ;Se le resta estado a W
    btfsc   ZERO	    ;Si es 0 se salta la siguiente línea
    goto    S1_Fecha	    ;Ir a S1_Fecha
    
    movlw   3		    ;Se mueve 3 a W
    subwf   estado, W	    ;Se le resta estado a W
    btfsc   ZERO	    ;Si es 0 se salta la siguiente línea
    goto    S2_Timer	    ;Ir a S2_Timer
    
    movlw   4		    ;Se mueve 1 a W
    subwf   estado, W	    ;Se le resta estado a W
    btfsc   ZERO	    ;Si es 0 se salta la siguiente línea
    goto    S3_Hora_Config  ;Ir a S0_Hora
    
    movlw   5		    ;Se mueve 2 a W
    subwf   estado, W	    ;Se le resta estado a W
    btfsc   ZERO	    ;Si es 0 se salta la siguiente línea
    goto    S4_Fecha_Config ;Ir a S1_Fecha
    
    movlw   6		    ;Se mueve 3 a W
    subwf   estado, W	    ;Se le resta estado a W
    btfsc   ZERO	    ;Si es 0 se salta la siguiente línea
    goto    S5_Timer_Config ;Ir a S2_Timer
    
    movlw   7		    ;Se mueve 4 a W
    subwf   estado, W	    ;Se le resta estado a W
    clrf    estado	    ;Se limpia la variable estado, o sea se reinicia
    btfsc   ZERO	    ;Si es 0 se salta la siguiente línea
    goto    reseteo	    ;Ir a reseteo
    
    S0_Hora:
	clrf    PORTC	    ;Limpiamos PORTC
	bsf	PORTC, 7    ;Estado HORA se enciende
	bcf	RBIF	    ;limpiamos la bandera
    return
    
    S1_Fecha:
	clrf	PORTC	    ;Limpiamos PORTC
	bsf	PORTC, 6    ;Estado FECHA se enciende
	bcf	RBIF	    ;limpiamos la bandera
    return
    
    S2_Timer:
	clrf	PORTC	    ;Limpiamos PORTC
	bsf	PORTC, 5    ;Estado TIMER se enciende
	btfss	PORTB, 2
	call	activar_bandera
	bcf	RBIF	    ;limpiamos la bandera
    return  
    
    S3_Hora_Config:
	clrf    PORTC	    ;Limpiamos PORTC
	bsf	PORTC, 7    ;Estado HORA se enciende
	bsf	PORTC, 4    ;Estado Configuración
	////////////////|UNIDADES|//////////////////
	btfss	PORTB, 2    ;Verificar el boton de incremento unidad esta en set
	call	over_min
	btfss	PORTB, 3    ;Verificar el boton de decremento unidad esta en set
	call	under_min
;	/////////////////|DECENAS|//////////////////
	btfss	PORTB, 4    ;Verificar el boton de incremento unidad esta en set
	call	over_hora
	btfss	PORTB, 5    ;Verificar el boton de decremento unidad esta en set
	call	under_hora
	bcf	RBIF	    ;limpiamos la bandera
    return
    
    S4_Fecha_Config:
	clrf	PORTC	    ;Limpiamos PORTC
	bsf	PORTC, 6    ;Estado FECHA se enciende
	bsf	PORTC, 4    ;Estado Configuración
	////////////////|UNIDADES|//////////////////
	btfss	PORTB, 2    ;Verificar el boton de incremento unidad esta en set
	call	over_mes
	btfss	PORTB, 3    ;Verificar el boton de decremento unidad esta en set
	call	under_mes
	/////////////////|DECENAS|//////////////////
	btfss	PORTB, 4    ;Verificar el boton de incremento unidad esta en set
	call	mes_check_over
	btfss	PORTB, 5    ;Verificar el boton de decremento unidad esta en set
	call	mes_check_under
	bcf	RBIF	    ;limpiamos la bandera
    return
    
    S5_Timer_Config:
	clrf	PORTC	    ;Limpiamos PORTC
	bsf	PORTC, 5    ;Estado TIMER se enciende
	bsf	PORTC, 4    ;Estado Configuración
	////////////////|UNIDADES|//////////////////
	btfss	PORTB, 2    ;Verificar el boton de incremento unidad esta en set
	call	over_seg_t
	btfss	PORTB, 3    ;Verificar el boton de decremento unidad esta en set
	call	under_seg_t
	/////////////////|DECENAS|//////////////////
	btfss	PORTB, 4    ;Verificar el boton de incremento unidad esta en set
	call	over_min_t
	btfss	PORTB, 5    ;Verificar el boton de decremento unidad esta en set
	call	under_min_t
	bcf	RBIF	    ;limpiamos la bandera
    return
    
    reseteo:
	clrf	estado	    ;Limpiamos estado
	incf	estado	    ;Se incrementa estado
	bcf	RBIF	    ;limpiamos la bandera
    return
    
interrupcion_TMR0:
    reset_tmr0
    bcf	    PORTC, 3
    bcf	    PORTC, 2
    bcf	    PORTC, 1
    bcf	    PORTC, 0
    
    btfss   banderas, 0		;Revisar variable banderas
    goto    display_0		;Ir a display_0
    
    btfss   banderas, 1		;Revisar variable banderas
    goto    display_1		;Ir a display_1
    
    btfss   banderas, 2		;Revisar variable banderas
    goto    display_2		;Ir a display_2
    
    btfss   banderas, 3		;Revisar variable banderas
    goto    display_3		;Ir a display_3
    
display_0:
    clrf    banderas
    bsf	    banderas, 0		;Se setea la variable banderas
    movf    valor_display+0, W	;Valor_display a W
    movwf   PORTA		;W a PORTA
    bsf	    PORTC, 3		;Transistor del display_0 en 1
    return
    
display_1:
    bsf	    banderas, 1		;Se sete la variable banderas
    movf    valor_display+1, W	;Valor_display+1 a W
    movwf   PORTA		;W a PORTA
    bsf	    PORTC, 2		;Transistor del display_1 en 1
    return
    
display_2:
    bsf	    banderas, 2		;Se sete la variable banderas
    movf    valor_display+2, W	;Valor_display+1 a W
    movwf   PORTA		;W a PORTA
    bsf	    PORTC, 1		;Transistor del display_1 en 1
    return
    
display_3:
    bsf	    banderas, 3		;Se sete la variable banderas
    movf    valor_display+3, W	;Valor_display+1 a W
    movwf   PORTA		;W a PORTA
    bsf	    PORTC, 0		;Transistor del display_1 en 1
    return
    
interrupcion_TMR1:
    reset_tmr1			 ;Se llama a reset_tmr1
    incf    segundo		 ;Incremento segundo
    call    check_bandera_activar
    return

check_bandera_activar:
    btfss   activar, 0
    return
    call    under_timer
    return
    
interrupcion_TMR2:
    bcf	    TMR2IF		 ;Limpiamos la bandera de interrupcion TMR2
    decfsz  contador_TMR2, 1	 ;Se decrementa el contador_TMR2
    return
    
    movlw   10			 ;10 a W
    movwf   contador_TMR2	 ;W a contador_TMR2
    btfsc   PORTD, 0		 ;Si RD0 es 0 salta una linea
    goto    apagar		 ;Va a rutina de apagar
    goto    encender		 ;Va a rutina de encender
    
    apagar:
    bcf	    PORTD, 0		 ;RD0 = 0
    bcf	    PORTD, 1		 ;RD1 = 0
    return
    
    encender:
    bsf	    PORTD, 0		 ;RD0 = 1
    bsf	    PORTD, 1		 ;RD1 = 1
    return
    
;CONFIGURACIÓN DE MICROCONTROLADOR
PSECT code, delta=2, abs
ORG 100h      ;posición para el código
;----------------CONFIGURACIÓN------------
tabla:
    clrf   PCLATH
    bsf	   PCLATH, 0   ; PCLATH = 01, esto es sin modificar W
    andlw  0x0f        ;donde el valor más grande es f, o sea 15
    addwf  PCL         ; PCL = PCLATH + PCL + W, en el momento que se escriba PCL, cambian los dos valores
    retlw  00111111B   ;0
    retlw  00000110B   ;1
    retlw  01011011B   ;2
    retlw  01001111B   ;3
    retlw  01100110B   ;4
    retlw  01101101B   ;5
    retlw  01111101B   ;6
    retlw  00000111B   ;7
    retlw  01111111B   ;8
    retlw  01101111B   ;9
    retlw  01110111B   ;10 = A
    retlw  01111100B   ;11 = B
    retlw  00111001B   ;12 = C
    retlw  01011110B   ;13 = D
    retlw  01111001B   ;14 = E
    retlw  01110001B   ;15 = F
    
main:
    call config_io
    call config_reloj
    call config_tmr0
    call config_tmr1
    call config_tmr2
    call config_ioc_PORTB
    call config_interrupciones

;-------------LOOP PRINCIPAL--------------
loop:
    call    revisar_maximos
    call    modo_estados
    goto    loop
;-----------------SUBRUTINAS-------------
config_io:
    bsf	    STATUS, 5	    ;banco 11
    bsf	    STATUS, 6
    clrf    ANSEL	    ;pines digitales
    clrf    ANSELH
    
    ;ESPECIFICACIÓN DE ENTRADAS Y SALIDAS
    bsf	    STATUS, 5	    ;banco 01
    bcf	    STATUS, 6
    ;ENTRADAS - BOTONES
    bsf	    TRISB, 0	    ;RB0 entrada - Boton de Modos
    bsf	    TRISB, 5	    ;RB5 entrada - Boton de Display Up
    bsf	    TRISB, 4	    ;RB4 entrada - Boton de Display Down
    bsf	    TRISB, 3	    ;RB3 entrada - Boton de Editar/Aceptar
    bsf	    TRISB, 2	    ;RB2 entrada - Boton de Iniciar/Parar
    ;PULL-UPS BOTONES - PORTB
    bcf	    OPTION_REG, 7   ;Habilitación de PORTB pull-ups
    bsf	    WPUB, 0	    ;Pull-Up en RB0
    bsf	    WPUB, 5	    ;Pull-Up en RB5
    bsf	    WPUB, 4	    ;Pull-Up en RB4
    bsf	    WPUB, 3	    ;Pull-Up en RB3
    bsf	    WPUB, 2	    ;Pull-Up en RB2
    ;SALIDAS - DISPLAYS, LED 
    bcf	    TRISB, 7	    ;ALARMA
    bcf	    TRISC, 7	    ;RC7 salida - Modo Alarma
    bcf	    TRISC, 6	    ;RC6 salida - Modo Timer
    bcf	    TRISC, 5	    ;RC5 salida - Modo Fecha
    bcf	    TRISC, 4	    ;RC4 salida - Modo Hora
    bcf	    TRISD, 0	    ;RD0 salida - LED dos puntos Display
    bcf	    TRISD, 1	    ;RD1 salida - LED dos puntos Display
    bcf	    TRISD, 2
    clrf    TRISA	    ;PORTA salida - DISPLAYS
    bcf	    TRISC, 3	    ;RC3 salida - Transistor Display_0
    bcf	    TRISC, 2	    ;RC2 salida - Transistor Display_1
    bcf	    TRISC, 1	    ;RC1 salida - Transistor Display_2
    bcf	    TRISC, 0	    ;RC0 salida - Transistor Display_3
    
    banksel PORTA
    clrf    PORTA	    ;Limpiamos PORTA
    clrf    PORTC	    ;Limpiamos PORTC
    clrf    PORTD	    ;Limpiamos PORTD
    clrf    PORTB	    ;Limpiamos PORTB
    clrf    segundo
    clrf    minuto
    clrf    hora
    clrf    dia
    clrf    mes    
    clrf    segundo_t
    clrf    minuto_t
    movlw   10
    movwf   contador_TMR2
    return

config_reloj:
    banksel OSCCON
    bsf SCS   ; reloj interno
    bsf IRCF2
    bcf IRCF1
    bsf IRCF0 ;101, 2MHz
    return    
    
config_tmr0:
    banksel TRISA
    banksel OPTION_REG
    bcf PSA	 ;prescaler
    bsf PS2
    bsf PS1
    bsf PS0      ;prescaler 1-256
    bcf T0CS	 ;reloj interno
    banksel PORTA
    reset_tmr0
    return
 
config_tmr1:
    banksel PORTA
    bcf	    TMR1GE	;Siempre contando
    bsf	    T1CKPS1	;Prescaler2 8:1
    bsf	    T1CKPS0
    bcf	    T1OSCEN	;Reloj interno
    bcf	    TMR1CS
    bsf	    TMR1ON	;Prender TMR1
    reset_tmr1
    return

config_tmr2:
    banksel PORTA
    bsf	    TOUTPS3
    bsf	    TOUTPS2
    bsf	    TOUTPS1
    bsf	    TOUTPS0	;1:16 POSTCALER
    bsf	    T2CKPS1	    
    bsf	    T2CKPS0	;1:16 PRESCALER
    bsf	    TMR2ON	;Prendemos TMR2
    return 
    
config_interrupciones:
   banksel  TRISA
   bsf	    T0IE	;Interrupción TMR0
   bsf	    TMR1IE	;Interrupcion TMR1
   bsf	    TMR2IE	;Interrupcion TMR2
   banksel  PORTA
   bsf	    GIE		;Se habilita las banderas globales
   bsf	    PEIE	;Habilita interrupciones perifericas
   bsf	    RBIE	;Se habilita el cambio de PORTB
   bcf	    RBIF	;Se habilita el cambio de bandera de PORTB
   bcf	    T0IF	;Limpiamos bandera
   bcf	    TMR1IF	;Bandera TMR1
   bcf	    TMR2IF	;Bandera TMR2
   return
   
config_ioc_PORTB:
    banksel TRISA
    bsf	    IOCB, 0	;Se habilita las interrupciones en el RB0
    bsf	    IOCB, 5	;Se habilita las interrupciones en el RB5
    bsf	    IOCB, 4	;Se habilita las interrupciones en el RB4
    bsf	    IOCB, 3	;Se habilita las interrupciones en el RB3
    bsf	    IOCB, 2	;Se habilita las interrupciones en el RB2
    
    banksel PORTA
    movf    PORTB, W	;Al leer termina la condición de mismatch
    bcf	    RBIF
    return
    
limpiarvariables:
    banksel PORTA
    clrf    PORTC	;Limpia PORTC
    clrf    PORTD	;Limpia PORTD
    clrf    estado	;Limpia variable estado
    clrf    activar
    clrf    minuto_unidad
    clrf    minuto_decena
    clrf    hora_unidad
    clrf    hora_decena
    clrf    segt_unidad_c
    clrf    segt_decena_c
    clrf    mint_unidad_c
    clrf    mint_decena_c
    clrf    mes_unidad
    clrf    mes_decena
    clrf    dia_unidad
    clrf    dia_decena
    clrf    valor_display
    clrf    banderas
    clrf    contador_TMR2
    return
    
//////////////////////////|MODO DE BOTON ESTADOS|///////////////////////////////
modo_estados:
    movlw   1		;Se mueve 1 a W
    subwf   estado, W	;Se le resta estado a W
    btfsc   ZERO	;Si es 0 se salta la siguiente línea
    goto    set_hora	;Ir a set_hora

    movlw   2		;Se mueve 2 a W
    subwf   estado, W	;Se le resta estado a W
    btfsc   ZERO	;Si es 0 se salta la siguiente línea
    goto    fecha_state	;Ir a fecha_state
    
    movlw   3		;Se mueve 3 a W
    subwf   estado, W	;Se le resta estado a W
    btfsc   ZERO	;Si es 0 se salta la siguiente línea
    goto    set_timer_config	;Ir a S2_Timer
    
    movlw   4		;Se mueve 1 a W
    subwf   estado, W	;Se le resta estado a W
    btfsc   ZERO	;Si es 0 se salta la siguiente línea
    goto    set_hora	;Ir a set_hora

    movlw   5		;Se mueve 2 a W
    subwf   estado, W	;Se le resta estado a W
    btfsc   ZERO	;Si es 0 se salta la siguiente línea
    goto    fecha_state	;Ir a set_fecha
    
    movlw   6		;Se mueve 3 a W
    subwf   estado, W	;Se le resta estado a W
    btfsc   ZERO	;Si es 0 se salta la siguiente línea
    goto    timer_conf_state	;Ir a S2_Timer
    
    movlw   7		;Se mueve 5 a W
    subwf   estado, W	;Se le resta estado a W
    clrf    estado	;Se limpia la variable estado, o sea se reinicia
    btfsc   ZERO	;Si es 0 se salta la siguiente línea
    goto    reseteo_1	;Ir a reseteo
    
    reseteo_1:
	clrf PORTC
	goto modo_estados
    
///////////////////////////////|MODO DE HORA|///////////////////////////////////
revisar_maximos:
    ;limite_max macro var, limite, var_incrementar
    limite_max segundo, 59, minuto
    limite_max minuto, 59, hora
    limite_max hora, 23, dia
    return
    
set_hora:
    ;division_m macro dividendo_f, divisor_l, resultado, residuo_f 
    division_m minuto, 10, minuto_decena, minuto_unidad
    division_m hora, 10, hora_decena, hora_unidad
    ;Variables a Displays
    movf    minuto_unidad, W	    ;minuto_unidad a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display	    ;W a valor_display
    movf    minuto_decena, W	    ;minuto_decena a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display+1	    ;W a valor_display+1
    movf    hora_unidad, W	    ;hora_unidad a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display+2	    ;W a valor_display+2
    movf    hora_decena, W	    ;hora_decena a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display+3	    ;W a valor_display+3
    return  
    
//////////////////////////////|MODO DE FECHA|///////////////////////////////////
fecha_state:  
    movlw   0
    subwf   dia, 0
    btfsc   ZERO
    incf    dia
    
    movlw   0
    subwf   mes, 0
    btfsc   ZERO
    incf    mes
    
    call    meses_12
    call    set_fecha
    return

meses_12:  
    movlw   1
    subwf   mes, W
    btfsc   ZERO
    goto    enero
    
    movlw   2
    subwf   mes, W
    btfsc   ZERO
    goto    febrero
    
    movlw   3
    subwf   mes, W
    btfsc   ZERO
    goto    marzo
    
    movlw   4
    subwf   mes, W
    btfsc   ZERO
    goto    abril
    
    movlw   5
    subwf   mes, W
    btfsc   ZERO
    goto    mayo
    
    movlw   6
    subwf   mes, W
    btfsc   ZERO
    goto    junio
    
    movlw   7
    subwf   mes, W
    btfsc   ZERO
    goto    julio
    
    movlw   8
    subwf   mes, W
    btfsc   ZERO
    goto    agosto
    
    movlw   9
    subwf   mes, W
    btfsc   ZERO
    goto    septiembre
    
    movlw   10
    subwf   mes, W
    btfsc   ZERO
    goto    octubre
    
    movlw   11
    subwf   mes, W
    btfsc   ZERO
    goto    noviembre
    
    movlw   12
    subwf   mes, W
    btfsc   ZERO
    goto    diciembre
    
enero:
    movf    dia, W   
    sublw   32		
    btfss   ZERO	 
    return
    clrf    dia     
    incf    mes 
    return  

febrero:
    movf    dia, W
    sublw   29		  
    btfss   ZERO	  
    return
    clrf    dia      
    incf    mes	  ;
    return  

marzo:
    movf    dia  , W   
    sublw   32		  
    btfss   ZERO	  
    return
    clrf    dia        
    incf    mes	  
    return  

abril:
    movf    dia  , W   
    sublw   31		 
    btfss   ZERO	  
    return
    clrf    dia       
    incf    mes	  
    return 
    
mayo:
    movf    dia, W   ;
    sublw   32		  
    btfss   ZERO	  
    return
    clrf    dia      
    incf    mes	 
    return  

junio:
    movf    dia, W  
    sublw   31		  
    btfss   ZERO	  
    return
    clrf    dia     
    incf    mes	  
    return

julio:
    movf    dia, W   
    sublw   32		 
    btfss   ZERO	 
    return
    clrf    dia    
    incf    mes	 
    return  
    
agosto:
    movf    dia, W   
    sublw   32		  
    btfss   ZERO	 
    return
    clrf    dia     
    incf    mes	
    return  
    
septiembre:
    movf    dia, W   
    sublw   31		  
    btfss   ZERO	  
    return
    clrf    dia     
    incf    mes	 
    return
    
octubre:
    movf    dia, W  
    sublw   32		  
    btfss   ZERO	  
    return
    clrf    dia     
    incf    mes	  
    return  
    
noviembre:
    movf    dia, W  
    sublw   31		  
    btfss   ZERO	 
    return
    clrf    dia    
    incf    mes	  
    return

diciembre:
    movf    dia, W   
    sublw   32		  
    btfss   ZERO	  
    return
    clrf    dia    
    clrf    mes	  
    return

    
set_fecha:
    ;division_m macro dividendo_f, divisor_l, resultado, residuo_f 
    division_m mes, 10, mes_decena, mes_unidad
    division_m dia, 10, dia_decena, dia_unidad
    ;Variables a Displays
    movf    mes_unidad, W	    ;mes_unidad a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display	    ;W a valor_display
    movf    mes_decena, W	    ;mes_decena a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display+1	    ;W a valor_display+1
    movf    dia_unidad, W	    ;dia_unidad a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display+2	    ;W a valor_display+2
    movf    dia_decena, W	    ;dia_decena a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display+3	    ;W a valor_display+3
    return
  
////////////////////////////////|MODO DE TIMER|/////////////////////////////////  
under_timer:
    movf    minuto_t, W
    sublw   0
    btfss   STATUS, 2
    call    under_segundo_timer_aun
    call    under_segundo_timer
    return    
    
under_segundo_timer_aun:
    movf    segundo_t, W
    sublw   0
    btfss   STATUS, 2
    goto    $+4
    decf    minuto_t
    movlw   60
    movwf   segundo_t
    return
    decf    segundo_t
    return
    
under_segundo_timer:
    movf    segundo_t, W
    sublw   0
    btfss   STATUS, 2
    goto    $+3
    call    ALARMA_BRO
    btfss   STATUS, 2
    decf    segundo_t
    return
 
ALARMA_BRO:
    bcf	    activar, 0
    btfsc   activar, 0
    return
    bsf	    PORTB, 7
    return
    
activar_bandera:
    bsf	    activar, 0
    return
    
/////////////////////|CONFIGURACIÓN PARA MODO DE HORA|//////////////////////////
over_min:
    incf    minuto
    movf    minuto, W
    sublw   60
    btfsc   ZERO
    clrf    minuto
    return
    
under_min:
    movf    minuto, W
    sublw   0
    btfss   STATUS, 2
    goto    $+4
    movlw   59
    movwf   minuto
    return
    decf    minuto
    return

over_hora:
    incf    hora
    movf    hora, W
    sublw   24
    btfsc   ZERO
    clrf    hora
    return
    
under_hora:
    movf    hora, W
    sublw   0
    btfss   STATUS, 2
    goto    $+4
    movlw   23
    movwf   hora
    return
    decf    hora
    return
/////////////////////|CONFIGURACIÓN PARA MODO DE FECHA|/////////////////////////
over_mes:
    incf    mes
    movf    mes, W
    sublw   13
    btfsc   ZERO
    clrf    mes
    return
    
under_mes:
    movf    mes, W
    sublw   1
    btfss   STATUS, 2
    goto    $+4
    movlw   12
    movwf   mes
    return
    decf    mes
    return

mes_check_over:
    movf    mes, W
    sublw   1
    btfsc   ZERO
    goto    over_dia_tresyuno
    
    movf    mes, W
    sublw   2
    btfsc   ZERO
    goto    over_dia_dosyocho
    
    movf    mes, W
    sublw   3
    btfsc   ZERO
    goto    over_dia_tresyuno
    
    movf    mes, W
    sublw   4
    btfsc   ZERO
    goto    over_dia_tresycero
    
    movf    mes, W
    sublw   5
    btfsc   ZERO
    goto    over_dia_tresyuno
    
    movf    mes, W
    sublw   6
    btfsc   ZERO
    goto    over_dia_tresycero
    
    movf    mes, W
    sublw   7
    btfsc   ZERO
    goto    over_dia_tresyuno
    
    movf    mes, W
    sublw   8
    btfsc   ZERO
    goto    over_dia_tresyuno
    
    movf    mes, W
    sublw   9
    btfsc   ZERO
    goto    over_dia_tresycero
    
    movf    mes, W
    sublw   10
    btfsc   ZERO
    goto    over_dia_tresyuno
    
    movf    mes, W
    sublw   11
    btfsc   ZERO
    goto    over_dia_tresycero
    
    movf    mes, W
    sublw   12
    btfsc   ZERO
    goto    over_dia_tresyuno

over_dia_dosyocho:
    incf    dia
    movf    dia, W
    sublw   29
    btfsc   ZERO
    clrf    dia
    return
    
over_dia_tresycero:
    incf    dia
    movf    dia, W
    sublw   31
    btfsc   ZERO
    clrf    dia
    return
    
over_dia_tresyuno:
    incf    dia
    movf    dia, W
    sublw   32
    btfsc   ZERO
    clrf    dia
    return
    
mes_check_under:
    movf    mes, W
    sublw   1
    btfsc   ZERO
    goto    under_dia_tresyuno 
    
    movf    mes, W
    sublw   2
    btfsc   ZERO
    goto    under_dia_dosyocho
    
    movf    mes, W
    sublw   3
    btfsc   ZERO
    goto    under_dia_tresyuno
    
    movf    mes, W
    sublw   4
    btfsc   ZERO
    goto    under_dia_tresycero
    
    movf    mes, W
    sublw   5
    btfsc   ZERO
    goto    under_dia_tresyuno
    
    movf    mes, W
    sublw   6
    btfsc   ZERO
    goto    under_dia_tresycero
    
    movf    mes, W
    sublw   7
    btfsc   ZERO
    goto    under_dia_tresyuno
    
    movf    mes, W
    sublw   8
    btfsc   ZERO
    goto    under_dia_tresyuno
    
    movf    mes, W
    sublw   9
    btfsc   ZERO
    goto    under_dia_tresycero
    
    movf    mes, W
    sublw   10
    btfsc   ZERO
    goto    under_dia_tresyuno
    
    movf    mes, W
    sublw   11
    btfsc   ZERO
    goto    under_dia_tresycero
    
    movf    mes, W
    sublw   12
    btfsc   ZERO
    goto    under_dia_tresyuno    
    
under_dia_dosyocho:
    movf    dia, W
    sublw   1
    btfss   STATUS, 2
    goto    $+4
    movlw   28
    movwf   dia
    return
    decf    dia
    return
    
under_dia_tresycero:
    movf    dia, W
    sublw   1
    btfss   STATUS, 2
    goto    $+4
    movlw   30
    movwf   dia
    return
    decf    dia
    return
    
under_dia_tresyuno:
    movf    dia, W
    sublw   1
    btfss   STATUS, 2
    goto    $+4
    movlw   31
    movwf   dia
    return
    decf    dia
    return
/////////////////////|CONFIGURACIÓN PARA MODO DE TIMER|/////////////////////////
timer_conf_state:
    movlw   0
    subwf   segundo_t, 0
    btfsc   ZERO
    incf    segundo_t
    call    set_timer_config
    return
    
set_timer_config:
    ;division_m macro dividendo_f, divisor_l, resultado, residuo_f 
    division_m segundo_t, 10, segt_decena_c, segt_unidad_c
    division_m minuto_t, 10, mint_decena_c, mint_unidad_c
    ;Variables a Displays
    movf    segt_unidad_c, W	    ;mes_unidad a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display	    ;W a valor_display
    movf    segt_decena_c, W	    ;mes_decena a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display+1	    ;W a valor_display+1
    movf    mint_unidad_c, W	    ;dia_unidad a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display+2	    ;W a valor_display+2
    movf    mint_decena_c, W	    ;dia_decena a W
    call    tabla		    ;Llama a tabla
    movwf   valor_display+3	    ;W a valor_display+3
    return
    
over_seg_t:
    incf    segundo_t
    movf    segundo_t, W
    sublw   60
    btfsc   ZERO
    clrf    segundo_t
    return
    
under_seg_t:
    movf    segundo_t, W
    sublw   1
    btfss   STATUS, 2
    goto    $+4
    movlw   59
    movwf   segundo_t
    return
    decf    segundo_t
    return
    
over_min_t:
    incf    minuto_t
    movf    minuto_t, W
    sublw   100
    btfsc   ZERO
    clrf    minuto_t
    return
    
under_min_t:
    movf    minuto_t, W
    sublw   0
    btfss   STATUS, 2
    goto    $+4
    movlw   99
    movwf   minuto_t
    return
    decf    minuto_t
    return
END
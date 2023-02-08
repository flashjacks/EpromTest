;*** EPROMTEST para probar cualquier FlashROM
;*** Por Aquijacks. www.retromsx.com

;*** Realiza un borrado, grabado de 0Fh, lectura de 0Fh, borrado, 
;*** grabado de F0h, lectura de F0h y borrado.

; Ensamblado con sjASM v0.42c
; http://www.xl2s.tk/
;
; Ejecutar: sjasm.exe EPROMTST.asm EPROMTST.COM
;
;--------------------------------------------------------------------------


; Código ASCII
LF	equ	0ah
CR	equ	0dh
ESC	equ	1bh
; Standard BIOS and work area entries
CLS	equ	000C3h
CHPUT	equ	000A2h
CHSNS	equ	0009Ch
KILBUF	equ	00156h

; Varios
CALSLT  equ     0001Ch
BDOS	equ	00005h
WRSLT	equ	00014h
ENASLT	equ	00024h
FCB	equ	0005ch
DMA	equ	00080h
RSLREG	equ	00138h
SNSMAT	equ	00141h
RAMAD1	equ	0f342h
RAMAD2	equ	0f343h
LOCATE	equ	0f3DCh
BUFTOP	equ	08000h
CHGET	equ	0009fh
POSIT	equ	000C6h
MNROM	equ	0FCC1h	; Main-ROM Slot number & Secondary slot flags table
DRVINV	equ	0FB22H	; Installed Disk-ROM

	org	0100h

START:
	jp	Main


; Textos del programa

MESVER:
	db	"FlashROM Test v1.00 para",CR,LF
	db	"por Aquijacks.",CR,LF
	db	"www.retromsx.com"
MESend:
	db	CR,LF,"$"
MESend1:
	db	CR,LF,"$"
HlpMes:
	db	"Comandos: EPROMTST /Sxx",CR,LF
	db	"          EPROMTST (Enter)",CR,LF
	db	"(xx: FlashRom direccion slot PS)",CR,LF
	db	"(x:  FlashRom direccion slot P)",CR,LF,"$"
FlsEra:
	db	"Borrando Flashrom...","$"
FlsEok:
	db	"OK",CR,LF,"$"
FlsErr:
	db	"Error escribiendo en Flashrom!",CR,LF,"$"
DonMes:
	db	"Completado. Hasta otra!!",CR,LF,"$"
DonMes2:
	db	"Hasta otra!!",CR,LF,"$"
AM29F0xx:
	db	"29F040 encontrado en Slot ","$"
NO_FLSH:
	db	"FlashRom no encontrada!",CR,LF,"$"
WarnMess:
	db	"Has seleccionado un slto que",CR,LF
	db	"contiene un DISK-ROM!",CR,LF,"$"
AvisoMess:
	db	CR,LF,"Este proceso borra la Flashrom.",CR,LF
	db	"Asegurate elegir el mapper correcto.",CR,LF
	db	"Yo no verifico que lo sea.",CR,LF,"$"
PregMess:
	db	CR,LF,"Elige opcion:",CR,LF
	db	"    1.-KONAMI5",CR,LF
	db	"    2.-ASCII8",CR,LF
	db	"    3.-ASCII16",CR,LF
	db	"    0.-Salir/Abortar",CR,LF,"$"
ConfirmMess:
	db	"Do you want to erase it? (Y/N)",CR,LF,"$"
CancelMess:
	db	"Cancelado.",CR,LF,"$"
Leer_Texto_0F:
	db	"Leyendo bloque de datos 0F:",CR,LF,"$"
Grabar_Texto_0F:
	db	"Grabando bloque de datos 0F:",CR,LF,"$"
Leer_Texto_F0:
	db	"Leyendo bloque de datos F0:",CR,LF,"$"
Grabar_Texto_F0:
	db	"Grabando bloque de datos F0:",CR,LF,"$"
Rec_0F_mes:
	db	"Grabados bytes 0F correctamente.",CR,LF,"$"
Rec_0F_fail:
	db	"Grabados bytes 0F con defectos.",CR,LF,"$"
Rec_F0_mes:
	db	"Grabados bytes F0 correctamente.",CR,LF,"$"
Rec_F0_fail:
	db	"Grabados bytes F0 con defectos.",CR,LF,"$"
Leidos_0F:
	db	"Leidos bytes 0F correctamente.",CR,LF,"$"
Leidos_F0:
	db	"Leidos bytes F0 correctamente.",CR,LF,"$"
Leidos_0F_Fallo:
	db	"Leidos bytes 0F con defectos.",CR,LF,"$"
Leidos_F0_Fallo:
	db	"Leidos bytes F0 con defectos.",CR,LF,"$"
Error_Leer:
	db	"Fallo. Lectura byte incorrecto.",CR,LF,"$"
Todo_OK:
	db	"Perfecto en todas las posiciones.",CR,LF,"$"
Todo_NOK:
	db	"Defectos en algunas posiciones.",CR,LF,"$"

;---------------------------------------------------
; Programa principal

Main:
	; Hace un clear Screen o CLS.
	xor    a		; Pone a cero el flag Z.
	ld     ix, CLS          ; Petición de la rutina BIOS. En este caso CLS (Clear Screen).
	ld     iy,(MNROM)       ; BIOS slot
        call   CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.

	; Imprime en pantalla en texto inicial.
	ld	de,MESVER
	call	Rep_Print	; Imprime texto por pantalla.


; *** Auto-detection routine
	ld	b,1		; B=Primary Slot
BCLM:
	ld	c,0		; C=Secondary Slot
BCLMI:
	push	bc		; Guarda en la Pila el Slot/Subslot.
	call	AutoSeek	; Hace búsqueda de FlashJacks en la propuesta Slot/Subslot
	pop	bc		; Recupera la pila Slot/Slubslot.
	ld	a,(ERMSlt)	; Recupera formato FxxxSSPP último.
	bit	7,a		; Verifica el bit de Slot expandido.
	jp	z, BCLMA	; Si no está expandido, salta al siguinte Slot ignorando los Subslots.
	inc	c		; Incrementa Subslot.
	ld	a,c		; Lo pasa al acumulador.
	cp	4		; Compara que no supere 4 (No existe el subslot 4).
	jr	nz,BCLMI	; Jump if Secondary Slot < 4
BCLMA:	inc	b		; Incrementa Slot Primario.
	ld	a,b		; Lo pasa al acumulador.
	cp	04h		; Compara que no supere 4 (No existe el slot 4).
	jp	nz,BCLM		; Jump if Primary Slot < 4

BCLM2:	ld	a,(SubslotA)	; Una vez barrido todos los Slots/Subslots, mira si hay algo en SubslotA. (Hace falta 1 como mínimo para cargar una ROM)
	cp	00h
	jp	z, NO_FND
	ld	a,(SubslotA)
	ld	(ERMSlt), a	; Carga el primer Subslot encontrado.
	ld	a,(TipoA)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida, la primera en este caso al no haber comandos.	
	jp	Parameters	; Continua con el programa.
	
NO_FND:
	ld	de,NO_FLSH	; Pointer to NO_FLSH message
	jp	Done


; --- Subrutina de búsqueda
AutoSeek:
	ld	a,b		; Pasa el acumulador el Slot Primario.
	ld	hl,MNROM	; Bios Slot 0FCC1h. Lo pasa a hl.
	ld	d,0		; Pone a cero d.
	ld	e,b		; Pasa a b el Slot Primario.
	add	hl,de		; Suma al BIOS Slot el Slot Primario. Esto fija en HL las banderas del Slot que se está tratando.
	bit	7,(hl)		; Mira si ese Slot está expandido o no.
	ld	a,b		; Pasa el acumulador el Slot Primario.
	jr	z,SalSlt	; Lee el FCC1h + NºSlot cada bit(7) si es expandido o no. Salta si no está expandido. a vale el NºSlot.
	; Si tiene subslot ejecuta lo siguiente.
	ld	a,c		; Reordena bc y lo transfiere en a con el formato FxxxSSPP
	sla	a
	sla	a
	or	b
	or	10000000b	; Le dice a EMRSlt que es un sublot. Bit 7 a 1.

SalSlt: ld	(ERMSlt),a	; format FxxxSSPP
	; Secuencia búsqueda si se trata de un DiskROM.
	ld	b,a		; Keep actual slot value
	bit	7,a
	jr	nz,SecSlt	; Jump if Secondary Slot
	and	3
SecSlt:
	ld	c,a
	ld	a,(DRVINV)	; A = slot value of main Rom-disk
	bit	7,a
	jp	nz,SecSlt1	; Jump if Secondary Slot
	and	3		; Keep primary slot bits
SecSlt1:
	cp	c
	ret	z		; Return if Disk-Rom Slot
	ld	a,(DRVINV+2)	; A = slot value of second Rom-disk
	bit	7,a
	jp	nz,SecSlt2	; Jump if Secondary Slot
	and	3		; Keep primary slot bits
SecSlt2:
	cp	c
	ret	z		; Return if Disk-Rom Slot
	ld	a,(DRVINV+4)	; A = slot value of third Rom-disk
	bit	7,a
	jp	nz,SecSlt3	; Jump if Secondary Slot
	and	3		; Keep primary slot bits
SecSlt3:
	cp	c
	ret	z		; Return if Disk-Rom Slot
	ld	a,(DRVINV+6)	; A = slot value of fourth Rom-disk
	bit	7,a
	jp	nz,SecSlt4	; Jump if Secondary Slot
	and	3		; Keep primary slot bits
SecSlt4:
	cp	c
	ld	a,b		; Restore actual slot value
	ret	z		; Return if Disk-Rom Slot
	; Fin secuencia búsqueda si se trata de un DiskROM
; ---
	ld	hl,4000h
	call	ENASLT		; Select a Slot in Bank 1 (4000h ~ 7FFFh)
	di

	ld	a, 00h		; Resetea el tipo de FlashRom
	ld	(SerchTipo),a	

	ld	a, 00h		; Resetea el tipo de FlashRom
	ld	(CartTipo),a	


	ld	a,(4000h)	; Hace una lectura para tirar cualquier intento pasado de petición.

	ld	a,0aah
	ld	(4555h),a	; Autoselect
	ld	a,055h
	ld	(42aah),a	; Mode
	ld	a,090h
	ld	(4555h),a	; ON
	
	ld	b,16
	ld	hl,4000h
RDID_BCL:
	ld	a,(hl)		; (HL) = Manufacturer ID

	inc	hl
	ld	a,(hl)

	cp	0D5h		; Device ID for AM29F080B
	ex	AF,AF'
	ld	a, 80h		; Guarda tipo de FlashRom 80h
	ld	(SerchTipo),a	
	ld	a,038h
	ld	(AM29F0xx+4),a
	ld	a,030h
	ld	(AM29F0xx+5),a
	ex	AF,AF'
	jp	z,ID_OK

	cp	0A4h		; Device ID for AM29F040B
	ex	AF,AF'
	ld	a, 40h		; Guarda tipo de FlashRom 40h
	ld	(SerchTipo),a	
	ld	a,034h
	ld	(AM29F0xx+4),a
	ld	a,030h
	ld	(AM29F0xx+5),a
	ex	AF,AF'
	jp	z,ID_OK

	cp	077h		; Device for AM29F004B (Top Boot Block)
	ex	AF,AF'
	ld	a, 04h		; Guarda tipo de FlashRom 04h
	ld	(SerchTipo),a	
	ld	a,030h
	ld	(AM29F0xx+4),a
	ld	a,034h
	ld	(AM29F0xx+5),a
	ex	AF,AF'
	jp	z,ID_OK
	cp	07Bh		; Device for AM29F004B (Bottom Boot Block)
	jp	z,ID_OK

	cp	0B0h		; Device for AM29F002 (Top Boot Block)
	ex	AF,AF'
	ld	a, 02h		; Guarda tipo de FlashRom 02h
	ld	(SerchTipo),a	
	ld	a,030h
	ld	(AM29F0xx+4),a
	ld	a,032h
	ld	(AM29F0xx+5),a
	ex	AF,AF'
	jp	z,ID_OK
	cp	034h		; Device for AM29F002 (Bottom Boot Block)
	jp	z,ID_OK

	cp	020h		; Device ID for AM29F010
	ex	AF,AF'
	ld	a, 10h		; Guarda tipo de FlashRom 10h
	ld	(SerchTipo),a	
	ld	a,031h
	ld	(AM29F0xx+4),a
	ld	a,030h
	ld	(AM29F0xx+5),a
	ex	AF,AF'
	jp	z,ID_OK

	cp	0ADh		; Device ID for AM29F016
	ex	AF,AF'
	ld	a, 16h		; Guarda tipo de FlashRom 16h
	ld	(SerchTipo),a	
	ld	a,031h
	ld	(AM29F0xx+4),a
	ld	a,036h
	ld	(AM29F0xx+5),a
	ex	AF,AF'
	jp	z,ID_OK

	cp	041h		; Device ID for AM29F032
	ex	AF,AF'
	ld	a, 32h		; Guarda tipo de FlashRom 32h
	ld	(SerchTipo),a	
	ld	a,033h
	ld	(AM29F0xx+4),a
	ld	a,032h
	ld	(AM29F0xx+5),a
	ex	AF,AF'
	jp	z,ID_OK

	ld	a, 00h		; Guarda tipo de FlashRom 00h (Ninguno)
	ld	(SerchTipo),a	
	ld	a,(RAMAD1)
	ld	hl,4000h
	ld	(hl),0f0h	; AM29F0xx ID reading mode OFF. Te saca fuera del Infochip
	call	ENASLT		; Select Main-RAM in MSX"s Bank 1
	ei
	ret

ID_OK:	ld	hl,4000h
	ld	(hl),0f0h	; AM29F0xx ID reading mode OFF. Te saca fuera del Infochip	
			
	ld	a,(RAMAD1)
	ld	hl,4000h
	call	ENASLT		; Select Main-RAM in MSX"s Bank 1
	ei			; Activa interrupciones.

	ld	de,AM29F0xx	; Puntero del texto de AM29F0xx encontrado
	call	Rep_Print	; Imprime texto por pantalla.
	
	ld	a,(ERMSlt)	; Recupera EMRSlt. Formato FxxxSSPP
	and	3		; Se queda solo con el número del Slot principal.
	add	a,30h		; Lo convierte a carácter.
	ld	e,a		; Lo transfiere a BDOS
	xor	a		 ; Pone a cero el flag Z.
	ld	a,e
	ld	ix, CHPUT        ; Petición de la rutina BIOS. En este caso CHPUT (Imprimir caracter).
	ld	iy,(MNROM)       ; BIOS slot
        call	CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	ld	a,(ERMSlt)	; Recupera EMRSlt. Formato FxxxSSPP
	bit	7,a		; Compara si el subslot está activo.
	jr	z,FinSlt2	; Salta si no hay subslot. 
	ld	e,02Dh		; Vuelca el carácter guión.
	xor	a		 ; Pone a cero el flag Z.
	ld	a,e
	ld	ix, CHPUT        ; Petición de la rutina BIOS. En este caso CHPUT (Imprimir caracter).
	ld	iy,(MNROM)       ; BIOS slot
        call	CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	ld	a,(ERMSlt)	; Recupera EMRSlt. Formato FxxxSSPP
	and	0Ch		; Se queda solo con el número del Subslot.
	srl	a		; Lo mueve a unidades.
	srl	a
	add	a,30h		; Lo convierte a carácter.
	ld	e,a		; Lo transfiere a BDOS
	xor	a		 ; Pone a cero el flag Z.
	ld	a,e
	ld	ix, CHPUT        ; Petición de la rutina BIOS. En este caso CHPUT (Imprimir caracter).
	ld	iy,(MNROM)       ; BIOS slot
        call	CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
FinSlt2:ld	de,MESend1	; Vuelca carácter enter.
	call	Rep_Print	; Imprime texto por pantalla.

; Guarda en SubslotA el primer valor, en SubslotB el segundo valor, etc.... hasta 8 valores (2 Cartuchos de AM29F0xx con todos sus Subslots con FlashRoms)
	ld	a, (Pasopor0)
	cp	00h
	jp	nz, Paso1
	inc	a
	ld	(Pasopor0), a
	ld	a,(ERMSlt)
	ld	(SubslotA), a
	ld	a,(SerchTipo)
	ld	(TipoA), a
	ret
Paso1:	
	ld	a, (Pasopor0)
	cp	01h
	jp	nz, Paso2
	inc	a
	ld	(Pasopor0), a
	ld	a,(ERMSlt)
	ld	(SubslotB), a
	ld	a,(SerchTipo)
	ld	(TipoB), a
	ret
Paso2:	
	ld	a, (Pasopor0)
	cp	02h
	jp	nz, Paso3
	inc	a
	ld	(Pasopor0), a
	ld	a,(ERMSlt)
	ld	(SubslotC), a
	ld	a,(SerchTipo)
	ld	(TipoC), a
	ret
Paso3:	
	ld	a, (Pasopor0)
	cp	03h
	jp	nz, Paso4
	inc	a
	ld	(Pasopor0), a
	ld	a,(ERMSlt)
	ld	(SubslotD), a
	ld	a,(SerchTipo)
	ld	(TipoD), a
	ret
Paso4:	
	ld	a, (Pasopor0)
	cp	04h
	jp	nz, Paso5
	inc	a
	ld	(Pasopor0), a
	ld	a,(ERMSlt)
	ld	(SubslotE), a
	ld	a,(SerchTipo)
	ld	(TipoE), a
	ret
Paso5:	
	ld	a, (Pasopor0)
	cp	05h
	jp	nz, Paso6
	inc	a
	ld	(Pasopor0), a
	ld	a,(ERMSlt)
	ld	(SubslotF), a
	ld	a,(SerchTipo)
	ld	(TipoF), a
	ret
Paso6:	
	ld	a, (Pasopor0)
	cp	06h
	jp	nz, Paso7
	inc	a
	ld	(Pasopor0), a
	ld	a,(ERMSlt)
	ld	(SubslotG), a
	ld	a,(SerchTipo)
	ld	(TipoG), a
	ret
Paso7:	
	ld	a, (Pasopor0)
	cp	07h
	jp	nz, Paso8
	inc	a
	ld	(Pasopor0), a
	ld	a,(ERMSlt)
	ld	(SubslotH), a
	ld	a,(SerchTipo)
	ld	(TipoH), a
	ret
Paso8:	
	ret

; *** End of Auto-detection routine


Parameters:
	ld	hl,(DMA)	; Esto pone un 255 al final de la entrada de parámetros. Necesario para los MSX1.
	ld	h,0
	ld	bc,DMA +1
	add	hl,bc
	ld	(hl),255
	
	ld	hl,DMA
Espaci:	inc	hl		; Esto ignora todos los espacios que hay en medio.
	ld	a,(hl)
	cp	020h
	jr	z,Espaci	; Bucle ignorar espacios.
	cp	255
	jp	z,OverWrite	; Jump if no parameter

; Check parameter /S . 
SecCon:	ld	c,"S"		; 'S' character
	call	SeekPar		; Busqueda con avance de letra.
	cp	254		; Si no ha encontrado parámetros, procede a la carga automática del archivo.
	jp	z,No_S		; Salta a la ejecución automática si el parámetro S no se ha encontrado.
	cp	253
	jp	z,SecGet	; Salta si es el parámetro S.	
	cp	255
	ld	de,HlpMes	; Si hay error en la síntasis, expulsa la ayuda.
	jp	z,Done		; Jump if syntax error
	ld	c,"s"		; 's' character
	call	SeekPar		; Busqueda con avance de letra.
	cp	254		; Si no ha encontrado parámetros, procede a la carga automática del archivo.
	jp	z,No_S		; Salta a la ejecución automática si el parámetro S no se ha encontrado.
	cp	253
	jp	z,SecGet	; Salta si es el parámetro S.	
	cp	255
	ld	de,HlpMes	; Si hay error en la síntasis, expulsa la ayuda.
	jp	z,Done		; Jump if syntax error
	jp	SecCon		; Salta a la ejecución de los parámetros si no hay error.	

; Subsecuencias de búsqueda de parámetros
SecGet:	call	GetNum		; Get the slot number from parameter
	cp	255
	ld	de,HlpMes	; Si hay error en la síntasis, expulsa la ayuda.
	jp	z,Done		; Jump if syntax error
	jp	ContSe


; Ejecución de los parámetros dados.
ContSe:	ld	a,(ForzaSlot)	; Recupera ForzaSlot para saber si hay Forzado de Slot principal.
	cp	01h		; Si hay Forzado de Slot
	jp	z,Slot_Pr	; Salta a la gestión de Slot Principal.

	call	CheckSLT	; check if Megaflash is inserted in /Sxx Slot
	ld	a,00h
	cp	e
	ld	de,NO_FLSH	; Pointer to NO_FLSH message
	jp	nz,Done		; Comprueba si ha habido un error. Salta a fallo de carga si lo ha habido.
	jp	OverWrite

Slot_Pr:call	CheckS2		; check if Megaflash is inserted in /Sxx Slot
	ld	(ERMSlt),a	; 
	ld	a,00h
	cp	e
	ld	de,NO_FLSH	; Pointer to NO_FLSH message
	jp	nz,Done		; Comprueba si ha habido un error. Salta a fallo de carga si lo ha habido.
	jp	OverWrite

No_S:
	ld	a,(SubslotA)	; Si no hay tampoco FlashRom salta el mensaje de FlashROM no encontrado.
	ld	(ERMSlt),a	; Vuelca el contenido de SubslotA por si tiene valor de carga.
	or	a
	ld	de,NO_FLSH	; Pointer to NO_FLSH message
	jp	z,Done		; Jump if Flash Rom not found


OverWrite:



;--- Pregunta si quiere continuar

	ld	de,AvisoMess
	call	Rep_Print	; Imprime texto por pantalla.

	ld	de,PregMess
	call	Rep_Print	; Imprime texto por pantalla.

WaitKey2:
	xor	a			; Pone a cero el flag Z.
	ld	ix, KILBUF		; Petición de la rutina BIOS. En este caso KILBUF (Borra el buffer del teclado).
	ld	iy,(MNROM)		; BIOS slot
        call	CALSLT			; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	
	ld	a,0			;Fila 0. Donde está el número 1.
	ld	ix,141h
	ld	iy,(MNROM)		; BIOS slot
        call	CALSLT			; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	bit	1,a			;Columna 1 para el número 1.
	jp	z,InicioKON

	xor	a			; Pone a cero el flag Z.
	ld	ix, KILBUF		; Petición de la rutina BIOS. En este caso KILBUF (Borra el buffer del teclado).
	ld	iy,(MNROM)		; BIOS slot
        call	CALSLT			; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	
	ld	a,0			;Fila 0. Donde está el número 2.
	ld	ix,141h
	ld	iy,(MNROM)		; BIOS slot
        call	CALSLT			; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	bit	2,a			;Columna 2 para el número 2.
	jp	z,InicioASC8

	xor	a			; Pone a cero el flag Z.
	ld	ix, KILBUF		; Petición de la rutina BIOS. En este caso KILBUF (Borra el buffer del teclado).
	ld	iy,(MNROM)		; BIOS slot
        call	CALSLT			; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	
	ld	a,0			;Fila 0. Donde está el número 3.
	ld	ix,141h
	ld	iy,(MNROM)		; BIOS slot
        call	CALSLT			; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	bit	3,a			;Columna 3 para el número 3.
	jp	z,InicioASC16
	
	xor	a			; Pone a cero el flag Z.
	ld	ix, KILBUF		; Petición de la rutina BIOS. En este caso KILBUF (Borra el buffer del teclado).
	ld	iy,(MNROM)		; BIOS slot
        call	CALSLT			; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	
	ld	a,0			;Fila 0. Donde está el número 0.
	ld	ix,141h
	ld	iy,(MNROM)		; BIOS slot
        call	CALSLT			; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	bit	0,a			;Columna 0 para el número 0.
	ld	de,DonMes2
	jp	z,Done	
	
	jp	WaitKey2

InicioKON:			; Selección mapper Konami5
	ld	a, 01h
	ld	(Mapper),a	; Vuelca el tipo de mapper que queremos (00 ASCII16K, 01 Konami5, 02 ASCII8K)
	;--- Asignación del tamaño de la FlashROM en bloques de 8k.
	ld	a, 0Fh		; 0Fh para 128kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	10h		; Comprueba si es FlashROM 128k. AM29F010
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 1Fh		; 1Fh para 256kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	02h		; Comprueba si es FlashROM 256k. AM29F002
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 3Fh		; 3Fh para 512kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	04h		; Comprueba si es FlashROM 512k. AM29F004
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 3Fh		; 3Fh para 512kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	40h		; Comprueba si es FlashROM 512k. AM29F040
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 7Fh		; 7Fh para 1024kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	80h		; Comprueba si es FlashROM 1024k. AM29F080
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 0FFh		; FFh para 2048kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	16h		; Comprueba si es FlashROM 2048k. AM29F016
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 0FFh		; FFh para 2048kB en bloques de 8k. Para 8k el tope está en 2048kB.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	32h		; Comprueba si es FlashROM 4096k. AM29F032
	jp	z,Iniciociclo	; Salta a iniciociclo.

	ld	a, 3Fh		; 3Fh para 512kB en bloques de 8k. Valor por defecto si no cuadran los anteriores
	ld	(RAMstart),a

	jp	Iniciociclo

InicioASC8:			; Selección mapper ASCII8K
	ld	a, 02h
	ld	(Mapper),a	; Vuelca el tipo de mapper que queremos (00 ASCII16K, 01 Konami5, 02 ASCII8K)
	;--- Asignación del tamaño de la FlashROM en bloques de 8k.
	ld	a, 0Fh		; 0Fh para 128kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	10h		; Comprueba si es FlashROM 128k. AM29F010
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 1Fh		; 1Fh para 256kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	02h		; Comprueba si es FlashROM 256k. AM29F002
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 3Fh		; 3Fh para 512kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	04h		; Comprueba si es FlashROM 512k. AM29F004
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 3Fh		; 3Fh para 512kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	40h		; Comprueba si es FlashROM 512k. AM29F040
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 7Fh		; 7Fh para 1024kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	80h		; Comprueba si es FlashROM 1024k. AM29F080
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 0FFh		; FFh para 2048kB en bloques de 8k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	16h		; Comprueba si es FlashROM 2048k. AM29F016
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 0FFh		; FFh para 2048kB en bloques de 8k. Para 8k el tope está en 2048kB.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	32h		; Comprueba si es FlashROM 4096k. AM29F032
	jp	z,Iniciociclo	; Salta a iniciociclo.

	ld	a, 3Fh		; 3Fh para 512kB en bloques de 8k. Valor por defecto si no cuadran los anteriores
	ld	(RAMstart),a

	jp	Iniciociclo

InicioASC16:			; Selección mapper ASCII16K
	
	ld	a, 00h
	ld	(Mapper),a	; Vuelca el tipo de mapper que queremos (00 ASCII16K, 01 Konami5, 02 ASCII8K)
	;--- Asignación del tamaño de la FlashROM en bloques de 16k.
	ld	a, 07h		; 07h para 128kB en bloques de 16k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	10h		; Comprueba si es FlashROM 128k. AM29F010
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 0Fh		; 0Fh para 256kB en bloques de 16k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	02h		; Comprueba si es FlashROM 256k. AM29F002
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 1Fh		; 1Fh para 512kB en bloques de 16k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	04h		; Comprueba si es FlashROM 512k. AM29F004
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 1Fh		; 1Fh para 512kB en bloques de 16k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	40h		; Comprueba si es FlashROM 512k. AM29F040
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 3Fh		; 3Fh para 1024kB en bloques de 16k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	80h		; Comprueba si es FlashROM 1024k. AM29F080
	jp	z,Iniciociclo	; Salta a iniciociclo. 
	
	ld	a, 07Fh		; 7Fh para 2048kB en bloques de 16k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	16h		; Comprueba si es FlashROM 2048k. AM29F016
	jp	z,Iniciociclo	; Salta a iniciociclo. 

	ld	a, 0FFh		; FFh para 4096kB en bloques de 16k.
	ld	(RAMstart),a
	ld	a, (CartTipo)	; Pide el tipo de FlashROM elegida. Mirar los números disponibles y comparar para dar el Nº bloques correctos.
	cp	32h		; Comprueba si es FlashROM 4096k. AM29F032
	jp	z,Iniciociclo	; Salta a iniciociclo. 

	ld	a, 1Fh		; 1Fh para 512kB en bloques de 16k. Valor por defecto si no cuadran los anteriores
	ld	(RAMstart),a
	
Iniciociclo:

;--- Escritura de la FlashRom.

	ld	a, 00h		
	ld	(Fail_Tot),a	; Desactiva la marca de fallo en mensaje final conclusivo.

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.

	ld	de,FlsEra	; Pointer to message FLASH-ROM erase start
	call	Rep_Print	; Imprime texto por pantalla.

	call	BorrarFlash	; Llamada a la rutina de borrado de la FlashROM
	jp	c,Done		; Jump if Erase fail

	ld	de,FlsEok	; Pointer to Erase OK message
	call	Rep_Print	; Imprime texto por pantalla.

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.r

	ld	a, 0Fh		; Almacena el byte de grabado. En este caso 0Fh.
	ld	(DatoByte),a
	
	call	GrabarFlash	; Ejecuta la rutina de grabado.

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.er

	ld	a,(Fail_Msg)	; Comprueba si ha habido un fallo durante la grabación.
	cp	00h
	jp	z,Graba0FOK

	ld	de,Rec_0F_fail
	call	Rep_Print	; Imprime texto por pantalla.
	jp	Graba0FOK2
Graba0FOK:	
	ld	de,Rec_0F_mes
	call	Rep_Print	; Imprime texto por pantalla.
Graba0FOK2:	
	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.r
	ld	de,Leer_Texto_0F
	call	Rep_Print	; Imprime texto por pantalla.

;--- Lectura de la FlashRom.
	
	ld	a, 0Fh		; Almacena el byte de grabado. En este caso 0Fh.
	ld	(DatoByte),a
	
	call	Leer_Flash	; Ejecuta la rutina de grabado.

; -- Segunda parte

OverWrite2:
;--- Escritura de la FlashRom.

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.
	
	ld	de,FlsEra	; Pointer to message FLASH-ROM erase start
	call	Rep_Print	; Imprime texto por pantalla.

	call	BorrarFlash	; Llamada a la rutina de borrado de la FlashROM
	jp	c,Done		; Jump if Erase fail

	ld	de,FlsEok	; Pointer to Erase OK message
	call	Rep_Print	; Imprime texto por pantalla.

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.

	ld	a, 0F0h		; Almacena el byte de grabado. En este caso F0h.
	ld	(DatoByte),a
	
	call	GrabarFlash	; Ejecuta la rutina de grabado.

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.
	
	ld	a,(Fail_Msg)	; Comprueba si ha habido un fallo durante la grabación.
	cp	00h
	jp	z,GrabaF0OK

	ld	de,Rec_F0_fail
	call	Rep_Print	; Imprime texto por pantalla.
	jp	GrabaF0OK2
GrabaF0OK:	
	ld	de,Rec_F0_mes
	call	Rep_Print	; Imprime texto por pantalla..
GrabaF0OK2:	
	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.
	
	ld	de,Leer_Texto_F0
	call	Rep_Print	; Imprime texto por pantalla.


		
;--- Lectura de la FlashRom.

	ld	a, 0F0h		; Almacena el byte de grabado. En este caso F0h.
	ld	(DatoByte),a
	
	call	Leer_Flash	; Ejecuta la rutina de grabado.

;--- Borrado final de la FlashRom.

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.

	ld	de,FlsEra	; Pointer to message FLASH-ROM erase start
	call	Rep_Print	; Imprime texto por pantalla.

	call	BorrarFlash	; Llamada a la rutina de borrado de la FlashROM
	jp	c,Done		; Jump if Erase fail

	ld	de,FlsEok	; Pointer to Erase OK message
	call	Rep_Print	; Imprime texto por pantalla.e	

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.
	
	ld	a,(Fail_Tot)	; Verifica si todas las pruebas han ido bien.
	cp	00h
	jp	z,Finalfeliz	; Salta si todo OK.

	ld	de,Todo_NOK	; No todas las pruebas efectuadas correctamente.
	call	Rep_Print	; Imprime texto por pantalla.

	ld	de,DonMes
	jp	Done

Finalfeliz:
	ld	de,Todo_OK	; Todas las pruebas efectuadas correctamente.
	call	Rep_Print	; Imprime texto por pantalla.

	ld	de,DonMes
	jp	Done
	

;--- Finalizar y salir del programa.

Done:
	push	de
	ld	a,(RAMAD1)
	ld	hl,4000h
	call	ENASLT		; Select Main-RAM at bank 4000h~7FFFh
	ld	a,(RAMAD2)
	ld	hl,8000h
	call	ENASLT		; Select Main-RAM at bank 8000h~BFFFh
	ei

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.

	pop	de
	call	Rep_Print	; Imprime texto por pantalla.

	xor    a		; Pone a cero el flag Z.
	ld     ix, KILBUF       ; Petición de la rutina BIOS. En este caso KILBUF (Borrar el buffer del teclado).
	ld     iy,(MNROM)       ; BIOS slot
        call   CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.

	rst	0

;--- Fin del programa.


; **********************************************************************
; *** Subrutinas del programa

; Rutina de búsqueda de parámetros.

; In: B = Length of parameters zone, C = Character, HL = Pointer address
; Out: A = 0 if Parameter not found or 255 if syntax error, DE = HlpMes if syntax error
; Modify AF, BC, HL

SeekPar:
	ld	a,(hl)
	cp	"/"		; Seek '/' character
	ld	a, 255		; Devuelve valor "Sin parámetros encontrados"
	ret	nz
	inc	hl		; Va a leer la letra del parámetro encontrado.
SeekPar2:
	ld	a,(hl)		; Carga la letra leida en el acumulador
	cp	c		; Compare found character with the input character
	ld	a, 253		; Devuelve error si no encuentra una letra correcta.
	ret	z		; Devuelve la letra del parámetro encontrado.
	ld	a,(hl)		; Carga la letra leida en el acumulador
	sub	020h		; Pasa de Mayúsculas a Minúsculas.
	cp	c		; Compare found character with the input character
	ld	a, 253		; Devuelve error si no encuentra una letra correcta.
	ret	z		; Devuelve la letra del parámetro encontrado.
	ld	a, 255		; Devuelve error si no encuentra una letra correcta.
	ret	

; Fin de la rutina de búsqueda de parámetros.


; Rutina de coger los slots y subslots del parámetro /Sxx

; Esto sirve para coger los dos números que van despues de la Sxx
; Los transfiere en formato EMRSlt. Si detecta un solo número, dispara a 01h la variable ForzaSlot.Fuerza Slot principal.
GetNum:	ld	a, 00h		; Pone a cero la variable ForzaSlot.
	ld	(ForzaSlot), a	
	inc	hl		; Incrementa el puntero del DMA
	ld	a,(hl)		; Transfiere su contenido a a.
	sub	030h		; Resta 30 para tener el número real en a.
	cp	04h		; Compara si supera el valor 3 o es un caracter.
	jp	c, GetNum1	; Si es menor de 4 continua.
	ld	a, 255		; Devuelve error si el número está por encima de 3 o es un caracter.
	ret			; Fin de la subrutina.
GetNum1:cp	00h		; Compara si el primer valor es cero.
	jp	nz, GetNum2	; Si no es cero, continua.
	ld	a, 255		; Devuelve error si el número es un cero.
	ret			; Fin de la subrutina.
GetNum2:ld	b,a		; Transfiere el resultado a b para posterior gestión.
	inc	hl		; Incrementa el puntero del DMA
	ld	(ERMSlt),a	; Graba en formato FxxxSSPP
	ld	a,(hl)		; Transfiere su contenido a a.
	cp	020h		; Busca si hay un espacio.
	jp	z,GetPri	; Salta para tratamiento como Slot primario único.
	cp	255		; Busca si no hay nada mas.
	jp	z,GetPri	; Salta para tratamiento como Slot primario único.
	sub	030h		; Resta 30 para tener el número real en a.
	cp	04h		; Compara si supera el valor 3 o es un caracter.
	jp	c,GetNum3  
	ld	a,255		; Devuelve error si el número está por encima de 3 o es un caracter.
	ret			; Fin de la subrutina.
GetNum3:sla	a		; Desplaza resultado de subslot a la posición SS
	sla	a
	or	b		; Añade resultado del slot a la posición PP
	add	080h		; Le dice a EMRSlt que es un sublot. Bit 7 a 1.
	ld	(ERMSlt),a	; Graba en formato FxxxSSPP
GetEsp:	inc	hl		; Esto ignora todos los espacios que hay en medio.
	ld	a,(hl)
	cp	020h
	jr	z,GetEsp	; Bucle ignorar espacios.
	ld	a, 00h		; Saca diferente de 255 (error).
	ret
GetPri:	ld	a, 01h		; Marca a 1 que se desea un forzado a un Slot primario.
	ld	(ForzaSlot), a	
	jp	GetEsp		; Fin del tratamiento, va al ignorar espacios.

; Fin Rutina de coger los slots y subslots del parámetro /Sxx


; ~~~ Rutina para chequear si la FlashROM está insertada en el parámetro /Sxx

CheckSLT:
	ld	a,(ERMSlt)	; Carga el valor cogido del parámetro /Sxx
	ld	e,a		; Lo transfiere a e
	ld	a,(SubslotA)	; Carga el posible valor del buffer.
	cp	e		; Compara.
	jp	nz, Check2	; Si no son iguales, salta al siguiente buffer.
	ld	a,(TipoA)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	de, 00h		; Si son iguales da resultado OK.	
	ret			; Devuelve la llamada
Check2:	ld	a,(SubslotB)	; Carga el posible valor del buffer
	cp	e		; Compara.
	jp	nz, Check3	; Si no son iguales, salta al siguiente buffer.
	ld	a,(TipoB)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	de, 00h		; Si son iguales da resultado OK.
	ret			; Devuelve la llamada
Check3:	ld	a,(SubslotC)	; Carga el posible valor del buffer
	cp	e		; Compara.
	jp	nz, Check4	; Si no son iguales, salta al siguiente buffer.
	ld	a,(TipoC)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	de, 00h		; Si son iguales da resultado OK.
	ret			; Devuelve la llamada
Check4:	ld	a,(SubslotD)	; Carga el posible valor del buffer
	cp	e		; Compara.
	jp	nz, Check5	; Si no son iguales, salta al siguiente buffer.
	ld	a,(TipoD)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	de, 00h		; Si son iguales da resultado OK.
	ret			; Devuelve la llamada
Check5:	ld	a,(SubslotE)	; Carga el posible valor del buffer
	cp	e		; Compara.
	jp	nz, Check6	; Si no son iguales, salta al siguiente buffer.
	ld	a,(TipoE)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	de, 00h		; Si son iguales da resultado OK.
	ret			; Devuelve la llamada
Check6:	ld	a,(SubslotF)	; Carga el posible valor del buffer
	cp	e		; Compara.
	jp	nz, Check7	; Si no son iguales, salta al siguiente buffer.
	ld	a,(TipoF)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	de, 00h		; Si son iguales da resultado OK.
	ret			; Devuelve la llamada
Check7: ld	a,(SubslotG)	; Carga el posible valor del buffer
	cp	e		; Compara.
	jp	nz, Check8	; Si no son iguales, salta al siguiente buffer.
	ld	a,(TipoG)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	de, 00h		; Si son iguales da resultado OK.
	ret			; Devuelve la llamada
Check8:	ld	a,(SubslotH)	; Carga el posible valor del buffer
	cp	e		; Compara.
	jp	nz, NO_FLH2	; Si no son iguales, salta a fallo ya que no hay mas.
	ld	a,(TipoH)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	de, 00h		; Si son iguales da resultado OK.
	ret			; Devuelve la llamada
NO_FLH2: ; No encuentra el Slot solicitado.
	ld	a,00h
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	de,NO_FLSH	; Pointer to NO_FLSH message
	ret			; Devuelve la llamada con error

; ~~~ Fin de la rutina para chequear si la FlashROM está insertada en el parámetro /Sxx


; ~~~ Rutina para chequear si la FlashROM está insertada en el parámetro /Sx

CheckS2:ld	a,(SubslotA)	; Si no hay tampoco FlashRom salta el mensaje de FlashROM no encontrado.
	and	03h		; Solo coge el valor PP de FxxxSSPP
	ld	de,(ERMSlt)	; Vuelca el contenido del valor leido
	cp	e		; Compara con "a"
	ld	a,(TipoA)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	a,(SubslotA)	; Vuelca el contenido encontrado del subslot completo.
	ld	de, 00h		; Si son iguales da resultado OK.
	ret	z		; Devuelve la función si lo ha encontrado.
	ld	a,(SubslotB)	; Si no hay tampoco FlashRom salta el mensaje de FlashROM no encontrado.
	and	03h		; Solo coge el valor PP de FxxxSSPP
	ld	de,(ERMSlt)	; Vuelca el contenido del valor leido
	cp	e		; Compara con "a"
	ld	a,(TipoB)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	a,(SubslotB)	; Vuelca el contenido encontrado del subslot completo.
	ld	de, 00h		; Si son iguales da resultado OK.
	ret	z		; Devuelve la función si lo ha encontrado.
	ld	a,(SubslotC)	; Si no hay tampoco FlashRom salta el mensaje de FlashROM no encontrado.
	and	03h		; Solo coge el valor PP de FxxxSSPP
	ld	de,(ERMSlt)	; Vuelca el contenido del valor leido
	cp	e		; Compara con "a"
	ld	a,(TipoC)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	a,(SubslotC)	; Vuelca el contenido encontrado del subslot completo.
	ld	de, 00h		; Si son iguales da resultado OK.
	ret	z		; Devuelve la función si lo ha encontrado.
	ld	a,(SubslotD)	; Si no hay tampoco FlashRom salta el mensaje de FlashROM no encontrado.
	and	03h		; Solo coge el valor PP de FxxxSSPP
	ld	de,(ERMSlt)	; Vuelca el contenido del valor leido
	cp	e		; Compara con "a"
	ld	a,(TipoD)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	a,(SubslotD)	; Vuelca el contenido encontrado del subslot completo.	
	ld	de, 00h		; Si son iguales da resultado OK.
	ret	z		; Devuelve la función si lo ha encontrado.
	ld	a,(SubslotE)	; Si no hay tampoco FlashRom salta el mensaje de FlashROM no encontrado.
	and	03h		; Solo coge el valor PP de FxxxSSPP
	ld	de,(ERMSlt)	; Vuelca el contenido del valor leido
	cp	e		; Compara con "a"
	ld	a,(TipoE)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	a,(SubslotE)	; Vuelca el contenido encontrado del subslot completo.
	ld	de, 00h		; Si son iguales da resultado OK.
	ret	z		; Devuelve la función si lo ha encontrado.
	ld	a,(SubslotF)	; Si no hay tampoco FlashRom salta el mensaje de FlashROM no encontrado.
	and	03h		; Solo coge el valor PP de FxxxSSPP
	ld	de,(ERMSlt)	; Vuelca el contenido del valor leido
	cp	e		; Compara con "a"
	ld	a,(TipoF)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	a,(SubslotF)	; Vuelca el contenido encontrado del subslot completo.
	ld	de, 00h		; Si son iguales da resultado OK.
	ret	z		; Devuelve la función si lo ha encontrado.	
	ld	a,(SubslotG)	; Si no hay tampoco FlashRom salta el mensaje de FlashROM no encontrado.
	and	03h		; Solo coge el valor PP de FxxxSSPP
	ld	de,(ERMSlt)	; Vuelca el contenido del valor leido
	cp	e		; Compara con "a"
	ld	a,(TipoG)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	a,(SubslotG)	; Vuelca el contenido encontrado del subslot completo.
	ld	de, 00h		; Si son iguales da resultado OK.
	ret	z		; Devuelve la función si lo ha encontrado.
	ld	a,(SubslotH)	; Si no hay tampoco FlashRom salta el mensaje de FlashROM no encontrado.
	and	03h		; Solo coge el valor PP de FxxxSSPP
	ld	de,(ERMSlt)	; Vuelca el contenido del valor leido
	cp	e		; Compara con "a"
	ld	a,(TipoH)
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	a,(SubslotH)	; Vuelca el contenido encontrado del subslot completo.
	ld	de, 00h		; Si son iguales da resultado OK.
	ret	z		; Devuelve la función si lo ha encontrado.
	ld	a,00h
	ld	(CartTipo),a	; Almacena el tipo de FlashRom elegida.	
	ld	a,(SubslotH)	; Vuelca el contenido encontrado del subslot completo. El último dado.
	ld	de,NO_FLSH	; Pointer to NO_FLSH message
	ret			; Jump Flash Rom not found

; ~~~ Fin de la rutina para chequear si la FlashROM está insertada en el parámetro /Sx


; Rutina de borrado completo de una Flashrom

BorrarFlash:
	
	ld	a,(ERMSlt)
	ld	hl,4000h
	call	ENASLT		; Select a Slot in Bank 1 (4000h ~ 7FFFh)
	di

	ld	hl,4000h
	ld	(hl),0f0h	; AM29F0xx ID reading mode OFF. Te saca fuera del Infochip

	ld	a,(4000h)	; Hace una lectura para tirar cualquier intento pasado de petición.

	ld	a,0aah
	ld	(4555h),a	; Flashrom...
	ld	a,055h
	ld	(42aah),a	;
	ld	a,080h
	ld	(4555h),a	; ... erase ...

	ld	a,(4000h)	; Hace una lectura para tirar cualquier intento pasado de petición.

	ld	a,0aah
	ld	(4555h),a	;
	ld	a,055h
	ld	(42aah),a	;
	ld	a,010h
	ld	(4555h),a	; ... command

	ld	a,0ffh
	ld	de,4000h
	
	ld	c,a
CHK2_L1:
	ld	a,(de)
	xor	c
	jp	p,CHK2_R1	; Jump if readed bit 7 = written bit 7
	xor	c
	and	020h
	jp	z,CHK2_L1	; Jump if readed bit 5 = 1
	ld	a,(de)
	xor	c
	jp	p,CHK2_R1	; Jump if readed bit 7 = written bit 7
	ld	a,(RAMAD1)
	ld	hl,4000h
	call	ENASLT		; Select Main-RAM at bank 4000h~7FFFh
	ei
	ld	de,FlsErr
	scf
	ret
CHK2_R1:
	ld	a,(RAMAD1)
	ld	hl,4000h
	call	ENASLT		; Select Main-RAM at bank 4000h~7FFFh
	ei
	or	a
	ret

; Fin rutina de borrado completo de una Flashrom


; Rutina de grabado de la FlashRom

GrabarFlash:
	ld	a,(RAMstart)	; Decrementa el primer bloque de comprobación.
	dec	a
	ld	(RAMtyp),a

	ld	a, 00h		
	ld	(Fail_Msg),a	; Desactiva la marca de fallo en mensaje final de grabación.

	ld	a, 00h
	ld	(PreBnk), a	; Resetea el prebanco a cero.

	ld	a,00h
	ld	(RetryFail),a	; Resetea el bucle infinito de fallos.
	
	ld	a,(ERMSlt)
	ld	hl,4000h
	call	ENASLT		; Select a Slot in Bank 1 (4000h ~ 7FFFh)
	ld	a,(ERMSlt)
	ld	hl,8000h
	call	ENASLT		; Select a Slot in Bank 2 (8000h ~ BFFFh)
	di

	ld	hl,4000h
	ld	(hl),0f0h	; AM29F0xx ID reading mode OFF. Te saca fuera del Infochip	
	
	ld	a,(DatoByte)
	cp	0F0h
	jp	z,Grabarver2	; Salta si tiene que poner texto F0h en lugar de 0Fh.
	
	ld	de,Grabar_Texto_0F
	call	Rep_Print	; Imprime texto por pantalla.
	di
	
	jp	FLashPage	; Salta a comprobación del primer bloque.

Grabarver2:
	ld	de,Grabar_Texto_F0
	call	Rep_Print	; Imprime texto por pantalla.
	di

	jp	FLashPage	; Salta a comprobación del primer bloque.

I8kL01:
	ld	a, 01h
	ld	(Grabar_Retry),a; Pone a 1 hacer un reintento en el envío del comando de grabación.

	ld	a,00h
	ld	(RetryFail),a	; Resetea el bucle infinito de fallos.
	
	ld	a, 00h		
	ld	(Fail_Temp),a	; Desactiva la marca de fallo temporal.
	
	ld	a,(RAMtyp)	; Compara cuantos bloques de 16k le quedan.
	cp	0FFh
	jp	z,GrabarFin	; Jump if any record is loaded
	dec	a
	ld	(RAMtyp),a
	ld	a,(PreBnk)
	and	0fh
	jp	nz,FLashPage
	
	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.
	di
	
FLashPage:
	ld	a,(4000h)	; Hace una lectura para tirar cualquier intento pasado de petición.
	
	ld	a,(Mapper)
	cp	01h
	jp	z,FLashKon	; Salta a FlashKon si el mapper es Konami5

	ld	a,(Mapper)
	cp	02h
	jp	z,FLashAsc8	; Salta a FLashAsc8 si el mapper es ASCII8K
				
				; Se programa en modo ASCII16K para cualquier otro mapper.
	ld	a,(PreBnk)
	ld	(7000h),a	; Select Flashrom page at Bank 8000h~BFFFh
	ld	bc,4000h	; Length
	ld	de,8000h	; Destination banco 2

	jp	LOOP

FLashAsc8:			; Se programa en modo ASCII8K
	ld	a,(PreBnk)
	ld	(6000h),a	; Select Flashrom page at Bank 4000h~5FFFh
	ld	bc,2000h	; Length
	ld	de,04000h	; Destination banco 1

	jp	LOOP

FLashKon:			; Se programa en modo KONAMI5
	ld	a,(PreBnk)	
	ld	(09000h),a	; Select Flashrom page at Bank 8000h~9FFFh
	ld	bc,2000h	; Length
	ld	de,8000h	; Destination banco 2

LOOP:	
	ld	a,0aah
	ld	(4555h),a
	ld	a,055h
	ld	(42aah),a
	ld	a,0a0h
	ld	(4555h),a
	ld	a,(DatoByte)	; Graba 0Fhsss
	ld	(de),a		; Write a byte to flashrom

	push	bc
	ld	c,a
CHK_L1:
	ld	a,(Mapper)
	cp	01h
	jp	nz,CHK_ASC	; Si es KONAMI, vuelve a poner la página que le toca
	ld	a,(PreBnk)	; Se moverá la página cuando se grave en la dirección 9000h-97FFh.	
	ld	(09000h),a	; Select Flashrom page at Bank 8000h~9FFFh. En la última página dará error porque es acceso a SCC.
CHK_ASC:	
	ld	a,(DatoByte)	; Recupera DatoByte.
	ld	c,a
	ld	a,(de)		; Compara el dato leido con DatoByte.
	cp	c
	jp	z,CHK_R1	; Si es el exacto salta al siguiente byte.
	jp	CHK_RTY		; Si no lo reintenta 0FFh veces. Si sigue en fallo, lo marca como defectuoso.
	
CHK_RTY:			; Comprobación de fallos reincidente
	ld	a,(RetryFail)
	inc	a
	ld	(RetryFail),a
	cp	0FFh
	jp	z, CHK_FL	; Rompe el bucle infinito de fallos de comprobación.
	jp	CHK_L1		; Vuelve a intentarlo

CHK_FL:
	ld	a,01h		
	ld	(Fail_Temp),a	; Activa la marca de fallo temporal.
	ld	(Fail_Msg),a	; Activa la marca de fallo en mensaje final de grabación.
	ld	(Fail_Tot),a	; Activa la marca de fallo en mensaje final conclusivo.
	ld	a,00h
	ld	(RetryFail),a	; Resetea el bucle infinito de fallos.
	pop	bc
	ld	bc, 0001h
	jp	NEXT		; Va a la siguiente página.

CHK_R1:
	pop	bc

NEXT:
	inc	de
	dec	bc
	ld	a,b
	or	c
	jp	nz,LOOP
	
	ld	a,(PreBnk)
	inc	a
	ld	(PreBnk),a	; Increments Rom mapper page
	dec	a

	and	0fh
	cp	10
	jp	c,I8kR01
	add	a,7		; add	a,'A'-'0'-10
I8kR01:
	add	a,030h		; add	a,'0'
	ld	e,a

	ld	a,(Fail_Temp)
	cp	00h
	jp	z,I8kR01NF	; Salta a valor correcto si no hay fallo.

	ld	a,078h
	ld	e,a		; Carga una "x" en la página de fallo.
I8kR01NF:
	
	xor	a		 ; Pone a cero el flag Z.
	ld	a,e
	ld	ix, CHPUT        ; Petición de la rutina BIOS. En este caso CHPUT (Imprimir caracter).
	ld	iy,(MNROM)       ; BIOS slot
        call	CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	di

	jp	I8kL01

GrabarFin:
	ld	a,(RAMAD1)
	ld	hl,4000h
	call	ENASLT		; Select Main-RAM at bank 4000h~7FFFh
	ld	a,(RAMAD2)
	ld	hl,8000h
	call	ENASLT		; Select Main-RAM at bank 8000h~BFFFh
	ei
	
	or	a		; Resetea el flag de Carry "c"
	ret

; Fin de la rutina de grabado de la FlashRom


; Rutina de lectura y comprobación de la FlashRom

Leer_Flash:
	ld	a,(RAMstart)
	dec	a
	ld	(RAMtyp),a

	ld	a, 00h		
	ld	(Fail_Msg),a	; Desactiva la marca de fallo en mensaje final de lectura.

	ld	a, 00h		
	ld	(PreBnk),a

Pre_Bucle_Leer:	
	ld	a,(ERMSlt)
	ld	hl,4000h
	call	ENASLT		; Select a Slot in Bank (4000h~7FFFh)
	di

	ld	hl,4000h
	ld	(hl),0f0h	; AM29F0xx ID reading mode OFF. Te saca fuera del Infochip

	ld	a,(4000h)	; Hace una lectura para tirar cualquier intento pasado de petición.

Pre_Bucle_Leer2:	

	ld	a,(Mapper)
	cp	01h
	jp	z,Leer_Kon	; Salta a mapper Konami5 si es seleccionado.

	ld	a,(Mapper)
	cp	02h
	jp	z,Leer_ASC8	; Salta a mapper ASCII8K si es seleccionado.
				; En los demas casos salta a ASCII16K
	ld	a,(PreBnk)	; Se lee en modo ASCII16K
	ld	(6000h),a	; Select Flashrom page at Bank (4000h~7FFFh)
	
	ld	de,4000h	; Destination
	ld	bc,4000h	; Lenght

	jp	Bucle_Leer

Leer_ASC8:
	ld	a,(PreBnk)	; Se lee en modo ASCII8K
	ld	(6000h),a	; Select Flashrom page at Bank (4000h~5FFFh)

	ld	(5000h),a	; Por si hubiera por error un Konami5, Select Flashrom page at Bank (4000h~5FFFh)
	
	ld	de,4000h	; Destination
	ld	bc,2000h	; Lenght

	jp	Bucle_Leer

Leer_Kon:
	ld	a,(PreBnk)	; Se lee en modo Konami5
	ld	(7000h),a	; Select Flashrom page at Bank (4000h~5FFFh)
	
	ld	de,6000h	; Destination
	ld	bc,2000h	; Lenght

Bucle_Leer:
	ld	a,(DatoByte)	; Almacena en l el byte de dato seleccionado.
	ld	l,a		; Almacena en l el byte de dato seleccionado.
	ld	a,(de)		; Read a byte to flashrom
	cp	l		; Comprueba con el byte de dato seleccionado.
	jp	z, DatoOK_Leer	; Salta si el byte comprobado es el correcto.
	
	ld	a, 01h		; Ejecuta la activación de fallo en esta página.
	ld	(Fail_Msg),a	; Activa la marca de fallo en mensaje final de lectura.
	ld	(Fail_Tot),a	; Activa la marca de fallo en mensaje final conclusivo.
	
	ld	a,078h
	ld	e,a		; Carga una "x" en la página de fallo.
	
	xor	a		 ; Pone a cero el flag Z.
	ld	a,e
	ld	ix, CHPUT        ; Petición de la rutina BIOS. En este caso CHPUT (Imprimir caracter).
	ld	iy,(MNROM)       ; BIOS slot
        call	CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	di
	
	jp	Bucle_Leer3	; Continua a la siguiente página.

DatoOK_Leer:
	inc	de		; Incrementa destino, resta pendientes y compara si cero.
	dec	bc
	ld	a,b
	or	c
	jp	nz, Bucle_Leer

	ld	a,(PreBnk)
	and	0fh
	cp	10
	jp	c,Bucle_Leer2
	add	a,7		; add	a,'A'-'0'-10
Bucle_Leer2:
	add	a,030h		; add	a,'0'
	ld	e,a
	
	xor	a		 ; Pone a cero el flag Z.
	ld	a,e
	ld	ix, CHPUT        ; Petición de la rutina BIOS. En este caso CHPUT (Imprimir caracter).
	ld	iy,(MNROM)       ; BIOS slot
        call	CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	di

Bucle_Leer3:
	ld	a,(RAMtyp)	; Compara cuantos bloques de 16k le quedan.
	cp	0FFh
	jp	z,Fin_lect	; Jump if any record is loaded
	dec	a
	ld	(RAMtyp),a
	
	ld	a,(PreBnk)	; Increments Rom mapper page
	inc	a
	ld	(PreBnk),a	; Increments Rom mapper page

	and	0fh
	jp	nz,Pre_Bucle_Leer2
	
	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.
	di
	
	jp	Pre_Bucle_Leer2

Fin_lect:
	ld	a,(RAMAD1)
	ld	hl,4000h
	call	ENASLT		; Select Main-RAM at bank 4000h~7FFFh
	ei

	ld	de,MESend1
	call	Rep_Print	; Imprime texto por pantalla.

	ld	a, (DatoByte)
	cp	0F0h
	jp	z, Fin_lect2

	ld	a,(Fail_Msg)	; Comprueba la marca de fallo en mensaje final de lectura.
	cp	01h
	push	af
	ld	a, 00h
	ld	(Fail_Msg),a	; Borra la marca de fallo una vez leida.
	pop	af
	jp	z,Fin_lect_fallo0F

	ld	de,Leidos_0F
	call	Rep_Print	; Imprime texto por pantalla.
	
	or	a		; Resetea el flag de Carry "c"
	ret

Fin_lect_fallo0F:
	ld	de,Leidos_0F_Fallo
	call	Rep_Print	; Imprime texto por pantalla.
	
	or	a		; Resetea el flag de Carry "c"
	ret

Fin_lect2:
	ld	a,(Fail_Msg)	; Comprueba la marca de fallo en mensaje final de lectura.
	cp	01h
	push	af
	ld	a, 00h
	ld	(Fail_Msg),a	; Borra la marca de fallo una vez leida.
	pop	af
	jp	z,Fin_lect_falloF0

	ld	de,Leidos_F0
	call	Rep_Print	; Imprime texto por pantalla.
	
	or	a		; Resetea el flag de Carry "c"
	ret

Fin_lect_falloF0:
	ld	de,Leidos_F0_Fallo
	call	Rep_Print	; Imprime texto por pantalla.
	
	or	a		; Resetea el flag de Carry "c"
	ret


; Fin de la rutina de lectura y comprobación de la FlashRom


; Rutina de escritura cadena de carácteres por pantalla.

Rep_Print:
	xor	a		 ; Pone a cero el flag Z.
	ld	a,(de)
	cp	"$"
	jp	z,Fin_Print
	inc	de
	ld	ix, CHPUT        ; Petición de la rutina BIOS. En este caso CHPUT (Imprimir caracter).
	ld	iy,(MNROM)       ; BIOS slot
        call	CALSLT           ; Llamada al interslot. Es necesario hacerlo así en MSXDOS para llamadas a BIOS.
	jp	Rep_Print

Fin_Print:
	ret

; Fin rutina de escritura cadena de carácteres por pantalla.


; *** Fin subrutinas del programa
; **********************************************************************

; Variables RAM

Pasopor0:
	db	0
ForzaSlot:
	db	0
SubslotA:
	db	0
SubslotB:
	db	0
SubslotC:
	db	0
SubslotD:
	db	0
SubslotE:
	db	0
SubslotF:
	db	0
SubslotG:
	db	0
SubslotH:
	db	0
TipoA:
	db	0
TipoB:
	db	0
TipoC:
	db	0
TipoD:
	db	0
TipoE:
	db	0
TipoF:
	db	0
TipoG:
	db	0
TipoH:
	db	0
ERMSlt:
	db	0
RAMtyp:
	db	0
RAMstart:
	db	0
PreBnk:
	db	0
DatoByte
	db	0
FLerase:
	db	0
MAN_ID:
	db	0
DEV_ID:
	db	0
patchID:
	db	0
CURRpatchID:
	db	0
ParameterR:
	db	0
Grabar_Retry:
	db	0
Mapper:
	db	0
SerchTipo:
	db	0
CartTipo:
	db	0
Fail_Temp:
	db	0
Fail_Msg:
	db	0
RetryFail:
	db	0	
Fail_Tot:
	db	0
OverWR:
	db	"Y"

; Fin del programa
end
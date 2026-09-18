 // encoding: utf-8
// Copyright (c) 2026 Luan Pestana
// SPDX-License-Identifier: MIT
.code16
.section .text
.global _start
#include "kernel_size.inc"

// Os enderecos sao escritos como AA:BB, que resulta em (AA * 16 + BB), onde BB se chama offset

_start:
    // Impede interrupcoes
    cli

    // Printa um 'T' na tela para debug
    mov $0xB8000, %bx
    movb $'T', 0(%bx)
    movb $0x07, 1(%bx)

    // Zera o AX
    xor %ax, %ax

    // Zera o DS, os enderecos durante o bootloader sao calculados DS:offset, com o DS em zero eh possivel escolher os enderecos somente com os offsets
    mov %ax, %ds

    // Zera o ES, usado para acessar a memoria, eh zerado para nao permanecer algum valor herdado de firmware
    mov %ax, %es

    // Poe SS como zero e SP como 0x7C00, a cpu usa SS:SP para localizar a stack, dessa forma fica 0:7C00
    // Stack eh necessaria para usar call
    mov %ax, %ss
    mov $0x7C00, %sp

    // Lendo a MBR //
    mov $0x02, %ah // AH eh usado para a BIOS saber qual operacao eh a desejada. Ler setores
    mov $0x01, %al // Ler 1 setor
    mov $0x00, %ch // Cilindro 0
    mov $0x01, %cl // Setor 1
    mov $0x00, %dh // Head 0 (cabeca de leitura)
    // DL ja tem a unidade do disco no boot fornecido pela BIOS
    mov $0x7E00, %bx // Poe os dados no offset 0x7E00

    int $0x13 // Chama BIOS para executar a tarefa especificada nos registradores

    jc read_error // Se der erro, executa o disk_error

    // Lendo o primeiro setor do disco para verificar se o bootloader esta gravado no mesmo
    movl $0, %eax // Poe o endereco do primeiro setor do disco em EAX
    movl %eax, dap+8 // Move os bytes de EAX para dap apos os primeiros 8 bytes
    movl $0, dap+12 // Move 4 bytes zerados para dap apos os primeiros 12 bytes
    xorw %ax, %ax // Zera AX
    movw %ax, %ds // Zera DS, o endereco eh lido pela bios como DS:SI
    movw $dap, %si // Poe o endereco de dap em SI
    movb $0x42, %ah // Funcao 0x42, Extended Read Sectors
    int $0x13 // Chama a BIOS
    jc read_error

    // Verifica se todos os bytes da assinatura estao corretos
    cmpb $'e', 0x81F8 // Compara bytes
    jne .start_search // Se nao forem iguais, o bootloader pode estar gravado em alguma particao, entao pula para a procura da assinatura em todas as particoes
    cmpb $'u', 0x81F9
    jne .start_search
    cmpb $'B', 0x81FA
    jne .start_search
    cmpb $'O', 0x81FB
    jne .start_search
    cmpb $'O', 0x81FC
    jne .start_search
    cmpb $'T', 0x81FD
    jne .start_search

    jmp .continue // Se a assinatura estava correta, apenas continua o bootloader pulando a procura nas particoes

.start_search:
    movl $0x7FC6, %ebx // Poe em EBX o endereco do LBA inicial da primeira particao na tabela MBR
    call find_partition // Procura a particao com a assinatura deste bootloader

.continue:
    // Apos a procura da assinatura, o LBA incial do bootloader ficou em EAX
    // Lendo o segundo bootloader no segundo setor e armazenando no endereco 0x8000
    incl %eax // Incrementa 1 no LBA inicial para ler o segundo setor da particao
    movl %eax, dap+8 // Move os bytes de EAX para dap apos os primeiros 8 bytes
    movl $0, dap+12 // Move 4 bytes zerados para dap apos os primeiros 12 bytes
    movw $(KERNEL_SIZE / 512 + 2), %ax
    movw %ax, dap+2
    xorw %ax, %ax // Zera AX
    movw %ax, %ds // Zera DS, o endereco eh lido pela bios como DS:SI
    movw $dap, %si // Poe o endereco de dap em SI
    movb $0x42, %ah // Funcao 0x42, Extended Read Sectors
    int $0x13 // Chama a BIOS
    jc read_error

    movb $'1', %al
    call print_char

	jmp 0x8000 // Pula para o bootloader 2


// Loop onde a cpu fica inativa
hang:
    hlt
    jmp hang

// Funcao responsavel por achar a particao com a assinatura deste bootloader
find_partition:
.loop:
    //l = Long = 32bits = 4 bytes
    // Supondo que em EAX ha o endereco de um LBA inicial lido da MBR
    movl (%ebx), %eax // Poe os bytes que ha no endereco armazenado em EBX para EAX
    movl %eax, dap+8 // Move os bytes de EAX para dap apos os primeiros 8 bytes
    movl $0, dap+12 // Move 4 bytes zerados para dap apos os primeiros 12 bytes
    xorw %ax, %ax // Zera AX
    movw %ax, %ds // Zera DS, o endereco eh lido pela bios como DS:SI
    movw $dap, %si // Poe o endereco de dap em SI
    movb $0x42, %ah // Funcao 0x42, Extended Read Sectors
    int $0x13 // Chama a BIOS
    jc read_error

    // Verifica se todos os bytes da assinatura estao corretos
    cmpb $'e', 0x81F8 // Compara bytes
    jne .next // Se nao forem iguais pula para .next
    cmpb $'u', 0x81F9
    jne .next
    cmpb $'B', 0x81FA
    jne .next
    cmpb $'O', 0x81FB
    jne .next
    cmpb $'O', 0x81FC
    jne .next
    cmpb $'T', 0x81FD
    jne .next

    ret // Todos os bytes da assinatura estavam corretos, entao retorna para onde foi chamado com o LBA inicial da particao em EAX
.next:
    cmpl $0x7FF6, %ebx // Compara o endereco do LBA inicial atual com o ultimo permitido numa tabela MBR
    je not_found_partition_error // Se for igual pula para tratamento de erro
    addl $16, %ebx // Aumenta 16 no EBX, indo para o endereco do proximo LBA inicial
    jmp .loop // Pula para .loop

dap:
    .byte 0x10, 0x00 // tamanho do dap = 2, reservado = 0
    .word 0x0003 // Numero de setores para ler
    .word 0x8000 // Offset do buffer (onde ficara na memoria)
    .word 0x0000 // Segmento do buffer
    .long 0x00000000 // LBA inicial
    .long 0x00000000

// Tratamento generico de erro
generic_error:
    movb $'E', %al // Move um unico byte (o caractere) para AL
    call print_char // Chama a funcao que printa o que ha em AL
    movb $'r', %al
    call print_char
    movb $'r', %al
    call print_char
    jmp hang

read_error:
    movw $read_error_msg, %si // Poe o endereco da mensagem em SI, o "w" apos o "mov" especifica word, ou seja, um endereco de 16 bits
    call print_string // Chama a funcao que printa a string no endereco de si
    jmp . // retorna ao proprio "jmp ."

not_found_partition_error:
    movw $not_found_partition_error_msg, %si
    call print_string
    jmp hang

// Printa um caractere usando interrupcoes da bios, eh printado o caractere presente em AL
print_char:
    mov $0x0E, %ah // Funcao teletype
    mov $0x00, %bh // Pagina 1 do display
    mov $0x07, %bl // Letra branca e fundo preto
    int $0x10 // Chama a BIOS
    ret // Retorna para onde a funcao foi chamada

// Printa uma string usando interrupcoes da bios, eh printado a string na qual o endereco word esta presente em SI
print_string:
    .print_loop: // Loop que printa os caracteres
        lodsb // Le um byte do endereco DS:SI e poe o byte lido em AL (se DF igual a 0, incrementa SI apos ler o byte, se DF igual a 1, decrementa SI)
        cmpb $0, %al // Compara AL e zero
        je .done // Se igual, pula para .done
        call print_char // Chama a funcao para printar caractere em AL
        jmp .print_loop // Repete o loop
    .done: // Retorna
        ret

// Armazena string em um endereco
read_error_msg:
     // ".asciz" Armazena uma string com o byte 00 no final
    .asciz "Disk Read Error"

not_found_partition_error_msg:
    .asciz "Partition Not Found"

    
// Declarando cada GDT, com seus respectivos descritores de segmento, .quad manda o assembler reservar 8 bytes e por este valor
//gdt_start:

//gdt_null:
//    .quad 0x0000000000000000

//gdt_code32:
//    .quad 0x00CF9A000000FFFF

//gdt_data:
//    .quad 0x00CF92000000FFFF

//gdt_code64:
//    .quad 0x00AF9A000000FFFF

//gdt_end:

// Diz ao GDTR o endereco e o limite da GDT
//gdt_descriptor:
//    .word gdt_end - gdt_start - 1
//    .long gdt_start

.org 504
.ascii "euBOOT"
// Isto diz que apartir daqui tudo ficara apartir do offset 510 (se nao ha 510 bytes, os bytes faltantes para totalizar 510 serao criados zerados)
.org 510
// Escreve a assinatira 0xAA55 (2 bytes), totalizando 512 bytes
.word 0xAA55

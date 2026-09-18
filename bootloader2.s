 // encoding: utf-8
// Copyright (c) 2026 Luan Pestana
// SPDX-License-Identifier: MIT
.code16
.section .text
.global _start
#include "kernel_size.inc"

// Os enderecos sao escritos como AA:BB, que resulta em (AA * 16 + BB), onde BB se chama offset

_start:
    cli

    // Saindo de Real-Mode 16bits para 32bits a fim de executar o kernel em x86_64 //

    // Habilita o A20, permitindo acessar enderecos acima de 1MiB
    in $0x92, %al // Le a porta I/O e poe o valor lido em AL
    or $0x02, %al // Aplica um OR (porta logica) bit a bit do numero 2 em 8 bits com o numero do registrador AL, como 2 em 8 bit eh 00000010, na pratica isso poe o segundo bit do registrador AL como 1
    out %al, $0x92 // Faz o oposto do in, poe o valor de AL na porta I/O numero 0x92
    // Assim o bit que foi ativado pela operacao or, foi o bit que habilita o A20

    // Fora do Real-Mode a cpu passa a usar descritores de segmentos armazenados na GDT
    lgdt gdt_descriptor // Carrega a GDT

    // Mesmo processo feito para habilitar o A20, porem para habilitar o Protection Enable (modo de 32 bits)
    mov %cr0, %eax
    or $0x1, %eax
    mov %eax, %cr0

    // Long Jump, diferente do Jump, consegue pular para um segmento tambem (Jump pula apenas para um enderenco)
    ljmp $0x08, $protected_mode // Entra no Protected Mode

// Instrucoes que seram executados durante o Protected Mode (modo 32 bits)
.code32
protected_mode:
    // Iniciando a paginacao //

    mov $0x1000, %edi // Endereco onde comeca a paginacao
    xor %eax, %eax // Zera EAX
    mov $4096 / 4, %ecx // Escreve 1024 em EAX
    rep stosl // Escreve o valor de EAX repetidamente na memoria

    mov $0x2000, %eax // Endereco da proxima tabela
    or $0x03, %eax // Os dois bits finais do 3 em 8 bit (00000011) significam Present (Valida) e Writable
    mov %eax, 0x1000 // Escreve o valor de EAX no byte 0x1000 da memoria, o endereco da segunda tabela no comeco da primeira tabela

    // Mesma ideia do anterior
    mov $0x3000, %eax
    or $0x03, %eax
    mov %eax, 0x2000

    // Habilita o setimo bit, Page Size, que diz que a entrada representa uma pagina de 2 MiB e nao eh para procurar abaixo da entrada
    mov $0x00000083, %eax
    mov %eax, 0x3000

    // Poe o endereco da primeira tabela no registrador CR3 (registrador que a cpu ja le a fim de achar o endereco da estrutura de paginacao)
    mov $0x1000, %eax
    mov %eax, %cr3

    // Fim da paginacao //



    // Habilita o bit 5 do registrador CR4, habilitando o PAE (Physical Address Extension)
    mov %cr4, %eax
    or $0x20, %eax
    mov %eax, %cr4

    // Poe o endereco de um MSR (MSR sao registradores especiais, inacessiveis com MOV) no registrador ECX
    mov $0xC0000080, %ecx
    rdmsr // RDMSR le o MSR do endereco presente em ECX e poe o valor lido no EAX
    or $0x100, %eax // Habilita o bit 8, responsavel pelo LME (Long Mode Enable, ativa o modo 64 bits)
    wrmsr // Escreve o valor de volta no MSR

    // Habilita Paging, habilitando o bit 31
    mov %cr0, %eax
    or $0x80000000, %eax
    mov %eax, %cr0

    ljmp $0x18, $long_mode // Entra no Long Mode

// Instrucoes que seram executados durante o Long Mode (modo 64 bits)
.code64
long_mode:
    // Aponta para a memoria VGA (endereco da memoria VGA)
    mov $0xB8000, %rax

    // Escreve um texto na memoria de textoVGA
    movb $'L', 0(%rax)
    movb $0x07, 1(%rax)

    movb $'o', 2(%rax)
    movb $0x07, 3(%rax)

    movb $'n', 4(%rax)
    movb $0x07, 5(%rax)

    movb $'g', 6(%rax)
    movb $0x07, 7(%rax)

    movb $'M', 8(%rax)
    movb $0x07, 9(%rax)

    movb $'o', 10(%rax)
    movb $0x07, 11(%rax)

    movb $'d', 12(%rax)
    movb $0x07, 13(%rax)

    movb $'e', 14(%rax)
    movb $0x07, 15(%rax)

    // Copiar kernel
    mov $0x8200, %rsi // Origem, onde o kernel esta na RAM
    mov $0x100000, %rdi // Destino
    mov $KERNEL_SIZE, %rcx // Tamanho do kernel
    rep movsb

    // Escreve um texto na memoria de textoVGA
    movb $'K', 16(%rax)
    movb $0x07, 17(%rax)

    movb $'L', 18(%rax)
    movb $0x07, 19(%rax)

    movb $'o', 20(%rax)
    movb $0x07, 21(%rax)

    movb $'a', 22(%rax)
    movb $0x07, 23(%rax)

    movb $'d', 24(%rax)
    movb $0x07, 25(%rax)

    // Entregar CPU ao kernel
    jmp 0x100000
    movb $' ', 26(%rax)
    movb $0x07, 27(%rax)

    movb 0x1001A0, %bl
    movb %bl, 28(%rax)
    movb $0x07, 29(%rax)

    movb 0x1001A1, %bl
    movb %bl, 30(%rax)
    movb $0x07, 31(%rax)

    movb 0x1001A2, %bl
    movb %bl, 32(%rax)
    movb $0x07, 33(%rax)

    movb 0x1001A3, %bl
    movb %bl, 34(%rax)
    movb $0x07, 35(%rax)

    movb 0x1001A4, %bl
    movb %bl, 36(%rax)
    movb $0x07, 37(%rax)

    jmp hang



hang:
    hlt
    jmp hang



// Declarando cada GDT, com seus respectivos descritores de segmento, .quad manda o assembler reservar 8 bytes e por este valor
gdt_start:

gdt_null:
    .quad 0x0000000000000000

gdt_code32:
    .quad 0x00CF9A000000FFFF

gdt_data:
    .quad 0x00CF92000000FFFF

gdt_code64:
    .quad 0x00AF9A000000FFFF

gdt_end:

// Diz ao GDTR o endereco e o limite da GDT
gdt_descriptor:
    .word gdt_end - gdt_start - 1
    .long gdt_start


.org 504
.ascii "euBOOT"
// Isto diz que apartir daqui tudo ficara apartir do offset 510 (se nao ha 510 bytes, os bytes faltantes para totalizar 510 serao criados zerados)
.org 510
// Escreve a assinatira 0xAA55 (2 bytes), totalizando 512 bytes
.word 0xAA55

// encoding: utf-8
// Copyright (c) 2026 Luan Pestana, Miguel Sampaio
// SPDX-License-Identifier: MIT
.global _start
.extern kernel_main
.extern __bss_start
.extern __bss_end

.section .text

_start:
    mov $stack_top, %rsp

    xor %eax, %eax // Zera EAX (importante pois o rep seguinte copia seu valor)
    mov $__bss_start, %rdi // Poe em RDI o endereco inicial de .bss
    mov $__bss_end, %rcx // Poe em RDI o endereco final de .bss   
    sub %rdi, %rcx // Subtrai o endereco final com o inicial para saber quantos bytes ha em .bss
    shr $2, %rcx // Right Shift, desloca 2 bits para direita em rcx, equivalente a dividir por 4
    rep stosl // Escreve os 4 bytes presentes em EAX repetidamente por todo o .bss, zerando o mesmo

    call kernel_main // Chama a funcao main do kernel

.hang:
    hlt
    jmp .hang

.section .bss
.align 16

stack_bottom:
    .skip 16384

stack_top:

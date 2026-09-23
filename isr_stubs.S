# encoding: utf-8
# Copyright (c) 2026 Miguel Sampaio
# SPDX-License-Identifier: MIT

# isr_stubs.S
# Stub para a interrupção do timer (IRQ0, vetor 32 após remap do PIC)

.section .text
.global irq0_stub
.extern timer_isr

irq0_stub:
    push %rax
    push %rbx
    push %rcx
    push %rdx
    push %rsi
    push %rdi
    push %r8
    push %r9
    push %r10
    push %r11

    sub $8, %rsp  

    mov %rsp, %rdi
    add $88, %rdi      

    call timer_isr

    add $8, %rsp         

    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rdi
    pop %rsi
    pop %rdx
    pop %rcx
    pop %rbx
    pop %rax

    iretq

# encoding: utf-8
# Copyright (c) 2026 Miguel Sampaio
# SPDX-License-Identifier: MIT

# idt.S
# void idt_load(uint64_t idtp_addr);
# Recebe o endereço da struct idt_ptr em %rdi (System V ABI)

.section .text
.global idt_load
.global enable_interrupts

idt_load:
    lidt (%rdi)
    ret

enable_interrupts:
    sti
    ret
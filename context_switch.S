# encoding: utf-8
# Copyright (c) 2026 Miguel Sampaio
# SPDX-License-Identifier: MIT

# Layout esperado da struct process (Caso a struct process seja mudada de ordem o codigo TEM QUE MUDAR. Isso ta levando em conta o layout original q eu fiz pra tabela, ent se isso for mudado, o codigo quebra e n tem como automatizar a troca de maneira facil):
#   uint64_t utime;          // offset 0
#   uint64_t stime;          // offset 8
#   uint32_t preempt_count;  // offset 16
#   int32_t  priority;       // offset 20
#   uint64_t saved_rsp;      // offset 24
#   int      state;          // offset 32

.section .text
.global context_switch
.equ SAVED_RSP_OFFSET, 24 # Esse numero e referente ao saved_rsp da tabela. Se a ordem for mudada independente do motivo, mude esse numero

context_switch:
    # Salva os registradores "callee-saved" do processo ANTIGO na pilha atual
    push %rbx
    push %rbp
    push %r12
    push %r13
    push %r14
    push %r15

    # Salva o RSP atual (já com os registradores acima empilhados)
    # dentro de prev->saved_rsp
    mov %rsp, SAVED_RSP_OFFSET(%rdi)

    # Carrega o RSP salvo de next->saved_rsp
    mov SAVED_RSP_OFFSET(%rsi), %rsp

    # Restaura os registradores "callee-saved" do processo NOVO
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbp
    pop %rbx

    # Volta para onde o processo novo estava executando
    ret

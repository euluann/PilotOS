// encoding: utf-8
// Copyright (c) 2026 Miguel Sampaio
// SPDX-License-Identifier: MIT

#ifndef STDLIB_H
#define STDLIB_H

// Tipos 
typedef unsigned char       uint8_t;
typedef unsigned short      uint16_t;
typedef unsigned int        uint32_t;
typedef unsigned long long  uint64_t;
typedef signed char         int8_t;
typedef signed short        int16_t;
typedef signed int          int32_t;
typedef signed long long    int64_t;

// CPU / CPUID 
struct cpuid_result {
    uint32_t eax, ebx, ecx, edx;
};

struct cpu_info {
    char     vendor[13];
    uint32_t family;
    uint32_t model;
    uint32_t stepping;
    int      has_tsc;
    int      has_msr;
    int      has_apic;
    int      has_hypervisor;
    int      tsc_invariant;
    uint64_t tsc_hz;
};

extern struct cpu_info cpu;

void cpu_detect(void);
uint64_t calibrate_tsc_hz(void);

// Timer / PIT 
#define HZ 1000
#define PIT_FREQ 1193182
#define PIT_COUNT 65280

void pit_init(uint32_t hz);

// Escalonador 
#define QUANTUM_MIN 1
#define QUANTUM_MAX 20
#define PRIORITY_MAX 99

extern volatile uint64_t system_ticks;  // contador global, incrementado a cada tick do timer

// Processos
#define PROC_UNUSED  0  // Slot vazio na tabela
#define PROC_READY   1  // Pronto pra rodar
#define PROC_RUNNING 2  // Rodando agora
#define PROC_BLOCKED 3  // Esperando algo (nao entra na escolha)
#define MAX_PROCESSES 16 // Numero maximo de processos que o kernel pode gerenciar (16 processos, incluindo o kernel)

// Estrutura que representa um processo no kernel
struct process {
    uint64_t utime; // Tempo de CPU gasto em modo usuário (ticks)
    uint64_t stime; // Tempo de CPU gasto em modo kernel (ticks)
    uint32_t preempt_count; // Contador de preempções (ticks)
    int32_t  priority; // 0 (alta) a 99 (baixa), como no Linux (Linux mentioned!!!!!!!!)
    uint64_t save_rsp; // Registrador RSP salvo 
    int state; // 0 = vazio, 1 = pronto, 2 = rodando, 3 = bloqueado
    uint64_t wake_at; // Tick em que o processo deve acordar (se estiver bloqueado)
};

extern struct process proc_table[MAX_PROCESSES];
extern struct process *current;

struct interrupt_frame {
    uint64_t rip;
    uint64_t cs;
    uint64_t rflags;
    uint64_t rsp;
    uint64_t ss;
};

void create_process(int index, void (*entry_point)(void), int32_t priority);
void timer_isr(struct interrupt_frame *frame);
void schedule(void);

// Clock
#define CLOCKS_PER_SEC 1000000L
uint64_t clock(void);

// Context switch
extern void context_switch(struct process *prev, struct process *next);

// IDT 
struct idt_entry {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t  ist;
    uint8_t  type_attr;
    uint16_t offset_mid;
    uint32_t offset_high;
    uint32_t zero;
} __attribute__((packed));

struct idt_ptr {
    uint16_t limit;
    uint64_t base;
} __attribute__((packed));

void idt_init(void);
void pic_remap(void);
void pic_send_eoi(uint8_t irq);
extern void enable_interrupts(void);

#define IDT_ENTRIES 256

#endif

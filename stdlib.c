// encoding: utf-8
// Copyright (c) 2026 Miguel Sampaio
// SPDX-License-Identifier: MIT

#include "stdlib.h"

// Variaveis de ambiente e tipos de dados que sao usados no stdlib padrao do C
typedef unsigned char       uint8_t;
typedef unsigned short      uint16_t;
typedef unsigned int        uint32_t;
typedef unsigned long long  uint64_t;
typedef signed char         int8_t;
typedef signed short        int16_t;
typedef signed int          int32_t;
typedef signed long long    int64_t;

// Funcao que escreve um byte em uma porta de E/S
static inline void outb(uint16_t port, uint8_t val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

// Funcao que le um byte de uma porta de E/S
static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

// Funcao que executa a instrução CPUID com os valores de leaf e subleaf dados na funcao
static inline struct cpuid_result cpuid(uint32_t leaf, uint32_t subleaf) {
    struct cpuid_result r;
    __asm__ volatile (
        "cpuid"
        : "=a"(r.eax), "=b"(r.ebx), "=c"(r.ecx), "=d"(r.edx) // Onde armazenar os resultados
        : "a"(leaf), "c"(subleaf) // Valores de input da funcao
        : "memory" // Evita que o compilador pare a funcao, ja que ela modifica registradores e memoria
    );
    return r; // Retorna os resutados na estrutura cpuid_result chamada "r" (meio obvio btw)
}

// Funcao que retorna o valor do TSC da CPU
static inline uint64_t rdtsc(void) {
    uint32_t lo, hi;
    __asm__ volatile ("rdtsc" : "=a"(lo), "=d"(hi));
    return ((uint64_t)hi << 32) | lo;
}

// Funcao que retorna o valor de um MSR da CPU
static inline uint64_t rdmsr(uint32_t msr) {
    uint32_t lo, hi;
    __asm__ volatile ("rdmsr" : "=a"(lo), "=d"(hi) : "c"(msr));
    return ((uint64_t)hi << 32) | lo;
}

struct cpu_info cpu;

// Funcao para detectar informacoes sobre a CPU, como vendor, family, model, stepping, features e TSC (ou seja, o comeco do que seria um kernel de vdd)
void cpu_detect(void) {
    struct cpuid_result r;

    // Vendor 
    r = cpuid(0, 0);
    *(uint32_t*)&cpu.vendor[0] = r.ebx;
    *(uint32_t*)&cpu.vendor[4] = r.edx;
    *(uint32_t*)&cpu.vendor[8] = r.ecx;
    cpu.vendor[12] = 0;

    // Família, Modelo e Stepping 
    r = cpuid(1, 0);
    cpu.stepping = r.eax & 0xF;
    uint32_t model   = (r.eax >> 4)  & 0xF;
    uint32_t family  = (r.eax >> 8)  & 0xF;
    uint32_t ext_model  = (r.eax >> 16) & 0xF;
    uint32_t ext_family = (r.eax >> 20) & 0xF;
    cpu.family   = family + ext_family;
    cpu.model    = model + (ext_model << 4);

    // Features EDX
    cpu.has_tsc  = (r.edx >> 4)  & 1;
    cpu.has_msr  = (r.edx >> 5)  & 1;
    cpu.has_apic = (r.edx >> 23) & 1;

    // Features ECX
    cpu.has_hypervisor = (r.ecx >> 31) & 1;

    // TSC Invariant
    cpu.tsc_invariant = 0;
    uint32_t max_ext = cpuid(0x80000000, 0).eax;
    if (max_ext >= 0x80000007) {
        r = cpuid(0x80000007, 0);
        cpu.tsc_invariant = (r.edx >> 8) & 1;
    } 
}

// Funcao para calibrar a frequencia do TSC usando o PIT
uint64_t calibrate_tsc_hz(void) {
    uint64_t best = 0;

    // Repete 5 vezes, pega o mínimo (elimina ruído de IRQs) 
    for (int i = 0; i < 5; i++) {

        // Configura o PIT para contar 0xFF00 ticks (aprox. 54.7 ms)
        outb(0x43, 0x34); // Escreve o byte de comando no registrador de comando do PIT (0x43)
        outb(0x40, PIT_COUNT & 0xFF);  // Escreve o low byte do contador no canal 0 do PIT (0x40)
        outb(0x40, (PIT_COUNT >> 8) & 0xFF); // Escreve o high byte do contador no canal 0 do PIT (0x40)

        uint64_t tsc_start = rdtsc(); // Pega o valor do TSC antes de esperar o PIT contar

        // Esperar 1 período completo (detectar wrap) 
        uint16_t prev = 0;
        for (;;) {
            outb(0x43, 0x00); // Escreve o byte de status do PIT (0x43)
            uint8_t lo = inb(0x40); // Le o low byte do contador do canal 0 do PIT (0x40)
            uint8_t hi = inb(0x40); // Le o high byte do contador do canal 0 do PIT (0x40)
            uint16_t count = (hi << 8) | lo; // Combina os bytes lidos em um valor de 16 bits
            if (prev != 0 && count > prev) // Verifica se o contador do PIT deu wrap (voltou a contar do zero)
                break;
            prev = count; // Atualiza o valor anterior do contador do PIT
        }

        uint64_t tsc_end = rdtsc(); // Pega o valor do TSC depois de esperar o PIT contar
        uint64_t hz = ((tsc_end - tsc_start) * PIT_FREQ) / PIT_COUNT; // Calcula a frequência do TSC em Hz usando a diferença de TSC e a frequência do PIT

        if (best == 0 || hz < best) // Se for a primeira iteração ou se a frequência calculada for menor que a melhor encontrada até agora, atualiza o valor de best
            best = hz;
    }

    return best;
}   

// Funcao que inicializa o PIT para gerar interrupções a uma frequência específica (em Hz)
void pit_init(uint32_t hz) {
    uint32_t divisor = PIT_FREQ / hz;
    outb(0x43, 0x36); // Configura o PIT para modo 3 (square wave)
    outb(0x40, divisor & 0xFF); // Escreve o low byte do divisor
    outb(0x40, (divisor >> 8) & 0xFF); // Escreve o high byte do divisor
}

struct process proc_table[MAX_PROCESSES];

struct process *current = 0;  // Vai ser definido pelo scheduler

// Funcao que implementa o escalonador de processos (scheduler) do kernel
void schedule(void) {
    if (current->state == PROC_RUNNING)
        current->state = PROC_READY;

    int current_index = 0;
    for (int i = 0; i < MAX_PROCESSES; i++) {
        if (&proc_table[i] == current) {
            current_index = i;
            break;
        }
    }

    struct process *next = 0;
    int32_t best_priority = PRIORITY_MAX + 1;

    for (int i = 1; i <= MAX_PROCESSES; i++) {
        int idx = (current_index + i) % MAX_PROCESSES;
        struct process *p = &proc_table[idx];

        if (p->state != PROC_READY)
            continue;

        if (p->priority < best_priority) {
            best_priority = p->priority;
            next = p;
        }
    }

    if (!next)
        next = current;

    next->state = PROC_RUNNING;

    if (next != current) {
        struct process *prev = current;
        current = next;
        context_switch(prev, next);   // TODOS OS ARQS REFERENTES AO CONTEXT SWITCH SAO SO PRA ISSO btw
    }
}

#define STACK_SIZE 8192 // Esse e o tamanho da pilha de cada processo (4 KB, o tamanho de uma pagina de memoria). Ou seja, se der erro de tamanho de pilha, aumentar esse valor. Mas nao muito, senao vai gastar muita memoria RAM do PC
static uint8_t stacks[MAX_PROCESSES][STACK_SIZE];

// Funcao que cria um novo processo no kernel, inicializando sua pilha e registradores (FINALEMENTE, A FUNCAO QUE CRIA UM PROCESSO, O KERNEL TA QUASE PRONTO)
void create_process(int index, void (*entry_point)(void), int32_t priority) {
    struct process *p = &proc_table[index];

    p->utime = 0;
    p->stime = 0;
    p->preempt_count = 0;
    p->priority = priority;
    p->state = PROC_READY;

    // Pega o topo da pilha reservada pra esse processo
    uint64_t *stack_top = (uint64_t *)(stacks[index] + STACK_SIZE);

    // Empilha o endereço que o "ret" dentro de context_switch vai pular quando
    // esse processo for escalado pela primeira vez
    stack_top--;
    *stack_top = (uint64_t)entry_point;

    // Empilha valores fake para os registradores callee-saved
    // (context_switch vai dar 6 "pop"s: r15, r14, r13, r12, rbp, rbx)
    stack_top--; *stack_top = 0; // r15
    stack_top--; *stack_top = 0; // r14
    stack_top--; *stack_top = 0; // r13
    stack_top--; *stack_top = 0; // r12
    stack_top--; *stack_top = 0; // rbp
    stack_top--; *stack_top = 0; // rbx

    // Salva esse RSP fabricado como se fosse o "estado salvo" desse processo
    p->save_rsp = (uint64_t)stack_top;
}

// Funcao que pega o QUANTUM
static inline uint32_t get_quantum(struct process *p) {
    uint32_t priority = p->priority;
    if (priority > PRIORITY_MAX) priority = PRIORITY_MAX;

    uint32_t q = QUANTUM_MAX - (priority * (QUANTUM_MAX - QUANTUM_MIN)) / PRIORITY_MAX;
    return q;
}

volatile uint64_t system_ticks = 0;

// Funcao que trata a interrupcao do timer (PIT) e atualiza o tempo de CPU gasto pelo processo atual
void timer_isr(struct interrupt_frame *frame) {
    system_ticks++;

    int was_user = (frame->cs & 0x03) == 3;

    if (was_user)
        current->utime++;
    else
        current->stime++;

    // Acorda processos bloqueados cujo tempo de espera ja passou
    for (int i = 0; i < MAX_PROCESSES; i++) {
        if (proc_table[i].state == PROC_BLOCKED && system_ticks >= proc_table[i].wake_at) {
            proc_table[i].state = PROC_READY;
        }
    }

    // Preempcao
    current->preempt_count++;
    if (current->preempt_count >= get_quantum(current)) {
        current->preempt_count = 0;
        schedule();
    }

    pic_send_eoi(0);
} 

// Funcao que retorna o tempo de CPU gasto pelo processo atual em microssegundos
uint64_t clock(void) {
    uint64_t ticks = current->utime + current->stime;
    // Cada tick = 1/HZ segundos
    return ticks * (CLOCKS_PER_SEC / HZ);
}

// IDT
extern void irq0_stub(void);
static struct idt_entry idt[IDT_ENTRIES];
static struct idt_ptr idtp;

// Preenche uma entrada da IDT com o endereço de um handler
static void idt_set_entry(int vector, uint64_t handler, uint16_t selector, uint8_t type_attr) {
    idt[vector].offset_low  = handler & 0xFFFF;
    idt[vector].selector    = selector;
    idt[vector].ist         = 0;
    idt[vector].type_attr   = type_attr;
    idt[vector].offset_mid  = (handler >> 16) & 0xFFFF;
    idt[vector].offset_high = (handler >> 32) & 0xFFFFFFFF;
    idt[vector].zero        = 0;
}

extern void idt_load(uint64_t idtp_addr);  // Implementado no idt.S

void idt_init(void) {
    idtp.limit = sizeof(idt) - 1;
    idtp.base  = (uint64_t)&idt;

    idt_set_entry(32, (uint64_t)irq0_stub, 0x18, 0x8E);

    idt_load((uint64_t)&idtp);
}

// PIC
#define PIC1_COMMAND 0x20
#define PIC1_DATA    0x21
#define PIC2_COMMAND 0xA0
#define PIC2_DATA    0xA1

#define PIC_EOI      0x20  // End of interrupt

void pic_remap(void) {
    uint8_t mask1 = inb(PIC1_DATA);
    uint8_t mask2 = inb(PIC2_DATA);

    outb(PIC1_COMMAND, 0x11);  // inicia sequencia de inicializacao, modo cascata
    outb(PIC2_COMMAND, 0x11);

    outb(PIC1_DATA, 0x20);     // PIC1: IRQs 0-7  -> vetores 32-39
    outb(PIC2_DATA, 0x28);     // PIC2: IRQs 8-15 -> vetores 40-47

    outb(PIC1_DATA, 0x04);     // avisa PIC1 que há um PIC2 ligado na linha IRQ2
    outb(PIC2_DATA, 0x02);     // avisa PIC2 sua identidade em cascata

    outb(PIC1_DATA, 0x01);     // modo 8086
    outb(PIC2_DATA, 0x01);

    outb(PIC1_DATA, mask1);    // restaura as mascaras originais (nada muda de habilitado/desabilitado)
    outb(PIC2_DATA, mask2);
}

// Avisa ao PIC que a interrupção foi tratada, senao ele para de mandar novas
void pic_send_eoi(uint8_t irq) {
    if (irq >= 8)
        outb(PIC2_COMMAND, PIC_EOI);
    outb(PIC1_COMMAND, PIC_EOI);
}

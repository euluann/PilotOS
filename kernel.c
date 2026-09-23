// encoding: utf-8
// Copyright (c) 2026 Luan Pestana e Miguel Sampaio
// SPDX-License-Identifier: MIT

#include "stdlib.h"
#include "libfoda.h"

// ATENCAO //
// O kernel.c DEVE comecar pela funcao main, ou o bootloader ira falhar

 // Pre declara funcoes e variaveis declaradas apos o main, ou nao sera possivel usa-las no main, mas NAO crie uma funcao antes do main
void main_process(void);

void kernel_main(void){
    idt_init(); // ESSA MERDA TEM QUE INICIAR ANTES DE ABSOLUTAMENTE TUDO!!!!!!!!!!!!!! 
    pic_remap(); // ESSA TBM TEM QUE!!!!!!!!!!!!

    // Etapas de verificacao do kernel, como detectar a CPU, inicializar o PIT e calibrar o TSC (MUITO IMPORTANTE, SEM ISSO O KERNEL NAO FUNCIONA)
    cpu_detect();

    if (!cpu.has_tsc) {
        print("Sem TSC; usando somente o PIT\n");
        cpu.tsc_hz = 0;
    } else if (!cpu.tsc_invariant) {
        print("TSC nao invariante; usando somente o PIT\n");
        cpu.tsc_hz = 0;
    } else {
        print("TSC invariante\n");
        cpu.tsc_hz = calibrate_tsc_hz();
    }

    // Criacao de um processo idle pro kernel, que vai rodar quando nao houver nenhum outro processo pronto e o codigo nao quebrar se nao houber nenhum processo pronto
    create_process(0, hlt, PRIORITY_MAX);
    create_process(1, main_process, 0);

    current = &proc_table[0];
    current->state = PROC_RUNNING;

    pit_init(HZ);
    enable_interrupts(); 

    hlt();
}

// Esse e o processo que inicia junto do kernel_main, entao todo o codigo base do kernel é escrito aqui
void main_process(void){
    clear();
    sleep(10000);
    print("Bom dia manos");
}

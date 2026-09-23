// encoding: utf-8
// Copyright (c) 2026 Miguel Sampaio
// SPDX-License-Identifier: MIT

#include "stdlib.h"
#include "libfoda.h"

volatile char *video = (volatile char *)0xB8000;
int cursor = 0;

void print(const char *str){
    while (*str != '\0') {
        if (*str == '\n') {
            cursor += 80 - (cursor % 80);
        } else {
            video[cursor * 2] = *str;
            video[cursor * 2 +1] = 0x07;
            cursor++;
        }
        str++;
    }
}

void clear(void){
    for (int i = 0; i < 80 * 25; i++){
        video[i * 2] = ' ';
        video[i * 2 + 1] = 0x07;
    }
    cursor = 0;
}

void hlt(void){
    for (;;){
        __asm__ volatile ("hlt");
    }
}

void sleep(uint32_t ms) {
    if (ms == 0) {
        return;
    }

    uint64_t ticks_to_wait =
        (((uint64_t)ms * (uint64_t)HZ) + 999ULL) / 1000ULL;

    if (ticks_to_wait == 0) {
        ticks_to_wait = 1;
    }

    current->wake_at = system_ticks + ticks_to_wait;
    current->state = PROC_BLOCKED;

    schedule();
}

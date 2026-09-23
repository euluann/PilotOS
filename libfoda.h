// encoding: utf-8
// Copyright (c) 2026 Miguel Sampaio
// SPDX-License-Identifier: MIT

#ifndef LIBFODA_H
#define LIBFODA_H

extern volatile char *video;
extern int cursor;

void print(const char *str);
void hlt(void);
void clear(void);
void sleep(uint32_t ms);

#endif

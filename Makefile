CC = clang
LD = ld.lld
OBJCOPY = llvm-objcopy

BUILD = compiled

KERNEL_ELF  = $(BUILD)/kernel.elf
KERNEL_BIN  = $(BUILD)/kernel.bin
KERNEL_SIZE = $(BUILD)/kernel_size.inc

BOOTLOADER_OBJ = $(BUILD)/bootloader.o
BOOTLOADER_BIN = $(BUILD)/bootloader.bin

IMG = $(BUILD)/MyOS.img
ISO = $(BUILD)/MyOS.iso


CFLAGS = --target=x86_64-unknown-none \
         -ffreestanding \
         -fno-stack-protector \
         -mno-red-zone


.PHONY: all run clean

all: $(ISO)


# ============================================================
# DIRETÓRIO
# ============================================================

$(BUILD):
	mkdir -p $(BUILD)


# ============================================================
# KERNEL
# ============================================================

$(BUILD)/isr_stubs.o: isr_stubs.S | $(BUILD)
	$(CC) --target=x86_64-unknown-none \
		-c isr_stubs.S \
		-o $@

$(BUILD)/idt.o: idt.S | $(BUILD)
	$(CC) --target=x86_64-unknown-none \
		-c idt.S \
		-o $@

$(BUILD)/boot.o: boot.S | $(BUILD)
	$(CC) --target=x86_64-unknown-none \
		-c boot.S \
		-o $@

$(BUILD)/stdlib.o: stdlib.c stdlib.h | $(BUILD)
	$(CC) $(CFLAGS) \
		-c stdlib.c \
		-o $@

$(BUILD)/libfoda.o: libfoda.c libfoda.h | $(BUILD)
	$(CC) $(CFLAGS) \
		-c libfoda.c \
		-o $@

$(BUILD)/kernel.o: kernel.c stdlib.h libfoda.h | $(BUILD)
	$(CC) $(CFLAGS) \
		-c kernel.c \
		-o $@

$(BUILD)/context_switch.o: context_switch.S | $(BUILD)
	$(CC) --target=x86_64-unknown-none \
		-c context_switch.S \
		-o $@

$(KERNEL_ELF): $(BUILD)/boot.o $(BUILD)/kernel.o $(BUILD)/stdlib.o $(BUILD)/context_switch.o $(BUILD)/idt.o $(BUILD)/isr_stubs.o $(BUILD)/libfoda.o linker.ld
	$(LD) -T linker.ld \
		-o $@ \
		$(BUILD)/boot.o \
		$(BUILD)/kernel.o \
		$(BUILD)/stdlib.o \
		$(BUILD)/context_switch.o \
		$(BUILD)/idt.o \
		$(BUILD)/isr_stubs.o \
		$(BUILD)/libfoda.o


$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary \
		$(KERNEL_ELF) \
		$(KERNEL_BIN)


# Gera o tamanho EXATO do kernel.bin
$(KERNEL_SIZE): $(KERNEL_BIN)
	@echo ".equ KERNEL_SIZE, $$(stat -c%s $(KERNEL_BIN))" > $@
	@echo "Kernel: $$(stat -c%s $(KERNEL_BIN)) bytes"


# ============================================================
# BOOTLOADER
# ============================================================

$(BOOTLOADER_OBJ): bootloader.S $(KERNEL_SIZE) | $(BUILD)
	$(CC) --target=i386-unknown-none \
		-m16 \
		-I$(BUILD) \
		-c bootloader.S \
		-o $@


$(BOOTLOADER_BIN): $(BOOTLOADER_OBJ)
	$(LD) -m elf_i386 \
		--image-base 0x7C00 \
		--oformat binary \
		-Ttext 0x7C00 \
		-o $@ \
		$(BOOTLOADER_OBJ)


# ============================================================
# DISK IMAGE
# ============================================================

$(IMG): $(BOOTLOADER_BIN) $(KERNEL_BIN)
	@echo "Criando imagem de disco..."

	dd if=/dev/zero \
		of=$(IMG) \
		bs=512 \
		count=2880

	@echo "Gravando bootloader..."

	dd if=$(BOOTLOADER_BIN) \
		of=$(IMG) \
		conv=notrunc

	@echo "Gravando kernel..."

	dd if=$(KERNEL_BIN) \
		of=$(IMG) \
		bs=512 \
		seek=1 \
		conv=notrunc

	@echo "Imagem criada: $(IMG)"


# ============================================================
# ISO
# ============================================================

$(ISO): $(IMG)
	@echo "Preparando ISO..."

	rm -rf $(BUILD)/iso
	mkdir -p $(BUILD)/iso

	cp $(IMG) $(BUILD)/iso/MyOS.img

	@echo "Gerando ISO..."

	xorriso -as mkisofs \
		-o $(ISO) \
		-b MyOS.img \
		-c boot.cat \
		-boot-load-size 2880 \
		$(BUILD)/iso

	rm -rf $(BUILD)/iso

	@echo
	@echo "=================================="
	@echo "ISO gerada:"
	@echo "	$(ISO)"
	@echo
	@echo "Use:"
	@echo "	qemu-system-x86_64 -cdrom compiled/MyOS.iso -display curses"
	@echo "Ou:"
	@echo "	make run"
	@echo "=================================="


# ============================================================
# RUN
# ============================================================

run: $(ISO)
	qemu-system-x86_64 \
		-cdrom $(ISO) \
		-cpu host \
		-enable-kvm \
		-d int,cpu_reset \
		-no-reboot \
		-no-shutdown \
		-display curses \
		2> qemu_debug.log

# ============================================================
# CLEAN
# ============================================================

clean:
	rm -rf $(BUILD)

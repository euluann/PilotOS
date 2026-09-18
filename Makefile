CC = clang
LD = ld.lld
OBJCOPY = llvm-objcopy

BUILD = compiled

KERNEL_ELF  = $(BUILD)/kernel.elf
KERNEL_BIN  = $(BUILD)/kernel.bin
KERNEL_SIZE = $(BUILD)/kernel_size.inc

BOOTLOADER1_OBJ = $(BUILD)/bootloader1.o
BOOTLOADER1_BIN = $(BUILD)/bootloader1.bin
BOOTLOADER2_OBJ = $(BUILD)/bootloader2.o
BOOTLOADER2_BIN = $(BUILD)/bootloader2.bin


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

$(BUILD)/boot.o: boot.s | $(BUILD)
	$(CC) --target=x86_64-unknown-none \
		-c boot.s \
		-o $@


$(BUILD)/kernel.o: kernel.c | $(BUILD)
	$(CC) $(CFLAGS) \
		-c kernel.c \
		-o $@


$(KERNEL_ELF): $(BUILD)/boot.o $(BUILD)/kernel.o linker.ld
	$(LD) -T linker.ld \
		-o $@ \
		$(BUILD)/boot.o \
		$(BUILD)/kernel.o


$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary \
		$(KERNEL_ELF) \
		$(KERNEL_BIN)


# Gera o tamanho EXATO do kernel.bin
$(KERNEL_SIZE): $(KERNEL_BIN)
	@echo "#define KERNEL_SIZE $$(stat -c%s $(KERNEL_BIN))" > $@
	@echo "Kernel: $$(stat -c%s $(KERNEL_BIN)) bytes"


# ============================================================
# BOOTLOADER
# ============================================================

$(BOOTLOADER1_OBJ): bootloader1.s $(KERNEL_SIZE) | $(BUILD)
	$(CC) --target=i386-unknown-none \
		-m16 \
		-x assembler-with-cpp \
		-I$(BUILD) \
		-c bootloader1.s \
		-o $@


$(BOOTLOADER1_BIN): $(BOOTLOADER1_OBJ)
	$(LD) -m elf_i386 \
		--image-base 0x7C00 \
		--oformat binary \
		-Ttext 0x7C00 \
		-o $@ \
		$(BOOTLOADER1_OBJ)


$(BOOTLOADER2_OBJ): bootloader2.s $(KERNEL_SIZE) | $(BUILD)
	$(CC) --target=i386-unknown-none \
		-m16 \
		-x assembler-with-cpp \
		-I$(BUILD) \
		-c bootloader2.s \
		-o $@


$(BOOTLOADER2_BIN): $(BOOTLOADER2_OBJ)
	$(LD) -m elf_i386 \
		--image-base 0x8000 \
		--oformat binary \
		-Ttext 0x8000 \
		-o $@ \
		$(BOOTLOADER2_OBJ)
		

# ============================================================
# DISK IMAGE
# ============================================================

$(IMG): $(BOOTLOADER1_BIN) $(BOOTLOADER2_BIN) $(KERNEL_BIN)
	@echo "Criando imagem de disco..."

	dd if=/dev/zero \
		of=$(IMG) \
		bs=512 \
		count=2880

	@echo "Gravando bootloader..."

	dd if=$(BOOTLOADER1_BIN) \
		of=$(IMG) \
		conv=notrunc
	dd if=$(BOOTLOADER2_BIN) \
		of=$(IMG) \
		bs=512 \
		seek=1 \
		conv=notrunc

	@echo "Gravando kernel..."

	dd if=$(KERNEL_BIN) \
		of=$(IMG) \
		bs=512 \
		seek=2 \
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
		-no-emul-boot \
		-boot-load-size 2880 \
                -boot-info-table \
		$(BUILD)/iso

	rm -rf $(BUILD)/iso

	@echo
	@echo "=================================="
	@echo "ISO gerada:"
	@echo "	$(ISO)"
	@echo
	@echo "Use:"
	@echo "	qemu-system-x86_64 -drive file=compiled/MyOS.img -display curses -monitor none -serial none"
	@echo "Ou:"
	@echo "	make run"
	@echo "=================================="


# ============================================================
# RUN
# ============================================================

run: $(IMG)
	qemu-system-x86_64 -drive file=$(IMG) -display curses -monitor none -serial none

# ============================================================
# CLEAN
# ============================================================

clean:
	rm -rf $(BUILD)

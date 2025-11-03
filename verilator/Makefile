# Makefile for Verilator audio testbench (no SDL2 required)

VERILATOR = verilator
SRC_DIR = ../src
VERILOG_SOURCES = $(SRC_DIR)/audio.v

# Verilator flags
VERILATOR_FLAGS = --cc --exe --build --top-module audio -Wall -Wno-UNUSED

# Target executable
TARGET = test_audio_verilator

all: $(TARGET)

$(TARGET): test_audio_verilator.cpp $(VERILOG_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) \
		$(VERILOG_SOURCES) \
		test_audio_verilator.cpp \
		--Mdir obj_dir \
		-CFLAGS -std=c++14
	cp obj_dir/Vaudio $(TARGET)

run: $(TARGET)
	./$(TARGET)

clean:
	rm -rf obj_dir $(TARGET) audio_*.wav

.PHONY: all run clean


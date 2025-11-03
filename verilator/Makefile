VERILATOR = verilator
VERILATOR_FLAGS = -Wno-widthexpand -Wno-widthtrunc -Wno-UNSIGNED --trace -cc --exe
CPP = g++
CPP_FLAGS = -std=c++11 -Wall

# Source files
SRC_DIR = ../src

# Goose game sources (includes audio)
GOOSE_SOURCES = $(SRC_DIR)/project.v \
                $(SRC_DIR)/hvsync_generator.v \
                $(SRC_DIR)/rendering.v \
                $(SRC_DIR)/jumping.v \
                $(SRC_DIR)/scroll.v \
                $(SRC_DIR)/rng.v \
                $(SRC_DIR)/audio.v

# VGA demo sources (simple color pattern demo)
VGADEMO_SOURCES = $(SRC_DIR)/vga_example.v \
                  $(SRC_DIR)/hvsync_generator.v

# Audio test sources
AUDIO_SOURCES = $(SRC_DIR)/audio.v

# Build targets
all: goosegame vgademo

goosegame: $(GOOSE_SOURCES) goosegame_tb.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $^ \
		-CFLAGS "-g -O3" --LDFLAGS "-lSDL2" --top-module tt_um_goose_game
	$(MAKE) -C obj_dir -f Vtt_um_goose_game.mk
	cp obj_dir/Vtt_um_goose_game goosegame

vgademo: $(VGADEMO_SOURCES) vgademo_tb.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $^ \
		-CFLAGS "-g -O3" --LDFLAGS "-lSDL2" --top-module tt_um_vga_example
	$(MAKE) -C obj_dir -f Vtt_um_vga_example.mk
	cp obj_dir/Vtt_um_vga_example vgademo

# Audio test (standalone, no SDL2)
test_audio: test_audio_verilator.cpp $(AUDIO_SOURCES)
	$(VERILATOR) -Wall -Wno-UNUSED --cc --exe --build \
		$(AUDIO_SOURCES) test_audio_verilator.cpp \
		--top-module audio --Mdir obj_dir_audio \
		-CFLAGS -std=c++14
	cp obj_dir_audio/Vaudio test_audio

clean:
	rm -rf obj_dir obj_dir_audio
	rm -f goosegame vgademo test_audio
	rm -f *.vcd audio_*.wav

run: goosegame
	./goosegame

run-demo: vgademo
	./vgademo

run-audio: test_audio
	./test_audio

.PHONY: all clean run run-demo run-audio

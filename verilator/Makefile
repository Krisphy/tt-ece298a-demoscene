VERILATOR = verilator
VERILATOR_FLAGS = -Wno-widthexpand -Wno-widthtrunc -Wno-UNSIGNED --trace -cc --exe
CPP = g++
CPP_FLAGS = -std=c++11 -Wall

# Source files
SRC_DIR = ../src

# Goose game sources (includes audio)
GOOSE_SOURCES = $(SRC_DIR)/goose_game_top.v \
                $(SRC_DIR)/game_controller.v \
                $(SRC_DIR)/rendering.v \
                $(SRC_DIR)/hvsync_generator.v \
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
all: goosegame goosegame-audio vgademo audiotest-play

# Goose game without audio (faster, simpler)
goosegame: $(GOOSE_SOURCES) goosegame_tb.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $^ \
		-CFLAGS "-g -O3 -DNO_AUDIO" --LDFLAGS "-lSDL2" --top-module tt_um_goose_game
	$(MAKE) -C obj_dir -f Vtt_um_goose_game.mk
	cp obj_dir/Vtt_um_goose_game goosegame

# Goose game with audio playback and event logging
goosegame-audio: $(GOOSE_SOURCES) goosegame_tb.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $^ \
		-CFLAGS "-g -O3 -DWITH_AUDIO" --LDFLAGS "-lSDL2" --top-module tt_um_goose_game
	$(MAKE) -C obj_dir -f Vtt_um_goose_game.mk
	cp obj_dir/Vtt_um_goose_game goosegame-audio

vgademo: $(VGADEMO_SOURCES) vgademo_tb.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $^ \
		-CFLAGS "-g -O3" --LDFLAGS "-lSDL2" --top-module tt_um_vga_example
	$(MAKE) -C obj_dir -f Vtt_um_vga_example.mk
	cp obj_dir/Vtt_um_vga_example vgademo

# Audio test with real-time playback via SDL2
audiotest-play: audiotest_tb.cpp $(AUDIO_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $^ \
		-CFLAGS "-g -O3" --LDFLAGS "-lSDL2" --top-module audio
	$(MAKE) -C obj_dir -f Vaudio.mk
	cp obj_dir/Vaudio audiotest-play

# Audio test that generates WAV files (no real-time playback)
audiotest-wav: test_audio_verilator.cpp $(AUDIO_SOURCES)
	$(VERILATOR) -Wall -Wno-UNUSED --cc --exe --build \
		$(AUDIO_SOURCES) test_audio_verilator.cpp \
		--top-module audio -CFLAGS -std=c++14
	cp obj_dir/Vaudio audiotest-wav

clean:
	rm -rf obj_dir
	rm -f goosegame goosegame-audio vgademo audiotest-play audiotest-wav
	rm -f *.vcd audio_*.wav

# Run targets
run: goosegame
	@echo "Running goose game (no audio)..."
	./goosegame

run-audio: goosegame-audio
	@echo "Running goose game with audio and event logging..."
	./goosegame-audio

run-demo: vgademo
	@echo "Running VGA demo..."
	./vgademo

run-audiotest-play: audiotest-play
	@echo "Running audio test with real-time playback..."
	./audiotest-play

run-audiotest-wav: audiotest-wav
	@echo "Running audio test (generates WAV files)..."
	./audiotest-wav

.PHONY: all clean run run-audio run-demo run-audiotest-play run-audiotest-wav

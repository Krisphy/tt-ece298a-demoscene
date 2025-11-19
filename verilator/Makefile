VERILATOR = verilator
VERILATOR_FLAGS = -Wno-widthexpand -Wno-widthtrunc -Wno-UNSIGNED --trace -cc --exe
CPP = g++
CPP_FLAGS = -std=c++14 -Wall

# SDL2 paths - try pkg-config first, then OS-specific fallbacks
PKG_CONFIG := $(shell command -v pkg-config 2>/dev/null)
ifeq ($(PKG_CONFIG),)
  # No pkg-config, detect OS and use appropriate paths
  UNAME_S := $(shell uname -s)
  ifeq ($(UNAME_S),Darwin)
    # macOS ARM (Apple Silicon) - Homebrew paths
    SDL2_CFLAGS = -I/opt/homebrew/include
    SDL2_LDFLAGS = -L/opt/homebrew/lib -lSDL2
  else
    # Linux (including Mint) - standard system paths
    SDL2_CFLAGS = -I/usr/include/SDL2
    SDL2_LDFLAGS = -lSDL2
  endif
else
  # Use pkg-config (works on both macOS ARM and Linux)
  SDL2_CFLAGS = $(shell pkg-config --cflags sdl2)
  SDL2_LDFLAGS = $(shell pkg-config --libs sdl2)
endif

# Source files
SRC_DIR = ../src

# Goose game sources (audio removed)
GOOSE_SOURCES = $(SRC_DIR)/goose_game_top.v \
                $(SRC_DIR)/game_controller.v \
                $(SRC_DIR)/rendering.v \
                $(SRC_DIR)/hvsync_generator.v \
                $(SRC_DIR)/jumping.v \
                $(SRC_DIR)/scroll.v

# Build targets
all: goosegame

# Goose game
goosegame: $(GOOSE_SOURCES) goosegame_tb.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $^ \
		-CFLAGS "-std=c++14 -g -O3 $(SDL2_CFLAGS)" --LDFLAGS "$(SDL2_LDFLAGS)" --top-module tt_um_goose_game
	$(MAKE) -C obj_dir -f Vtt_um_goose_game.mk
	cp obj_dir/Vtt_um_goose_game goosegame

clean:
	rm -rf obj_dir
	rm -f goosegame
	rm -f *.vcd

# Run targets
run: goosegame
	@echo "Running goose game..."
	./goosegame

.PHONY: all clean run

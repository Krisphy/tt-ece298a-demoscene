![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Goose Game - DinoGame Style Runner for Tiny Tapeout

A Chrome Dino Game-style endless runner implemented in Verilog and deployable through the TinyTapeout ASIC workflow. The player controls a goose that jumps over the University of Waterloo emblem. Video is output through VGA at 640x480 60Hz (With the correct clock input).

## Overview

This project implements a side-scrolling game with:
- Button-based control for jump and reset
- RGB222 VGA output (2-bit RGB color, 64 colors)
- Parabolic jump movement
- Scrolling ground texture
- Pixel accurate collision detection
- Game state management (running, game over, reset)
- A custom rendered Goose and University of Waterloo emblem
- Incremental speedups for difficulty

## Architecture

The design is organized into five main modules:

- **`game_controller.v`**: Central game logic including FSM (startup, running, game over), collision handling, obstacle spawning, and reset detection
- **`rendering.v`**: VGA rendering engine with sprite storage, layered compositing, and collision detection logic
- **`jumping.v`**: Jump physics using ROM-based lookup table with mirrored ascent/descent for space optimization
- **`scroll.v`**: Horizontal scrolling logic with configurable speed
- **`hvsync_generator.v`**: VGA timing signal generation (hsync, vsync, display_on)

insert diagram here

## Inputs and Outputs

### Inputs
- `ui_in[0]`: Jump button (Active Low)
- `ui_in[1]`: Reset button (Active Low)
- `clk`: 25MHz clock (or 25.175MHz for exact VGA 640x480 @ 60Hz timing)

### Outputs (TinyVGA PMOD Format)
- `uo_out[7]`: HSync
- `uo_out[6:4]`: Blue, Green, Red (LSBs)
- `uo_out[3]`: VSync
- `uo_out[2:0]`: Blue, Green, Red (MSBs)

The remaining Tiny Tapeout inputs and bidirectional IOs are unused. The chip is best paired with the TinyVGA PMOD for VGA output.

## Gameplay
Gameplay is simple: the user has access to just the jump button and reset button. Jump over the obstacles, and if you lose, press reset to play again! A lost game state is indicated by an all-red goose and the visuals being halted.

## Testing

To run a visual simulation of the game with SDL2, ensure the required libraries are installed (see `verilator/README.md`) and run the following commands:
```bash
cd verilator
make all
./goosegame
```

**Controls:**
- `SPACE` or `↑` = Jump
- `R` = Reset game
- `ESC` = Quit

For detailed information about the project, see [docs/info.md](docs/info.md).  
For information about the verilator test bench, see [verilator/README.md](verilator/README.md).

![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Goose Game - DinoGame Style Runner for Tiny Tapeout

A Chrome Dino-style endless runner game implemented in Verilog that outputs VGA video (640x480 @ 60Hz). The player plays a goose that jumps over the University of Waterloo emblem.

## Overview

This project implements a side-scrolling game with:
- RGB222 VGA output (2-bit RGB color, 64 colors)
- Parabolic jump movement
- Scrolling ground texture
- Pixel accurate collision detection
- Game state management (startup, running, game over, reset)
- A custom rendered Goose and University of Waterloo emblem

## Architecture

The design is organized into five main modules:

- **`game_controller.v`**: Central game logic including FSM (startup, running, game over), collision handling, obstacle spawning, and reset detection
- **`rendering.v`**: VGA rendering engine with sprite storage, layered compositing, and collision detection logic
- **`jumping.v`**: Jump physics using ROM-based lookup table with mirrored ascent/descent for space optimization
- **`scroll.v`**: Horizontal scrolling logic with configurable speed
- **`hvsync_generator.v`**: VGA timing signal generation (hsync, vsync, display_on)

All modules use synchronous reset and are optimized for minimal area usage.

## Inputs and Outputs

### Inputs
- `ui_in[0]`: Jump button
- `ui_in[1]`: Reset button

### Outputs (TinyVGA PMOD Format)
- `uo_out[7]`: HSync
- `uo_out[6:4]`: Blue, Green, Red (LSBs)
- `uo_out[3]`: VSync
- `uo_out[2:0]`: Blue, Green, Red (MSBs)

## Additional Notes

- **Clock**: 25 MHz (Setup for 640x480 @ 60Hz)
- **Hardware Requirements**: TinyVGA PMOD for VGA output, two push buttons for input

### Testing

Run an interactive visual simulation with SDL2, ensure the required libraries are installed:
```bash
cd verilator
make all
./goosegame
```

**Controls:**
- `SPACE` or `↑` = Jump
- `R` = Reset game
- `ESC` = Quit

For detailed information, see [docs/info.md](docs/info.md).

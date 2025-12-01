![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Goose Game - DinoGame Style Runner for Tiny Tapeout

A Chrome Dino-style endless runner game implemented in Verilog that outputs VGA video (640x480 @ 60Hz). Guide a goose as it jumps over obstacles featuring the University of Waterloo emblem!

## Overview

This project implements a complete side-scrolling game with:
- Real-time VGA output with 2-bit RGB color (8 colors)
- Physics-based jump mechanics with parabolic trajectory
- Scrolling background with animated ground texture
- Collision detection
- Game state management (startup, running, game over, reset)
- Rendered sprites for the goose character and UW emblem obstacle

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

Provides 2-bit per channel RGB (8 total colors).

## Additional Notes

- **Clock**: 25 MHz (VGA pixel clock)
- **Resolution**: 640x480 @ 60Hz
- **Collision**: Pixel-perfect detection between goose sprite and obstacle sprites
- **Hardware Requirements**: TinyVGA PMOD for VGA output, two push buttons for input

### Testing

Run an interactive visual simulation with SDL2:
```bash
cd verilator
make
./goosegame
```

**Controls:**
- `SPACE` or `↑` = Jump
- `R` = Reset game
- `ESC` = Quit

For detailed information, see [docs/info.md](docs/info.md).

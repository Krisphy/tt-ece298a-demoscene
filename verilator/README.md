# Verilator Simulation for Goose Game

This directory contains Verilator-based simulations with SDL2 for real-time VGA display.

## Projects

1. **Goose Game** - Chrome Dino-style game with jumping goose and obstacles
2. **VGA Demo** - Simple animated color pattern demo

## Requirements

- Verilator (for Verilog simulation)
- SDL2 development libraries
- C++ compiler (g++)

### Installing Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get install verilator libsdl2-dev g++
```

**macOS:**
```bash
brew install verilator sdl2
```

**Arch Linux:**
```bash
sudo pacman -S verilator sdl2
```

## Building

**Build both projects:**
```bash
cd verilator
make
```

**Build only goose game:**
```bash
make goosegame
```

**Build only VGA demo:**
```bash
make vgademo
```

This will:
1. Run Verilator on all source files
2. Compile the generated C++ and testbench
3. Link with SDL2
4. Create the executables

## Running

**Run goose game:**
```bash
make run
# or
./goosegame
```

**Run VGA demo:**
```bash
make run-demo
# or
./vgademo
```

## Controls

- **SPACE** or **UP Arrow**: Jump
- **H**: Toggle Halt/Pause
- **ESC**: Quit

## How It Works

The testbench simulates the full hardware at 25 MHz clock speed:

1. **VGA Timing**: Generates 640x480 @ 60Hz VGA timing (800x525 total including blanking)
2. **Frame Rendering**: Clocks through 420,000 cycles per frame
3. **SDL Display**: Captures the 2-bit RGB output and displays in real-time
4. **Keyboard Input**: Maps keyboard to game controls (ui_in signals)

## Game Mechanics

- **Goose**: Green rectangle that jumps with parabolic arc
- **Obstacles**:
  - ION railway crossings (red rectangles)
  - UW emblem (blue square)
- **Scrolling**: World scrolls right-to-left with increasing speed
- **Collision**: Game ends when goose hits an obstacle (turns red)
- **Reset**: Press jump after game over to restart

## VGA Output Format

The design outputs 2-bit RGB on the TinyVGA PMOD pinout:
```
uo_out[7:0] = {HSync, B0, G0, R0, VSync, B1, G1, R1}
```

Each color channel has 2 bits, giving 64 possible colors (4 red × 4 green × 4 blue).

## Troubleshooting

**SDL2 not found:**
- Make sure SDL2 development libraries are installed
- On some systems, you may need to modify LDFLAGS in the Makefile

**Verilator warnings:**
- Width expansion/truncation warnings are suppressed with `-Wno-widthexpand -Wno-widthtrunc`
- These are expected due to bit manipulation in the rendering logic

**No display:**
- Check that SDL2 video backend is available
- Try running with `SDL_VIDEODRIVER=x11 ./goosegame` on Linux

## Clean Build

```bash
make clean
```

This removes all generated files and the executable.

<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

The Goose Game is a Chrome Dino-style endless runner game implemented in Verilog for VGA display. The game features a goose character that must jump over obstacles (ION railway crossings) that scroll across the screen. All of course to match the University of Waterloo theme. It outputs RGB222

### Architecture

The design consists of several key modules:

- **Game Controller** (`game_controller.v`): Manages game state, score tracking, collision detection, and game over logic
- **Jumping Module** (`jumping.v`): Handles the goose's vertical position and jump physics [TODO: add details about jump mechanics, gravity simulation, etc.]
- **Scrolling Module** (`scroll.v`): Controls horizontal obstacle movement and spawning [TODO: describe scroll speed, obstacle generation]
- **Rendering Module** (`rendering.v`): Generates pixel data for the goose, obstacles, ground, and score display
- **HVSync Generator** (`hvsync_generator.v`): Produces VGA timing signals (640x480 @ 60Hz)

### Game Mechanics

[TODO: Fill in specific details]
- Jump height: [X pixels]
- Jump duration: [X frames]
- Scroll speed: [X pixels per frame]
- Obstacle spacing: [random/fixed, X to Y pixels apart]
- Score increments: [every X obstacles cleared / time-based]

The game runs at 25 MHz (VGA pixel clock) with collision detection performed each frame. When the goose collides with an obstacle, the game enters a "game over" state where scrolling stops.

## How to test

### Required Setup

1. Connect a TinyVGA PMOD to the output pins (uo[7:0])
2. Connect the TinyVGA PMOD to a VGA monitor
3. [TODO: Add audio setup if implemented] Connect a speaker/audio output to uio[7] (PWM audio)
4. Connect push buttons to:
   - `ui[0]`: Jump button
   - `ui[1]`: Reset button

### Playing the Game

1. Power on the device - the game starts automatically
2. Press the jump button (`ui[0]`) to make the goose jump over obstacles
3. Press the reset button (`ui[1]`) to restart the game at any time
4. [TODO: Add details about:]
   - Game speed progression (does it get faster?)

### Testing in Simulation

The project includes a testbench (`test/tb.v` and `test/test.py`) that simulates button presses and verifies:
- VGA sync signal generation
- Jump mechanics
- Collision detection
- [TODO: Add other test scenarios]

Run tests with:
```bash
cd test
make
```

### Verilator Simulation

A Verilator-based simulation is also available for visual testing:
```bash
cd verilator
make
./goosegame
```

## External hardware

- **TinyVGA PMOD**: Required for VGA output (connects to uo[7:0])
  - Provides 2-bit color depth (8 colors)
  - Outputs 640x480 @ 60Hz video
- **VGA Monitor**: Standard VGA display
- **Push Buttons**: Two buttons for jump and reset controls (connected to ui[0] and ui[1])
- **Speaker** (optional): For audio output via PWM on uio[7] [TODO: confirm if audio is implemented]

### Pin Mapping

**Inputs:**
- `ui[0]`: Jump button (bt1)
- `ui[1]`: Reset button (rst)

**Outputs (TinyVGA PMOD format, RGB222):**
- `uo[0]`: R1
- `uo[1]`: G1
- `uo[2]`: B1
- `uo[3]`: VSync
- `uo[4]`: R0
- `uo[5]`: G0
- `uo[6]`: B0
- `uo[7]`: HSync

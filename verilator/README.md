# Verilator Simulation

This directory contains a Verilator-based simulation environment for the Goose Game that displays the VGA output using SDL2.

## Building

### Requirements
- Verilator
- SDL2 development libraries
- C++ compiler (g++)

### Build the simulation
```bash
make
```

This will:
1. Run Verilator to generate C++ model from Verilog sources
2. Compile the C++ testbench with SDL2
3. Create the `goosegame` executable

## Running

```bash
./goosegame
```

Or build and run in one step:
```bash
make run
```

The simulation will open an SDL2 window displaying the VGA output at 640x480 resolution.

## Make Targets

```bash
make            # Build the goosegame executable (default)
make all        # Same as make
make clean      # Remove all build artifacts and generated files
make run        # Build and run the simulation
```

## Controls

**All game builds:**
- `SPACE` or `↑` = Jump
- `R` = Reset
- `ESC` = Quit

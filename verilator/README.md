# Verilator Build Targets

## Goose Game Targets

### `make goosegame`
Builds the game **without audio**.
- No audio processing
- Good for testing game logic and visuals
```bash
make goosegame
./goosegame
```

### `make goosegame-audio`
Builds the game **with audio playback**.
- Real-time audio playback via SDL2
```bash
make goosegame-audio
./goosegame-audio
```

## Audio Test Targets

### `make audiotest-play`
Tests audio module with **real-time playback** via SDL2.
- Plays audio as simulation runs
- For interactive audio testing
```bash
make audiotest-play
./audiotest-play
```

### `make audiotest-wav`
Tests audio module and **generates WAV files**.
- Creates separate WAV files for each sound effect
- No real-time playback
- For offline audio analysis
```bash
make audiotest-wav
./audiotest-wav
# Creates: audio_jump.wav, audio_death.wav, audio_highscore.wav
```

## VGA Demo Target

### `make vgademo`
Simple VGA color pattern demo (no game logic).
```bash
make vgademo
./vgademo
```

## Convenience Targets

```bash
make all            # Build all targets (default)
make clean          # Remove all build artifacts

make run            # Build and run goosegame (no audio)
make run-audio      # Build and run goosegame-audio
make run-demo       # Build and run vgademo
make run-audiotest-play    # Build and run audiotest-play
make run-audiotest-wav     # Build and run audiotest-wav
```

## Controls

**All game builds:**
- `SPACE` or `↑` = Jump
- `R` = Reset
- `ESC` = Quit

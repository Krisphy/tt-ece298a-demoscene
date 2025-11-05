#include <stdint.h>
#include "Vtt_um_goose_game.h"
#include "Vtt_um_goose_game__Syms.h"
#include "verilated.h"
#include <SDL2/SDL.h>
#include <unistd.h>

// Standard VGA 640x480 timing
#define H_TOTAL 800
#define H_DISPLAY 640
#define V_TOTAL 525
#define V_DISPLAY 480


static inline uint32_t expand_2bit(uint32_t x) {
  // Expand 2-bit color to 8-bit
  // 00 -> 00000000 (0)
  // 01 -> 01010101 (85)
  // 10 -> 10101010 (170)
  // 11 -> 11111111 (255)
  return (x << 6) | (x << 4) | (x << 2) | x;
}

#ifdef WITH_AUDIO
// Audio sample buffer (ring buffer)
#define AUDIO_BUFFER_SIZE 2048  // ~42ms buffer at 48.8kHz
uint16_t audio_buffer[AUDIO_BUFFER_SIZE];
volatile int audio_write_pos = 0;
volatile int audio_read_pos = 0;

// Initialize buffer with silence
void init_audio_buffer() {
  for (int i = 0; i < AUDIO_BUFFER_SIZE; i++) {
    audio_buffer[i] = 0x8000;  // Silence in unsigned 16-bit
  }
}

// SDL audio callback - reads from pre-generated buffer
void audio_callback(void* userdata, uint8_t* stream, int len) {
  uint16_t *stream16 = (uint16_t*) stream;
  
  // Read samples from buffer
  for (int i = 0; i < len/2; i++) {
    if (audio_read_pos != audio_write_pos) {
      stream16[i] = audio_buffer[audio_read_pos];
      audio_read_pos = (audio_read_pos + 1) % AUDIO_BUFFER_SIZE;
    } else {
      // Buffer underrun - output silence
      stream16[i] = 0x8000;
    }
  }
}
#endif

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  Vtt_um_goose_game* top = new Vtt_um_goose_game;

  // Set default inputs
  top->ui_in = 0;
  top->uio_in = 0;
  top->ena = 1;
  
  // Reset (active low)
  top->rst_n = 0;
  top->clk = 0; top->eval(); 
  top->clk = 1; top->eval();
  top->rst_n = 1;
  top->clk = 0; top->eval();
  
#ifdef WITH_AUDIO
  // Initialize audio buffer with silence
  init_audio_buffer();
#endif
  
  // Run one warmup frame to synchronize VGA counters
  for(int warmup = 0; warmup < H_TOTAL * V_TOTAL; warmup++) {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
  }

  // Initialize SDL
#ifdef WITH_AUDIO
  if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
    SDL_Log("Failed to initialize SDL: %s", SDL_GetError());
    return 1;
  }
  SDL_Log("Running with audio playback and event logging enabled");
#else
  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    SDL_Log("Failed to initialize SDL: %s", SDL_GetError());
    return 1;
  }
#endif
  
  SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");

  // Create window
#ifdef WITH_AUDIO
  SDL_Window* window = SDL_CreateWindow("Goose Game (with Audio) - Jump with SPACE",
#else
  SDL_Window* window = SDL_CreateWindow("Goose Game - Jump with SPACE",
#endif 
                                        SDL_WINDOWPOS_UNDEFINED, 
                                        SDL_WINDOWPOS_UNDEFINED, 
                                        H_DISPLAY, V_DISPLAY, 0);
  if (window == nullptr) {
    SDL_Log("Failed to create window: %s", SDL_GetError());
    SDL_Quit();
    return 1;
  }

  // Create renderer
  SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
  if (renderer == nullptr) {
    SDL_Log("Failed to create renderer: %s", SDL_GetError());
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
  }

  // Create texture
  SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, 
                                           SDL_TEXTUREACCESS_STREAMING, 
                                           H_DISPLAY, V_DISPLAY);
  if (texture == nullptr) {
    SDL_Log("Failed to create texture: %s", SDL_GetError());
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
  }

#ifdef WITH_AUDIO
  // Setup audio device
  SDL_AudioSpec desiredSpec, obtainedSpec;
  desiredSpec.freq = 48000;  // Target 48kHz sample rate
  desiredSpec.format = AUDIO_U16;
  desiredSpec.channels = 1;
  desiredSpec.samples = 2048;
  desiredSpec.callback = audio_callback;
  desiredSpec.userdata = (void*) top;

  SDL_AudioDeviceID audioDevice = SDL_OpenAudioDevice(NULL, 0, &desiredSpec, &obtainedSpec, 0);
  if (audioDevice == 0) {
    SDL_Log("Failed to open audio device: %s", SDL_GetError());
    SDL_Log("Continuing without audio...");
  } else {
    SDL_Log("Audio opened: %d Hz, %d channels, %d samples buffer", 
            obtainedSpec.freq, obtainedSpec.channels, obtainedSpec.samples);
    // Start audio playback
    SDL_PauseAudioDevice(audioDevice, 0);
  }
#else
  SDL_AudioDeviceID audioDevice = 0;  // Dummy for cleanup
#endif

  SDL_Log("Controls: SPACE/UP = Jump, H = Halt/Pause, ESC = Quit");

  // Main loop
  bool quit = false;
  uint8_t jump_button = 0;
  uint8_t jump_button_held = 0;
  uint8_t halt_button = 0;
  bool last_jump_state = false;
  int jump_pulse_counter = 0;
  
  while (!quit) {
    // Handle events
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
      if (event.type == SDL_QUIT) {
        quit = true;
      }
      else if (event.type == SDL_KEYDOWN) {
        switch (event.key.keysym.sym) {
          case SDLK_ESCAPE:
            quit = true;
            break;
          case SDLK_SPACE:
          case SDLK_UP:
            jump_button_held = 1;
            break;
          case SDLK_h:
            halt_button = !halt_button;  // Toggle halt
            break;
        }
      }
      else if (event.type == SDL_KEYUP) {
        switch (event.key.keysym.sym) {
          case SDLK_SPACE:
          case SDLK_UP:
            jump_button_held = 0;
            break;
        }
      }
    }

    // Generate short pulse from button press (hardware has pulse stretching too)
    if (jump_button_held && !last_jump_state) {
      jump_pulse_counter = 1000;  // ~40us pulse at 25MHz
    }
    jump_button = (jump_pulse_counter > 0) ? 1 : 0;
    last_jump_state = jump_button_held;
    
    // Set input signals
    top->ui_in = (halt_button << 1) | jump_button;

    // Get framebuffer pointer
    uint32_t* pixels;
    int pitch;
    if (SDL_LockTexture(texture, nullptr, (void**)&pixels, &pitch) != 0) {
      SDL_Log("Failed to lock texture: %s", SDL_GetError());
      break;
    }

    // Render one frame
    int k = 0;
    for(int v = 0; v < V_TOTAL; v++) {
      for(int h = 0; h < H_TOTAL; h++) {
        // Clock the system
        top->clk = 0; top->eval(); 
        top->clk = 1; top->eval();
        
        // Decrement jump pulse counter
        if (jump_pulse_counter > 0) {
          jump_pulse_counter--;
          if (jump_pulse_counter == 0) {
            top->ui_in = (halt_button << 1) | 0;
          }
        }
        
#ifdef WITH_AUDIO
        // Capture audio samples when new_sample signal is high
        if (top->rootp->tt_um_goose_game__DOT__audio_ctrl__DOT__new_sample) {
          // Read the audio sample (convert signed to unsigned for SDL)
          int16_t signed_sample = top->rootp->tt_um_goose_game__DOT__audio_ctrl__DOT__audio_sample_reg;
          uint16_t sample = signed_sample ^ 0x8000;  // Convert to unsigned
          
          int next_write = (audio_write_pos + 1) % AUDIO_BUFFER_SIZE;
          if (next_write != audio_read_pos) {  // Don't overwrite if buffer is full
            audio_buffer[audio_write_pos] = sample;
            audio_write_pos = next_write;
          }
        }
#endif
        
        // Sample outputs in visible area
        if (v < V_DISPLAY && h < H_DISPLAY) {
          // Extract 2-bit RGB from uo_out: {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
          // Bit mapping: uo_out[7:0] = {HSync, B0, G0, R0, VSync, B1, G1, R1}
          uint8_t r = ((top->uo_out & 0x01) << 1) | ((top->uo_out & 0x08) >> 3);  // R1, R0
          uint8_t g = ((top->uo_out & 0x02) << 0) | ((top->uo_out & 0x10) >> 4);  // G1, G0
          uint8_t b = ((top->uo_out & 0x04) >> 1) | ((top->uo_out & 0x20) >> 5);  // B1, B0
          
          uint32_t color = 0xFF000000 | 
                          (expand_2bit(r) << 16) | 
                          (expand_2bit(g) << 8) | 
                          expand_2bit(b);
          pixels[k++] = color;
        }
      }
    }
    
    SDL_UnlockTexture(texture);
    SDL_RenderCopy(renderer, texture, nullptr, nullptr);
    SDL_RenderPresent(renderer);
  }

  // Cleanup
#ifdef WITH_AUDIO
  if (audioDevice != 0) {
    SDL_CloseAudioDevice(audioDevice);
  }
#endif
  SDL_DestroyTexture(texture);
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit();
  
  delete top;

  return 0;
}


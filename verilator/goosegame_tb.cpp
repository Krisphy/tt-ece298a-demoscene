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

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  Vtt_um_goose_game* top = new Vtt_um_goose_game;

  // Set default inputs (buttons active-low, so default high = not pressed)
  top->ui_in = 0xFF;
  top->uio_in = 0;
  top->ena = 1;
  
  // Reset (active low)
  top->rst_n = 0;
  top->clk = 0; top->eval(); 
  top->clk = 1; top->eval();
  top->rst_n = 1;
  top->clk = 0; top->eval();
  
  // Run one warmup frame to synchronize VGA counters
  for(int warmup = 0; warmup < H_TOTAL * V_TOTAL; warmup++) {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
  }

  // Initialize SDL
  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    SDL_Log("Failed to initialize SDL: %s", SDL_GetError());
    return 1;
  }
  
  SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");

  // Create window
  SDL_Window* window = SDL_CreateWindow("Goose Game - Jump with SPACE",
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

  SDL_Log("Controls: SPACE/UP = Jump, R = Reset, ESC = Quit");

  // Main loop
  bool quit = false;
  uint8_t jump_held = 0;
  uint8_t reset_held = 0;
  
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
            jump_held = 1;
            break;
          case SDLK_r:
            reset_held = 1;
            break;
        }
      }
      else if (event.type == SDL_KEYUP) {
        switch (event.key.keysym.sym) {
          case SDLK_SPACE:
          case SDLK_UP:
            jump_held = 0;
            break;
          case SDLK_r:
            reset_held = 0;
            break;
        }
      }
    }

    // Pass raw button state directly (active-low: 0 = pressed, 1 = not pressed)
    uint8_t jump_low = jump_held ? 0 : 1;
    uint8_t reset_low = reset_held ? 0 : 1;
    top->ui_in = 0xFC | (reset_low << 1) | jump_low;

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
  SDL_DestroyTexture(texture);
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit();
  
  delete top;

  return 0;
}


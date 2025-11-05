#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include "Vaudio.h"
#include "Vaudio__Syms.h"
#include "verilated.h"
#include <SDL2/SDL.h>

uint64_t samples_generated = 0;
int current_test = 0;
uint64_t test_start_time = 0;

// SDL audio callback - runs in a separate thread
void audio_callback(void* userdata, uint8_t* stream, int len) {
  Vaudio* top = (Vaudio*) userdata;

  uint16_t *stream16 = (uint16_t*) stream;
  
  // Generate audio samples
  for (int i = 0; i < len/2; i++) {
    // Force new sample generation by setting sample_div near rollover
    top->rootp->audio__DOT__sample_div = 1023;
    
    // Clock the audio module
    top->clk = 0; top->eval(); 
    top->clk = 1; top->eval();
    
    // Read the 16-bit signed audio sample and convert to unsigned for SDL
    int16_t signed_sample = top->audio_sample;
    uint16_t unsigned_sample = (uint16_t)(signed_sample + 32768);
    
    stream16[i] = unsigned_sample;
  }
  
  samples_generated += len / 2;
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  Vaudio* top = new Vaudio;

  // Reset the audio module
  top->rst_n = 0;
  top->event_jump = 0;
  top->event_death = 0;
  top->event_highscore = 0;
  top->game_running = 1;
  top->clk = 0; top->eval(); 
  top->clk = 1; top->eval();
  top->rst_n = 1;

  SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");

  // Initialize SDL audio
  if (SDL_Init(SDL_INIT_AUDIO) < 0) {
    printf("SDL audio initialization failed: %s\n", SDL_GetError());
    return 1;
  }

  SDL_AudioSpec desiredSpec, obtainedSpec;
  desiredSpec.freq = 48000;
  desiredSpec.format = AUDIO_U16;
  desiredSpec.channels = 1;
  desiredSpec.samples = 2048;
  desiredSpec.callback = audio_callback;
  desiredSpec.userdata = (void*) top;

  SDL_AudioDeviceID audioDevice = SDL_OpenAudioDevice(NULL, 0, &desiredSpec, &obtainedSpec, 0);
  if (audioDevice == 0) {
    printf("Failed to open audio device: %s\n", SDL_GetError());
    SDL_Quit();
    return 1;
  }

  // Start audio playback
  SDL_PauseAudioDevice(audioDevice, 0);

  test_start_time = samples_generated;
  current_test = 0;

  printf("\n=== Audio Test Starting ===\n");
  printf("Playing sound effects with 1 second breaks...\n\n");
  printf("Playing jump sound\n");
  fflush(stdout);

  // Play 3 sound effects with 1 second breaks
  // 0: Jump, 1: Silence, 2: Death, 3: Silence, 4: High Score, 5: Done
  while (current_test < 5) {
    const uint64_t SOUND_DURATION = 48000 * 3;  // 3 seconds for each sound to fully play
    const uint64_t BREAK_DURATION = 48000 * 1;  // 1 second break
    
    uint64_t duration = (current_test % 2 == 0) ? SOUND_DURATION : BREAK_DURATION;
    
    if (samples_generated - test_start_time > duration) {
      current_test++;
      test_start_time = samples_generated;
      
      // Print what sound we're about to play
      switch (current_test) {
        case 0:
          printf("Playing jump sound\n");
          break;
        case 1:
          printf("1 second silence\n");
          break;
        case 2:
          printf("Playing death sound\n");
          break;
        case 3:
          printf("1 second silence\n");
          break;
        case 4:
          printf("Playing high score sound\n");
          break;
        case 5:
          printf("\nAudio test complete\n");
          break;
      }
      fflush(stdout);
    }

    // Trigger each sound effect with a single brief pulse at the start
    // The audio module will play the complete sound once
    uint64_t sample_in_test = samples_generated - test_start_time;
    
    // Reset all events first
    top->event_jump = 0;
    top->event_death = 0;
    top->event_highscore = 0;
    
    // Only trigger on the first few samples (brief pulse)
    if (sample_in_test < 10) {
      switch (current_test) {
        case 0: // Jump sound
          top->event_jump = 1;
          break;
          
        case 2: // Death sound
          top->event_death = 1;
          break;
          
        case 4: // High score sound
          top->event_highscore = 1;
          break;
      }
    }
    
    usleep(50000);  // Sleep 50ms
  }

  // Close audio device and quit SDL
  SDL_CloseAudioDevice(audioDevice);
  SDL_Quit();
  
  delete top;
  
  return 0;
}


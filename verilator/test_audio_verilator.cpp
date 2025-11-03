#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

#include "Vaudio.h"
#include "Vaudio__Syms.h"
#include "verilated.h"

// Simple WAV file writer (no external dependencies)
void write_wav_header(FILE* f, uint32_t sample_rate, uint32_t num_samples) {
  // WAV header
  fwrite("RIFF", 1, 4, f);
  uint32_t file_size = 36 + num_samples * 2;  // 36 bytes header + 2 bytes per sample
  fwrite(&file_size, 4, 1, f);
  fwrite("WAVE", 1, 4, f);
  fwrite("fmt ", 1, 4, f);
  uint32_t fmt_size = 16;
  fwrite(&fmt_size, 4, 1, f);
  uint16_t audio_format = 1;  // PCM
  fwrite(&audio_format, 2, 1, f);
  uint16_t num_channels = 1;  // Mono
  fwrite(&num_channels, 2, 1, f);
  fwrite(&sample_rate, 4, 1, f);
  uint32_t byte_rate = sample_rate * 2;  // sample_rate * channels * 2 bytes
  fwrite(&byte_rate, 4, 1, f);
  uint16_t block_align = 2;  // channels * 2 bytes
  fwrite(&block_align, 2, 1, f);
  uint16_t bits_per_sample = 16;
  fwrite(&bits_per_sample, 2, 1, f);
  fwrite("data", 1, 4, f);
  uint32_t data_size = num_samples * 2;
  fwrite(&data_size, 4, 1, f);
}

// Generate a single audio sample by running normal clock cycles
// Sample when new_sample naturally becomes true (one cycle after sample_div wraps)
int16_t generate_sample(Vaudio* top) {
  // Run clock cycles until we get a new sample
  // new_sample is registered, so it becomes 1 one cycle after sample_div >= 1023
  int16_t sample = 0;
  int waited = 0;
  
  // Run until sample_div wraps and new_sample becomes true
  // We need to wait until sample_div naturally reaches 1023
  while (waited < 1024) {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
    
    // Check if new_sample is true (this happens one cycle after sample_div >= 1023)
    if (top->rootp->audio__DOT__new_sample) {
      // Read the audio sample (already signed 16-bit)
      sample = top->audio_sample;
      break;
    }
    waited++;
  }
  
  // If we didn't get a sample, force one by setting sample_div near wrap
  if (waited >= 1024) {
    // Force sample_div to 1022, then clock twice
    top->rootp->audio__DOT__sample_div = 1022;
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();  // sample_div becomes 1023, new_sample stays 0
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();  // sample_div becomes 0, new_sample becomes 1
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();  // Now audio_sample_reg updates
    
    sample = top->audio_sample;
  }
  
  return sample;
}

void generate_samples(Vaudio* top, int16_t* samples, int num_samples) {
  for (int i = 0; i < num_samples; i++) {
    samples[i] = generate_sample(top);
  }
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  Vaudio* top = new Vaudio;

  // Initialize reset
  top->rst_n = 0;
  top->clk = 0; top->eval();
  top->clk = 1; top->eval();
  
  // Release reset
  top->rst_n = 1;
  top->event_jump = 0;
  top->event_death = 0;
  top->event_highscore = 0;
  top->game_running = 0;
  
  // Run a few clocks to stabilize
  for (int i = 0; i < 10; i++) {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
  }

  const uint32_t sample_rate = 46875;  // 50MHz / 1024 ≈ 46875 Hz

  printf("Audio test - generating sounds...\n\n");

  // 1. Jump sound (120ms + 50ms padding = 170ms)
  printf("1. Generating jump sound...\n");
  top->game_running = 1;
  
  // Let game_running propagate through a few clocks
  for (int i = 0; i < 5; i++) {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
  }
  
  top->event_jump = 1;
  
  // Generate first sample with event high (so module sees it when new_sample=1)
  const int jump_samples = (int)(sample_rate * 0.170f);  // 120ms sound + 50ms padding
  int16_t* samples = new int16_t[jump_samples];
  
  // Generate first sample (event will be captured, but sfx_type won't update until next clock)
  samples[0] = generate_sample(top);
  
  // Generate second sample (now sfx_type should be active and sound starts)
  samples[1] = generate_sample(top);
  
  // Now clear event for remaining samples
  top->event_jump = 0;
  
  // Generate rest of the samples
  for (int i = 2; i < jump_samples; i++) {
    samples[i] = generate_sample(top);
  }
  
  FILE* f = fopen("audio_jump.wav", "wb");
  write_wav_header(f, sample_rate, jump_samples);
  fwrite(samples, 2, jump_samples, f);
  fclose(f);
  printf("   Saved to audio_jump.wav\n\n");

  // Reset
  top->rst_n = 0;
  top->clk = 0; top->eval();
  top->clk = 1; top->eval();
  top->rst_n = 1;
  top->game_running = 0;
  top->event_jump = 0;
  top->event_death = 0;
  top->event_highscore = 0;
  
  for (int i = 0; i < 10; i++) {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
  }

  // 2. Death sound (250ms + 50ms padding = 300ms)
  printf("2. Generating death sound...\n");
  top->game_running = 1;
  top->event_death = 1;
  
  const int death_samples = (int)(sample_rate * 0.300f);  // 250ms sound + 50ms padding
  delete[] samples;
  samples = new int16_t[death_samples];
  
  // Generate first two samples (event captured, then sound starts)
  samples[0] = generate_sample(top);
  samples[1] = generate_sample(top);
  
  // Clear event for remaining samples
  top->event_death = 0;
  
  // Generate rest of the samples
  for (int i = 2; i < death_samples; i++) {
    samples[i] = generate_sample(top);
  }
  
  f = fopen("audio_death.wav", "wb");
  write_wav_header(f, sample_rate, death_samples);
  fwrite(samples, 2, death_samples, f);
  fclose(f);
  printf("   Saved to audio_death.wav\n\n");

  // Reset
  top->rst_n = 0;
  top->clk = 0; top->eval();
  top->clk = 1; top->eval();
  top->rst_n = 1;
  top->game_running = 0;
  top->event_jump = 0;
  top->event_death = 0;
  top->event_highscore = 0;
  
  for (int i = 0; i < 10; i++) {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
  }

  // 3. High score sound (280ms + 50ms padding = 330ms)
  printf("3. Generating high score sound...\n");
  top->game_running = 1;
  top->event_highscore = 1;
  
  const int high_samples = (int)(sample_rate * 0.330f);  // 280ms sound + 50ms padding
  delete[] samples;
  samples = new int16_t[high_samples];
  
  // Generate first two samples (event captured, then sound starts)
  samples[0] = generate_sample(top);
  samples[1] = generate_sample(top);
  
  // Clear event for remaining samples
  top->event_highscore = 0;
  
  // Generate rest of the samples
  for (int i = 2; i < high_samples; i++) {
    samples[i] = generate_sample(top);
  }
  
  f = fopen("audio_highscore.wav", "wb");
  write_wav_header(f, sample_rate, high_samples);
  fwrite(samples, 2, high_samples, f);
  fclose(f);
  printf("   Saved to audio_highscore.wav\n\n");

  delete[] samples;
  top->final();
  delete top;

  printf("Done! Play files with:\n");
  printf("  macOS:   afplay audio_*.wav\n");
  printf("  Linux:   aplay audio_*.wav\n");

  return 0;
}

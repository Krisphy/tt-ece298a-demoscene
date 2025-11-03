/*
 * Improved Audio Module with Sigma-Delta Modulation
 * 
 * Uses sigma-delta modulation for high-quality 1-bit audio output.
 * Generates samples at ~48kHz (downsampled from 50MHz clock).
 * 
 * Inputs from Game Controller:
 * - event_jump: pulse when jump happens
 * - event_death: pulse when collision/death
 * - event_highscore: pulse when new high score
 * - game_running: high during gameplay
 * 
 * Output:
 * - audio_pwm: Sigma-delta modulated signal for uio[7] (A_PWM)
 * - audio_sample: 16-bit signed audio sample for testbenches
 */

`default_nettype none

module audio (
    input  wire        clk,
    input  wire        rst_n,
    
    // game events
    input  wire        event_jump,
    input  wire        event_death,
    input  wire        event_highscore,
    input  wire        game_running,
    
    // audio output
    output reg         audio_pwm,
    output wire signed [15:0] audio_sample
);

  // 50MHz / 1024 ≈ 48.8kHz sample rate
  reg [9:0] sample_div;
  reg new_sample;
  
  reg [15:0] sfx_counter;
  reg [2:0]  sfx_type;         // 0=idle, 1=jump, 2=death, 3=highscore
  reg [31:0] sfx_phase;
  reg [31:0] sfx_step;
  reg signed [31:0] sfx_step_delta;
  reg [2:0]  high_note_idx;
  
  // phase step = freq_hz * 89478485 (2^32/48000)
  parameter JUMP_START_FREQ = 32'd53687091;   // 600 Hz
  parameter JUMP_END_FREQ   = 32'd107374182;  // 1200 Hz
  parameter DEATH_START_FREQ = 32'd35791394;  // 400 Hz
  parameter DEATH_END_FREQ   = 32'd7158279;   // 80 Hz
  parameter HIGH_NOTE1_FREQ = 32'd46787226;   // 523 Hz (C5)
  parameter HIGH_NOTE2_FREQ = 32'd58953527;   // 659 Hz (E5)
  parameter HIGH_NOTE3_FREQ = 32'd70138929;   // 784 Hz (G5)
  
  // duration in samples (ms * 48)
  parameter JUMP_TIME  = 16'd5760;
  parameter DEATH_TIME = 16'd12000;
  parameter HIGH_NOTE1_TIME = 16'd3360;
  parameter HIGH_NOTE2_TIME = 16'd3360;
  parameter HIGH_NOTE3_TIME = 16'd6720;
  
  // sweep rate = (end_freq - start_freq) / duration
  parameter JUMP_SWEEP_DELTA = 32'd9316;
  parameter DEATH_SWEEP_DELTA = -32'd2386;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sfx_counter <= 16'd0;
      sfx_type <= 3'd0;
      sfx_phase <= 32'd0;
      sfx_step <= 32'd0;
      sfx_step_delta <= 32'd0;
      high_note_idx <= 3'd0;
    end else if (new_sample) begin
      if (sfx_type == 0) begin
        // priority: death > highscore > jump
        if (event_death) begin
          sfx_type <= 3'd2;
          sfx_counter <= DEATH_TIME;
          sfx_phase <= 32'd0;
          sfx_step <= DEATH_START_FREQ;
          sfx_step_delta <= DEATH_SWEEP_DELTA;
        end else if (event_highscore) begin
          sfx_type <= 3'd3;
          sfx_counter <= HIGH_NOTE1_TIME;
          sfx_phase <= 32'd0;
          sfx_step <= HIGH_NOTE1_FREQ;
          sfx_step_delta <= 32'd0;
          high_note_idx <= 3'd0;
        end else if (event_jump) begin
          sfx_type <= 3'd1;
          sfx_counter <= JUMP_TIME;
          sfx_phase <= 32'd0;
          sfx_step <= JUMP_START_FREQ;
          sfx_step_delta <= JUMP_SWEEP_DELTA;
        end
      end else begin
        sfx_phase <= sfx_phase + sfx_step;
        
        if (sfx_type == 1 || sfx_type == 2) begin
          sfx_step <= sfx_step + sfx_step_delta;
          if (sfx_counter > 0) begin
            sfx_counter <= sfx_counter - 1;
          end else begin
            sfx_type <= 3'd0;
          end
        end else begin
          if (sfx_counter > 0) begin
            sfx_counter <= sfx_counter - 1;
          end else begin
            if (high_note_idx == 3'd0) begin
              high_note_idx <= 3'd1;
              sfx_counter <= HIGH_NOTE2_TIME;
              sfx_phase <= 32'd0;
              sfx_step <= HIGH_NOTE2_FREQ;
            end else if (high_note_idx == 3'd1) begin
              high_note_idx <= 3'd2;
              sfx_counter <= HIGH_NOTE3_TIME;
              sfx_phase <= 32'd0;
              sfx_step <= HIGH_NOTE3_FREQ;
            end else begin
              sfx_type <= 3'd0;
            end
          end
        end
      end
    end
  end
  
  reg signed [15:0] audio_sample_reg;
  reg signed [15:0] envelope;
  wire [15:0] env_raw;
  reg [15:0] envelope_threshold;
  
  assign env_raw = sfx_counter >> 4;
  assign audio_sample = audio_sample_reg;
  
  parameter AMPLITUDE_SHIFT = 4;
  
  always @(*) begin
    case (sfx_type)
      3'd1: envelope_threshold = 16'd900;
      3'd2: envelope_threshold = 16'd1200;
      3'd3: envelope_threshold = 16'd600;
      default: envelope_threshold = 16'd0;
    endcase
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      audio_sample_reg <= 16'sd0;
      envelope <= 16'sd0;
    end else if (new_sample) begin
      if (sfx_type != 0) begin
        envelope <= (env_raw > envelope_threshold) ? envelope_threshold : env_raw;
        audio_sample_reg <= sfx_phase[31] ? (envelope << AMPLITUDE_SHIFT) 
                                          : -(envelope << AMPLITUDE_SHIFT);
      end else begin
        audio_sample_reg <= 16'sd0;
      end
    end
  end
  
  // xor with 0x8000 converts signed to unsigned for sigma-delta
  wire [15:0] audio_sample_unsigned = audio_sample_reg ^ 16'h8000;
  
  reg signed [16:0] sigma_delta_accum;
  wire signed [16:0] sigma_delta_next = sigma_delta_accum + {1'b0, audio_sample_unsigned};
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sample_div <= 10'd0;
      new_sample <= 1'b0;
      sigma_delta_accum <= 17'sd0;
      audio_pwm <= 1'b0;
    end else begin
      if (sample_div >= 10'd1023) begin
        sample_div <= 10'd0;
        new_sample <= 1'b1;
      end else begin
        sample_div <= sample_div + 10'd1;
        new_sample <= 1'b0;
      end
      
      sigma_delta_accum <= sigma_delta_next;
      audio_pwm <= sigma_delta_accum[16];
    end
  end
  
endmodule

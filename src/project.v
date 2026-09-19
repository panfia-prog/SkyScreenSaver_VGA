/*
 * Tiny Tapeout VGA: Day-Night Cycle Graphics Generator (1x1 Tile & Lint-Clean Fit)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_panfia_skyscreensaver (
    input  wire [7:0] ui_in,    // ui_in[7:1]: Manual Time/Phase Control
    output wire [7:0] uo_out,   // TinyVGA outputs: {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // Unused IO outputs
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // Always 1
    input  wire       clk,      // 24 MHz clock
    input  wire       rst_n     // Active-low reset
);

    // ------------------------------------------------------------------------
    // 1. VGA TIMING & FRAME COUNTER
    // ------------------------------------------------------------------------
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;

    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // 8-bit Frame Counter for animations and day-night transition speed
    reg [7:0] frame_count;
    always @(posedge vsync or negedge rst_n) begin
        if (~rst_n) frame_count <= 8'd0;
        else        frame_count <= frame_count + 1'b1;
    end

    assign uio_oe  = 8'h00;
    assign uio_out = 8'h00;

    // ------------------------------------------------------------------------
    // 2. DAY-NIGHT TIME TRACKER
    // ------------------------------------------------------------------------
    // Use ui_in[7:6] if high for manual override, otherwise run automatic cycle
    reg [5:0] cycle_timer;
    always @(posedge vsync or negedge rst_n) begin
        if (~rst_n) begin
            cycle_timer <= 6'd0;
        end else if (frame_count == 8'd255) begin
            cycle_timer <= cycle_timer + 1'b1;
        end
    end

    // Is it Night Time?
    wire is_night = ui_in[7] ? ui_in[6] : cycle_timer[5];

    // ------------------------------------------------------------------------
    // 3. LOW-GATE PARALLAX BACKGROUND
    // ------------------------------------------------------------------------
    wire scroll_y_bit6 = pix_y[6] + frame_count[6]; 
    wire bg_pattern_a  = (scroll_y_bit6 ^ pix_x[6]) & (pix_y[0] ^ pix_x[0]);
    wire bg_pattern_b  = (pix_y[5] ^ pix_x[5]) & (pix_y[1] ^ pix_x[1]);

    reg [1:0] bg_R, bg_G, bg_B;
    always @(*) begin
        if (is_night) begin
            // Night Palette
            if (bg_pattern_a)      {bg_R, bg_G, bg_B} = 6'b00_01_10; // Slate Blue
            else if (bg_pattern_b) {bg_R, bg_G, bg_B} = 6'b00_00_10; // Dark Blue
            else                {bg_R, bg_G, bg_B} = 6'b00_00_01; // Midnight Blue
        end else begin
            // Day Palette
            if (bg_pattern_a)      {bg_R, bg_G, bg_B} = 6'b10_11_11; // Soft Cyan Sky
            else if (bg_pattern_b) {bg_R, bg_G, bg_B} = 6'b01_10_11; // Sky Blue
            else                {bg_R, bg_G, bg_B} = 6'b01_01_11; // Deep Horizon
        end
    end

    // ------------------------------------------------------------------------
    // 4. CELESTIAL BODY RENDERER (Sun / Moon)
    // ------------------------------------------------------------------------
    wire in_orb_box = (pix_x >= 256 && pix_x < 384) && (pix_y >= 176 && pix_y < 304);
    
    // Octagonal clipping (prevents square edges)
    wire [3:0] rel_x_hi = pix_x[6:3];
    wire [3:0] rel_y_hi = pix_y[6:3];
    wire corner_clip    = (rel_x_hi[3] == rel_y_hi[3]) && (rel_x_hi[2:0] + rel_y_hi[2:0] < 3);

    wire is_orb_shape = in_orb_box && !corner_clip;

    // Moon Crescent cutout
    wire phase_right  = pix_x >= 320;
    wire is_lit_celestial = is_night ? (is_orb_shape && phase_right) : is_orb_shape;

    // ------------------------------------------------------------------------
    // 5. UNROLLED 2-STAR / CLOUD REGISTER ENGINE
    // ------------------------------------------------------------------------
    reg [15:0] lfsr;
    reg [9:0]  particle_pos_0,  particle_pos_1;
    reg [2:0]  particle_life_0, particle_life_1;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            lfsr            <= 16'hACE1;
            particle_pos_0  <= 10'd0;
            particle_pos_1  <= 10'd0;
            particle_life_0 <= 3'd0;
            particle_life_1 <= 3'd0;
        end else begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13]};

            if (pix_x == 10'd0 && pix_y == 10'd0) begin
                // Slot 0 update
                if (particle_life_0 == 3'd0 && lfsr[0]) begin
                    particle_pos_0  <= lfsr[9:0];
                    particle_life_0 <= 3'd7;
                end else if (particle_life_0 > 3'd0) begin
                    particle_life_0 <= particle_life_0 - 1'b1;
                end

                // Slot 1 update
                if (particle_life_1 == 3'd0 && !lfsr[0]) begin
                    particle_pos_1  <= lfsr[15:6];
                    particle_life_1 <= 3'd7;
                end else if (particle_life_1 > 3'd0) begin
                    particle_life_1 <= particle_life_1 - 1'b1;
                end
            end
        end
    end

    wire [9:0] curr_cell = {pix_y[8:4], pix_x[8:4]};
    wire is_particle = ((particle_life_0 > 0 && particle_pos_0 == curr_cell) ||
                        (particle_life_1 > 0 && particle_pos_1 == curr_cell)) &&
                       (pix_x[3:2] == 2'b01 && pix_y[3:2] == 2'b01) && !is_lit_celestial;

    // ------------------------------------------------------------------------
    // 6. COLOR COMPOSITION
    // ------------------------------------------------------------------------
    reg [1:0] R, G, B;

    always @(*) begin
        if (!video_active) begin
            {R, G, B} = 6'b00_00_00; // Blanking
        end else if (is_lit_celestial) begin
            {R, G, B} = is_night ? 6'b11_11_00 : 6'b11_11_01; // Yellow Moon / Golden Sun
        end else if (is_particle) begin
            {R, G, B} = is_night ? 6'b11_11_11 : 6'b11_11_10; // White Stars / Bright Clouds
        end else begin
            {R, G, B} = {bg_R, bg_G, bg_B}; // Parallax Sky
        end
    end

    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    wire _unused_ok = &{ena, uio_in, ui_in[5:0]};

endmodule

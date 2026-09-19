/*
 * Tiny Tapeout VGA: Dual Day/Night Phase Graphics Generator
 * - Day Phase: Subdued/lighter sky progression from soft sunrise to muted sunset
 * - Night Phase: Moon phases, vertical parallax, twinkling colored stars
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_panfia_skyscreensaver (
    input  wire [7:0] ui_in,    // ui_in[0]: 0=Night Phase, 1=Day Phase
    output wire [7:0] uo_out,   // TinyVGA outputs: {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // uio_out[7] carries 1-bit audio signal
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // Always 1
    input  wire       clk,      // 24 MHz clock
    input  wire       rst_n     // Active-low reset
);

    // Mode Control Signal
    wire day_mode = ui_in[0];

    // ------------------------------------------------------------------------
    // 1. VGA SIGNAL GENERATION & FRAME COUNTER
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

    // Frame counter for Parallax Animation
    reg [9:0] counter;
    always @(posedge vsync or negedge rst_n) begin
        if (~rst_n) begin
            counter <= 10'd0;
        end else begin
            counter <= counter + 1'b1;
        end
    end

    // Output pin setup
    assign uio_oe  = 8'h80; // Configure uio_out[7] as output for audio
    assign uio_out = {sound_out, 7'b0};

    // ------------------------------------------------------------------------
    // 2. PARALLAX SKY BACKGROUND & DYNAMIC SUN TONE CONTROL
    // ------------------------------------------------------------------------
    wire [9:0] layer_a_coord = day_mode ? (pix_x + (counter * 2))  : (pix_y + (counter * 2));
    wire [9:0] layer_b_coord = day_mode ? (pix_x + counter)        : (pix_y + counter);
    wire [9:0] layer_c_coord = day_mode ? (pix_x + (counter >> 1)) : (pix_y + (counter >> 1));

    wire [9:0] static_coord  = day_mode ? pix_y : pix_x;

    wire layer_a_mask = (layer_a_coord[7] ^ static_coord[7]) & (pix_y[0] ^ pix_x[0]); 
    wire layer_b_mask = (layer_b_coord[6] ^ static_coord[6]) & (~pix_y[0] ^ pix_x[1]); 
    wire layer_c_mask = layer_c_coord[6] ^ static_coord[6];                          

    // Priority Selection for Day Sky Progression
    reg [2:0] day_sky_state;
    always @(*) begin
        if (ui_in[7])      day_sky_state = 3'd7; // Muted Deep Sunset
        else if (ui_in[6]) day_sky_state = 3'd6; // Soft Dusk Purple
        else if (ui_in[5]) day_sky_state = 3'd5; // Subdued Golden Hour
        else if (ui_in[4]) day_sky_state = 3'd4; // Bright Sky Blue (Midday)
        else if (ui_in[3]) day_sky_state = 3'd3; // Soft Morning Cyan
        else if (ui_in[2]) day_sky_state = 3'd2; // Pastel Morning
        else if (ui_in[1]) day_sky_state = 3'd1; // Soft Sunrise Glow
        else               day_sky_state = 3'd0; // Early Sunrise (Default Start)
    end

    // Dynamic Palette Map & Matching Sun Color
    reg [5:0] color_layer_a, color_layer_b, color_layer_c, color_bg;
    reg [5:0] sun_color;

    always @(*) begin
        if (!day_mode) begin
            // --- NIGHT PALETTE ---
            color_layer_a = 6'b00_01_10; // Soft Slate-Blue
            color_layer_b = 6'b00_00_10; // Medium Night Blue
            color_layer_c = 6'b00_00_01; // Soft Midnight Blue
            color_bg      = 6'b00_00_01; // Deepest Midnight
            sun_color     = 6'b11_10_00; // Unused in night mode
        end else begin
            // --- DAY PALETTE (Subdued / Lighter Tones) ---
            case (day_sky_state)
                3'd0: begin // Early Sunrise (Soft Peach/Lavender)
                    color_layer_a = 6'b11_10_10; color_layer_b = 6'b11_01_10;
                    color_layer_c = 6'b10_01_10; color_bg      = 6'b01_01_10;
                    sun_color     = 6'b11_01_00; // Deep Red-Orange Sun
                end
                3'd1: begin // Bright Sunrise (Warm Peach & Soft Gold)
                    color_layer_a = 6'b11_10_01; color_layer_b = 6'b11_10_10;
                    color_layer_c = 6'b10_01_11; color_bg      = 6'b01_01_11;
                    sun_color     = 6'b11_01_00; // Deep Red-Orange Sun
                end
                3'd2: begin // Morning Horizon (Pastel Blue & Soft Cream)
                    color_layer_a = 6'b11_11_10; color_layer_b = 6'b10_11_11;
                    color_layer_c = 6'b01_10_11; color_bg      = 6'b01_01_11;
                    sun_color     = 6'b11_10_00; // Warm Orange-Yellow
                end
                3'd3: begin // Soft Morning (Clear Soft Blue)
                    color_layer_a = 6'b10_11_11; color_layer_b = 6'b01_11_11;
                    color_layer_c = 6'b01_10_11; color_bg      = 6'b00_10_11;
                    sun_color     = 6'b11_11_10; // Soft White with Yellow Tint
                end
                3'd4: begin // Midday (Light Sky Blue / Cyan Peak)
                    color_layer_a = 6'b11_11_11; color_layer_b = 6'b10_11_11;
                    color_layer_c = 6'b01_11_11; color_bg      = 6'b01_10_11;
                    sun_color     = 6'b11_11_10; // Soft White with Yellow Tint
                end
                3'd5: begin // Golden Afternoon (Subdued Warm Coral)
                    color_layer_a = 6'b11_10_10; color_layer_b = 6'b11_01_01;
                    color_layer_c = 6'b10_01_11; color_bg      = 6'b01_01_10;
                    sun_color     = 6'b11_10_00; // Warm Orange-Yellow
                end
                3'd6: begin // Dusk (Soft Rose & Dusky Purple)
                    color_layer_a = 6'b11_01_10; color_layer_b = 6'b10_01_10;
                    color_layer_c = 6'b01_01_10; color_bg      = 6'b01_00_01;
                    sun_color     = 6'b11_01_00; // Rich Red-Orange
                end
                3'd7: begin // Deep Sunset (Subdued Indigo & Crimson)
                    color_layer_a = 6'b11_01_01; color_layer_b = 6'b10_00_10;
                    color_layer_c = 6'b01_00_10; color_bg      = 6'b00_00_01;
                    sun_color     = 6'b11_00_00; // Rich Crimson Red-Orange
                end
            endcase
        end
    end

    reg [1:0] active_sky_R, active_sky_G, active_sky_B;

    always @(*) begin
        if (layer_a_mask) begin
            {active_sky_R, active_sky_G, active_sky_B} = color_layer_a;
        end else if (layer_b_mask) begin
            {active_sky_R, active_sky_G, active_sky_B} = color_layer_b;
        end else if (layer_c_mask) begin
            {active_sky_R, active_sky_G, active_sky_B} = color_layer_c;
        end else begin
            {active_sky_R, active_sky_G, active_sky_B} = color_bg; 
        end
    end

    // ------------------------------------------------------------------------
    // 3. PRIORITY ENCODER FOR MOON PHASES (NIGHT MODE ONLY)
    // ------------------------------------------------------------------------
    reg [2:0] moon_phase;
    always @(*) begin
        if (ui_in[7])      moon_phase = 3'd7; 
        else if (ui_in[6]) moon_phase = 3'd3; 
        else if (ui_in[5]) moon_phase = 3'd6; 
        else if (ui_in[4]) moon_phase = 3'd4; 
        else if (ui_in[3]) moon_phase = 3'd2; 
        else if (ui_in[2]) moon_phase = 3'd5; 
        else if (ui_in[1]) moon_phase = 3'd1; 
        else               moon_phase = 3'd1; 
    end

    // ------------------------------------------------------------------------
    // 4. ENTITY MANAGER (STARS FOR NIGHT, BIRDS FOR DAY)
    // ------------------------------------------------------------------------
    reg [15:0] lfsr;
    wire feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    // Grid: 32x24 cells
    reg [6:0] star_timer [0:1023];
    reg [9:0] active_stars [0:19];  
    reg [4:0] active_count;          
    reg [4:0] head_ptr;              
    reg [9:0] update_idx;

    // Audio Synth State
    reg [11:0] tone_divider;
    reg [11:0] tone_counter;
    reg [15:0] note_duration;
    reg        synth_wave;
    wire       sound_out = synth_wave & (note_duration > 0);

    wire [9:0] candidate_cell = lfsr[9:0];
    wire [4:0] cand_x = candidate_cell[4:0];
    wire [4:0] cand_y = candidate_cell[9:5];

    wire [9:0] cell_left  = {cand_y, cand_x - 5'd1};
    wire [9:0] cell_right = {cand_y, cand_x + 5'd1};
    wire [9:0] cell_up    = {cand_y - 5'd1, cand_x};
    wire [9:0] cell_down  = {cand_y + 5'd1, cand_x};

    wire is_candidate_clear = (star_timer[candidate_cell][6:3] == 0) &&
                              (star_timer[cell_left][6:3] == 0) &&
                              (star_timer[cell_right][6:3] == 0) &&
                              (star_timer[cell_up][6:3] == 0) &&
                              (star_timer[cell_down][6:3] == 0);

    always @(posedge clk) begin
        if (~rst_n) begin
            lfsr <= 16'hACE1;
            update_idx <= 0;
            active_count <= 0;
            head_ptr <= 0;
            tone_counter <= 0;
            note_duration <= 0;
            synth_wave <= 0;
        end else begin
            lfsr <= {lfsr[14:0], feedback};

            if (pix_x == 0 && pix_y == 0) begin
                if ((lfsr[15:13] == 3'b101) && is_candidate_clear) begin
                    if (active_count == 5'd20) begin
                        star_timer[active_stars[head_ptr]] <= 7'd0;
                        star_timer[candidate_cell] <= {4'd10, lfsr[2:1], lfsr[0]};
                        active_stars[head_ptr] <= candidate_cell;
                        head_ptr <= (head_ptr == 5'd19) ? 5'd0 : head_ptr + 1'b1;
                    end else begin
                        star_timer[candidate_cell] <= {4'd10, lfsr[2:1], lfsr[0]};
                        active_stars[active_count] <= candidate_cell;
                        active_count <= active_count + 1'b1;
                    end

                    tone_divider  <= 12'd400 + {lfsr[7:0], 2'b00};
                    note_duration <= 16'd5000;
                end

                if (star_timer[update_idx][6:3] > 0) begin
                    star_timer[update_idx][6:3] <= star_timer[update_idx][6:3] - 1'b1;
                    if (star_timer[update_idx][6:3] == 4'd1 && active_count > 0) begin
                        active_count <= active_count - 1'b1;
                    end
                end
                
                update_idx <= update_idx + 1'b1;
            end

            if (note_duration > 0) begin
                note_duration <= note_duration - 1'b1;
                if (tone_counter >= tone_divider) begin
                    tone_counter <= 0;
                    synth_wave <= ~synth_wave;
                end else begin
                    tone_counter <= tone_counter + 1'b1;
                end
            end else begin
                synth_wave <= 0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // 5. CELESTIAL GRAPHICS (MOON FOR NIGHT, SUN WITH DETACHED THICK RAYS)
    // ------------------------------------------------------------------------
    localparam CENTER_X = 320;
    localparam CENTER_Y = 240;

    wire signed [10:0] dx = pix_x - CENTER_X;
    wire signed [10:0] dy = pix_y - CENTER_Y;
    wire [20:0] dist_sq   = (dx * dx) + (dy * dy);

    // --- MOON LOGIC (Night Phase) ---
    localparam MOON_RADIUS_SQ = 90 * 90;
    wire is_in_moon_circle = (dist_sq <= MOON_RADIUS_SQ);

    wire signed [10:0] dx_offset_crescent_wax = dx - 38;
    wire signed [10:0] dx_offset_crescent_wan = dx + 38;

    wire is_in_crescent_wax_cutout = (((dx_offset_crescent_wax * dx_offset_crescent_wax) + (dy * dy)) <= MOON_RADIUS_SQ);
    wire is_in_crescent_wan_cutout = (((dx_offset_crescent_wan * dx_offset_crescent_wan) + (dy * dy)) <= MOON_RADIUS_SQ);

    reg is_lit_moon;
    always @(*) begin
        case (moon_phase)
            3'd0: is_lit_moon = 1'b0;
            3'd1: is_lit_moon = is_in_moon_circle && !is_in_crescent_wax_cutout;
            3'd2: is_lit_moon = is_in_moon_circle && is_in_crescent_wan_cutout;
            3'd3: is_lit_moon = is_in_moon_circle && (dx > 0);
            3'd4: is_lit_moon = is_in_moon_circle;
            3'd5: is_lit_moon = is_in_moon_circle && (dx < 0);
            3'd6: is_lit_moon = is_in_moon_circle && is_in_crescent_wax_cutout;
            3'd7: is_lit_moon = is_in_moon_circle && !is_in_crescent_wan_cutout;
            default: is_lit_moon = 1'b0;
        endcase
    end

    // --- SUN LOGIC (Day Phase: Detached & Thick Rays) ---
    localparam SUN_RADIUS_SQ  = 50 * 50;     // Sun core
    localparam RAY_INNER_SQ   = 62 * 62;     // Detached gap boundary
    localparam RAY_OUTER_SQ   = 115 * 115;   // Ray tip boundary

    wire is_in_sun_core = (dist_sq <= SUN_RADIUS_SQ);
    wire is_in_ray_zone = (dist_sq >= RAY_INNER_SQ) && (dist_sq <= RAY_OUTER_SQ);

    wire [10:0] abs_dx = dx[10] ? -dx : dx;
    wire [10:0] abs_dy = dy[10] ? -dy : dy;

    // Thick rays (5px thickness)
    wire ray_vertical   = (abs_dx <= 2);
    wire ray_horizontal = (abs_dy <= 2);
    
    wire signed [11:0] diag_diff_30 = (abs_dy * 7) - (abs_dx << 2);
    wire ray_diag_30 = (diag_diff_30 >= -22) && (diag_diff_30 <= 22);

    wire signed [11:0] diag_diff_60 = abs_dy - ((abs_dx * 7) >> 2);
    wire ray_diag_60 = (diag_diff_60 >= -4) && (diag_diff_60 <= 4);

    wire is_sun_ray = is_in_ray_zone && (ray_vertical || ray_horizontal || ray_diag_30 || ray_diag_60);
    wire is_lit_sun = day_mode && (is_in_sun_core || is_sun_ray);

    // ------------------------------------------------------------------------
    // 6. NIGHT STARS & DAY TIME BIRD RENDERER
    // ------------------------------------------------------------------------
    wire [4:0] grid_x = pix_x[9:5];
    wire [4:0] grid_y = pix_y[9:5];
    wire [9:0] current_cell = {grid_y, grid_x};
    
    wire [6:0] star_entry = star_timer[current_cell];
    wire [3:0] star_life  = star_entry[6:3];
    wire [1:0] star_color_code = star_entry[2:1]; 
    wire       star_shape = star_entry[0]; 

    wire [2:0] local_x = pix_x[4:2];
    wire [2:0] local_y = pix_y[4:2];

    // --- NIGHT STAR SHAPES ---
    wire is_asterisk_pixel = ((local_x == 3) && (local_y >= 2 && local_y <= 4)) || 
                             ((local_y == 3) && (local_x >= 2 && local_x <= 4));

    wire signed [3:0] dot_dx = local_x - 3;
    wire signed [3:0] dot_dy = local_y - 3;
    wire is_circle_pixel = ((dot_dx * dot_dx) + (dot_dy * dot_dy) <= 2);

    wire is_shape_pixel = star_shape ? is_asterisk_pixel : is_circle_pixel;
    wire is_star_active = !day_mode && (star_life > 0) && is_shape_pixel && !is_lit_moon;

    // --- DAYTIME BIRD PIXELS ---
    wire flap_state = counter[4]; 

    // Bird Frame 1 (Wings Up)
    wire bird_wings_up = ((local_y == 2) && (local_x == 1 || local_x == 5)) ||
                         ((local_y == 3) && (local_x == 2 || local_x == 4)) ||
                         ((local_y == 4) && (local_x == 3));

    // Bird Frame 2 (Wings Down)
    wire bird_wings_down = ((local_y == 2) && (local_x == 3)) ||
                           ((local_y == 3) && (local_x >= 1 && local_x <= 5));

    wire is_bird_shape  = flap_state ? bird_wings_up : bird_wings_down;
    wire is_bird_active = day_mode && (star_life > 0) && is_bird_shape && !is_lit_sun;

    reg [5:0] final_star_rgb;
    always @(*) begin
        case (star_color_code)
            2'b00: final_star_rgb = 6'b01_11_10; // #57f2a4 (Mint Green)
            2'b01: final_star_rgb = 6'b11_10_10; // #f58c9a (Soft Pink)
            2'b10: final_star_rgb = 6'b10_11_11; // #94daff (Sky Blue)
            2'b11: final_star_rgb = 6'b11_11_11; // Pure White
        endcase
    end

    // ------------------------------------------------------------------------
    // 7. COLOR COMPOSITOR
    // ------------------------------------------------------------------------
    reg [1:0] R, G, B;

    always @(*) begin
        if (!video_active) begin
            {R, G, B} = 6'b00_00_00; // Blanking
        end else if (day_mode) begin
            if (is_lit_sun) begin
                {R, G, B} = sun_color; // Dynamic Sun Color matching Sky Time
            end else if (is_bird_active) begin
                {R, G, B} = 6'b00_00_00; // Black Bird Silhouette
            end else begin
                {R, G, B} = {active_sky_R, active_sky_G, active_sky_B}; // Day Sky Gradient
            end
        end else begin
            if (is_lit_moon) begin
                {R, G, B} = 6'b11_11_00; // Bright Yellow Moon
            end else if (is_star_active) begin
                {R, G, B} = final_star_rgb; // Custom Color Stars
            end else begin
                {R, G, B} = {active_sky_R, active_sky_G, active_sky_B}; // Night Parallax Background
            end
        end
    end

    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    wire _unused_ok = &{ena, uio_in};

endmodule

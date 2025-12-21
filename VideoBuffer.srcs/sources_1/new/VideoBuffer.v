`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
// Create Date: 20.12.2025 16:28:53
// Module Name: VideoBuffer
// Project Name: VideoBuffer
// Target Devices: Generic
// Description: Parameterizable line buffer / frame buffer for video upscaler
// License: MIT / BSD-3-Clause (choose as needed for open source)
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------------
// Line Buffer Module
// Stores N lines in a circular buffer for streaming video processing
// ----------------------------------------------------------------------------
module line_buffer #(
    parameter MAX_WIDTH        = 1920,      // Maximum line width supported
    parameter MAX_HEIGHT       = 8,         // Maximum number of lines to buffer
    parameter PIXEL_WIDTH      = 24,        // Bits per pixel
    parameter ADDR_WIDTH       = $clog2(MAX_WIDTH * MAX_HEIGHT)
)(
    input  wire clk,
    input  wire rst_n,
    
    // Runtime configuration inputs
    input  wire [15:0]                  cfg_width,       // Actual line width to use
    input  wire [3:0]                   cfg_num_lines,   // Actual number of lines (1-MAX_HEIGHT)
    
    // Write interface
    input  wire                         wr_en,
    input  wire [PIXEL_WIDTH-1:0]       wr_data,
    input  wire                         wr_line_start,
    
    // Read interface
    input  wire                         rd_en,
    output reg  [PIXEL_WIDTH-1:0]       rd_data,
    input  wire [ADDR_WIDTH-1:0]        rd_addr,
    
    // Status
    output reg                          ready,
    output reg  [3:0]                   lines_stored
);

    // Memory storage (sized for maximum)
    reg [PIXEL_WIDTH-1:0] mem [0:MAX_WIDTH*MAX_HEIGHT-1];
    
    // Write pointer and line counter
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [3:0] wr_line_count;
    
    // Calculate buffer size at runtime
    wire [ADDR_WIDTH-1:0] buffer_size = cfg_width * cfg_num_lines;
    
    // Write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            wr_line_count <= 0;
            lines_stored <= 0;
            ready <= 0;
        end else begin
            if (wr_line_start) begin
                // New line starting
                if (wr_line_count < cfg_num_lines) begin
                    wr_line_count <= wr_line_count + 1;
                end
                lines_stored <= (wr_line_count >= cfg_num_lines-1) ? cfg_num_lines : wr_line_count + 1;
                ready <= (wr_line_count >= cfg_num_lines-1);
            end
            
            if (wr_en) begin
                mem[wr_ptr] <= wr_data;
                // Wrap at runtime-configured buffer size
                wr_ptr <= (wr_ptr >= buffer_size-1) ? 0 : wr_ptr + 1;
            end
        end
    end
    
    // Read logic (synchronous)
    always @(posedge clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end

endmodule

// ----------------------------------------------------------------------------
// Frame Buffer Module
// ----------------------------------------------------------------------------
module frame_buffer #(
    parameter MAX_WIDTH        = 1920,
    parameter MAX_HEIGHT       = 1080,
    parameter PIXEL_WIDTH      = 24,
    parameter ADDR_WIDTH       = $clog2(MAX_WIDTH * MAX_HEIGHT)
)(
    input  wire                      clk,
    input  wire                      rst_n,
    
    // Runtime configuration inputs
    input  wire [15:0]               cfg_width,
    input  wire [15:0]               cfg_height,
    
    // Write interface (port A)
    input  wire                      wr_en,
    input  wire [ADDR_WIDTH-1:0]     wr_addr,
    input  wire [PIXEL_WIDTH-1:0]    wr_data,
    input  wire                      wr_frame_start,
    
    // Read interface (port B)
    input  wire                      rd_en,
    input  wire [ADDR_WIDTH-1:0]     rd_addr,
    output reg  [PIXEL_WIDTH-1:0]    rd_data,
    
    // Status
    output reg                       frame_ready
);

    // Dual-port memory (sized for maximum)
    reg [PIXEL_WIDTH-1:0] mem [0:MAX_WIDTH*MAX_HEIGHT-1];
    
    // Calculate frame size at runtime
    wire [ADDR_WIDTH-1:0] frame_size = cfg_width * cfg_height;
    
    // Frame tracking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_ready <= 0;
        end else if (wr_frame_start) begin
            frame_ready <= 1;
        end
    end
    
    // Port A: Write (with bounds checking)
    always @(posedge clk) begin
        if (wr_en && wr_addr < frame_size) begin
            mem[wr_addr] <= wr_data;
        end
    end
    
    // Port B: Read
    always @(posedge clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end

endmodule

// ----------------------------------------------------------------------------
// Top-Level Buffer with Runtime and Compile-Time Configuration
// ----------------------------------------------------------------------------
module VideoBuffer #(
    parameter MAX_WIDTH        = 1920,      // Maximum width supported
    parameter MAX_HEIGHT       = 1080,      // Maximum height supported
    parameter PIXEL_WIDTH      = 24,
    parameter MAX_NUM_LINES    = 8,         // Maximum line buffer depth
    
    // Compile-time buffer mode selection
    parameter USE_LINE_BUFFER  = 1,
    parameter USE_FRAME_BUFFER = 0
)(
    input  wire                      clk,
    input  wire                      rst_n,
    
    // Runtime configuration inputs (connected to top-level register interface)
    input  wire [15:0]               cfg_width,
    input  wire [15:0]               cfg_height,
    input  wire [3:0]                cfg_num_lines,      // 1-MAX_NUM_LINES
    input  wire                      cfg_enable_line,    // Runtime enable for line buffer
    input  wire                      cfg_enable_frame,   // Runtime enable for frame buffer
    
    // Universal write interface
    input  wire                      wr_en,
    input  wire [PIXEL_WIDTH-1:0]    wr_data,
    input  wire                      wr_line_start,
    input  wire                      wr_frame_start,
    input  wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0] wr_addr,
    
    // Universal read interface
    input  wire                      rd_en,
    input  wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0] rd_addr,
    output wire [PIXEL_WIDTH-1:0]    rd_data,
    
    // Status outputs
    output wire                      ready,
    output wire [3:0]                lines_stored,
    output wire                      frame_ready
);

    // Internal signals
    wire [PIXEL_WIDTH-1:0] lb_rd_data, fb_rd_data;
    wire lb_ready, fb_ready;
    wire [3:0] lb_lines_stored;
    
    // Generate line buffer instance if enabled at compile time
    generate
        if (USE_LINE_BUFFER) begin : g_line_buffer
            line_buffer #(
                .MAX_WIDTH(MAX_WIDTH),
                .MAX_HEIGHT(MAX_NUM_LINES),
                .PIXEL_WIDTH(PIXEL_WIDTH)
            ) u_line_buffer (
                .clk(clk),
                .rst_n(rst_n),
                // Runtime config
                .cfg_width(cfg_width),
                .cfg_num_lines(cfg_num_lines),
                // Data interface
                .wr_en(wr_en & cfg_enable_line),
                .wr_data(wr_data),
                .wr_line_start(wr_line_start),
                .rd_en(rd_en & cfg_enable_line),
                .rd_data(lb_rd_data),
                .rd_addr(rd_addr[$clog2(MAX_WIDTH*MAX_NUM_LINES)-1:0]),
                .ready(lb_ready),
                .lines_stored(lb_lines_stored)
            );
        end else begin : g_no_line_buffer
            assign lb_rd_data = {PIXEL_WIDTH{1'b0}};
            assign lb_ready = 1'b0;
            assign lb_lines_stored = 4'b0;
        end
    endgenerate
    
    // Generate frame buffer instance if enabled at compile time
    generate
        if (USE_FRAME_BUFFER) begin : g_frame_buffer
            frame_buffer #(
                .MAX_WIDTH(MAX_WIDTH),
                .MAX_HEIGHT(MAX_HEIGHT),
                .PIXEL_WIDTH(PIXEL_WIDTH)
            ) u_frame_buffer (
                .clk(clk),
                .rst_n(rst_n),
                // Runtime config
                .cfg_width(cfg_width),
                .cfg_height(cfg_height),
                // Data interface
                .wr_en(wr_en & cfg_enable_frame),
                .wr_addr(wr_addr),
                .wr_data(wr_data),
                .wr_frame_start(wr_frame_start),
                .rd_en(rd_en & cfg_enable_frame),
                .rd_addr(rd_addr),
                .rd_data(fb_rd_data),
                .frame_ready(fb_ready)
            );
        end else begin : g_no_frame_buffer
            assign fb_rd_data = {PIXEL_WIDTH{1'b0}};
            assign fb_ready = 1'b0;
        end
    endgenerate
    
    // Output multiplexing
    assign rd_data = lb_rd_data | fb_rd_data;
    assign ready = lb_ready | fb_ready;
    assign lines_stored = lb_lines_stored;
    assign frame_ready = fb_ready;

endmodule


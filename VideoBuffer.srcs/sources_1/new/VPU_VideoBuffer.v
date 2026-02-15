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
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module VPU_VideoBuffer #(
    parameter MAX_WIDTH        = 1024,
    parameter MAX_HEIGHT       = 960,
    parameter PIXEL_WIDTH      = 24,
    parameter MAX_NUM_LINES    = 2,        
    parameter USE_LINE_BUFFER  = 1,
    parameter USE_FRAME_BUFFER = 0
)(
    input  wire                      clk,
    input  wire                      rst_n,
    
    input  wire [15:0]              VPU_cfg_width,
    input  wire [15:0]              VPU_cfg_height,
    input  wire [3:0]               VPU_cfg_num_lines,      // 1-MAX_NUM_LINES
    input  wire                     VPU_cfg_enable_line,    // Runtime enable for line buffer
    input  wire                     VPU_cfg_enable_frame,   // Runtime enable for frame buffer
    input  wire                     VPU_cfg_use_frame_buffer, 
    

    input  wire                     VPU_in_valid,
    input  wire                     VPU_out_ready,
    output wire                     VPU_in_ready,
    input  wire [PIXEL_WIDTH-1:0]   VPU_in_pixel,
    input  wire                     VPU_in_line_start,
    input  wire                     VPU_in_frame_start,
    input  wire                     VPU_in_interlaced,
    input  wire                     VPU_in_field_id,
    input  wire [11:0]              VPU_in_h_count,
    input  wire [11:0]              VPU_in_v_count,
    input  wire [11:0]              VPU_in_h_active,
    input  wire [11:0]              VPU_in_v_active,
    
    output wire                     VPU_out_valid,
    output wire [PIXEL_WIDTH-1:0]   VPU_out_pixel,
    output wire                     VPU_out_line_start,
    output wire                     VPU_out_frame_start,
    output wire                     VPU_out_interlaced,
    output wire                     VPU_out_field_id,
    output wire [11:0]              VPU_out_h_count,
    output wire [11:0]              VPU_out_v_count,
    output wire [11:0]              VPU_out_h_active,
    output wire [11:0]              VPU_out_v_active,
    
    input  wire                                    wr_en,
    input  wire [PIXEL_WIDTH-1:0]                  wr_data,
    input  wire                                    wr_line_start,
    input  wire                                    wr_frame_start,
    input  wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0] wr_addr,
    
    input  wire                                    rd_en,
    input  wire [$clog2(MAX_WIDTH*MAX_HEIGHT)-1:0] rd_addr,
    output wire [PIXEL_WIDTH-1:0]                  rd_data,
    
    output wire                                    buffer_ready,
    output wire [3:0]                              lines_stored,
    output wire                                    frame_ready
);

    localparam LB_ADDR_WIDTH = $clog2(MAX_WIDTH*MAX_NUM_LINES);
    localparam FB_ADDR_WIDTH = $clog2(MAX_WIDTH*MAX_HEIGHT);
    
    reg                     out_valid_r;
    reg [PIXEL_WIDTH-1:0]   out_pixel_r;
    reg                     out_line_start_r;
    reg                     out_frame_start_r;
    reg                     out_interlaced_r;
    reg                     out_field_id_r;
    reg [11:0]              out_h_count_r;
    reg [11:0]              out_v_count_r;
    reg [11:0]              out_h_active_r;
    reg [11:0]              out_v_active_r;

    // Internal signals
    wire [PIXEL_WIDTH-1:0] lb_rd_data;
    wire [PIXEL_WIDTH-1:0] fb_rd_data;
    wire lb_ready;
    wire fb_ready;
    wire [3:0] lb_lines_stored;
    wire lb_rd_en_internal;
    wire fb_rd_en_internal;
       
    wire passthrough_ready = !out_valid_r || VPU_out_ready;

    generate
        if (USE_LINE_BUFFER && USE_FRAME_BUFFER) begin : g_both_buffers
            assign lb_rd_en_internal = rd_en && !VPU_cfg_use_frame_buffer && VPU_cfg_enable_line;
            assign fb_rd_en_internal = rd_en && VPU_cfg_use_frame_buffer && VPU_cfg_enable_frame;
            assign rd_data           = VPU_cfg_use_frame_buffer ? fb_rd_data : lb_rd_data;
            assign buffer_ready      = VPU_cfg_use_frame_buffer ? fb_ready   : lb_ready;
            
        end else if (USE_LINE_BUFFER) begin : g_line_only
            assign lb_rd_en_internal = rd_en && VPU_cfg_enable_line;
            assign fb_rd_en_internal = 1'b0;
            assign rd_data           = lb_rd_data;
            assign buffer_ready      = lb_ready;
            
        end else if (USE_FRAME_BUFFER) begin : g_frame_only
            assign lb_rd_en_internal = 1'b0;
            assign fb_rd_en_internal = rd_en && VPU_cfg_enable_frame;
            assign rd_data           = fb_rd_data;
            assign buffer_ready      = fb_ready;
            
        end else begin : g_no_buffer
            assign lb_rd_en_internal = 1'b0;
            assign fb_rd_en_internal = 1'b0;
            assign rd_data           = {PIXEL_WIDTH{1'b0}};
            assign buffer_ready      = 1'b0;
        end
    endgenerate
    
    // Generate line buffer instance if enabled at compile time
    generate
        if (USE_LINE_BUFFER) begin : g_line_buffer
            LineBuffer #(
                .MAX_WIDTH(MAX_WIDTH),
                .MAX_HEIGHT(MAX_NUM_LINES),
                .PIXEL_WIDTH(PIXEL_WIDTH)
            ) u_line_buffer (
                .clk(clk),
                .rst_n(rst_n),
                .cfg_width(VPU_cfg_width),
                .cfg_num_lines(VPU_cfg_num_lines),
                .wr_en(wr_en & VPU_cfg_enable_line),
                .wr_data(wr_data),
                .wr_line_start(wr_line_start),
                .rd_en(lb_rd_en_internal),
                .rd_data(lb_rd_data),
                .rd_addr(rd_addr[LB_ADDR_WIDTH-1:0]),
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
            FrameBuffer #(
                .MAX_WIDTH(MAX_WIDTH),
                .MAX_HEIGHT(MAX_HEIGHT),
                .PIXEL_WIDTH(PIXEL_WIDTH)
            ) u_frame_buffer (
                .clk(clk),
                .rst_n(rst_n),
                .cfg_width(VPU_cfg_width),
                .cfg_height(VPU_cfg_height),
                .wr_en(wr_en & VPU_cfg_enable_frame),
                .wr_addr(wr_addr),
                .wr_data(wr_data),
                .wr_frame_start(wr_frame_start),
                .rd_en(fb_rd_en_internal),
                .rd_addr(rd_addr[FB_ADDR_WIDTH-1:0]),
                .rd_data(fb_rd_data),
                .frame_ready(fb_ready)
            );
        end else begin : g_no_frame_buffer
            assign fb_rd_data = {PIXEL_WIDTH{1'b0}};
            assign fb_ready = 1'b0;
        end
    endgenerate
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid_r       <= 1'b0;
            out_pixel_r       <= {PIXEL_WIDTH{1'b0}};
            out_line_start_r  <= 1'b0;
            out_frame_start_r <= 1'b0;
            out_interlaced_r  <= 1'b0;
            out_field_id_r    <= 1'b0;
            out_h_count_r     <= 12'd0;
            out_v_count_r     <= 12'd0;
            out_h_active_r    <= 12'd0;
            out_v_active_r    <= 12'd0;
        end else if (passthrough_ready) begin
            out_valid_r       <= VPU_in_valid;
            out_pixel_r       <= VPU_in_pixel;
            out_line_start_r  <= VPU_in_line_start;
            out_frame_start_r <= VPU_in_frame_start;
            out_interlaced_r  <= VPU_in_interlaced;
            out_field_id_r    <= VPU_in_field_id;
            out_h_count_r     <= VPU_in_h_count;
            out_v_count_r     <= VPU_in_v_count;
            out_h_active_r    <= VPU_in_h_active;
            out_v_active_r    <= VPU_in_v_active;
        end
    end
    
    assign lines_stored = lb_lines_stored;
    assign VPU_out_valid = out_valid_r;
    assign VPU_out_pixel = out_pixel_r;
    assign VPU_out_line_start = out_line_start_r;
    assign VPU_out_frame_start = out_frame_start_r;
    assign VPU_out_interlaced = out_interlaced_r;
    assign VPU_out_field_id = out_field_id_r;
    assign VPU_out_h_count = out_h_count_r;
    assign VPU_out_v_count = out_v_count_r;
    assign VPU_out_h_active = out_h_active_r;
    assign VPU_out_v_active = out_v_active_r;
    assign VPU_in_ready = passthrough_ready;

endmodule
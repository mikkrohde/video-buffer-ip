`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.12.2025 13:03:50
// Design Name: 
// Module Name: LineBuffer
// Project Name: Frame Buffer Module
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module FrameBuffer #(
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
    (* ram_style = "block" *)
    (* rw_addr_collision = "yes" *)
    reg [PIXEL_WIDTH-1:0] mem [0:MAX_WIDTH*MAX_HEIGHT-1];
    
    // Calculate frame size at runtime
    //wire [ADDR_WIDTH-1:0] frame_size = cfg_width * cfg_height;
    localparam MAX_ADDR = MAX_WIDTH * MAX_HEIGHT - 1;
    
    
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
        if (wr_en) begin
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
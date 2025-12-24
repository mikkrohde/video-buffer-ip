`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.12.2025 13:03:50
// Design Name: 
// Module Name: LineBuffer
// Project Name: 
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


// ----------------------------------------------------------------------------
// Line Buffer Module
// Stores N lines in a circular buffer for streaming video processing
// ----------------------------------------------------------------------------
module LineBuffer #(
    parameter MAX_WIDTH        = 1920,      // Maximum line width supported
    parameter MAX_HEIGHT       = 8,         // Maximum number of lines to buffer
    parameter PIXEL_WIDTH      = 24,        // Bits per pixel
    parameter ADDR_WIDTH       = $clog2(MAX_WIDTH * MAX_HEIGHT)
)(
    input wire clk,
    input wire rst_n,
    
    // Runtime configuration inputs
    input wire [15:0]                  cfg_width,       // Actual line width to use
    input wire [3:0]                   cfg_num_lines,   // Actual number of lines (1-MAX_HEIGHT)
    
    // Write interface
    input wire                         wr_en,
    input wire [PIXEL_WIDTH-1:0]       wr_data,
    input wire                         wr_line_start,
    
    // Read interface
    input wire                         rd_en,
    output reg [PIXEL_WIDTH-1:0]       rd_data,
    input wire [ADDR_WIDTH-1:0]        rd_addr,
    
    // Status
    output reg                         ready,
    output reg  [3:0]                  lines_stored
);

    // Memory storage (sized for maximum)
    (* ram_style = "block" *)
    (* rw_addr_collision = "yes" *)
    reg [PIXEL_WIDTH-1:0] mem [0:MAX_WIDTH*MAX_HEIGHT-1];
    
    // Write pointer and line counter
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [3:0] wr_line_count;
    
    // Calculate buffer size at runtime
    //wire [ADDR_WIDTH-1:0] buffer_size = cfg_width * cfg_num_lines;
    localparam MAX_ADDR = MAX_WIDTH * MAX_HEIGHT - 1;
    
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
                if (wr_ptr >= MAX_ADDR) begin
                    wr_ptr <= 0;
                end else begin
                    wr_ptr <= wr_ptr + 1;
                end
                
            end
        end
    end
    
    // Write logic (synchronous)
    always @(posedge clk) begin
        if (wr_en) begin
            mem[wr_ptr] <= wr_data;
        end
    end
    
    // Read logic (synchronous)
    always @(posedge clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end

endmodule

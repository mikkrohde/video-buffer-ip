`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

// 
// Create Date: 20.12.2025 17:12:23
// Design Name: 
// Module Name: tb_line_buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench for Line Buffer Module
// 
// Tests: Runtime configuration, write/read operations, circular buffering
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_line_buffer;

    // Parameters
    parameter MAX_WIDTH = 64;
    parameter MAX_HEIGHT = 5;
    parameter PIXEL_WIDTH = 24;
    parameter ADDR_WIDTH = $clog2(MAX_WIDTH * MAX_HEIGHT);
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Runtime configuration
    reg [15:0] cfg_width;
    reg [3:0] cfg_num_lines;
    
    // Write interface
    reg wr_en;
    reg [PIXEL_WIDTH-1:0] wr_data;
    reg wr_line_start;
    
    // Read interface
    reg rd_en;
    reg [ADDR_WIDTH-1:0] rd_addr;
    wire [PIXEL_WIDTH-1:0] rd_data;
    
    // Status
    wire ready;
    wire [3:0] lines_stored;
    
    // Instantiate DUT
    LineBuffer #(
        .MAX_WIDTH(MAX_WIDTH),
        .MAX_HEIGHT(MAX_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_width(cfg_width),
        .cfg_num_lines(cfg_num_lines),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .wr_line_start(wr_line_start),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .rd_addr(rd_addr),
        .ready(ready),
        .lines_stored(lines_stored)
    );
    
    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test variables
    integer i, j;
    reg [PIXEL_WIDTH-1:0] expected_data;
    integer error_count;
    
    // Main test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        cfg_width = 16;
        cfg_num_lines = 3;
        wr_en = 0;
        wr_data = 0;
        wr_line_start = 0;
        rd_en = 0;
        rd_addr = 0;
        error_count = 0;
        
        // Apply reset
        #20;
        rst_n = 1;
        #20;
        
        $display("========================================");
        $display("Line Buffer Testbench Started");
        $display("Configuration: Width=%0d, Lines=%0d", cfg_width, cfg_num_lines);
        $display("========================================");
        
        // TEST 1: Write 3 lines of data
        $display("\n[TEST 1] Writing 3 lines...");
        for (j = 0; j < 3; j = j + 1) begin
            @(posedge clk);
            wr_line_start = 1;
            @(posedge clk);
            wr_line_start = 0;
            
            for (i = 0; i < cfg_width; i = i + 1) begin
                @(posedge clk);
                wr_en = 1;
                wr_data = (j << 16) | i;  // Encode line number and pixel position
            end
            @(posedge clk);
            wr_en = 0;
            
            $display("  Line %0d written, lines_stored=%0d, ready=%0b", j, lines_stored, ready);
        end
        
        // Wait a bit
        repeat(10) @(posedge clk);
        
        // TEST 2: Verify buffer is ready
        if (ready) begin
            $display("[TEST 1] PASS: Buffer ready after %0d lines", cfg_num_lines);
        end else begin
            $display("[TEST 1] FAIL: Buffer not ready!");
            error_count = error_count + 1;
        end
        
        // TEST 3: Read back data from line 0
        // FIXED: Account for 1-cycle read latency
        $display("\n[TEST 2] Reading back line 0...");
        for (i = 0; i < cfg_width; i = i + 1) begin
            @(posedge clk);
            rd_en = 1;
            rd_addr = i;  // Line 0 addresses
            @(posedge clk);  // Wait one cycle for read
            rd_en = 0;
            
            expected_data = (0 << 16) | i;
            if (rd_data !== expected_data) begin
                $display("  ERROR at addr %0d: expected=%h, got=%h", i, expected_data, rd_data);
                error_count = error_count + 1;
            end
        end
        $display("[TEST 2] Line 0 readback completed (errors: %0d)", error_count);
        
        // TEST 4: Read back data from line 1
        $display("\n[TEST 3] Reading back line 1...");
        for (i = 0; i < cfg_width; i = i + 1) begin
            @(posedge clk);
            rd_en = 1;
            rd_addr = cfg_width + i;  // Line 1 addresses
            @(posedge clk);  // Wait one cycle for read
            rd_en = 0;
            
            expected_data = (1 << 16) | i;
            if (rd_data !== expected_data) begin
                $display("  ERROR at addr %0d: expected=%h, got=%h", cfg_width + i, expected_data, rd_data);
                error_count = error_count + 1;
            end
        end
        $display("[TEST 3] Line 1 readback completed");
        
        // TEST 5: Read back data from line 2
        $display("\n[TEST 4] Reading back line 2...");
        for (i = 0; i < cfg_width; i = i + 1) begin
            @(posedge clk);
            rd_en = 1;
            rd_addr = (cfg_width * 2) + i;  // Line 2 addresses
            @(posedge clk);  // Wait one cycle for read
            rd_en = 0;
            
            expected_data = (2 << 16) | i;
            if (rd_data !== expected_data) begin
                $display("  ERROR at addr %0d: expected=%h, got=%h", (cfg_width * 2) + i, expected_data, rd_data);
                error_count = error_count + 1;
            end
        end
        $display("[TEST 4] Line 2 readback completed");
        
        // TEST 6: Test circular buffer by writing more lines
        $display("\n[TEST 5] Testing circular buffer (writing 2 more lines)...");
        for (j = 3; j < 5; j = j + 1) begin
            @(posedge clk);
            wr_line_start = 1;
            @(posedge clk);
            wr_line_start = 0;
            
            for (i = 0; i < cfg_width; i = i + 1) begin
                @(posedge clk);
                wr_en = 1;
                wr_data = (j << 16) | i;
            end
            @(posedge clk);
            wr_en = 0;
        end
        
        repeat(10) @(posedge clk);
        
        // Verify circular wrap - oldest data should be overwritten
        $display("  Verifying circular buffer wrapped correctly...");
        @(posedge clk);
        rd_en = 1;
        rd_addr = 0;  // This should now contain data from line 3 or 4
        @(posedge clk);
        rd_en = 0;
        
        $display("  First location now contains: %h", rd_data);
        $display("[TEST 5] Circular buffer write completed");
        
        // TEST 7: Runtime reconfiguration
        $display("\n[TEST 6] Testing runtime reconfiguration...");
        @(posedge clk);
        cfg_width = 32;
        cfg_num_lines = 4;
        @(posedge clk);
        rst_n = 0;  // Reset to apply new config
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("  New configuration: Width=%0d, Lines=%0d", cfg_width, cfg_num_lines);
        
        // Write one line with new config
        @(posedge clk);
        wr_line_start = 1;
        @(posedge clk);
        wr_line_start = 0;
        
        for (i = 0; i < cfg_width; i = i + 1) begin
            @(posedge clk);
            wr_en = 1;
            wr_data = 24'hABCD00 | i;
        end
        @(posedge clk);
        wr_en = 0;
        
        repeat(10) @(posedge clk);
        
        // Read back a few values to verify new config
        $display("  Reading back with new configuration...");
        for (i = 0; i < 5; i = i + 1) begin
            @(posedge clk);
            rd_en = 1;
            rd_addr = i;
            @(posedge clk);
            rd_en = 0;
            
            expected_data = 24'hABCD00 | i;
            if (rd_data !== expected_data) begin
                $display("  ERROR at addr %0d: expected=%h, got=%h", i, expected_data, rd_data);
                error_count = error_count + 1;
            end
        end
        
        $display("[TEST 6] Runtime reconfiguration test completed");
        
        // Final results
        repeat(20) @(posedge clk);
        $display("\n========================================");
        if (error_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("TESTS FAILED - %0d errors detected", error_count);
        end
        $display("========================================");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
    // Optional: Waveform dump for GTKWave/ModelSim
    initial begin
        $dumpfile("tb_line_buffer.vcd");
        $dumpvars(0, tb_line_buffer);
    end

endmodule


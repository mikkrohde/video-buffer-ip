`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date: 20.12.2025 17:19:20
// Design Name: 
// Module Name: tb_frame_buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench for Frame Buffer Module
// 
// Tests: Runtime configuration, dual-port operation, random access
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_frame_buffer;

    // Parameters
    parameter MAX_WIDTH = 64;
    parameter MAX_HEIGHT = 48;
    parameter PIXEL_WIDTH = 24;
    parameter ADDR_WIDTH = $clog2(MAX_WIDTH * MAX_HEIGHT);
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Runtime configuration
    reg [15:0] cfg_width;
    reg [15:0] cfg_height;
    
    // Write interface (port A)
    reg wr_en;
    reg [ADDR_WIDTH-1:0] wr_addr;
    reg [PIXEL_WIDTH-1:0] wr_data;
    reg wr_frame_start;
    
    // Read interface (port B)
    reg rd_en;
    reg [ADDR_WIDTH-1:0] rd_addr;
    wire [PIXEL_WIDTH-1:0] rd_data;
    
    // Status
    wire frame_ready;
    
    // Instantiate DUT
    frame_buffer #(
        .MAX_WIDTH(MAX_WIDTH),
        .MAX_HEIGHT(MAX_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_width(cfg_width),
        .cfg_height(cfg_height),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_frame_start(wr_frame_start),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .frame_ready(frame_ready)
    );
    
    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test variables
    integer i, x, y;
    reg [PIXEL_WIDTH-1:0] expected_data;
    integer error_count;
    integer frame_size;
    
    // Main test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        cfg_width = 32;
        cfg_height = 24;
        wr_en = 0;
        wr_addr = 0;
        wr_data = 0;
        wr_frame_start = 0;
        rd_en = 0;
        rd_addr = 0;
        error_count = 0;
        
        // Apply reset
        #20;
        rst_n = 1;
        #20;
        
        frame_size = cfg_width * cfg_height;
        
        $display("========================================");
        $display("Frame Buffer Testbench Started");
        $display("Configuration: %0dx%0d (%0d pixels)", cfg_width, cfg_height, frame_size);
        $display("========================================");
        
        // TEST 1: Write a complete frame
        $display("\n[TEST 1] Writing full frame...");
        @(posedge clk);
        wr_frame_start = 1;
        @(posedge clk);
        wr_frame_start = 0;
        
        for (i = 0; i < frame_size; i = i + 1) begin
            @(posedge clk);
            wr_en = 1;
            wr_addr = i;
            wr_data = 24'h100000 | i;  // Unique data per pixel
        end
        @(posedge clk);
        wr_en = 0;
        
        repeat(10) @(posedge clk);
        
        if (frame_ready) begin
            $display("[TEST 1] PASS: Frame ready flag set");
        end else begin
            $display("[TEST 1] FAIL: Frame ready flag not set!");
            error_count = error_count + 1;
        end
        
        // TEST 2: Read back sequential addresses
        $display("\n[TEST 2] Reading back sequential addresses...");
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            rd_en = 1;
            rd_addr = i;
            @(posedge clk);  // FIXED: Data valid on this edge
            rd_en = 0;
            
            expected_data = 24'h100000 | i;
            if (rd_data !== expected_data) begin
                $display("  ERROR at addr %0d: expected=%h, got=%h", i, expected_data, rd_data);
                error_count = error_count + 1;
            end
        end
        $display("[TEST 2] Sequential read completed (errors: %0d)", error_count);
        
        // TEST 3: Test dual-port operation (simultaneous read/write)
        $display("\n[TEST 3] Testing dual-port operation...");
        fork
            // Write process
            begin
                for (i = 100; i < 200; i = i + 1) begin
                    @(posedge clk);
                    wr_en = 1;
                    wr_addr = i;
                    wr_data = 24'h200000 | i;
                end
                @(posedge clk);
                wr_en = 0;
            end
            
            // Read process (reading different addresses)
            begin
                repeat(5) @(posedge clk);
                for (i = 0; i < 50; i = i + 1) begin
                    @(posedge clk);
                    rd_en = 1;
                    rd_addr = i;
                    @(posedge clk);
                    rd_en = 0;
                    
                    // Verify we can still read old data while writing
                    expected_data = 24'h100000 | i;
                    if (rd_data !== expected_data) begin
                        $display("  ERROR during dual-port at addr %0d", i);
                        error_count = error_count + 1;
                    end
                end
            end
        join
        
        repeat(10) @(posedge clk);
        $display("[TEST 3] Dual-port operation completed");
        
        // TEST 4: Verify writes from TEST 3
        $display("\n[TEST 4] Verifying writes from dual-port test...");
        for (i = 100; i < 120; i = i + 1) begin
            @(posedge clk);
            rd_en = 1;
            rd_addr = i;
            @(posedge clk);
            rd_en = 0;
            
            expected_data = 24'h200000 | i;
            if (rd_data !== expected_data) begin
                $display("  ERROR at addr %0d: expected=%h, got=%h", i, expected_data, rd_data);
                error_count = error_count + 1;
            end
        end
        $display("[TEST 4] Dual-port write verification completed");
        
        // TEST 5: Random access pattern
        $display("\n[TEST 5] Testing random access...");
        // Write to random locations
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk);
            wr_en = 1;
            wr_addr = (i * 37) % frame_size;  // Pseudo-random addresses
            wr_data = 24'hAA0000 | (i * 37);
        end
        @(posedge clk);
        wr_en = 0;
        
        repeat(5) @(posedge clk);
        
        // Read back and verify
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk);
            rd_en = 1;
            rd_addr = (i * 37) % frame_size;
            @(posedge clk);  // FIXED: Data valid here
            rd_en = 0;
            
            expected_data = 24'hAA0000 | (i * 37);
            if (rd_data !== expected_data) begin
                $display("  ERROR at random addr %0d: expected=%h, got=%h", 
                         (i * 37) % frame_size, expected_data, rd_data);
                error_count = error_count + 1;
            end
        end
        $display("[TEST 5] Random access test completed");
        
        // TEST 6: Test 2D addressing (row/column)
        $display("\n[TEST 6] Testing 2D addressing (row/column)...");
        // Write a pattern: pixel at (x, y) = y * width + x
        for (y = 0; y < 8; y = y + 1) begin
            for (x = 0; x < 8; x = x + 1) begin
                @(posedge clk);
                wr_en = 1;
                wr_addr = y * cfg_width + x;
                wr_data = (y << 12) | (x << 4);  // Encode y and x
            end
        end
        @(posedge clk);
        wr_en = 0;
        
        repeat(5) @(posedge clk);
        
        // Read back and verify 2D pattern
        for (y = 0; y < 8; y = y + 1) begin
            for (x = 0; x < 8; x = x + 1) begin
                @(posedge clk);
                rd_en = 1;
                rd_addr = y * cfg_width + x;
                @(posedge clk);  // FIXED: Data valid here
                rd_en = 0;
                
                expected_data = (y << 12) | (x << 4);
                if (rd_data !== expected_data) begin
                    $display("  ERROR at (%0d, %0d): expected=%h, got=%h", 
                             x, y, expected_data, rd_data);
                    error_count = error_count + 1;
                end
            end
        end
        $display("[TEST 6] 2D addressing test completed");
        
        // TEST 7: Runtime reconfiguration
        $display("\n[TEST 7] Testing runtime reconfiguration...");
        @(posedge clk);
        cfg_width = 16;
        cfg_height = 16;
        frame_size = cfg_width * cfg_height;
        @(posedge clk);
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("  New configuration: %0dx%0d", cfg_width, cfg_height);
        
        // Write small frame with new config
        @(posedge clk);
        wr_frame_start = 1;
        @(posedge clk);
        wr_frame_start = 0;
        
        for (i = 0; i < frame_size; i = i + 1) begin
            @(posedge clk);
            wr_en = 1;
            wr_addr = i;
            wr_data = 24'hCC0000 | i;
        end
        @(posedge clk);
        wr_en = 0;
        
        repeat(10) @(posedge clk);
        
        // Verify new frame
        $display("  Verifying reconfigured frame...");
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            rd_en = 1;
            rd_addr = i;
            @(posedge clk);
            rd_en = 0;
            
            expected_data = 24'hCC0000 | i;
            if (rd_data !== expected_data) begin
                $display("  ERROR at addr %0d: expected=%h, got=%h", i, expected_data, rd_data);
                error_count = error_count + 1;
            end
        end
        
        $display("[TEST 7] Runtime reconfiguration test completed");
        
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
        #200000;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
    // Optional: Waveform dump
    initial begin
        $dumpfile("tb_frame_buffer.vcd");
        $dumpvars(0, tb_frame_buffer);
    end

endmodule


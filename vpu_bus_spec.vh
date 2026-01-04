//////////////////////////////////////////////////////////////////////////////////
// VPU Bus Specification v1.0
// Video Processing Unit - Standard Streaming Interface
//
// This header defines the standard VPU bus signals used throughout the
// video processing pipeline for consistent module interconnection.
//
// Author: Mikkel's Video Upscaler Project
// License: MIT
// Date: 2026-01-01
//////////////////////////////////////////////////////////////////////////////////

`ifndef VPU_BUS_SPEC_VH
`define VPU_BUS_SPEC_VH

//==============================================================================
// VPU Bus Signal Naming Convention
//==============================================================================
// All VPU bus signals use the prefix "vpu_" followed by direction and name:
//   - vpu_in_<signal>  : Input stream to a module
//   - vpu_out_<signal> : Output stream from a module
//
// Example module ports:
//   input  wire                    vpu_in_valid,
//   input  wire [PIXEL_WIDTH-1:0]  vpu_in_pixel,
//   output wire                    vpu_in_ready,
//   ...
//   output wire                    vpu_out_valid,
//   output wire [PIXEL_WIDTH-1:0]  vpu_out_pixel,
//   input  wire                    vpu_out_ready,
//   ...

//==============================================================================
// Core VPU Stream Signals (Always Required)
//==============================================================================

// Data Stream Signals:
// - vpu_valid      : Indicates pixel data is valid (active high)
// - vpu_pixel      : RGB pixel data [23:0] or parameterized width
// - vpu_ready      : Backpressure signal (1=ready to accept, 0=stalled)
//                    Optional for modules that cannot stall

// Frame Synchronization Signals:
// - vpu_frame_start: Single-cycle pulse at the start of a new frame
//                    Coincides with first pixel of first line
// - vpu_line_start : Single-cycle pulse at the start of a new line
//                    Coincides with first pixel of the line

//==============================================================================
// VPU Format Metadata (Recommended)
//==============================================================================

// Scan Format:
// - vpu_interlaced : 1=interlaced scan, 0=progressive scan
// - vpu_field_id   : Field indicator (0=even/first field, 1=odd/second field)
//                    Only meaningful when vpu_interlaced=1

//==============================================================================
// VPU Position Tracking (Optional but Recommended)
//==============================================================================

// Pixel Position:
// - vpu_h_count    : Horizontal pixel position [11:0] (0 to h_active-1)
// - vpu_v_count    : Vertical line position [11:0] (0 to v_active-1)

// Resolution Metadata:
// - vpu_h_active   : Active pixels per line [11:0]
// - vpu_v_active   : Active lines per frame [11:0]
//                    For interlaced: lines per field (not full frame)

//==============================================================================
// VPU Bus Timing Specification
//==============================================================================

// Timing Rules:
// 1. All signals are synchronous to the same clock (pixel_clk)
// 2. vpu_valid qualifies all data signals (pixel, h_count, v_count)
// 3. When vpu_valid=0, data signals may be undefined/don't care
// 4. vpu_frame_start and vpu_line_start are single-cycle pulses
// 5. vpu_frame_start MUST coincide with vpu_line_start on first line
// 6. Both start signals MUST coincide with vpu_valid=1 (first pixel)
//
// Backpressure (if supported):
// 7. When vpu_ready=0, upstream module MUST NOT advance
// 8. vpu_valid may remain high during backpressure
// 9. Start pulses must be held until acknowledged (valid && ready)

// Example Timing Diagram:
//
// Clock:         ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
//                │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │
//                ┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └
//
// frame_start:   ──┐ ┌─────────────────────────────────
//                  └─┘
//
// line_start:    ──┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌────────
//                  └─┘     └─┘     └─┘     └─┘
//
// valid:         ────┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌───────────
//                    └─┘ └─┘ └─┘ └─┘ └─┘ └─┘
//
// pixel:         ════X P0X P1X P2X P3X P4X═══════════
//
// h_count:       ════X 0 X 1 X 2 X 3 X 4 X═══════════
//
// v_count:       ════X 0 X 0 X 0 X 0 X 0 X═══════════

//==============================================================================
// VPU Module Port Template
//==============================================================================

// Use this template for all VPU-compatible modules:
/*
module vpu_<module_name> #(
    parameter PIXEL_WIDTH = 24
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // VPU Input Stream
    input  wire                    vpu_in_valid,
    input  wire [PIXEL_WIDTH-1:0]  vpu_in_pixel,
    output wire                    vpu_in_ready,        // Optional
    input  wire                    vpu_in_frame_start,
    input  wire                    vpu_in_line_start,
    input  wire                    vpu_in_interlaced,   // Optional
    input  wire                    vpu_in_field_id,     // Optional
    input  wire [11:0]             vpu_in_h_count,      // Optional
    input  wire [11:0]             vpu_in_v_count,      // Optional
    input  wire [11:0]             vpu_in_h_active,     // Optional
    input  wire [11:0]             vpu_in_v_active,     // Optional

    // VPU Output Stream
    output wire                    vpu_out_valid,
    output wire [PIXEL_WIDTH-1:0]  vpu_out_pixel,
    input  wire                    vpu_out_ready,       // Optional
    output wire                    vpu_out_frame_start,
    output wire                    vpu_out_line_start,
    output wire                    vpu_out_interlaced,  // Optional
    output wire                    vpu_out_field_id,    // Optional
    output wire [11:0]             vpu_out_h_count,     // Optional
    output wire [11:0]             vpu_out_v_count,     // Optional
    output wire [11:0]             vpu_out_h_active,    // Optional
    output wire [11:0]             vpu_out_v_active     // Optional
);
    // Module implementation
endmodule
*/

//==============================================================================
// VPU Passthrough Macro
//==============================================================================

// For modules that don't modify certain signals, use passthrough:
// Syntax: `VPU_PASSTHROUGH(signal_name, in_prefix, out_prefix)
/*
`define VPU_PASSTHROUGH(signal, in_prefix, out_prefix) \
    assign out_prefix``_``signal = in_prefix``_``signal

// Example usage in a module that only modifies pixels:
    `VPU_PASSTHROUGH(interlaced, vpu_in, vpu_out);
    `VPU_PASSTHROUGH(field_id, vpu_in, vpu_out);
    `VPU_PASSTHROUGH(h_active, vpu_in, vpu_out);
    `VPU_PASSTHROUGH(v_active, vpu_in, vpu_out);
*/

`endif // VPU_BUS_SPEC_VH

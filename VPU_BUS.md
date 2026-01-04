# VPU Bus Specification v1.0

**VPU** = Video Processing Unit

Standard streaming interface for video processing pipeline modules.

---

## Overview

The VPU Bus is a standardized signal naming convention for connecting video processing modules in a streaming pipeline. It ensures consistent interfaces across all modules and simplifies integration.

## Core Principles

1. **Stream-based**: Data flows continuously, pixel by pixel
2. **Synchronous**: All signals use the same clock domain (pixel_clk)
3. **Backpressure support**: Optional ready/valid handshaking
4. **Frame awareness**: Built-in frame and line synchronization signals
5. **Format metadata**: Carries information about scan format (progressive/interlaced)

---

## Signal Groups

### 1. Core Data Stream (Required)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `vpu_valid` | 1 | Output | Pixel data is valid (active high) |
| `vpu_pixel` | 24 | Output | RGB pixel data (or parameterized width) |
| `vpu_ready` | 1 | Input | Backpressure: 1=ready to accept, 0=stall (optional) |

### 2. Frame Synchronization (Required)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `vpu_frame_start` | 1 | Output | Single-cycle pulse at start of new frame |
| `vpu_line_start` | 1 | Output | Single-cycle pulse at start of new line |

### 3. Scan Format Metadata (Recommended)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `vpu_interlaced` | 1 | Output | 1=interlaced scan, 0=progressive scan |
| `vpu_field_id` | 1 | Output | Field indicator: 0=even/first, 1=odd/second |

### 4. Position Tracking (Optional)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `vpu_h_count` | 12 | Output | Horizontal pixel position (0 to h_active-1) |
| `vpu_v_count` | 12 | Output | Vertical line position (0 to v_active-1) |

### 5. Resolution Metadata (Optional)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `vpu_h_active` | 12 | Output | Active pixels per line |
| `vpu_v_active` | 12 | Output | Active lines per frame/field |

---

## Naming Convention

All VPU bus signals follow this pattern:

```
vpu_<direction>_<signal_name>
```

- `vpu_in_*` - Input stream to a module
- `vpu_out_*` - Output stream from a module

**Example:**
```verilog
input  wire                    vpu_in_valid,
input  wire [PIXEL_WIDTH-1:0]  vpu_in_pixel,
output wire                    vpu_in_ready,
input  wire                    vpu_in_frame_start,
input  wire                    vpu_in_line_start,
...
output wire                    vpu_out_valid,
output wire [PIXEL_WIDTH-1:0]  vpu_out_pixel,
input  wire                    vpu_out_ready,
output wire                    vpu_out_frame_start,
output wire                    vpu_out_line_start,
...
```

---

## Timing Specification

### Basic Timing Rules

1. **Synchronous**: All signals synchronous to `pixel_clk`
2. **Valid qualifies data**: When `vpu_valid=0`, data signals are don't-care
3. **Single-cycle pulses**: `frame_start` and `line_start` are 1-cycle pulses
4. **Alignment**: `frame_start` MUST coincide with `line_start` on first line
5. **First pixel**: Both start signals MUST coincide with `vpu_valid=1`

### Backpressure Protocol (Optional)

6. **Stall behavior**: When `vpu_ready=0`, upstream MUST NOT advance
7. **Valid persistence**: `vpu_valid` may remain high during stall
8. **Start pulse hold**: Start pulses held until handshake (`valid && ready`)

### Timing Diagram

```
Clock:         ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
               │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │ │
               ┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └

frame_start:   ──┐ ┌─────────────────────────────────
                 └─┘

line_start:    ──┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌────────
                 └─┘     └─┘     └─┘     └─┘

valid:         ────┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌───────────
                   └─┘ └─┘ └─┘ └─┘ └─┘ └─┘

pixel:         ════X P0X P1X P2X P3X P4X═══════════
                   │   │   │   │   │

h_count:       ════X 0 X 1 X 2 X 3 X 4 X═══════════

v_count:       ════X 0 X 0 X 0 X 0 X 0 X═══════════

interlaced:    ════════════X 0 X════════════════════

field_id:      ════════════X 0 X════════════════════
```

---

## Module Port Template

### Full VPU-Compatible Module

```verilog
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
```

### Minimal VPU Module (Core Signals Only)

```verilog
module vpu_simple_filter #(
    parameter PIXEL_WIDTH = 24
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // VPU Input
    input  wire                    vpu_in_valid,
    input  wire [PIXEL_WIDTH-1:0]  vpu_in_pixel,
    input  wire                    vpu_in_frame_start,
    input  wire                    vpu_in_line_start,

    // VPU Output
    output wire                    vpu_out_valid,
    output wire [PIXEL_WIDTH-1:0]  vpu_out_pixel,
    output wire                    vpu_out_frame_start,
    output wire                    vpu_out_line_start
);
    // Simple passthrough or processing
endmodule
```

---

## Common Module Patterns

### 1. Passthrough (No modification)

For signals that aren't modified by the module:

```verilog
// Passthrough unmodified signals
assign vpu_out_interlaced = vpu_in_interlaced;
assign vpu_out_field_id   = vpu_in_field_id;
assign vpu_out_h_active   = vpu_in_h_active;
assign vpu_out_v_active   = vpu_in_v_active;
```

### 2. Pipeline Stage (1-cycle delay)

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vpu_out_valid       <= 1'b0;
        vpu_out_pixel       <= {PIXEL_WIDTH{1'b0}};
        vpu_out_frame_start <= 1'b0;
        vpu_out_line_start  <= 1'b0;
    end else begin
        vpu_out_valid       <= vpu_in_valid;
        vpu_out_pixel       <= processed_pixel;  // Your processing
        vpu_out_frame_start <= vpu_in_frame_start;
        vpu_out_line_start  <= vpu_in_line_start;
    end
end
```

### 3. Format Conversion (e.g., Deinterlacer)

```verilog
// Input is interlaced, output is progressive
assign vpu_out_interlaced = 1'b0;           // Always progressive
assign vpu_out_v_active   = vpu_in_v_active << 1;  // Double vertical resolution
```

---

## Example Pipeline

```
┌──────────────┐    ┌───────────────┐    ┌─────────────┐    ┌──────────┐      ┌──────────┐
│ SyncDecoder  │──▶│ Deinterlacer   │──▶│LineRepeater │──▶│ Scaler2x  │───▶│  DVIout   │ ───▶ Display
└──────────────┘    └───────────────┘    └─────────────┘    └──────────┘      └──────────┘
  vpu_out_*           vpu_in/out_*         vpu_in/out_*       vpu_in/out_*       vpu_in
```

All modules use VPU bus for consistent interconnection.

---

## Compatibility

### Legacy Module Adaptation

If you have existing modules with different signal names, create a simple adapter:

```verilog
module vpu_adapter_legacy_to_vpu #(
    parameter PIXEL_WIDTH = 24
)(
    // Legacy interface
    input  wire                    pixel_valid,
    input  wire [PIXEL_WIDTH-1:0]  pixel_data,
    input  wire                    line_start,
    input  wire                    frame_start,

    // VPU output
    output wire                    vpu_out_valid,
    output wire [PIXEL_WIDTH-1:0]  vpu_out_pixel,
    output wire                    vpu_out_line_start,
    output wire                    vpu_out_frame_start
);
    // Simple renaming
    assign vpu_out_valid       = pixel_valid;
    assign vpu_out_pixel       = pixel_data;
    assign vpu_out_line_start  = line_start;
    assign vpu_out_frame_start = frame_start;
endmodule
```

---

## Reference Implementations

- **SyncDecoder**: Converts HSYNC/VSYNC to VPU bus
- **Deinterlacer_bob**: Doubles lines for interlaced → progressive
- **LineRepeater**: Repeats lines when line_start without valid
- **Scaler2x**: 2x upscaling with VPU interface

---

## Version History

- **v1.0** (2026-01-01): Initial specification
  - Core data stream signals
  - Frame synchronization
  - Scan format metadata
  - Position tracking
  - Resolution metadata

---

## License

MIT License

# VPU Bus Specification v1.1

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
6. **Configurable**: Module-specific configuration via dedicated `VPU_cfg_*` signals

---

## Signal Groups

### 1. Core Data Stream (Required)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_out_valid` | 1 | Output | Pixel data is valid (active high) |
| `VPU_out_pixel` | 24 | Output | RGB pixel data (or parameterized width) |
| `VPU_in_ready` | 1 | Input | Backpressure: 1=ready to accept, 0=stall (optional) |

### 2. Frame Synchronization (Required)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_out_frame_start` | 1 | Output | Single-cycle pulse at start of new frame |
| `VPU_out_line_start` | 1 | Output | Single-cycle pulse at start of new line |

### 3. Scan Format Metadata (Recommended)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_out_interlaced` | 1 | Output | 1=interlaced scan, 0=progressive scan |
| `VPU_out_field_id` | 1 | Output | Field indicator: 0=even/first, 1=odd/second |

### 4. Position Tracking (Optional)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_out_h_count` | 12 | Output | Horizontal pixel position (0 to h_active-1) |
| `VPU_out_v_count` | 12 | Output | Vertical line position (0 to v_active-1) |

### 5. Resolution Metadata (Optional)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_out_h_active` | 12 | Output | Active pixels per line |
| `VPU_out_v_active` | 12 | Output | Active lines per frame/field |

### 6. Configuration Signals (Optional)

Module-specific configuration inputs, typically driven by a Wishbone or AXI bridge. These signals use the naming pattern:
```
VPU_cfg_<parameter_name>
```

#### Common Timing Configuration

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_cfg_h_active` | 12 | Input | Expected horizontal active pixels |
| `VPU_cfg_h_sync` | 12 | Input | Horizontal sync width |
| `VPU_cfg_h_backporch` | 12 | Input | Horizontal back porch |
| `VPU_cfg_v_active` | 12 | Input | Expected vertical active lines |
| `VPU_cfg_v_sync` | 12 | Input | Vertical sync width |
| `VPU_cfg_v_backporch` | 12 | Input | Vertical back porch |

#### Mode Control

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_cfg_force_interlaced` | 1 | Input | Force interlaced detection |
| `VPU_cfg_force_progressive` | 1 | Input | Force progressive detection |
| `VPU_cfg_ignore_de` | 1 | Input | Ignore data enable signal |
| `VPU_cfg_bypass` | 1 | Input | Bypass processing (passthrough) |
| `VPU_cfg_enable` | 1 | Input | Enable module (0 = disabled/reset) |

#### Scaler-Specific (Example)

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_cfg_out_width` | 12 | Input | Target output width |
| `VPU_cfg_out_height` | 12 | Input | Target output height |
| `VPU_cfg_x_offset` | 12 | Input | Horizontal offset in output frame |
| `VPU_cfg_y_offset` | 12 | Input | Vertical offset in output frame |
| `VPU_cfg_scale_mode` | 2 | Input | 0=nearest, 1=bilinear, 2=integer |

#### Configuration Update

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| `VPU_cfg_update` | 1 | Input | Pulse to latch new config (optional) |
| `VPU_cfg_frame_sync` | 1 | Input | Apply config on next frame start |

**Note:** Modules should latch configuration either immediately, on `VPU_cfg_update` pulse, or on frame boundaries (recommended for glitch-free operation).

---

## Naming Convention

All VPU bus signals follow this pattern:
```
VPU_<direction>_<signal_name>
VPU_cfg_<parameter_name>
```

- `VPU_in_*` - Input stream to a module
- `VPU_out_*` - Output stream from a module
- `VPU_cfg_*` - Configuration input to a module

**Example:**
```verilog
// Stream inputs
input  wire                    VPU_in_valid,
input  wire [PIXEL_WIDTH-1:0]  VPU_in_pixel,
output wire                    VPU_in_ready,
input  wire                    VPU_in_frame_start,
input  wire                    VPU_in_line_start,

// Stream outputs
output wire                    VPU_out_valid,
output wire [PIXEL_WIDTH-1:0]  VPU_out_pixel,
input  wire                    VPU_out_ready,
output wire                    VPU_out_frame_start,
output wire                    VPU_out_line_start,

// Configuration
input  wire [11:0]             VPU_cfg_h_active,
input  wire [11:0]             VPU_cfg_v_active,
input  wire                    VPU_cfg_enable,
```

---

## Timing Specification

### Basic Timing Rules

1. **Synchronous**: All signals synchronous to `pixel_clk`
2. **Valid qualifies data**: When `VPU_in_valid=0`, data signals are don't-care
3. **Single-cycle pulses**: `frame_start` and `line_start` are 1-cycle pulses
4. **Alignment**: `frame_start` MUST coincide with `line_start` on first line
5. **First pixel**: Both start signals MUST coincide with `VPU_out_valid=1`

### Backpressure Protocol (Optional)

6. **Stall behavior**: When `vpu_ready=0`, upstream MUST NOT advance
7. **Valid persistence**: `vpu_valid` may remain high during stall
8. **Start pulse hold**: Start pulses held until handshake (`valid && ready`)

### Configuration Timing

9. **Async safe**: Configuration signals should be synchronized if crossing clock domains
10. **Frame boundary**: For glitch-free updates, latch config on `VPU_in_frame_start`

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

## System Integration

### Wishbone/AXI Configuration Architecture

The recommended integration uses a bus bridge per module:
```
                      Wishbone / AXI Bus
                              │
          ┌───────────────────┼────────────────────┐
          │                   │                    │
          ▼                   ▼                    ▼
    ┌──────────┐         ┌──────────┐         ┌──────────┐
    │ WB→VPU   │         │ WB→VPU   │         │ WB→VPU   │
    │ Bridge   │         │ Bridge   │         │ Bridge   │
    │ @0x1000  │         │ @0x2000  │         │ @0x3000  │
    └────┬─────┘         └────┬─────┘         └────┬─────┘
         │VPU_cfg_*           │VPU_cfg_*           │VPU_cfg_*
         ▼                    ▼                    ▼
    ┌──────────┐         ┌──────────┐         ┌──────────┐
    │SyncDecode│ ─VPU──▶│Deinterlac│ ─VPU──▶│  Scaler  │ ─VPU──▶
    └──────────┘         └──────────┘         └──────────┘
```

Each module receives configuration through its dedicated `VPU_cfg_*` ports while video data flows through the standard VPU stream interface.

### Bridge Implementation Example
```verilog
module wb_to_vpu_cfg_syncdecoder (
    input  wire        wb_clk,
    input  wire        wb_rst,
    
    // Wishbone slave
    input  wire [3:0]  wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output reg  [31:0] wb_dat_o,
    input  wire        wb_we_i,
    input  wire        wb_stb_i,
    output wire        wb_ack_o,
    
    // VPU config outputs
    output reg  [11:0] VPU_cfg_h_active,
    output reg  [11:0] VPU_cfg_h_sync,
    output reg  [11:0] VPU_cfg_h_backporch,
    output reg  [11:0] VPU_cfg_v_active,
    output reg  [11:0] VPU_cfg_v_sync,
    output reg  [11:0] VPU_cfg_v_backporch,
    output reg         VPU_cfg_force_interlaced,
    output reg         VPU_cfg_force_progressive,
    output reg         VPU_cfg_ignore_de
);
    // Single-cycle ack
    assign wb_ack_o = wb_stb_i;
    
    always @(posedge wb_clk) begin
        if (wb_rst) begin
            VPU_cfg_h_active          <= 12'd640;
            VPU_cfg_h_sync            <= 12'd96;
            VPU_cfg_h_backporch       <= 12'd48;
            VPU_cfg_v_active          <= 12'd480;
            VPU_cfg_v_sync            <= 12'd2;
            VPU_cfg_v_backporch       <= 12'd33;
            VPU_cfg_force_interlaced  <= 1'b0;
            VPU_cfg_force_progressive <= 1'b0;
            VPU_cfg_ignore_de         <= 1'b0;
        end else if (wb_stb_i && wb_we_i) begin
            case (wb_adr_i)
                4'h0: VPU_cfg_h_active          <= wb_dat_i[11:0];
                4'h1: VPU_cfg_h_sync            <= wb_dat_i[11:0];
                4'h2: VPU_cfg_h_backporch       <= wb_dat_i[11:0];
                4'h3: VPU_cfg_v_active          <= wb_dat_i[11:0];
                4'h4: VPU_cfg_v_sync            <= wb_dat_i[11:0];
                4'h5: VPU_cfg_v_backporch       <= wb_dat_i[11:0];
                4'h6: begin
                    VPU_cfg_force_interlaced  <= wb_dat_i[0];
                    VPU_cfg_force_progressive <= wb_dat_i[1];
                    VPU_cfg_ignore_de         <= wb_dat_i[2];
                end
            endcase
        end
    end
    
    // Read back
    always @(*) begin
        case (wb_adr_i)
            4'h0: wb_dat_o = {20'b0, VPU_cfg_h_active};
            4'h1: wb_dat_o = {20'b0, VPU_cfg_h_sync};
            4'h2: wb_dat_o = {20'b0, VPU_cfg_h_backporch};
            4'h3: wb_dat_o = {20'b0, VPU_cfg_v_active};
            4'h4: wb_dat_o = {20'b0, VPU_cfg_v_sync};
            4'h5: wb_dat_o = {20'b0, VPU_cfg_v_backporch};
            4'h6: wb_dat_o = {29'b0, VPU_cfg_ignore_de, 
                                    VPU_cfg_force_progressive,
                                    VPU_cfg_force_interlaced};
            default: wb_dat_o = 32'b0;
        endcase
    end
endmodule
```

---

## Module Port Template

### Full VPU-Compatible Module (with Configuration)
```verilog
module vpu_<module_name> #(
    parameter PIXEL_WIDTH = 24
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // VPU Input Stream
    input  wire                    VPU_in_valid,
    input  wire [PIXEL_WIDTH-1:0]  VPU_in_pixel,
    output wire                    VPU_in_ready,        // Optional
    input  wire                    VPU_in_frame_start,
    input  wire                    VPU_in_line_start,
    input  wire                    VPU_in_interlaced,   // Optional
    input  wire                    VPU_in_field_id,     // Optional
    input  wire [11:0]             VPU_in_h_count,      // Optional
    input  wire [11:0]             VPU_in_v_count,      // Optional
    input  wire [11:0]             VPU_in_h_active,     // Optional
    input  wire [11:0]             VPU_in_v_active,     // Optional

    // VPU Output Stream
    output wire                    VPU_out_valid,
    output wire [PIXEL_WIDTH-1:0]  VPU_out_pixel,
    input  wire                    VPU_out_ready,       // Optional
    output wire                    VPU_out_frame_start,
    output wire                    VPU_out_line_start,
    output wire                    VPU_out_interlaced,  // Optional
    output wire                    VPU_out_field_id,    // Optional
    output wire [11:0]             VPU_out_h_count,     // Optional
    output wire [11:0]             VPU_out_v_count,     // Optional
    output wire [11:0]             VPU_out_h_active,    // Optional
    output wire [11:0]             VPU_out_v_active,    // Optional

    // VPU Configuration (from Wishbone/AXI bridge)
    input  wire [11:0]             VPU_cfg_param1,      // Module-specific
    input  wire [11:0]             VPU_cfg_param2,      // Module-specific
    input  wire                    VPU_cfg_enable,      // Common
    input  wire                    VPU_cfg_bypass       // Common
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
    input  wire                    VPU_in_valid,
    input  wire [PIXEL_WIDTH-1:0]  VPU_in_pixel,
    input  wire                    VPU_in_frame_start,
    input  wire                    VPU_in_line_start,

    // VPU Output
    output wire                    VPU_out_valid,
    output wire [PIXEL_WIDTH-1:0]  VPU_out_pixel,
    output wire                    VPU_out_frame_start,
    output wire                    VPU_out_line_start
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
assign VPU_out_interlaced = VPU_in_interlaced;
assign VPU_out_field_id   = VPU_in_field_id;
assign VPU_out_h_active   = VPU_in_h_active;
assign VPU_out_v_active   = VPU_in_v_active;
```

### 2. Pipeline Stage (1-cycle delay)
```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        VPU_out_valid       <= 1'b0;
        VPU_out_pixel       <= {PIXEL_WIDTH{1'b0}};
        VPU_out_frame_start <= 1'b0;
        VPU_out_line_start  <= 1'b0;
    end else begin
        VPU_out_valid       <= VPU_in_valid;
        VPU_out_pixel       <= processed_pixel;  // Your processing
        VPU_out_frame_start <= VPU_in_frame_start;
        VPU_out_line_start  <= VPU_in_line_start;
    end
end
```

### 3. Format Conversion (e.g., Deinterlacer)
```verilog
// Input is interlaced, output is progressive
assign VPU_out_interlaced = 1'b0;                    // Always progressive
assign VPU_out_v_active   = VPU_in_v_active << 1;    // Double vertical resolution
```

### 4. Configuration Latching (Frame-Sync)
```verilog
reg [11:0] active_h_active;
reg [11:0] active_v_active;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        active_h_active <= 12'd640;
        active_v_active <= 12'd480;
    end else if (VPU_in_frame_start && VPU_in_valid) begin
        // Latch new config at frame boundary
        active_h_active <= VPU_cfg_h_active;
        active_v_active <= VPU_cfg_v_active;
    end
end
```

### 5. Bypass Mode
```verilog
assign VPU_out_valid       = VPU_in_valid;
assign VPU_out_pixel       = VPU_cfg_bypass ? VPU_in_pixel : processed_pixel;
assign VPU_out_frame_start = VPU_in_frame_start;
assign VPU_out_line_start  = VPU_in_line_start;
```

---

## Example Pipeline
```
┌──────────────┐    ┌───────────────┐    ┌─────────────┐    ┌──────────┐    ┌──────────┐
│ SyncDecoder  │──▶│ Deinterlacer  │──▶│   Scaler    │──▶│Compositor│──▶│  DVIout  │──▶ Display
└──────────────┘    └───────────────┘    └─────────────┘    └──────────┘    └──────────┘
       ▲                   ▲                   ▲                  ▲
       │                   │                   │                  │
   VPU_cfg_*           VPU_cfg_*           VPU_cfg_*          VPU_cfg_*
       │                   │                   │                  │
       └───────────────────┴───────────────────┴──────────────────┘
                                    │
                           Wishbone / AXI Bus
```

All modules use VPU bus for video data and receive configuration from a shared system bus.

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
    output wire                    VPU_out_valid,
    output wire [PIXEL_WIDTH-1:0]  VPU_out_pixel,
    output wire                    VPU_out_line_start,
    output wire                    VPU_out_frame_start
);
    // Simple renaming
    assign VPU_out_valid       = pixel_valid;
    assign VPU_out_pixel       = pixel_data;
    assign VPU_out_line_start  = line_start;
    assign VPU_out_frame_start = frame_start;
endmodule
```

---

## Reference Implementations

| Module | Description | VPU Features Used |
|--------|-------------|-------------------|
| **SyncDecoder** | Converts HSYNC/VSYNC to VPU bus | Full output, timing config |
| **Deinterlacer** | Bob deinterlacing (interlaced → progressive) | Full I/O, format metadata |
| **Scaler** | Resolution scaling | Full I/O, scaler config |
| **Compositor** | Layer compositing with OSD | Full I/O, layer config |
| **VPU-to-DVI** | Output adapter for DVI/HDMI TX | Input only | (Todo)

---

## Version History

- **v1.0** (2025-01-01): Initial specification
  - Core data stream signals
  - Frame synchronization
  - Scan format metadata
  - Position tracking
  - Resolution metadata

- **v1.1** (2025-02-08): Configuration interface
  - Updated naming scheme to VPU in all caps
  - Added configuration signals (`VPU_cfg_*`) for module parameters
  - Added system integration section with Wishbone bridge example
  - Added common configuration signals (enable, bypass, frame_sync)
  - Added configuration latching pattern (frame-sync)
  - Updated module port template with configuration inputs
  - Added reference implementation table

---

## License

MIT License
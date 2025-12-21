# VideoBuffer IP Core

Configurable line buffer and frame buffer for FPGA video processing.

## Features

✅ Line buffer mode (low latency streaming)  
✅ Frame buffer mode (random access)  
✅ Runtime reconfigurable width/height/depth  
✅ Fully tested with comprehensive testbenches
❌ Framebuffer mode not implemented with external ram yet

## Quick Start

### Use as Verilog Source

Add `src/VideoBuffer.v` to your project:

```Verilog
VideoBuffer #(
    .MAX_WIDTH(1920),
    .MAX_HEIGHT(1080),
    .USE_LINE_BUFFER(1),
    .USE_FRAME_BUFFER(0)
) u_buffer (
    .clk(clk),
    .rst_n(rst_n),
    .cfg_width(16'd1920),
    .cfg_height(16'd1080),
    // ... connect your signals
);
```

### Package as Vivado IP

Then add `ip_repo/` to your Vivado project IP repositories.

## Parameters

| Name | Default | Description |
|------|---------|-------------|
| MAX_WIDTH | 1920 | Maximum supported width |
| MAX_HEIGHT | 1080 | Maximum supported height |
| PIXEL_WIDTH | 24 | Bits per pixel |
| MAX_NUM_LINES | 8 | Max line buffer depth |
| USE_LINE_BUFFER | 1 | Compile-time enable |
| USE_FRAME_BUFFER | 0 | Compile-time enable |

## License

MIT License - see [LICENSE](LICENSE)



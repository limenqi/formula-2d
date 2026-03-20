# Formula-2D — FPGA Racing Game

A hardware-accelerated 2D racing game implemented on a Zynq FPGA using Vivado.

---

## Repository Structure

```
vivado/
├── InfoProcTopLevel.xpr                        # Vivado project file (open this in Vivado)
├── top_design.bit                              # Prebuilt bitstream (ready to flash)
├── top_design.hwh                              # Hardware handoff file (for Pynq/Jupyter)
├── top_design.tcl                              # TCL script to regenerate the block design
│
├── InfoProcTopLevel.srcs/sources_1/bd/top_design/
│   ├── top_design.bd                           # Block design
│   ├── imports/hdl/top_design_wrapper.v        # Top-level HDL wrapper
│   └── ip/                                     # IP instance configs (.xci)
│
├── ip_repo/physics_axi_ip/physics_axi_ip_1.0/ # Physics Engine custom IP
│   ├── hdl/                                    # AXI wrapper (top-level + slave interface)
│   ├── src/                                    # Physics RTL source files
│   │   ├── physics_top.v
│   │   ├── collision_response.v
│   │   ├── heading_update.v
│   │   ├── motion_update.v
│   │   ├── speed_update.v
│   │   ├── dir_lut.v
│   │   ├── track_lookup.v
│   │   └── *.mem                               # sin/cos/track lookup tables
│   └── drivers/physics_axi_ip_v1_0/src/       # C driver (.h / .c)
│
└── racing_axi/racing_axi.srcs/sources_1/imports/filles_axi/   # Renderer custom IP
    ├── racing_renderer_axi.v                   # Top-level AXI wrapper
    ├── axi_registers.v
    ├── tile_renderer.v
    ├── sprite_overlay.v
    ├── hdmi_out.v
    ├── vga_timing.v
    ├── tmds_encoder.v
    ├── clock_gen.v
    └── *.hex                                   # Tilemap, tileset, sprite graphics data
```

---

## Custom IPs

| IP | Location | Description |
|----|----------|-------------|
| Physics Engine | `vivado/ip_repo/physics_axi_ip/physics_axi_ip_1.0/` | AXI-connected IP handling car physics (motion, collision, heading) |
| Renderer | `vivado/racing_axi/racing_axi.srcs/sources_1/imports/filles_axi/` | AXI-connected IP rendering tiles, sprites and HDMI output |

---

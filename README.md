# Formula-2D — FPGA Racing Game

A hardware-accelerated 2D racing game implemented on a Zynq FPGA using Vivado.

---

## Repository Structure

```
vivado/
├── InfoProcTopLevel.xpr          # Vivado project file (open this in Vivado)
├── top_design.bit                # Prebuilt bitstream (ready to flash)
├── top_design.hwh                # Hardware handoff file (for Pynq/Jupyter)
├── top_design.tcl                # TCL script to regenerate the block design
├── InfoProcTopLevel.srcs/        # All HDL source files
│   └── sources_1/                # Top-level and supporting RTL sources
├── ip_repo/                      # Custom IP: Physics Engine (AXI)
│   └── physics_axi_ip/
│       └── physics_axi_ip_1.0/
│           ├── hdl/              # RTL source for physics IP
│           └── xgui/             # Vivado GUI config
└── racing_axi/                   # Custom IP: Renderer (AXI)
    ├── hdl/                      # RTL source for renderer IP
    └── xgui/                     # Vivado GUI config
```

---

## Custom IPs

| IP | Folder | Description |
|----|--------|-------------|
| Physics Engine | `vivado/ip_repo/physics_axi_ip/` | Handles car physics over AXI interface |
| Renderer | `vivado/racing_axi/` | Renders the 2D racing scene over AXI interface |

---

## How to Open the Project

1. Open **Vivado**
2. Click **Open Project** and select `vivado/InfoProcTopLevel.xpr`
3. The custom IPs will be resolved automatically from `ip_repo/` and `racing_axi/`

> To rebuild the block design from scratch, run `vivado/top_design.tcl` via **Tools → Run Tcl Script**

---

## Flashing the Bitstream

Use the prebuilt `top_design.bit` and `top_design.hwh` with Pynq:

```python
from pynq import Overlay
ol = Overlay("top_design.bit")
```

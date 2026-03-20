## ============================================================================
## PYNQ-Z1 Constraints for Racing Renderer (AXI Block Design version)
## ============================================================================
## Port names have _0 suffix to match Block Design's auto-generated names.
## No sysclk — the Zynq PS handles the clock.
## ============================================================================

## ── TMDS Clock ──
set_property -dict { PACKAGE_PIN L16  IOSTANDARD TMDS_33 } [get_ports { tmds_clk_p_0 }];
set_property -dict { PACKAGE_PIN L17  IOSTANDARD TMDS_33 } [get_ports { tmds_clk_n_0 }];

## ── TMDS Data Channel 0 (Blue) ──
set_property -dict { PACKAGE_PIN K17  IOSTANDARD TMDS_33 } [get_ports { tmds_data_p_0[0] }];
set_property -dict { PACKAGE_PIN K18  IOSTANDARD TMDS_33 } [get_ports { tmds_data_n_0[0] }];

## ── TMDS Data Channel 1 (Green) ──
set_property -dict { PACKAGE_PIN K19  IOSTANDARD TMDS_33 } [get_ports { tmds_data_p_0[1] }];
set_property -dict { PACKAGE_PIN J19  IOSTANDARD TMDS_33 } [get_ports { tmds_data_n_0[1] }];

## ── TMDS Data Channel 2 (Red) ──
set_property -dict { PACKAGE_PIN J18  IOSTANDARD TMDS_33 } [get_ports { tmds_data_p_0[2] }];
set_property -dict { PACKAGE_PIN H18  IOSTANDARD TMDS_33 } [get_ports { tmds_data_n_0[2] }];

## ── Config ──
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

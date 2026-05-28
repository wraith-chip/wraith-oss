# SPDX-License-Identifier: MIT
# pins.xdc — Pin mappings for Husk on VCU118
# Copyright (c) 2026 Pradyun Narkadamilli

set_property IOSTANDARD LVCMOS12 [get_ports wraith*]
set_property IOSTANDARD LVCMOS12 [get_ports dbus*]
set_property IOSTANDARD LVCMOS12 [get_ports rvtu*]
set_property IOSTANDARD LVCMOS12 [get_ports fb*]
set_property IOSTANDARD LVCMOS12 [get_ports {led[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports rst]
set_false_path -reset_path -from rst -through *
set_false_path -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks mmcm_clkout0]
set_clock_groups -asynchronous -group [get_clocks mmcm_clkout0] -group [get_clocks clk_out1_clk_wiz_0]

set_property PACKAGE_PIN L19 [get_ports rst]
set_property PACKAGE_PIN AL31 [get_ports wraith_clk]
set_property PACKAGE_PIN R11 [get_ports wraith_rst]
set_property PACKAGE_PIN AA13 [get_ports {dbus[0]}]
set_property PACKAGE_PIN AJ32 [get_ports {dbus[1]}]
set_property PACKAGE_PIN W14 [get_ports {dbus[2]}]
set_property PACKAGE_PIN R14 [get_ports {dbus[3]}]
set_property PACKAGE_PIN AL35 [get_ports {dbus[4]}]
set_property PACKAGE_PIN AR37 [get_ports {dbus[5]}]
set_property PACKAGE_PIN N14 [get_ports {dbus[6]}]
set_property PACKAGE_PIN V15 [get_ports {dbus[7]}]
set_property PACKAGE_PIN AT39 [get_ports {dbus[8]}]
set_property PACKAGE_PIN AG31 [get_ports {dbus[9]}]
set_property PACKAGE_PIN R31 [get_ports {dbus[10]}]
set_property PACKAGE_PIN N32 [get_ports {dbus[11]}]
set_property PACKAGE_PIN Y32 [get_ports {dbus[12]}]
set_property PACKAGE_PIN K11 [get_ports {dbus[13]}]
set_property PACKAGE_PIN K12 [get_ports {dbus[14]}]
set_property PACKAGE_PIN L14 [get_ports {dbus[15]}]
set_property PACKAGE_PIN K14 [get_ports {dbus[16]}]
set_property PACKAGE_PIN M15 [get_ports {dbus[17]}]
set_property PACKAGE_PIN P15 [get_ports {dbus[18]}]
set_property PACKAGE_PIN M13 [get_ports {dbus[19]}]
set_property PACKAGE_PIN AJ35 [get_ports {dbus[20]}]
set_property PACKAGE_PIN V33 [get_ports {dbus[21]}]
set_property PACKAGE_PIN N33 [get_ports {dbus[22]}]
set_property PACKAGE_PIN V32 [get_ports {dbus[23]}]
set_property PACKAGE_PIN L34 [get_ports {dbus[24]}]
set_property PACKAGE_PIN L33 [get_ports {dbus[25]}]
set_property PACKAGE_PIN Y34 [get_ports {dbus[26]}]
set_property PACKAGE_PIN P37 [get_ports {dbus[27]}]
set_property PACKAGE_PIN N38 [get_ports {dbus[28]}]
set_property PACKAGE_PIN T34 [get_ports {dbus[29]}]
set_property PACKAGE_PIN U35 [get_ports {dbus[30]}]
set_property PACKAGE_PIN M36 [get_ports {dbus[31]}]
set_property PACKAGE_PIN U11 [get_ports rvtu_0_rst]
set_property PACKAGE_PIN AK29 [get_ports rvtu_1_rst]
set_property PACKAGE_PIN V13 [get_ports {dbus_fsm[0]}]
set_property PACKAGE_PIN T16 [get_ports {dbus_fsm[1]}]
set_property PACKAGE_PIN AP38 [get_ports {dbus_fsm[2]}]
set_property PACKAGE_PIN AJ33 [get_ports fb_d_out]
set_property PACKAGE_PIN T14 [get_ports fb_d_out_vld]
set_property PACKAGE_PIN AG32 [get_ports fb_d_clsc]
set_property PACKAGE_PIN AP35 [get_ports fb_d_in]
set_property PACKAGE_PIN AH33 [get_ports fb_d_in_vld]
set_property PACKAGE_PIN AJ30 [get_ports fb_en]
set_property PACKAGE_PIN L35 [get_ports wraith_pwr]

set_property PACKAGE_PIN AT32 [get_ports {led[0]}]
set_property PACKAGE_PIN AV34 [get_ports {led[1]}]
set_property PACKAGE_PIN AY30 [get_ports {led[2]}]
set_property PACKAGE_PIN BB32 [get_ports {led[3]}]
set_property PACKAGE_PIN BF32 [get_ports {led[4]}]
set_property PACKAGE_PIN AU37 [get_ports {led[5]}]
set_property PACKAGE_PIN AV36 [get_ports {led[6]}]
set_property PACKAGE_PIN BA37 [get_ports {led[7]}]

# Clock definition for forwarded clock
create_generated_clock -name wraith_clk -source [get_pins clk_out_oddr/C] -divide_by 1 [get_ports wraith_clk]

# 1ns input delay on everything coming FROM WRAITH
set_input_delay -clock wraith_clk 1.000 dbus_fsm[0]
set_input_delay -clock wraith_clk 1.000 dbus_fsm[1]
set_input_delay -clock wraith_clk 1.000 dbus_fsm[2]
set_input_delay -clock wraith_clk 1.000 fb_d_out
set_input_delay -clock wraith_clk 1.000 fb_d_out_vld
set_input_delay -clock wraith_clk 1.000 fb_d_clsc

# 1ns output delay on everything going TO WRAITH
set_output_delay -clock wraith_clk 1.000 wraith_rst
set_output_delay -clock wraith_clk 1.000 wraith_pwr
set_output_delay -clock wraith_clk 1.000 rvtu_0_rst
set_output_delay -clock wraith_clk 1.000 rvtu_1_rst
set_output_delay -clock wraith_clk 1.000 fb_d_in
set_output_delay -clock wraith_clk 1.000 fb_d_in_vld
set_output_delay -clock wraith_clk 1.000 fb_en

set_input_delay -clock wraith_clk 1.800 dbus[0]
set_input_delay -clock wraith_clk 1.800 dbus[1]
set_input_delay -clock wraith_clk 1.800 dbus[2]
set_input_delay -clock wraith_clk 1.800 dbus[3]
set_input_delay -clock wraith_clk 1.800 dbus[4]
set_input_delay -clock wraith_clk 1.800 dbus[5]
set_input_delay -clock wraith_clk 1.800 dbus[6]
set_input_delay -clock wraith_clk 1.800 dbus[7]
set_input_delay -clock wraith_clk 1.800 dbus[8]
set_input_delay -clock wraith_clk 1.800 dbus[9]
set_input_delay -clock wraith_clk 1.800 dbus[10]
set_input_delay -clock wraith_clk 1.800 dbus[11]
set_input_delay -clock wraith_clk 1.800 dbus[12]
set_input_delay -clock wraith_clk 1.800 dbus[13]
set_input_delay -clock wraith_clk 1.800 dbus[14]
set_input_delay -clock wraith_clk 1.800 dbus[15]
set_input_delay -clock wraith_clk 1.800 dbus[16]
set_input_delay -clock wraith_clk 1.800 dbus[17]
set_input_delay -clock wraith_clk 1.800 dbus[18]
set_input_delay -clock wraith_clk 1.800 dbus[19]
set_input_delay -clock wraith_clk 1.800 dbus[20]
set_input_delay -clock wraith_clk 1.800 dbus[21]
set_input_delay -clock wraith_clk 1.800 dbus[22]
set_input_delay -clock wraith_clk 1.800 dbus[23]
set_input_delay -clock wraith_clk 1.800 dbus[24]
set_input_delay -clock wraith_clk 1.800 dbus[25]
set_input_delay -clock wraith_clk 1.800 dbus[26]
set_input_delay -clock wraith_clk 1.800 dbus[27]
set_input_delay -clock wraith_clk 1.800 dbus[28]
set_input_delay -clock wraith_clk 1.800 dbus[29]
set_input_delay -clock wraith_clk 1.800 dbus[30]
set_input_delay -clock wraith_clk 1.800 dbus[31]

set_output_delay -clock wraith_clk 1.000 dbus[0]
set_output_delay -clock wraith_clk 1.000 dbus[1]
set_output_delay -clock wraith_clk 1.000 dbus[2]
set_output_delay -clock wraith_clk 1.000 dbus[3]
set_output_delay -clock wraith_clk 1.000 dbus[4]
set_output_delay -clock wraith_clk 1.000 dbus[5]
set_output_delay -clock wraith_clk 1.000 dbus[6]
set_output_delay -clock wraith_clk 1.000 dbus[7]
set_output_delay -clock wraith_clk 1.000 dbus[8]
set_output_delay -clock wraith_clk 1.000 dbus[9]
set_output_delay -clock wraith_clk 1.000 dbus[10]
set_output_delay -clock wraith_clk 1.000 dbus[11]
set_output_delay -clock wraith_clk 1.000 dbus[12]
set_output_delay -clock wraith_clk 1.000 dbus[13]
set_output_delay -clock wraith_clk 1.000 dbus[14]
set_output_delay -clock wraith_clk 1.000 dbus[15]
set_output_delay -clock wraith_clk 1.000 dbus[16]
set_output_delay -clock wraith_clk 1.000 dbus[17]
set_output_delay -clock wraith_clk 1.000 dbus[18]
set_output_delay -clock wraith_clk 1.000 dbus[19]
set_output_delay -clock wraith_clk 1.000 dbus[20]
set_output_delay -clock wraith_clk 1.000 dbus[21]
set_output_delay -clock wraith_clk 1.000 dbus[22]
set_output_delay -clock wraith_clk 1.000 dbus[23]
set_output_delay -clock wraith_clk 1.000 dbus[24]
set_output_delay -clock wraith_clk 1.000 dbus[25]
set_output_delay -clock wraith_clk 1.000 dbus[26]
set_output_delay -clock wraith_clk 1.000 dbus[27]
set_output_delay -clock wraith_clk 1.000 dbus[28]
set_output_delay -clock wraith_clk 1.000 dbus[29]
set_output_delay -clock wraith_clk 1.000 dbus[30]
set_output_delay -clock wraith_clk 1.000 dbus[31]

# make this more conservative if going to use
# set_max_delay -datapath_only -from [get_pins {husk_bridge/dbus_dir_reg[31]/C}] -to [get_ports {dbus[31]}] 6.000
# set_max_delay -datapath_only -from [get_pins {husk_bridge/dbus_dir_reg[30]/C}] -to [get_ports {dbus[30]}] 6.000
# set_max_delay -datapath_only -from [get_pins {husk_bridge/dbus_dir_reg[29]/C}] -to [get_ports {dbus[29]}] 6.000
# set_max_delay -datapath_only -from [get_pins {husk_bridge/dbus_dir_reg[28]/C}] -to [get_ports {dbus[28]}] 6.000
# set_max_delay -datapath_only -from [get_pins {husk_bridge/dbus_dir_reg[27]/C}] -to [get_ports {dbus[27]}] 6.000
# set_max_delay -datapath_only -from [get_pins {husk_bridge/dbus_dir_reg[26]/C}] -to [get_ports {dbus[26]}] 6.000

####################################################################################
# Constraints from file : 'husk_bd_microblaze_riscv_0_axi_periph_imp_auto_cc_0_clocks.xdc'
####################################################################################


####################################################################################
# Constraints from file : 'husk_bd_microblaze_riscv_0_axi_periph_imp_auto_cc_0_clocks.xdc'
####################################################################################

set_property ASYNC_REG true [get_cells {husk_bridge/req_chain_reg[0]}]
set_property ASYNC_REG true [get_cells {husk_bridge/req_chain_reg[1]}]

####################################################################################
# Constraints from file : 'husk_bd_microblaze_riscv_0_axi_periph_imp_auto_cc_0_clocks.xdc'
####################################################################################

current_instance husk_soc/ddr4_0/inst
set_property LOC MMCM_X0Y2 [get_cells -hier -filter {NAME =~ */u_ddr4_infrastructure/gen_mmcme*.u_mmcme_adv_inst}]
current_instance -quiet
set_property INTERNAL_VREF 0.84 [get_iobanks 42]
set_property INTERNAL_VREF 0.84 [get_iobanks 40]

set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]

# ----------------------------------------------------------------------------
#
#        ** **        **          **  ****      **  **********  ********** �
#       **   **        **        **   ** **     **  **              **
#      **     **        **      **    **  **    **  **              **
#     **       **        **    **     **   **   **  *********       **
#    **         **        **  **      **    **  **  **              **
#   **           **        ****       **     ** **  **              **
#  **  .........  **        **        **      ****  **********      **
#     ...........
#                                     Reach Further�
#
# ----------------------------------------------------------------------------
# 
#  This design is the property of Avnet.  Publication of this
#  design is not authorized without written consent from Avnet.
# 
#  Please direct any questions to the Avnet Technical Community:
#     http://minized.org/forums/zed-english-forum
# 
#  Product information is available at:
#     http://minized.org
# 
#  Disclaimer:
#     Avnet, Inc. makes no warranty for the use of this code or design.
#     This code is provided  "As Is". Avnet, Inc assumes no responsibility for
#     any errors, which may appear in this code, nor does it make a commitment
#     to update the information contained herein. Avnet, Inc specifically
#     disclaims any implied warranties of fitness for a particular purpose.
#                      Copyright(c) 2017 Avnet, Inc.
#                              All rights reserved.
# 
# ----------------------------------------------------------------------------
# 
#  Create Date:         July 05, 2017
#  Design Name:         MiniZed Sensor Fusion
#  Module Name:         minized_sensor_fusion.tcl
#  Project Name:        minized_sensor_fusion
#  Target Devices:      Xilinx Zynq-7000
#  Hardware Boards:     MiniZed
# 
#  Tool versions:       Xilinx Vivado 2017.1
# 
#  Description:         MiniZed Sensor Fusion hardware platform for I2C 
#                       sensor Pmods
# 
#  Dependencies:        To be called from a configured make script call
#                       Calls support scripts, such as board configuration 
#                       scripts IP generation scripts or others as needed     
#
#  Revision:            Jul 05, 2017: 1.00 Initial version
# 
# ----------------------------------------------------------------------------
#
# 'private' used to allow this project to be privately tagged
# 'public' used to allow this project to be publicly tagged
set release_state public

if {[string match -nocase "yes" $clean]} {
   # Clean up project output products.

   # Open the existing project.
   puts "***** Opening Vivado Project $projects_folder/$project.xpr ..."
   open_project $projects_folder/$project.xpr
   
   # Reset output products.
   reset_target all [get_files ${projects_folder}/${project}.srcs/sources_1/bd/${project}/${project}.bd]

   # Reset design runs.
   reset_run impl_1
   reset_run synth_1

   # Reset project.
   reset_project
} else {
# Create Vivado project
puts "***** Creating Vivado Project..."
source ../Boards/$board/$board.tcl -notrace
avnet_create_project $project $projects_folder $scriptdir
# Remove the SOM specific XDC file since no constraints are needed for 
# the basic system design
remove_files -fileset constrs_1 *.xdc

# Apply board specific project property settings
switch -nocase $board {
   MINIZED {
      puts "***** Assigning Vivado Project board_part Property to minized..."
      set_property board_part em.avnet.com:minized:part0:1.2 [current_project]
   }
   MINIZED7010 {
      puts "***** Assigning Vivado Project board_part Property to minized7z010..."
      set_property board_part em.avnet.com:minized7z010:part0:1.1 [current_project]
   }
}

# Generate Avnet IP
# puts "***** Generating MiniZed microphone_mgr IP..."
# source ./makeip.tcl -notrace
# avnet_generate_ip microphone_mgr

# Add Avnet IP Repository
# The IP_REPO_PATHS looks for a <component>.xml file, where <component> is the name of the IP to add to the catalog. The XML file identifies the various files that define the IP.
# The IP_REPO_PATHS property does not have to point directly at the XML file for each IP in the repository.
# The IP catalog searches through the sub-folders of the specified IP repositories, looking for IP to add to the catalog. 
puts "***** Updating Vivado to include IP Folder"
cd ../Projects/$project
set_property ip_repo_paths  ../../IP [current_fileset]
update_ip_catalog

# Create Block Design and Add PS core
puts "***** Creating Block Design..."
create_bd_design ${project}
set design_name ${project}
# avnet_add_custom_ps $project $projects_folder $scriptdir

# Add preset IP from board definitions
# avnet_add_user_io_preset $project $projects_folder $scriptdir

# General Config
puts "***** General Configuration for Design..."
set_property target_language VHDL [current_project]

# Add Minized-specific RTL design sources
# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
set files_hdl [list \
 "[file normalize "../../IP/minized/hdl/vhdl/microphone_mgr.vhd"]"\
 "[file normalize "../../IP/minized/hdl/vhdl/arduino_mgr.vhd"]"\
 "[file normalize "../../IP/minized/hdl/vhdl/wireless_mgr.vhd"]"\
 "[file normalize "../../IP/minized/hdl/vhdl/led_mgr.vhd"]"\
]
# For PetaLinux 2017.2 or later, any IP module that is derived from through 
# the use RTL-based IP modules without having to go through the process of 
# packaging the RTL as an IP to be added through the Vivado IP catalog will
# need to have the soruce copied into the project folder otherwise a missing
# file reference will be encountered when opening the project outside of the
# original build context.  Although Avnet would prefer that users take 
# advantage of the inherant benefits of building the hardware platform from 
# our freely provided, public revision controlled source repository, which is  
# the preferred method for recreating a project, this is a workaround used to 
# maintain the appearance of equivalence with other board manufacturers who 
# do not follow revision control methodology and provide customers a hardware
# platform as part of the PetaLinux BSP deliverable.
#add_files -copy_to ${projects_folder}/${project}.srcs/sources_1/bd/${project}/hdl/ -norecurse -fileset $obj $files
add_files -norecurse -scan_for_includes -fileset $obj $files_hdl
import_files -force -norecurse 

# Add RTL-based IP modules without having to go through the process of packaging the RTL as an IP to be added through the Vivado IP catalog. 
# See chap 12 'Referencing RTL Modules' https://www.xilinx.com/support/documentation/sw_manuals/xilinx2017_1/ug994-vivado-ip-subsystems.pdf

source ../../Scripts/make_RTL_ip.tcl
avnet_generate_RTL_ip microphone_mgr microphone_mgr_0
avnet_generate_RTL_ip arduino_mgr arduino_mgr_0
avnet_generate_RTL_ip wireless_mgr wireless_mgr_0
avnet_generate_RTL_ip led_mgr led_mgr_0

# -------------------------------------------------------------------------------------------------------------------------------------------
# Start insert Stefan May 20 'hdl.zip'

  # Create interface ports
  set DDR [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR ]
  set FIXED_IO [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO ]
  set iic_rtl_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 iic_rtl_0 ]
  set iic_rtl_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 iic_rtl_1 ]
  set iic_rtl_2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 iic_rtl_2 ]
  set pl_sw_1bit [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 pl_sw_1bit ]

  # Create ports
  set ARD_ADDR0 [ create_bd_port -dir I ARD_ADDR0 ]
  set ARD_ADDR1 [ create_bd_port -dir I ARD_ADDR1 ]
  set ARD_ADDR2 [ create_bd_port -dir O ARD_ADDR2 ]
  set ARD_DAT0 [ create_bd_port -dir O ARD_DAT0 ]
  set ARD_DAT1 [ create_bd_port -dir O ARD_DAT1 ]
  set ARD_DAT2 [ create_bd_port -dir O ARD_DAT2 ]
  set ARD_DAT3 [ create_bd_port -dir O ARD_DAT3 ]
  set ARD_DAT4 [ create_bd_port -dir I ARD_DAT4 ]
  set ARD_DAT5 [ create_bd_port -dir I ARD_DAT5 ]
  set ARD_DAT6 [ create_bd_port -dir I ARD_DAT6 ]
  set ARD_DAT7 [ create_bd_port -dir O ARD_DAT7 ]
  set ARD_DAT8 [ create_bd_port -dir O ARD_DAT8 ]
  set ARD_DAT9 [ create_bd_port -dir O ARD_DAT9 ]
  set ARD_DAT10 [ create_bd_port -dir O ARD_DAT10 ]
  set ARD_DAT11 [ create_bd_port -dir O ARD_DAT11 ]
  set ARD_DAT12 [ create_bd_port -dir O ARD_DAT12 ]
  set ARD_DAT13 [ create_bd_port -dir O ARD_DAT13 ]
  set AUDIO_CLK [ create_bd_port -dir O -type clk AUDIO_CLK ]
  set AUDIO_DAT [ create_bd_port -dir I AUDIO_DAT ]
  set BT_CTS_IN_N [ create_bd_port -dir O BT_CTS_IN_N ]
  set BT_HOST_WAKE [ create_bd_port -dir I BT_HOST_WAKE ]
  set BT_REG_ON [ create_bd_port -dir O BT_REG_ON ]
  set BT_RTS_OUT_N [ create_bd_port -dir I BT_RTS_OUT_N ]
  set BT_RXD_IN [ create_bd_port -dir O BT_RXD_IN ]
  set BT_TXD_OUT [ create_bd_port -dir I BT_TXD_OUT ]
  set PL_LED_G [ create_bd_port -dir O PL_LED_G ]
  set PL_LED_R [ create_bd_port -dir O PL_LED_R ]
  set WL_HOST_WAKE [ create_bd_port -dir I WL_HOST_WAKE ]
  set WL_REG_ON [ create_bd_port -dir O WL_REG_ON ]
  set WL_SDIO_CLK [ create_bd_port -dir O -type clk WL_SDIO_CLK ]
  set WL_SDIO_CMD [ create_bd_port -dir IO WL_SDIO_CMD ]
  set WL_SDIO_DAT [ create_bd_port -dir IO -from 3 -to 0 WL_SDIO_DAT ]

  
  # Create instance: axi_gpio_0, and set properties
  set axi_gpio_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0 ]
  set_property -dict [ list \
CONFIG.C_ALL_INPUTS_2 {0} \
CONFIG.C_ALL_OUTPUTS {1} \
CONFIG.C_ALL_OUTPUTS_2 {1} \
CONFIG.C_GPIO2_WIDTH {1} \
CONFIG.C_GPIO_WIDTH {1} \
CONFIG.C_IS_DUAL {1} \
CONFIG.GPIO_BOARD_INTERFACE {Custom} \
CONFIG.USE_BOARD_FLOW {true} \
 ] $axi_gpio_0

  # Create instance: axi_gpio_1, and set properties
  set axi_gpio_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_1 ]
  set_property -dict [ list \
CONFIG.C_ALL_INPUTS {1} \
CONFIG.C_GPIO_WIDTH {1} \
CONFIG.GPIO_BOARD_INTERFACE {pl_sw_1bit} \
CONFIG.USE_BOARD_FLOW {true} \
 ] $axi_gpio_1

  # Create instance: axi_gpio_2, and set properties
  set axi_gpio_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_2 ]
  set_property -dict [ list \
CONFIG.C_GPIO_WIDTH {8} \
 ] $axi_gpio_2

  # Create instance: axi_iic_0, and set properties
  set axi_iic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.0 axi_iic_0 ]

    # Create instance: axi_iic_1, and set properties
  set axi_iic_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.0 axi_iic_1 ]

    # Create instance: axi_iic_2, and set properties
  set axi_iic_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.0 axi_iic_2 ]

  # Create AXI UART 16550 instance and set properties
  set bluetooth_uart [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uart16550:2.0 axi_uart16550_0 ]
  set_property name bluetooth_uart [get_bd_cells axi_uart16550_0]
  set_property -dict [ list \
 CONFIG.C_HAS_EXTERNAL_XIN {1} \
 CONFIG.C_EXTERNAL_XIN_CLK_HZ_d {48} \
 CONFIG.C_EXTERNAL_XIN_CLK_HZ {48000000}
  ] $bluetooth_uart
  
# Create instance: ila_0, and set properties
# Capture raw PDM (single-bit) output of mic -- this can be used to export raw PDM to Simulink model as input stimulus
# Note: PDM data from the mic is collected into 1024-bit vectors in microphone_mgr_0 code
#       ... this is done to maximize usage of BRAM storage, otherwise would max out if captured as single-bits
#       ... must de-serialize when reading into MATLAB
# When capturing data in ILA, use microphone_mgr_0/PDM_vector_full_STROBE to qualify capture control to PDM capture at output sample rate of 160MHz/64 = 2.5 MSPS in 160 MHz clock domain

  set ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_0 ]
  set_property -dict [ list \
CONFIG.ALL_PROBE_SAME_MU_CNT {2} \
CONFIG.C_ENABLE_ILA_AXI_MON {false} \
CONFIG.C_EN_STRG_QUAL {1} \
CONFIG.C_MONITOR_TYPE {Native} \
CONFIG.C_NUM_OF_PROBES {3} \
CONFIG.C_PROBE0_MU_CNT {2} \
CONFIG.C_PROBE1_MU_CNT {2} \
CONFIG.C_PROBE1_TYPE {1} \
CONFIG.C_PROBE1_WIDTH {1024} \
CONFIG.C_PROBE2_MU_CNT {2} \
CONFIG.C_PROBE2_TYPE {1} \
 ] $ila_0

# Create instance: ila_1, and set properties
# Capture audio output of mic
# When capturing data in ILA, use CE from pdm_filter_sysgen to qualify capture control to capture audio data at output sample rate of 160MHz/(64*64) = 39.0625 KSPS in 160 MHz clock domain

  set ila_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_1 ]
  set_property -dict [ list \
CONFIG.ALL_PROBE_SAME_MU_CNT {2} \
CONFIG.C_DATA_DEPTH {32768} \
CONFIG.C_ENABLE_ILA_AXI_MON {false} \
CONFIG.C_EN_STRG_QUAL {1} \
CONFIG.C_MONITOR_TYPE {Native} \
CONFIG.C_NUM_OF_PROBES {3} \
CONFIG.C_PROBE0_MU_CNT {2} \
CONFIG.C_PROBE1_MU_CNT {2} \
CONFIG.C_PROBE1_TYPE {1} \
CONFIG.C_PROBE1_WIDTH {16} \
CONFIG.C_PROBE2_TYPE {2} \
 ] $ila_1

  
  # Create instance: microphone_mgr_0, and set properties
  # set microphone_mgr_0 [ create_bd_cell -type ip -vlnv avnet.com:ip:microphone_mgr:1.0 microphone_mgr_0 ]

  # Create instance: pdm_filter_sysgen_0, and set properties
  set pdm_filter_sysgen_0 [ create_bd_cell -type ip -vlnv Avnet_Inc:SysGen:pdm_filter_sysgen:1.0 pdm_filter_sysgen_0 ]

  
  # Create instance: processing_system7_0, and set properties
  set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]
  set_property -dict [ list \
CONFIG.PCW_ACT_CAN_PERIPHERAL_FREQMHZ {10.000000} \
CONFIG.PCW_ACT_DCI_PERIPHERAL_FREQMHZ {10.158730} \
CONFIG.PCW_ACT_ENET0_PERIPHERAL_FREQMHZ {10.000000} \
CONFIG.PCW_ACT_ENET1_PERIPHERAL_FREQMHZ {10.000000} \
CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ {100.000000} \
CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ {48.000000} \
CONFIG.PCW_ACT_FPGA2_PERIPHERAL_FREQMHZ {160.000000} \
CONFIG.PCW_ACT_FPGA3_PERIPHERAL_FREQMHZ {10.000000} \
CONFIG.PCW_ACT_PCAP_PERIPHERAL_FREQMHZ {200.000000} \
CONFIG.PCW_ACT_QSPI_PERIPHERAL_FREQMHZ {123.076920} \
CONFIG.PCW_ACT_SDIO_PERIPHERAL_FREQMHZ {25.396826} \
CONFIG.PCW_ACT_SMC_PERIPHERAL_FREQMHZ {10.000000} \
CONFIG.PCW_ACT_SPI_PERIPHERAL_FREQMHZ {10.000000} \
CONFIG.PCW_ACT_TPIU_PERIPHERAL_FREQMHZ {200.000000} \
CONFIG.PCW_ACT_UART_PERIPHERAL_FREQMHZ {100.000000} \
CONFIG.PCW_APU_CLK_RATIO_ENABLE {6:2:1} \
CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {666.666666} \
CONFIG.PCW_CAN0_PERIPHERAL_CLKSRC {External} \
CONFIG.PCW_CAN0_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_CAN1_PERIPHERAL_CLKSRC {External} \
CONFIG.PCW_CAN1_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_CAN_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_CLK0_FREQ {100000000} \
CONFIG.PCW_CLK1_FREQ {48000000} \
CONFIG.PCW_CLK2_FREQ {160000000} \
CONFIG.PCW_CLK3_FREQ {10000000} \
CONFIG.PCW_CPU_CPU_6X4X_MAX_RANGE {667} \
CONFIG.PCW_CPU_PERIPHERAL_CLKSRC {ARM PLL} \
CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ {33.333333} \
CONFIG.PCW_DCI_PERIPHERAL_CLKSRC {DDR PLL} \
CONFIG.PCW_DCI_PERIPHERAL_FREQMHZ {10.159} \
CONFIG.PCW_DDR_PERIPHERAL_CLKSRC {DDR PLL} \
CONFIG.PCW_DDR_RAM_HIGHADDR {0x1FFFFFFF} \
CONFIG.PCW_DM_WIDTH {2} \
CONFIG.PCW_DQS_WIDTH {2} \
CONFIG.PCW_DQ_WIDTH {16} \
CONFIG.PCW_ENET0_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_ENET1_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_ENET1_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_ENET_RESET_POLARITY {Active Low} \
CONFIG.PCW_EN_4K_TIMER {0} \
CONFIG.PCW_EN_CLK1_PORT {1} \
CONFIG.PCW_EN_CLK2_PORT {1} \
CONFIG.PCW_EN_EMIO_CD_SDIO0 {1} \
CONFIG.PCW_EN_EMIO_CD_SDIO1 {1} \
CONFIG.PCW_EN_EMIO_GPIO {1} \
CONFIG.PCW_EN_EMIO_I2C0 {0} \
CONFIG.PCW_EN_EMIO_MODEM_UART0 {1} \
CONFIG.PCW_EN_EMIO_SDIO0 {1} \
CONFIG.PCW_EN_EMIO_UART0 {1} \
CONFIG.PCW_EN_EMIO_WP_SDIO0 {1} \
CONFIG.PCW_EN_EMIO_WP_SDIO1 {1} \
CONFIG.PCW_EN_GPIO {1} \
CONFIG.PCW_EN_I2C0 {0} \
CONFIG.PCW_EN_MODEM_UART0 {1} \
CONFIG.PCW_EN_QSPI {1} \
CONFIG.PCW_EN_RST2_PORT {1} \
CONFIG.PCW_EN_SDIO0 {1} \
CONFIG.PCW_EN_SDIO1 {1} \
CONFIG.PCW_EN_UART0 {1} \
CONFIG.PCW_EN_UART1 {1} \
CONFIG.PCW_EN_USB0 {1} \
CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_FCLK0_PERIPHERAL_DIVISOR0 {8} \
CONFIG.PCW_FCLK1_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_FCLK1_PERIPHERAL_DIVISOR0 {15} \
CONFIG.PCW_FCLK2_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_FCLK2_PERIPHERAL_DIVISOR0 {5} \
CONFIG.PCW_FCLK2_PERIPHERAL_DIVISOR1 {2} \
CONFIG.PCW_FCLK3_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_FCLK_CLK0_BUF {TRUE} \
CONFIG.PCW_FCLK_CLK1_BUF {TRUE} \
CONFIG.PCW_FCLK_CLK2_BUF {TRUE} \
CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {48} \
CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {160} \
CONFIG.PCW_FPGA3_PERIPHERAL_FREQMHZ {50} \
CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
CONFIG.PCW_FPGA_FCLK1_ENABLE {1} \
CONFIG.PCW_FPGA_FCLK2_ENABLE {1} \
CONFIG.PCW_FTM_CTI_IN0 {<Select>} \
CONFIG.PCW_FTM_CTI_IN1 {<Select>} \
CONFIG.PCW_FTM_CTI_IN2 {<Select>} \
CONFIG.PCW_FTM_CTI_IN3 {<Select>} \
CONFIG.PCW_FTM_CTI_OUT0 {<Select>} \
CONFIG.PCW_FTM_CTI_OUT1 {<Select>} \
CONFIG.PCW_FTM_CTI_OUT2 {<Select>} \
CONFIG.PCW_FTM_CTI_OUT3 {<Select>} \
CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {1} \
CONFIG.PCW_GPIO_EMIO_GPIO_IO {4} \
CONFIG.PCW_GPIO_EMIO_GPIO_WIDTH {4} \
CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1} \
CONFIG.PCW_GPIO_MIO_GPIO_IO {MIO} \
CONFIG.PCW_GPIO_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_I2C0_RESET_ENABLE {0} \
CONFIG.PCW_I2C1_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_I2C_PERIPHERAL_FREQMHZ {25} \
CONFIG.PCW_I2C_RESET_ENABLE {1} \
CONFIG.PCW_I2C_RESET_POLARITY {Active Low} \
CONFIG.PCW_IOPLL_CTRL_FBDIV {48} \
CONFIG.PCW_IO_IO_PLL_FREQMHZ {1600.000} \
CONFIG.PCW_IRQ_F2P_INTR {1} \
CONFIG.PCW_MIO_0_DIRECTION {inout} \
CONFIG.PCW_MIO_0_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_0_PULLUP {enabled} \
CONFIG.PCW_MIO_0_SLEW {slow} \
CONFIG.PCW_MIO_10_DIRECTION {inout} \
CONFIG.PCW_MIO_10_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_10_PULLUP {enabled} \
CONFIG.PCW_MIO_10_SLEW {slow} \
CONFIG.PCW_MIO_11_DIRECTION {inout} \
CONFIG.PCW_MIO_11_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_11_PULLUP {enabled} \
CONFIG.PCW_MIO_11_SLEW {slow} \
CONFIG.PCW_MIO_12_DIRECTION {inout} \
CONFIG.PCW_MIO_12_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_12_PULLUP {enabled} \
CONFIG.PCW_MIO_12_SLEW {slow} \
CONFIG.PCW_MIO_13_DIRECTION {inout} \
CONFIG.PCW_MIO_13_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_13_PULLUP {enabled} \
CONFIG.PCW_MIO_13_SLEW {slow} \
CONFIG.PCW_MIO_14_DIRECTION {inout} \
CONFIG.PCW_MIO_14_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_14_PULLUP {enabled} \
CONFIG.PCW_MIO_14_SLEW {slow} \
CONFIG.PCW_MIO_15_DIRECTION {inout} \
CONFIG.PCW_MIO_15_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_15_PULLUP {enabled} \
CONFIG.PCW_MIO_15_SLEW {slow} \
CONFIG.PCW_MIO_1_DIRECTION {out} \
CONFIG.PCW_MIO_1_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_1_PULLUP {enabled} \
CONFIG.PCW_MIO_1_SLEW {slow} \
CONFIG.PCW_MIO_28_DIRECTION {inout} \
CONFIG.PCW_MIO_28_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_28_PULLUP {enabled} \
CONFIG.PCW_MIO_28_SLEW {slow} \
CONFIG.PCW_MIO_29_DIRECTION {in} \
CONFIG.PCW_MIO_29_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_29_PULLUP {enabled} \
CONFIG.PCW_MIO_29_SLEW {slow} \
CONFIG.PCW_MIO_2_DIRECTION {inout} \
CONFIG.PCW_MIO_2_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_2_PULLUP {disabled} \
CONFIG.PCW_MIO_2_SLEW {slow} \
CONFIG.PCW_MIO_30_DIRECTION {out} \
CONFIG.PCW_MIO_30_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_30_PULLUP {enabled} \
CONFIG.PCW_MIO_30_SLEW {slow} \
CONFIG.PCW_MIO_31_DIRECTION {in} \
CONFIG.PCW_MIO_31_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_31_PULLUP {enabled} \
CONFIG.PCW_MIO_31_SLEW {slow} \
CONFIG.PCW_MIO_32_DIRECTION {inout} \
CONFIG.PCW_MIO_32_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_32_PULLUP {enabled} \
CONFIG.PCW_MIO_32_SLEW {slow} \
CONFIG.PCW_MIO_33_DIRECTION {inout} \
CONFIG.PCW_MIO_33_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_33_PULLUP {enabled} \
CONFIG.PCW_MIO_33_SLEW {slow} \
CONFIG.PCW_MIO_34_DIRECTION {inout} \
CONFIG.PCW_MIO_34_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_34_PULLUP {enabled} \
CONFIG.PCW_MIO_34_SLEW {slow} \
CONFIG.PCW_MIO_35_DIRECTION {inout} \
CONFIG.PCW_MIO_35_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_35_PULLUP {enabled} \
CONFIG.PCW_MIO_35_SLEW {slow} \
CONFIG.PCW_MIO_36_DIRECTION {in} \
CONFIG.PCW_MIO_36_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_36_PULLUP {enabled} \
CONFIG.PCW_MIO_36_SLEW {slow} \
CONFIG.PCW_MIO_37_DIRECTION {inout} \
CONFIG.PCW_MIO_37_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_37_PULLUP {enabled} \
CONFIG.PCW_MIO_37_SLEW {slow} \
CONFIG.PCW_MIO_38_DIRECTION {inout} \
CONFIG.PCW_MIO_38_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_38_PULLUP {enabled} \
CONFIG.PCW_MIO_38_SLEW {slow} \
CONFIG.PCW_MIO_39_DIRECTION {inout} \
CONFIG.PCW_MIO_39_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_39_PULLUP {enabled} \
CONFIG.PCW_MIO_39_SLEW {slow} \
CONFIG.PCW_MIO_3_DIRECTION {inout} \
CONFIG.PCW_MIO_3_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_3_PULLUP {disabled} \
CONFIG.PCW_MIO_3_SLEW {slow} \
CONFIG.PCW_MIO_48_DIRECTION {out} \
CONFIG.PCW_MIO_48_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_48_PULLUP {enabled} \
CONFIG.PCW_MIO_48_SLEW {slow} \
CONFIG.PCW_MIO_49_DIRECTION {in} \
CONFIG.PCW_MIO_49_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_49_PULLUP {enabled} \
CONFIG.PCW_MIO_49_SLEW {slow} \
CONFIG.PCW_MIO_4_DIRECTION {inout} \
CONFIG.PCW_MIO_4_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_4_PULLUP {disabled} \
CONFIG.PCW_MIO_4_SLEW {slow} \
CONFIG.PCW_MIO_52_DIRECTION {inout} \
CONFIG.PCW_MIO_52_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_52_PULLUP {enabled} \
CONFIG.PCW_MIO_52_SLEW {slow} \
CONFIG.PCW_MIO_53_DIRECTION {inout} \
CONFIG.PCW_MIO_53_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_53_PULLUP {enabled} \
CONFIG.PCW_MIO_53_SLEW {slow} \
CONFIG.PCW_MIO_5_DIRECTION {inout} \
CONFIG.PCW_MIO_5_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_5_PULLUP {disabled} \
CONFIG.PCW_MIO_5_SLEW {slow} \
CONFIG.PCW_MIO_6_DIRECTION {out} \
CONFIG.PCW_MIO_6_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_6_PULLUP {disabled} \
CONFIG.PCW_MIO_6_SLEW {slow} \
CONFIG.PCW_MIO_7_DIRECTION {out} \
CONFIG.PCW_MIO_7_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_7_PULLUP {disabled} \
CONFIG.PCW_MIO_7_SLEW {slow} \
CONFIG.PCW_MIO_8_DIRECTION {out} \
CONFIG.PCW_MIO_8_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_8_PULLUP {disabled} \
CONFIG.PCW_MIO_8_SLEW {slow} \
CONFIG.PCW_MIO_9_DIRECTION {inout} \
CONFIG.PCW_MIO_9_IOTYPE {LVCMOS 3.3V} \
CONFIG.PCW_MIO_9_PULLUP {enabled} \
CONFIG.PCW_MIO_9_SLEW {slow} \
CONFIG.PCW_MIO_PRIMITIVE {32} \
CONFIG.PCW_MIO_TREE_PERIPHERALS {GPIO#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#USB Reset#Quad SPI Flash#GPIO#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#UART 1#UART 1#Unbonded#Unbonded#GPIO#GPIO} \
CONFIG.PCW_MIO_TREE_SIGNALS {gpio[0]#qspi0_ss_b#qspi0_io[0]#qspi0_io[1]#qspi0_io[2]#qspi0_io[3]#qspi0_sclk#reset#qspi_fbclk#gpio[9]#data[0]#cmd#clk#data[1]#data[2]#data[3]#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#data[4]#dir#stp#nxt#data[0]#data[1]#data[2]#data[3]#clk#data[5]#data[6]#data[7]#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#Unbonded#tx#rx#Unbonded#Unbonded#gpio[52]#gpio[53]} \
CONFIG.PCW_NAND_CYCLES_T_AR {1} \
CONFIG.PCW_NAND_CYCLES_T_CLR {1} \
CONFIG.PCW_NAND_CYCLES_T_RC {11} \
CONFIG.PCW_NAND_CYCLES_T_REA {1} \
CONFIG.PCW_NAND_CYCLES_T_RR {1} \
CONFIG.PCW_NAND_CYCLES_T_WC {11} \
CONFIG.PCW_NAND_CYCLES_T_WP {1} \
CONFIG.PCW_NOR_CS0_T_CEOE {1} \
CONFIG.PCW_NOR_CS0_T_PC {1} \
CONFIG.PCW_NOR_CS0_T_RC {11} \
CONFIG.PCW_NOR_CS0_T_TR {1} \
CONFIG.PCW_NOR_CS0_T_WC {11} \
CONFIG.PCW_NOR_CS0_T_WP {1} \
CONFIG.PCW_NOR_CS0_WE_TIME {0} \
CONFIG.PCW_NOR_CS1_T_CEOE {1} \
CONFIG.PCW_NOR_CS1_T_PC {1} \
CONFIG.PCW_NOR_CS1_T_RC {11} \
CONFIG.PCW_NOR_CS1_T_TR {1} \
CONFIG.PCW_NOR_CS1_T_WC {11} \
CONFIG.PCW_NOR_CS1_T_WP {1} \
CONFIG.PCW_NOR_CS1_WE_TIME {0} \
CONFIG.PCW_NOR_SRAM_CS0_T_CEOE {1} \
CONFIG.PCW_NOR_SRAM_CS0_T_PC {1} \
CONFIG.PCW_NOR_SRAM_CS0_T_RC {11} \
CONFIG.PCW_NOR_SRAM_CS0_T_TR {1} \
CONFIG.PCW_NOR_SRAM_CS0_T_WC {11} \
CONFIG.PCW_NOR_SRAM_CS0_T_WP {1} \
CONFIG.PCW_NOR_SRAM_CS0_WE_TIME {0} \
CONFIG.PCW_NOR_SRAM_CS1_T_CEOE {1} \
CONFIG.PCW_NOR_SRAM_CS1_T_PC {1} \
CONFIG.PCW_NOR_SRAM_CS1_T_RC {11} \
CONFIG.PCW_NOR_SRAM_CS1_T_TR {1} \
CONFIG.PCW_NOR_SRAM_CS1_T_WC {11} \
CONFIG.PCW_NOR_SRAM_CS1_T_WP {1} \
CONFIG.PCW_NOR_SRAM_CS1_WE_TIME {0} \
CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY0 {0.468} \
CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY1 {0.475} \
CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY2 {0.510} \
CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY3 {0.625} \
CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_0 {-0.034} \
CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_1 {-0.025} \
CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_2 {-0.050} \
CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_3 {-0.230} \
CONFIG.PCW_PACKAGE_NAME {clg225} \
CONFIG.PCW_PCAP_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_PCAP_PERIPHERAL_DIVISOR0 {8} \
CONFIG.PCW_PCAP_PERIPHERAL_FREQMHZ {200} \
CONFIG.PCW_PJTAG_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_PLL_BYPASSMODE_ENABLE {0} \
CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V} \
CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 3.3V} \
CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE {1} \
CONFIG.PCW_QSPI_GRP_FBCLK_IO {MIO 8} \
CONFIG.PCW_QSPI_GRP_IO1_ENABLE {0} \
CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {1} \
CONFIG.PCW_QSPI_GRP_SINGLE_SS_IO {MIO 1 .. 6} \
CONFIG.PCW_QSPI_GRP_SS1_ENABLE {0} \
CONFIG.PCW_QSPI_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_QSPI_PERIPHERAL_DIVISOR0 {13} \
CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {1} \
CONFIG.PCW_QSPI_PERIPHERAL_FREQMHZ {120} \
CONFIG.PCW_QSPI_QSPI_IO {MIO 1 .. 6} \
CONFIG.PCW_SD0_GRP_CD_ENABLE {1} \
CONFIG.PCW_SD0_GRP_CD_IO {EMIO} \
CONFIG.PCW_SD0_GRP_POW_ENABLE {0} \
CONFIG.PCW_SD0_GRP_WP_ENABLE {1} \
CONFIG.PCW_SD0_GRP_WP_IO {EMIO} \
CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1} \
CONFIG.PCW_SD0_SD0_IO {EMIO} \
CONFIG.PCW_SD1_GRP_CD_ENABLE {1} \
CONFIG.PCW_SD1_GRP_CD_IO {EMIO} \
CONFIG.PCW_SD1_GRP_POW_ENABLE {0} \
CONFIG.PCW_SD1_GRP_WP_ENABLE {1} \
CONFIG.PCW_SD1_GRP_WP_IO {EMIO} \
CONFIG.PCW_SD1_PERIPHERAL_ENABLE {1} \
CONFIG.PCW_SD1_SD1_IO {MIO 10 .. 15} \
CONFIG.PCW_SDIO_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_SDIO_PERIPHERAL_DIVISOR0 {63} \
CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ {25} \
CONFIG.PCW_SDIO_PERIPHERAL_VALID {1} \
CONFIG.PCW_SMC_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_SPI0_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_SPI1_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_SPI_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
CONFIG.PCW_S_AXI_HP1_DATA_WIDTH {64} \
CONFIG.PCW_S_AXI_HP2_DATA_WIDTH {64} \
CONFIG.PCW_S_AXI_HP3_DATA_WIDTH {64} \
CONFIG.PCW_TPIU_PERIPHERAL_CLKSRC {External} \
CONFIG.PCW_TRACE_INTERNAL_WIDTH {2} \
CONFIG.PCW_TRACE_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_TTC0_CLK0_PERIPHERAL_CLKSRC {CPU_1X} \
CONFIG.PCW_TTC0_CLK0_PERIPHERAL_DIVISOR0 {1} \
CONFIG.PCW_TTC0_CLK1_PERIPHERAL_CLKSRC {CPU_1X} \
CONFIG.PCW_TTC0_CLK1_PERIPHERAL_DIVISOR0 {1} \
CONFIG.PCW_TTC0_CLK2_PERIPHERAL_CLKSRC {CPU_1X} \
CONFIG.PCW_TTC0_CLK2_PERIPHERAL_DIVISOR0 {1} \
CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_TTC1_CLK0_PERIPHERAL_CLKSRC {CPU_1X} \
CONFIG.PCW_TTC1_CLK0_PERIPHERAL_DIVISOR0 {1} \
CONFIG.PCW_TTC1_CLK1_PERIPHERAL_CLKSRC {CPU_1X} \
CONFIG.PCW_TTC1_CLK1_PERIPHERAL_DIVISOR0 {1} \
CONFIG.PCW_TTC1_CLK2_PERIPHERAL_CLKSRC {CPU_1X} \
CONFIG.PCW_TTC1_CLK2_PERIPHERAL_DIVISOR0 {1} \
CONFIG.PCW_TTC1_PERIPHERAL_ENABLE {0} \
CONFIG.PCW_UART0_BAUD_RATE {115200} \
CONFIG.PCW_UART0_GRP_FULL_ENABLE {1} \
CONFIG.PCW_UART0_GRP_FULL_IO {EMIO} \
CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1} \
CONFIG.PCW_UART0_UART0_IO {EMIO} \
CONFIG.PCW_UART1_BAUD_RATE {115200} \
CONFIG.PCW_UART1_GRP_FULL_ENABLE {0} \
CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \
CONFIG.PCW_UART1_UART1_IO {MIO 48 .. 49} \
CONFIG.PCW_UART_PERIPHERAL_CLKSRC {IO PLL} \
CONFIG.PCW_UART_PERIPHERAL_DIVISOR0 {16} \
CONFIG.PCW_UART_PERIPHERAL_FREQMHZ {100} \
CONFIG.PCW_UART_PERIPHERAL_VALID {1} \
CONFIG.PCW_UIPARAM_DDR_ADV_ENABLE {0} \
CONFIG.PCW_UIPARAM_DDR_AL {0} \
CONFIG.PCW_UIPARAM_DDR_BL {8} \
CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 {0.234} \
CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 {0.234} \
CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY2 {0.100} \
CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY3 {0.100} \
CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {16 Bit} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_0_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PACKAGE_LENGTH {470.0} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_1_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PACKAGE_LENGTH {470.0} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_2_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PACKAGE_LENGTH {470.0} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_3_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PACKAGE_LENGTH {470.0} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_CLOCK_STOP_EN {0} \
CONFIG.PCW_UIPARAM_DDR_DEVICE_CAPACITY {4096 MBits} \
CONFIG.PCW_UIPARAM_DDR_DQS_0_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_DQS_0_PACKAGE_LENGTH {504} \
CONFIG.PCW_UIPARAM_DDR_DQS_0_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_DQS_1_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_DQS_1_PACKAGE_LENGTH {495} \
CONFIG.PCW_UIPARAM_DDR_DQS_1_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_DQS_2_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_DQS_2_PACKAGE_LENGTH {520} \
CONFIG.PCW_UIPARAM_DDR_DQS_2_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_DQS_3_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_DQS_3_PACKAGE_LENGTH {700} \
CONFIG.PCW_UIPARAM_DDR_DQS_3_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 {0.054} \
CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 {0.054} \
CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_2 {0.0} \
CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_3 {0.0} \
CONFIG.PCW_UIPARAM_DDR_DQ_0_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_DQ_0_PACKAGE_LENGTH {465} \
CONFIG.PCW_UIPARAM_DDR_DQ_0_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_DQ_1_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_DQ_1_PACKAGE_LENGTH {480} \
CONFIG.PCW_UIPARAM_DDR_DQ_1_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_DQ_2_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_DQ_2_PACKAGE_LENGTH {550} \
CONFIG.PCW_UIPARAM_DDR_DQ_2_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_DQ_3_LENGTH_MM {0} \
CONFIG.PCW_UIPARAM_DDR_DQ_3_PACKAGE_LENGTH {780} \
CONFIG.PCW_UIPARAM_DDR_DQ_3_PROPOGATION_DELAY {160} \
CONFIG.PCW_UIPARAM_DDR_DRAM_WIDTH {16 Bits} \
CONFIG.PCW_UIPARAM_DDR_ENABLE {1} \
CONFIG.PCW_UIPARAM_DDR_FREQ_MHZ {533.333333} \
CONFIG.PCW_UIPARAM_DDR_HIGH_TEMP {Normal (0-85)} \
CONFIG.PCW_UIPARAM_DDR_MEMORY_TYPE {DDR 3 (Low Voltage)} \
CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41K256M16 RE-125} \
CONFIG.PCW_UIPARAM_DDR_ROW_ADDR_COUNT {15} \
CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE {1} \
CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE {1} \
CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL {1} \
CONFIG.PCW_UIPARAM_DDR_T_FAW {40.0} \
CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF {0} \
CONFIG.PCW_USB0_PERIPHERAL_ENABLE {1} \
CONFIG.PCW_USB0_RESET_ENABLE {1} \
CONFIG.PCW_USB0_RESET_IO {MIO 7} \
CONFIG.PCW_USB0_USB0_IO {MIO 28 .. 39} \
CONFIG.PCW_USB_RESET_ENABLE {1} \
CONFIG.PCW_USB_RESET_POLARITY {Active Low} \
CONFIG.PCW_USB_RESET_SELECT {Share reset pin} \
CONFIG.PCW_USE_CROSS_TRIGGER {0} \
CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
CONFIG.PCW_USE_M_AXI_GP0 {1} \
CONFIG.PCW_WDT_PERIPHERAL_CLKSRC {CPU_1X} \
CONFIG.PCW_WDT_PERIPHERAL_DIVISOR0 {1} \
CONFIG.PCW_WDT_PERIPHERAL_ENABLE {0} \
 ] $processing_system7_0

  # Create instance: ps7_0_axi_periph, and set properties
  set ps7_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps7_0_axi_periph ]
  set_property -dict [ list \
CONFIG.NUM_MI {07} \
 ] $ps7_0_axi_periph

  # Create instance: rst_ps7_0_50M, and set properties
  set rst_ps7_0_50M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_50M ]
  
  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [ list \
CONFIG.NUM_PORTS {9} \
 ] $xlconcat_0

  # Create interface connections
  connect_bd_intf_net -intf_net axi_gpio_1_GPIO [get_bd_intf_ports pl_sw_1bit] [get_bd_intf_pins axi_gpio_1/GPIO]
  connect_bd_intf_net -intf_net axi_iic_0_IIC [get_bd_intf_ports iic_rtl_0] [get_bd_intf_pins axi_iic_0/IIC]
  connect_bd_intf_net -intf_net axi_iic_1_IIC [get_bd_intf_ports iic_rtl_1] [get_bd_intf_pins axi_iic_1/IIC]
  connect_bd_intf_net -intf_net axi_iic_2_IIC [get_bd_intf_ports iic_rtl_2] [get_bd_intf_pins axi_iic_2/IIC]
  connect_bd_intf_net -intf_net processing_system7_0_DDR [get_bd_intf_ports DDR] [get_bd_intf_pins processing_system7_0/DDR]
  connect_bd_intf_net -intf_net processing_system7_0_FIXED_IO [get_bd_intf_ports FIXED_IO] [get_bd_intf_pins processing_system7_0/FIXED_IO]
  connect_bd_intf_net -intf_net processing_system7_0_M_AXI_GP0 [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins ps7_0_axi_periph/S00_AXI]
  connect_bd_intf_net -intf_net ps7_0_axi_periph_M00_AXI [get_bd_intf_pins axi_gpio_0/S_AXI] [get_bd_intf_pins ps7_0_axi_periph/M00_AXI]
  connect_bd_intf_net -intf_net ps7_0_axi_periph_M01_AXI [get_bd_intf_pins axi_gpio_1/S_AXI] [get_bd_intf_pins ps7_0_axi_periph/M01_AXI]
  connect_bd_intf_net -intf_net ps7_0_axi_periph_M02_AXI [get_bd_intf_pins axi_iic_0/S_AXI] [get_bd_intf_pins ps7_0_axi_periph/M02_AXI]
  connect_bd_intf_net -intf_net ps7_0_axi_periph_M03_AXI [get_bd_intf_pins axi_gpio_2/S_AXI] [get_bd_intf_pins ps7_0_axi_periph/M03_AXI]
  connect_bd_intf_net -intf_net ps7_0_axi_periph_M04_AXI [get_bd_intf_pins bluetooth_uart/S_AXI] [get_bd_intf_pins ps7_0_axi_periph/M04_AXI]
  connect_bd_intf_net -intf_net ps7_0_axi_periph_M05_AXI [get_bd_intf_pins axi_iic_1/S_AXI] [get_bd_intf_pins ps7_0_axi_periph/M05_AXI]
  connect_bd_intf_net -intf_net ps7_0_axi_periph_M06_AXI [get_bd_intf_pins axi_iic_2/S_AXI] [get_bd_intf_pins ps7_0_axi_periph/M06_AXI]
	
  # Create port connections
  connect_bd_net -net ARD_ADDR0_1 [get_bd_ports ARD_ADDR0] [get_bd_pins arduino_mgr_0/ARD_ADDR0]
  connect_bd_net -net ARD_ADDR1_1 [get_bd_ports ARD_ADDR1] [get_bd_pins arduino_mgr_0/ARD_ADDR1]
  connect_bd_net -net ARD_DAT4_1 [get_bd_ports ARD_DAT4] [get_bd_pins arduino_mgr_0/ARD_DAT4]
  connect_bd_net -net ARD_DAT5_1 [get_bd_ports ARD_DAT5] [get_bd_pins arduino_mgr_0/ARD_DAT5]
  connect_bd_net -net ARD_DAT6_1 [get_bd_ports ARD_DAT6] [get_bd_pins arduino_mgr_0/ARD_DAT6]
  connect_bd_net -net AUDIO_DAT_1 [get_bd_ports AUDIO_DAT] [get_bd_pins microphone_mgr_0/AUDIO_DAT] [get_bd_pins pmod2_mgr_0/AUDIO_DAT_in]
  connect_bd_net -net BT_HOST_WAKE_1 [get_bd_ports BT_HOST_WAKE] [get_bd_pins wireless_mgr_0/BT_HOST_WAKE]
  connect_bd_net -net BT_RTS_OUT_N_1 [get_bd_ports BT_RTS_OUT_N] [get_bd_pins wireless_mgr_0/BT_RTS_OUT_N]
  connect_bd_net -net BT_TXD_OUT_1 [get_bd_ports BT_TXD_OUT] [get_bd_pins wireless_mgr_0/BT_TXD_OUT]
  connect_bd_net -net Net [get_bd_ports WL_SDIO_CMD] [get_bd_pins wireless_mgr_0/WL_SDIO_CMD]
  connect_bd_net -net Net1 [get_bd_ports WL_SDIO_DAT] [get_bd_pins wireless_mgr_0/WL_SDIO_DAT]
  connect_bd_net -net WL_HOST_WAKE_1 [get_bd_ports WL_HOST_WAKE] [get_bd_pins wireless_mgr_0/WL_HOST_WAKE]
  connect_bd_net -net arduino_mgr_0_ARD_ADDR2 [get_bd_ports ARD_ADDR2] [get_bd_pins arduino_mgr_0/ARD_ADDR2]
  connect_bd_net -net arduino_mgr_0_ARD_DAT0 [get_bd_ports ARD_DAT0] [get_bd_pins arduino_mgr_0/ARD_DAT0]
  connect_bd_net -net arduino_mgr_0_ARD_DAT1 [get_bd_ports ARD_DAT1] [get_bd_pins arduino_mgr_0/ARD_DAT1]
  connect_bd_net -net arduino_mgr_0_ARD_DAT2 [get_bd_ports ARD_DAT2] [get_bd_pins arduino_mgr_0/ARD_DAT2]
  connect_bd_net -net arduino_mgr_0_ARD_DAT3 [get_bd_ports ARD_DAT3] [get_bd_pins arduino_mgr_0/ARD_DAT3]
  connect_bd_net -net arduino_mgr_0_ARD_DAT7 [get_bd_ports ARD_DAT7] [get_bd_pins arduino_mgr_0/ARD_DAT7]
  connect_bd_net -net arduino_mgr_0_ARD_DAT8 [get_bd_ports ARD_DAT8] [get_bd_pins arduino_mgr_0/ARD_DAT8]
  connect_bd_net -net arduino_mgr_0_ARD_DAT9 [get_bd_ports ARD_DAT9] [get_bd_pins arduino_mgr_0/ARD_DAT9]
  connect_bd_net -net arduino_mgr_0_ARD_DAT10 [get_bd_ports ARD_DAT10] [get_bd_pins arduino_mgr_0/ARD_DAT10]
  connect_bd_net -net arduino_mgr_0_ARD_DAT11 [get_bd_ports ARD_DAT11] [get_bd_pins arduino_mgr_0/ARD_DAT11]
  connect_bd_net -net arduino_mgr_0_ARD_DAT12 [get_bd_ports ARD_DAT12] [get_bd_pins arduino_mgr_0/ARD_DAT12]
  connect_bd_net -net arduino_mgr_0_ARD_DAT13 [get_bd_ports ARD_DAT13] [get_bd_pins arduino_mgr_0/ARD_DAT13]
  connect_bd_net -net arduino_mgr_0_HTS221_DRDY [get_bd_pins arduino_mgr_0/HTS221_DRDY] [get_bd_pins xlconcat_0/In6]
  connect_bd_net -net arduino_mgr_0_LIS3MDL_DRDY [get_bd_pins arduino_mgr_0/LIS3MDL_DRDY] [get_bd_pins xlconcat_0/In8]
  connect_bd_net -net arduino_mgr_0_LIS3MDL_INT1 [get_bd_pins arduino_mgr_0/LIS3MDL_INT1] [get_bd_pins xlconcat_0/In7]
  connect_bd_net -net arduino_mgr_0_LPS25H_INT1 [get_bd_pins arduino_mgr_0/LPS25H_INT1] [get_bd_pins xlconcat_0/In5]
  connect_bd_net -net arduino_mgr_0_LSM6DS0_INT1 [get_bd_pins arduino_mgr_0/LSM6DS0_INT1] [get_bd_pins xlconcat_0/In4]
  connect_bd_net -net axi_gpio_0_gpio2_io_o [get_bd_pins axi_gpio_0/gpio2_io_o] [get_bd_pins led_mgr_0/CPU_PL_LED_R]
  connect_bd_net -net axi_gpio_0_gpio_io_o [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins led_mgr_0/CPU_PL_LED_G]
  connect_bd_net -net axi_gpio_2_gpio_io_o [get_bd_pins axi_gpio_2/gpio_io_o] [get_bd_pins led_mgr_0/GPIO_from_Zynq]
  connect_bd_net -net axi_gpio_2_gpio_io_t [get_bd_pins axi_gpio_2/gpio_io_t] [get_bd_pins led_mgr_0/GPIO_dir]
  connect_bd_net -net axi_iic_0_iic2intc_irpt [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net axi_iic_1_iic2intc_irpt [get_bd_pins axi_iic_1/iic2intc_irpt] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net axi_iic_2_iic2intc_irpt [get_bd_pins axi_iic_2/iic2intc_irpt] [get_bd_pins xlconcat_0/In3]
  connect_bd_net -net bluetooth_uart_INT [get_bd_pins bluetooth_uart/ip2intc_irpt] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net led_mgr_0_GPIO_to_Zynq [get_bd_pins axi_gpio_2/gpio_io_i] [get_bd_pins led_mgr_0/GPIO_to_Zynq]
  connect_bd_net -net led_mgr_0_PL_LED_G [get_bd_ports PL_LED_G] [get_bd_pins led_mgr_0/PL_LED_G]
  connect_bd_net -net led_mgr_0_PL_LED_R [get_bd_ports PL_LED_R] [get_bd_pins led_mgr_0/PL_LED_R]
  connect_bd_net -net led_mgr_0_USER_TRIGGER [get_bd_pins ila_1/probe2] [get_bd_pins led_mgr_0/USER_TRIGGER]
  connect_bd_net -net microphone_mgr_0_AUDIO_CLK [get_bd_ports AUDIO_CLK] [get_bd_pins microphone_mgr_0/AUDIO_CLK] [get_bd_pins pmod2_mgr_0/AUDIO_CLK_in]
  connect_bd_net -net microphone_mgr_0_AUDIO_PDM [get_bd_pins microphone_mgr_0/AUDIO_PDM] [get_bd_pins pdm_filter_sysgen_0/pdm_in]
  connect_bd_net -net microphone_mgr_0_PDM_vector_full_STROBE [get_bd_pins ila_0/probe0] [get_bd_pins microphone_mgr_0/PDM_vector_full_STROBE]
  connect_bd_net -net microphone_mgr_0_audio_captureCE [get_bd_pins ila_0/probe2] [get_bd_pins microphone_mgr_0/audio_captureCE]
  connect_bd_net -net microphone_mgr_0_audio_data_vector_OUT [get_bd_pins ila_0/probe1] [get_bd_pins microphone_mgr_0/audio_data_vector_OUT]
  connect_bd_net -net pdm_filter_sysgen_0_audio_ce [get_bd_pins ila_1/probe0] [get_bd_pins pdm_filter_sysgen_0/audio_ce]
  connect_bd_net -net pdm_filter_sysgen_0_audio_out [get_bd_pins ila_1/probe1] [get_bd_pins led_mgr_0/AUDIO_RAW] [get_bd_pins pdm_filter_sysgen_0/audio_out] [get_bd_pins pmod2_mgr_0/DSP_in]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins axi_gpio_1/s_axi_aclk] [get_bd_pins axi_gpio_2/s_axi_aclk] [get_bd_pins axi_iic_0/s_axi_aclk] [get_bd_pins axi_iic_1/s_axi_aclk] [get_bd_pins axi_iic_2/s_axi_aclk] [get_bd_pins bluetooth_uart/s_axi_aclk] [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] [get_bd_pins ps7_0_axi_periph/ACLK] [get_bd_pins ps7_0_axi_periph/M00_ACLK] [get_bd_pins ps7_0_axi_periph/M01_ACLK] [get_bd_pins ps7_0_axi_periph/M02_ACLK] [get_bd_pins ps7_0_axi_periph/M03_ACLK] [get_bd_pins ps7_0_axi_periph/M04_ACLK] [get_bd_pins ps7_0_axi_periph/M05_ACLK] [get_bd_pins ps7_0_axi_periph/M06_ACLK] [get_bd_pins ps7_0_axi_periph/S00_ACLK] [get_bd_pins rst_ps7_0_50M/slowest_sync_clk]
  connect_bd_net -net processing_system7_0_FCLK_CLK1 [get_bd_pins arduino_mgr_0/clk_in] [get_bd_pins pmod2_mgr_0/clk_in] [get_bd_pins bluetooth_uart/xin] [get_bd_pins processing_system7_0/FCLK_CLK1] 
  connect_bd_net -net processing_system7_0_FCLK_CLK2 [get_bd_pins ila_0/clk] [get_bd_pins ila_1/clk] [get_bd_pins led_mgr_0/clk_in] [get_bd_pins microphone_mgr_0/clk_in] [get_bd_pins pdm_filter_sysgen_0/clk] [get_bd_pins processing_system7_0/FCLK_CLK2]
  connect_bd_net -net processing_system7_0_FCLK_RESET0_N [get_bd_pins arduino_mgr_0/resetn_in] [get_bd_pins led_mgr_0/resetn_in] [get_bd_pins pmod2_mgr_0/resetn_in] [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_50M/ext_reset_in]
  connect_bd_net -net processing_system7_0_FCLK_RESET2_N [get_bd_pins microphone_mgr_0/resetn_in] [get_bd_pins processing_system7_0/FCLK_RESET2_N]
  connect_bd_net -net processing_system7_0_GPIO_O [get_bd_pins processing_system7_0/GPIO_O] [get_bd_pins wireless_mgr_0/GPIO_from_Zynq]
  connect_bd_net -net processing_system7_0_GPIO_T [get_bd_pins processing_system7_0/GPIO_T] [get_bd_pins wireless_mgr_0/GPIO_dir]
  connect_bd_net -net processing_system7_0_SDIO0_CLK [get_bd_pins processing_system7_0/SDIO0_CLK] [get_bd_pins wireless_mgr_0/SDIO_CLK]
  connect_bd_net -net processing_system7_0_SDIO0_CMD_O [get_bd_pins processing_system7_0/SDIO0_CMD_O] [get_bd_pins wireless_mgr_0/SDIO_CMD_from_Zynq]
  connect_bd_net -net processing_system7_0_SDIO0_CMD_T [get_bd_pins processing_system7_0/SDIO0_CMD_T] [get_bd_pins wireless_mgr_0/SDIO_CMD_dir]
  connect_bd_net -net processing_system7_0_SDIO0_DATA_O [get_bd_pins processing_system7_0/SDIO0_DATA_O] [get_bd_pins wireless_mgr_0/SDIO_DATA_from_Zynq]
  connect_bd_net -net processing_system7_0_SDIO0_DATA_T [get_bd_pins processing_system7_0/SDIO0_DATA_T] [get_bd_pins wireless_mgr_0/SDIO_DATA_dir]
  # Disconnecting PS UART so that the 16550 UART can be used instead
  #connect_bd_net -net processing_system7_0_UART0_RTSN [get_bd_pins processing_system7_0/UART0_RTSN] [get_bd_pins wireless_mgr_0/ZYNQ_UART_RTS]
  #connect_bd_net -net processing_system7_0_UART0_TX [get_bd_pins processing_system7_0/UART0_TX] [get_bd_pins wireless_mgr_0/ZYNQ_UART_TX]
  connect_bd_net -net rst_ps7_0_50M_interconnect_aresetn [get_bd_pins ps7_0_axi_periph/ARESETN] [get_bd_pins rst_ps7_0_50M/interconnect_aresetn]
  connect_bd_net -net rst_ps7_0_50M_peripheral_aresetn [get_bd_pins axi_gpio_0/s_axi_aresetn] [get_bd_pins axi_gpio_1/s_axi_aresetn] [get_bd_pins axi_gpio_2/s_axi_aresetn] [get_bd_pins axi_iic_0/s_axi_aresetn] [get_bd_pins axi_iic_1/s_axi_aresetn] [get_bd_pins axi_iic_2/s_axi_aresetn] [get_bd_pins bluetooth_uart/s_axi_aresetn] [get_bd_pins ps7_0_axi_periph/M00_ARESETN] [get_bd_pins ps7_0_axi_periph/M01_ARESETN] [get_bd_pins ps7_0_axi_periph/M02_ARESETN] [get_bd_pins ps7_0_axi_periph/M03_ARESETN] [get_bd_pins ps7_0_axi_periph/M04_ARESETN] [get_bd_pins ps7_0_axi_periph/M05_ARESETN] [get_bd_pins ps7_0_axi_periph/M06_ARESETN] [get_bd_pins ps7_0_axi_periph/S00_ARESETN] [get_bd_pins rst_ps7_0_50M/peripheral_aresetn]
  connect_bd_net -net wireless_mgr_0_BT_CTS_IN_N [get_bd_ports BT_CTS_IN_N] [get_bd_pins wireless_mgr_0/BT_CTS_IN_N]
  connect_bd_net -net wireless_mgr_0_BT_REG_ON [get_bd_ports BT_REG_ON] [get_bd_pins wireless_mgr_0/BT_REG_ON]
  connect_bd_net -net wireless_mgr_0_BT_RXD_IN [get_bd_ports BT_RXD_IN] [get_bd_pins wireless_mgr_0/BT_RXD_IN]
  connect_bd_net -net wireless_mgr_0_GPIO_to_Zynq [get_bd_pins processing_system7_0/GPIO_I] [get_bd_pins wireless_mgr_0/GPIO_to_Zynq]
  connect_bd_net -net wireless_mgr_0_SDIO_CDN [get_bd_pins processing_system7_0/SDIO0_CDN] [get_bd_pins wireless_mgr_0/SDIO_CDN]
  connect_bd_net -net wireless_mgr_0_SDIO_CLK_FB [get_bd_pins processing_system7_0/SDIO0_CLK_FB] [get_bd_pins wireless_mgr_0/SDIO_CLK_FB]
  connect_bd_net -net wireless_mgr_0_SDIO_CMD_to_Zynq [get_bd_pins processing_system7_0/SDIO0_CMD_I] [get_bd_pins wireless_mgr_0/SDIO_CMD_to_Zynq]
  connect_bd_net -net wireless_mgr_0_SDIO_DATA_to_Zynq [get_bd_pins processing_system7_0/SDIO0_DATA_I] [get_bd_pins wireless_mgr_0/SDIO_DATA_to_Zynq]
  connect_bd_net -net wireless_mgr_0_SDIO_WP [get_bd_pins processing_system7_0/SDIO0_WP] [get_bd_pins wireless_mgr_0/SDIO_WP]
  connect_bd_net -net wireless_mgr_0_UART_CTS [get_bd_pins bluetooth_uart/ctsn] [get_bd_pins wireless_mgr_0/ZYNQ_UART_CTS]
  connect_bd_net -net wireless_mgr_0_UART_RTS [get_bd_pins bluetooth_uart/rtsn] [get_bd_pins wireless_mgr_0/ZYNQ_UART_RTS]
  connect_bd_net -net wireless_mgr_0_UART_RX [get_bd_pins bluetooth_uart/sin] [get_bd_pins wireless_mgr_0/ZYNQ_UART_RX]
  connect_bd_net -net wireless_mgr_0_UART_TX [get_bd_pins bluetooth_uart/sout] [get_bd_pins wireless_mgr_0/ZYNQ_UART_TX]
  connect_bd_net -net wireless_mgr_0_WL_REG_ON [get_bd_ports WL_REG_ON] [get_bd_pins wireless_mgr_0/WL_REG_ON]
  connect_bd_net -net wireless_mgr_0_WL_SDIO_CLK [get_bd_ports WL_SDIO_CLK] [get_bd_pins wireless_mgr_0/WL_SDIO_CLK]
  # Disconnecting PS UART so that the 16550 UART can be used instead
  # connect_bd_net -net wireless_mgr_0_ZYNQ_UART_CTS [get_bd_pins processing_system7_0/UART0_CTSN] [get_bd_pins wireless_mgr_0/ZYNQ_UART_CTS]
  # connect_bd_net -net wireless_mgr_0_ZYNQ_UART_RX [get_bd_pins processing_system7_0/UART0_RX] [get_bd_pins wireless_mgr_0/ZYNQ_UART_RX]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins processing_system7_0/IRQ_F2P] [get_bd_pins xlconcat_0/dout]

  # Create address segments
  create_bd_addr_seg -range 0x00010000 -offset 0x41200000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] SEG_axi_gpio_0_Reg
  create_bd_addr_seg -range 0x00010000 -offset 0x41210000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_gpio_1/S_AXI/Reg] SEG_axi_gpio_1_Reg
  create_bd_addr_seg -range 0x00010000 -offset 0x41220000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_gpio_2/S_AXI/Reg] SEG_axi_gpio_2_Reg
  create_bd_addr_seg -range 0x00010000 -offset 0x41600000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_iic_0/S_AXI/Reg] SEG_axi_iic_0_Reg
  create_bd_addr_seg -range 0x00010000 -offset 0x41610000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_iic_1/S_AXI/Reg] SEG_axi_iic_1_Reg
  create_bd_addr_seg -range 0x00010000 -offset 0x41620000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_iic_2/S_AXI/Reg] SEG_axi_iic_2_Reg
  create_bd_addr_seg -range 0x00010000 -offset 0x43C00000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs bluetooth_uart/S_AXI/Reg] SEG_bluetooth_uart_Reg

# End insert Stefan May 20 'hdl.zip'

# -------------------------------------------------------------------------------------------------------------------------------------------


# Create BD ports to LEDs
# ->->->-> this should use board automation, but can't get it to work (May 3, 2017) -- see line 62 .\boards\MINIZED\MINIZED.tcl
# ...      C:\Xilinx\Vivado\2016.4\data\boards\board_files\minized\1.1\part0_pins.xml
# create_bd_port -dir O pl_led_r_tri_o
# connect_bd_net [get_bd_ports pl_led_r_tri_o] [get_bd_pins axi_gpio_1/gpio_io_o]
# create_bd_port -dir O pl_led_g_tri_o
# connect_bd_net [get_bd_ports pl_led_g_tri_o] [get_bd_pins axi_gpio_1/gpio_io_o]

# Add Minized-specific design constraints based on project needs.
# Set 'constrs_1' fileset object
set files_constraints [list \
 "[file normalize "$scriptdir/../Boards/MINIZED/minized_mic.xdc"]"\
 "[file normalize "$scriptdir/../Boards/MINIZED/minized_LEDs.xdc"]"\
 "[file normalize "$scriptdir/../Boards/bitstream_compression_enable.xdc"]"\
 "[file normalize "${projects_folder}/../minized_sensor_fusion.xdc"]"\
]
import_files -fileset constrs_1 -norecurse $files_constraints

# Add Project source files
puts "***** Adding Source Files to Block Design..."
make_wrapper -files [get_files ${projects_folder}/${project}.srcs/sources_1/bd/${project}/${project}.bd] -top
add_files -norecurse ${projects_folder}/${project}.srcs/sources_1/bd/${project}/hdl/${project}_wrapper.vhd

# Build the binary
#*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
#*- KEEP OUT, do not touch this section unless you know what you are doing! -*
#*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
puts "***** Building Binary..."
# add this to allow up+enter rebuild capability 
cd $scripts_folder
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
save_bd_design
launch_runs impl_1 -to_step write_bitstream -j 8
#*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
#*- KEEP OUT, do not touch this section unless you know what you are doing! -*
#*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
}

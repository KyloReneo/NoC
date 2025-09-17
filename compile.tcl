# Create library and map it
vlib work
vmap work work

# Compile Packages First
vcom -2008 ./src/packages/ROUTER_PKG.vhd

# Compile Modules

# INPUT_BUFFER
vcom -2008 ./src/modules/INPUT_BUFFER/FIFO_CONTROLLER.vhd
vcom -2008 ./src/modules/INPUT_BUFFER/REGISTER_FILE.vhd
vcom -2008 ./src/modules/INPUT_BUFFER/INPUT_BUFFER.vhd

# CROSSBAR_SWITCH
vcom -2008 ./src/modules/CROSSBAR_SWITCH/CROSSBAR_MUX_LOCAL.vhd
vcom -2008 ./src/modules/CROSSBAR_SWITCH/CROSSBAR_MUX_NORTH.vhd
vcom -2008 ./src/modules/CROSSBAR_SWITCH/CROSSBAR_MUX_EAST.vhd
vcom -2008 ./src/modules/CROSSBAR_SWITCH/CROSSBAR_MUX_SOUTH.vhd
vcom -2008 ./src/modules/CROSSBAR_SWITCH/CROSSBAR_MUX_WEST.vhd
vcom -2008 ./src/modules/CROSSBAR_SWITCH/CROSSBAR_SWITCH.vhd

# ARBITER
vcom -2008 ./src/modules/ARBITER/ARBITER.vhd

# ROUTING_UNIT
vcom -2008 ./src/modules/ROUTING_UNIT/ROUTING_UNIT.vhd

# NETWORK_INTERFACE
vcom -2008 ./src/modules/NETWORK_INTERFACE/EXTRACTOR_BUFFER.vhd
vcom -2008 ./src/modules/NETWORK_INTERFACE/NETWORK_INTERFACE.vhd

# IP_CORE
vcom -2008 ./src/modules/IP_CORE/IP_CORE.vhd

# ROUTER AND IT'S TESTBENCH
vcom -2008 ./src/modules/ROUTER/ROUTER.vhd
vcom -2008 ./src/modules/ROUTER/ROUTER_TB.vhd

# ROUTERS 5 AND 6 AND IT'S TESTBENCH
vcom -2008 ./src/modules/ROUTERS_5_AND_6/ROUTERS_5_AND_6.vhd
vcom -2008 ./src/modules/ROUTERS_5_AND_6/ROUTERS_5_AND_6_TB.vhd
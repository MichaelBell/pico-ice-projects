# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
PROG_FILE ?= lcd.hex
START_SIG ?= 0
END_SIG ?= 0

VERILOG_SOURCES += tb_top.v top.v fft-core/*.v
COMPILE_ARGS    += -DSIM -DPROG_FILE=\"$(PROG_FILE)\" -DSTART_SIG=$(START_SIG) -DEND_SIG=$(END_SIG) -Ifft-core/

COMPILE_ARGS += -DICE40 -DNO_ICE40_DEFAULT_ASSIGNMENTS
VERILOG_SOURCES += $(PWD)/ice40_cells_sim.v

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = tb_top

# MODULE is the basename of the Python test file
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

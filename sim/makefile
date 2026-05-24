OP ?= add
TEST ?= fp_$(OP)


PROJECT_PATH := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
-include $(PROJECT_PATH)/sim/.env
VLIB ?= /mnt/d/Quartus/modelsim_ase/win32aloem/vlib.exe
WORK_DIR ?= $(PROJECT_PATH)/sim/work_$(OP)
MODE ?= RNE
VECTORS = $(PROJECT_PATH)/$(OP)/vectors
DO_FILE = $(PROJECT_PATH)/sim/wave.do
GUI ?= 0
VSIM_FLAGS := -c
QUIT_CMD := quit -f

ifeq ($(GUI),1)
VSIM_FLAGS =
QUIT_CMD   =
else
VSIM_FLAGS = -c
QUIT_CMD   = quit -f
endif

.PHONY: gen_flist modelsim_init modelsim_compile modelsim modelsim_all

# Generate filelist for OP: common → $(OP)/rtl → $(OP)/tb
gen_flist:
	@find $(PROJECT_PATH)/common -name "*.v" | sort  > $(PROJECT_PATH)/sim/fp_$(OP).f
	@find $(PROJECT_PATH)/$(OP)/rtl -name "*.v" | sort >> $(PROJECT_PATH)/sim/fp_$(OP).f
	@find $(PROJECT_PATH)/$(OP)/tb  -name "*.v" | sort >> $(PROJECT_PATH)/sim/fp_$(OP).f
	@echo "Generated $(PROJECT_PATH)/sim/fp_$(OP).f"

# Initialize ModelSim work library
modelsim_init:
	@echo "Initializing ModelSim work library..."
	@if [ ! -d $(WORK_DIR) ]; then $(VLIB) $(WORK_DIR); fi

modelsim_compile: modelsim_init gen_flist
	@echo "Compiling source files..."
	vlog.exe -work $(WORK_DIR) -f $(PROJECT_PATH)/sim/fp_$(OP).f

# Run simulation
modelsim: modelsim_compile
	vsim.exe -c -do "set OP $(OP); set MODE $(MODE); set IN $(VECTORS)/test_$(shell echo $(MODE) | tr A-Z a-z).txt; set OUT $(VECTORS)/test_$(shell echo $(MODE) | tr A-Z a-z)_result.txt; do $(DO_FILE); $(QUIT_CMD)"

modelsim_all: modelsim_compile
	$(MAKE) modelsim MODE=RTZ | grep "TOTAL ERRORS"
	$(MAKE) modelsim MODE=RUP | grep "TOTAL ERRORS"
	$(MAKE) modelsim MODE=RDN | grep "TOTAL ERRORS"
	$(MAKE) modelsim MODE=RNE | grep "TOTAL ERRORS"
	$(MAKE) modelsim MODE=RMM | grep "TOTAL ERRORS"

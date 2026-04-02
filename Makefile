VENVDIR ?= $(WORKDIR)/.venv
REQUIREMENTS_TXT ?= $(wildcard python-requirements.txt)
include Makefile.venv

RTL_MODULE ?= $(firstword $(basename $(notdir $(wildcard rtl/*.sv))))
RESULT_DIR ?= result
PARAMETER_NAME ?= $(RTL_MODULE)


SIM_BUILD := build/$(PARAMETER_NAME)


$(RESULT_PATH):
	mkdir -p $@

TOPLEVEL_LANG ?= verilog
SIM ?= verilator

# -----------------------------
# Verilator flags
# -----------------------------
VERILATOR_BASE_ARGS := \
	+1800-2017ext+sv -sv -Wall \
	-Wno-UNUSEDPARAM -Wno-GENUNNAMED \
	--Werror-USERERROR -Wno-fatal \
	--coverage --coverage-toggle --coverage-user \
	--unroll-count 10 \
	--trace --trace-structs --trace-underscore \
	--trace-params --trace-max-width 512 --trace-max-array 256 \
	--x-assign unique --x-initial unique

# -----------------------------
# Bender sources (cached)
# -----------------------------
BENDER_RAW := $(shell bender script --target tb_standalone $(SIM))
BENDER_DEFINES := $(filter +define+%,$(BENDER_RAW))
BENDER_DIR := $(filter +incdir+%,$(BENDER_RAW))

VERILATOR_BASE_ARGS += $(BENDER_DIR)
BENDER_SOURCES := $(filter-out +define+% +incdir+%,$(BENDER_RAW))
VERILOG_SOURCES += $(BENDER_SOURCES)


TB_WRAPPER_DIR := $(wildcard tb/tb_wrapper)

TOPLEVEL := $(if $(TB_WRAPPER_DIR),wrapper_$(RTL_MODULE),$(RTL_MODULE))

export PYTHONPATH := $(PWD)/tb/cocotb:$(PYTHONPATH)



COCOTB_MODULE=tb_$(RTL_MODULE)
MODULE   = tb.cocotb.tb_xif_wrapper


ifeq ($(SIM),verilator)
	EXTRA_ARGS := $(VERILATOR_BASE_ARGS)
endif
$(info VERILOG_SOURCES=$(VERILOG_SOURCES))
# -----------------------------
# Cocotb
# -----------------------------
include $(shell cocotb-config --makefiles)/Makefile.sim

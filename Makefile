
RTL_COMMON_FILES ?= tb/setup

setup_common_files:
	
	mkdir -p $(RTL_COMMON_FILES)
	git clone git@ssh.dev.azure.com:v3/nvisiones/AIQ%20Ready/x-heep -b custom-instr-synth-wrapper_instructator_v1 $(RTL_COMMON_FILES)/x-heep

remove_common_files:
	rm -rdf $(RTL_COMMON_FILES)/x-heep

include ./utils/script_lib/main.mk

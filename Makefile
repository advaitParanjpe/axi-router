SHELL := /usr/bin/env bash

BUILD_DIR := build
IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
YOSYS ?= yosys

RTL_FLIST := filelists/rtl.f
DIRECTED_TB_FLIST := filelists/tb_directed.f
PARAM_TB_FLIST := filelists/tb_param.f
RANDOM_TB_FLIST := filelists/tb_random.f
RTL_SRCS := $(shell cat $(RTL_FLIST))
RANDOM_SEEDS ?= 1 7 23 101
SEED ?= 1

DIRECTED_SIM := $(BUILD_DIR)/tb_axis_pkt_router.vvp
PARAM_SIM_DEFAULT := $(BUILD_DIR)/tb_axis_pkt_router_param_default.vvp
PARAM_SIM_DATA16 := $(BUILD_DIR)/tb_axis_pkt_router_param_data16.vvp
PARAM_SIM_MAX1 := $(BUILD_DIR)/tb_axis_pkt_router_param_max1.vvp
PARAM_SIM_COUNTER_WRAP := $(BUILD_DIR)/tb_axis_pkt_router_param_counter_wrap.vvp
RANDOM_SIM := $(BUILD_DIR)/tb_axis_pkt_router_random.vvp

.PHONY: sim lint synth-check test clean waves random random-seed failure-check regression

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/tmp

$(DIRECTED_SIM): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(DIRECTED_TB_FLIST))
	$(IVERILOG) -g2012 -o $@ -f $(RTL_FLIST) -f $(DIRECTED_TB_FLIST)

$(PARAM_SIM_DEFAULT): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(PARAM_TB_FLIST))
	$(IVERILOG) -g2012 -s tb_axis_pkt_router_param -o $@ -f $(RTL_FLIST) -f $(PARAM_TB_FLIST)

$(PARAM_SIM_DATA16): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(PARAM_TB_FLIST))
	$(IVERILOG) -g2012 -s tb_axis_pkt_router_param \
		-P tb_axis_pkt_router_param.DATA_W=16 \
		-P tb_axis_pkt_router_param.DEST_W=3 \
		-P tb_axis_pkt_router_param.INGRESS_MAX_PKT_BEATS=3 \
		-P tb_axis_pkt_router_param.COUNTER_W=4 \
		-P tb_axis_pkt_router_param.PACKETS_TO_SEND=5 \
		-o $@ -f $(RTL_FLIST) -f $(PARAM_TB_FLIST)

$(PARAM_SIM_MAX1): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(PARAM_TB_FLIST))
	$(IVERILOG) -g2012 -s tb_axis_pkt_router_param \
		-P tb_axis_pkt_router_param.DATA_W=32 \
		-P tb_axis_pkt_router_param.DEST_W=2 \
		-P tb_axis_pkt_router_param.INGRESS_MAX_PKT_BEATS=1 \
		-P tb_axis_pkt_router_param.COUNTER_W=3 \
		-P tb_axis_pkt_router_param.PACKETS_TO_SEND=4 \
		-o $@ -f $(RTL_FLIST) -f $(PARAM_TB_FLIST)

$(PARAM_SIM_COUNTER_WRAP): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(PARAM_TB_FLIST))
	$(IVERILOG) -g2012 -s tb_axis_pkt_router_param \
		-P tb_axis_pkt_router_param.DATA_W=8 \
		-P tb_axis_pkt_router_param.DEST_W=2 \
		-P tb_axis_pkt_router_param.INGRESS_MAX_PKT_BEATS=1 \
		-P tb_axis_pkt_router_param.COUNTER_W=2 \
		-P tb_axis_pkt_router_param.PACKETS_TO_SEND=5 \
		-o $@ -f $(RTL_FLIST) -f $(PARAM_TB_FLIST)

$(RANDOM_SIM): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(RANDOM_TB_FLIST))
	$(IVERILOG) -g2012 -s tb_axis_pkt_router_random -o $@ -f $(RTL_FLIST) -f $(RANDOM_TB_FLIST)

sim: $(DIRECTED_SIM)
	$(VVP) $(DIRECTED_SIM)

waves: $(DIRECTED_SIM)
	$(VVP) $(DIRECTED_SIM) +WAVES +WAVE_FILE=$(BUILD_DIR)/tb_axis_pkt_router.vcd

lint:
	$(VERILATOR) --lint-only -Wall -Wno-DECLFILENAME --top-module axis_pkt_router -f $(RTL_FLIST)

synth-check:
	$(YOSYS) -q -p 'read_verilog -sv -DSYNTHESIS $(RTL_SRCS); hierarchy -top axis_pkt_router; proc; opt; check'

test: sim $(PARAM_SIM_DEFAULT) $(PARAM_SIM_DATA16) $(PARAM_SIM_MAX1) $(PARAM_SIM_COUNTER_WRAP) lint synth-check
	$(VVP) $(PARAM_SIM_DEFAULT)
	$(VVP) $(PARAM_SIM_DATA16)
	$(VVP) $(PARAM_SIM_MAX1)
	$(VVP) $(PARAM_SIM_COUNTER_WRAP)

random-seed: $(RANDOM_SIM)
	$(VVP) $(RANDOM_SIM) +SEED=$(SEED) | tee $(BUILD_DIR)/random-seed-$(SEED).log

random: $(RANDOM_SIM)
	@set -e; \
	for seed in $(RANDOM_SEEDS); do \
		echo "Running random seed $$seed"; \
		$(VVP) $(RANDOM_SIM) +SEED=$$seed | tee $(BUILD_DIR)/random-seed-$$seed.log; \
	done

failure-check: $(RANDOM_SIM)
	@set +e; \
	$(VVP) $(RANDOM_SIM) +FORCE_SCOREBOARD_ERROR > $(BUILD_DIR)/forced-failure.log 2>&1; \
	status=$$?; \
	set -e; \
	if [ $$status -eq 0 ]; then \
		echo "forced failure unexpectedly passed"; \
		exit 1; \
	fi; \
	echo "forced failure returned nonzero as expected"

regression: test random

clean:
	rm -rf $(BUILD_DIR)

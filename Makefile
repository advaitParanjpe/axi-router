SHELL := /usr/bin/env bash

BUILD_DIR := build
IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
YOSYS ?= yosys

RTL_FLIST := filelists/rtl.f
DIRECTED_TB_FLIST := filelists/tb_directed.f
PARAM_TB_FLIST := filelists/tb_param.f
RTL_SRCS := $(shell cat $(RTL_FLIST))

DIRECTED_SIM := $(BUILD_DIR)/tb_axis_pkt_router.vvp
PARAM_SIM_DEFAULT := $(BUILD_DIR)/tb_axis_pkt_router_param_default.vvp
PARAM_SIM_DATA16 := $(BUILD_DIR)/tb_axis_pkt_router_param_data16.vvp
PARAM_SIM_MAX1 := $(BUILD_DIR)/tb_axis_pkt_router_param_max1.vvp
PARAM_SIM_DEPTH1 := $(BUILD_DIR)/tb_axis_pkt_router_param_depth1.vvp

.PHONY: sim lint synth-check test clean waves

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(DIRECTED_SIM): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(DIRECTED_TB_FLIST))
	$(IVERILOG) -g2012 -o $@ -f $(RTL_FLIST) -f $(DIRECTED_TB_FLIST)

$(PARAM_SIM_DEFAULT): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(PARAM_TB_FLIST))
	$(IVERILOG) -g2012 -s tb_axis_pkt_router_param -o $@ -f $(RTL_FLIST) -f $(PARAM_TB_FLIST)

$(PARAM_SIM_DATA16): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(PARAM_TB_FLIST))
	$(IVERILOG) -g2012 -s tb_axis_pkt_router_param \
		-P tb_axis_pkt_router_param.DATA_W=16 \
		-P tb_axis_pkt_router_param.MAX_PKT_BEATS=5 \
		-P tb_axis_pkt_router_param.OUT_FIFO_DEPTH=3 \
		-o $@ -f $(RTL_FLIST) -f $(PARAM_TB_FLIST)

$(PARAM_SIM_MAX1): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(PARAM_TB_FLIST))
	$(IVERILOG) -g2012 -s tb_axis_pkt_router_param \
		-P tb_axis_pkt_router_param.DATA_W=32 \
		-P tb_axis_pkt_router_param.MAX_PKT_BEATS=1 \
		-P tb_axis_pkt_router_param.OUT_FIFO_DEPTH=3 \
		-o $@ -f $(RTL_FLIST) -f $(PARAM_TB_FLIST)

$(PARAM_SIM_DEPTH1): $(BUILD_DIR) $(shell cat $(RTL_FLIST) $(PARAM_TB_FLIST))
	$(IVERILOG) -g2012 -s tb_axis_pkt_router_param \
		-P tb_axis_pkt_router_param.DATA_W=32 \
		-P tb_axis_pkt_router_param.MAX_PKT_BEATS=4 \
		-P tb_axis_pkt_router_param.OUT_FIFO_DEPTH=1 \
		-o $@ -f $(RTL_FLIST) -f $(PARAM_TB_FLIST)

sim: $(DIRECTED_SIM)
	$(VVP) $(DIRECTED_SIM)

waves: $(DIRECTED_SIM)
	$(VVP) $(DIRECTED_SIM) +WAVES +WAVE_FILE=$(BUILD_DIR)/tb_axis_pkt_router.vcd

lint:
	$(VERILATOR) --lint-only -Wall --top-module axis_pkt_router -f $(RTL_FLIST)

synth-check:
	$(YOSYS) -q -p 'read_verilog -sv -DSYNTHESIS $(RTL_SRCS); hierarchy -top axis_pkt_router; proc; opt; check'

test: sim $(PARAM_SIM_DEFAULT) $(PARAM_SIM_DATA16) $(PARAM_SIM_MAX1) $(PARAM_SIM_DEPTH1) lint synth-check
	$(VVP) $(PARAM_SIM_DEFAULT)
	$(VVP) $(PARAM_SIM_DATA16)
	$(VVP) $(PARAM_SIM_MAX1)
	$(VVP) $(PARAM_SIM_DEPTH1)

clean:
	rm -rf $(BUILD_DIR)

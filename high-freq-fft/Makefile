PROJECT = high_freq_fft

ICEPACK = icepack
NEXTPNR = nextpnr-ice40 --randomize-seed --up5k --package sg48
YOSYS = yosys
BIN2UF2 = bin2uf2
DFU-UTIL = dfu-util -R -a 1
DFU-SUFFIX = dfu-suffix -v 1209 -p b1c0

PICO_ICE_SDK = ../../pico-ice-sdk/
PCF_FILE = pico_ice.pcf
RTL = top.v fft-core/*.v

all: $(PROJECT).uf2 $(PROJECT).dfu

clean:
	rm -f *.log *.json *.asc *.bit *.dfu *.uf2
	rm -rf verilator

flash: pico_ice_bitstream.dfu
	$(DFU-UTIL) -D $(PROJECT).dfu

pico_ice_bitstream.json: ${RTL}

.SUFFIXES: .sv .elf .vcd .json .asc .bit .dfu .uf2

$(PROJECT).json: $(RTL)
	${YOSYS} -p "read_verilog ${RTL}; synth_ice40 -dsp -top $(PROJECT)_top -json $@" >$*.yosys.log
	-grep -i -e err -e warn $*.yosys.log

.json.asc:
	${NEXTPNR} -q -l $*.nextpnr.log --pcf $(PCF_FILE) --top $(PROJECT)_top --json $< --asc $@

.asc.bit:
	${ICEPACK} $< $@

.bit.uf2:
	$(BIN2UF2) -o $@ 0x00000000 $<

.bit.dfu:
	cp $< $@
	$(DFU-SUFFIX) -a $@


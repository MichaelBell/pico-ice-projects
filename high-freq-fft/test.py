import random
import math

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge
from cocotb.utils import get_sim_time

async def send_sample(dut, value):
    out_value = 0
    for i in range(16):
        dut.sample_in.value = value & 1
        value >>= 1
        await FallingEdge(dut.sample_clk)
        #out_value |= dut.sample_out.value << i
    return out_value

# Just executes whatever is in test.mem so you can inspect the waveform
# https://riscvasm.lucasteske.dev/# is useful for assembling hex for the file.
@cocotb.test()
async def test_start(dut):
    clock = Clock(dut.clk, 28, units="ns")         # ~36 MHz
    sclock = Clock(dut.sample_clk, 97, units="ns") # ~144/14 = 10.28MHz
    #sclock = Clock(dut.sample_clk, 1000, units="ns") # 1MHz
    cocotb.start_soon(clock.start())
    cocotb.start_soon(sclock.start())
    
    dut.rstn.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rstn.value = 0
    dut.sample_in.value = 0
    await ClockCycles(dut.sample_clk, 1000)
    await FallingEdge(dut.sample_clk)
    dut.rstn.value = 1

    # Apply a 100kHz sin wave
    for i in range(1024):
        #t = get_sim_time("ns") * 0.00004
        dut.debug_counter.value = i
        t = i / 32
        val = math.sin(t * 2 * math.pi)
        await send_sample(dut, int(2047 + val * 400))





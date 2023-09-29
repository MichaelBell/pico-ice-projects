import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge

async def do_start(spi):
    clock = Clock(spi.spi_clk, 4, units="ns")
    cocotb.start_soon(clock.start())
    spi.spi_mosi.value = 0
    spi.spi_select.value = 1
    await ClockCycles(spi.spi_clk, 2)
    assert spi.error.value == 0

async def do_write(spi, addr, data):
    cmd = 2
    spi.spi_select.value = 0
    for i in range(8):
        spi.spi_mosi.value = 1 if (cmd & 0x80) != 0 else 0
        cmd <<= 1
        await ClockCycles(spi.spi_clk, 1)
    for i in range(24):
        spi.spi_mosi.value = 1 if (addr & 0x800000) != 0 else 0
        addr <<= 1
        await ClockCycles(spi.spi_clk, 1)
    for j in range(len(data)):
        d = data[j]
        for i in range(8):
            spi.spi_mosi.value = 1 if (d & 0x80) != 0 else 0
            d <<= 1
            await ClockCycles(spi.spi_clk, 1)
    spi.spi_select.value = 1
    await Timer(1, "ns")

async def do_read(spi, addr, length):
    cmd = 3
    data = []
    spi.spi_select.value = 0
    for i in range(8):
        spi.spi_mosi.value = 1 if (cmd & 0x80) != 0 else 0
        cmd <<= 1
        await ClockCycles(spi.spi_clk, 1)
    for i in range(24):
        spi.spi_mosi.value = 1 if (addr & 0x800000) != 0 else 0
        addr <<= 1
        await ClockCycles(spi.spi_clk, 1)
    #await ClockCycles(spi.spi_clk, 1)
    for j in range(length):
        d = 0
        for i in range(8):
            await ClockCycles(spi.spi_clk, 1)
            d <<= 1
            d |= spi.spi_miso.value
        data.append(d)
    spi.spi_select.value = 1
    await Timer(1, "ns")
    return data

@cocotb.test()
async def test_spi(spi):
    await do_start(spi)
    await do_write(spi, 1, [1, 2, 3, 4])
    recv = await do_read(spi, 1, 4)
    assert recv == [1, 2, 3, 4]

    await do_write(spi, 1, [1, 0xff, 0xaa, 4])
    recv = await do_read(spi, 1, 4)
    assert recv == [1, 0xff, 0xaa, 4]

    #for i in range(100):
    #    addr = random.randint(0, 65536-4)
    #    data = [random.randint(0, 255), random.randint(0, 255), random.randint(0, 255), random.randint(0, 255)]
    #    if (random.randint(0, 1) == 0):
    #        await do_read(spi, addr, data)
    #    else:
    #        await do_write(spi, addr, data)

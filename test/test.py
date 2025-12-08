# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

"""
Testbench for Goose Game VGA timing verification.
Tests that hsync and vsync signals follow correct 640x480 @ 60Hz timing.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_hsync_timing(dut):
    """Verify HSYNC signal timing matches VGA 640x480 spec."""
    dut._log.info("Testing HSYNC timing")

    # 25mhz clock (40ns period)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # reset
    dut.ena.value = 1
    dut.ui_in.value = 0xFF
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # skip first scanline for initialization
    await ClockCycles(dut.clk, 800)

    # during display area, hsync should be high (inactive, active-low signal)
    assert dut.uo_out[7].value == 1, "HSYNC should be high during display"

    # advance to sync pulse: 640 display + 16 front porch + 2 pipeline delay
    await ClockCycles(dut.clk, 640 + 16 + 2)
    assert dut.uo_out[7].value == 0, "HSYNC should be low during sync pulse"

    # after 96-cycle sync pulse, hsync should go high again
    await ClockCycles(dut.clk, 96)
    assert dut.uo_out[7].value == 1, "HSYNC should be high after sync pulse"

    dut._log.info("HSYNC timing test PASSED")


@cocotb.test()
async def test_vsync_timing(dut):
    """Verify VSYNC signal timing matches VGA 640x480 spec."""
    dut._log.info("Testing VSYNC timing")

    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # reset
    dut.ena.value = 1
    dut.ui_in.value = 0xFF
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # during first line, vsync should be high (inactive)
    await ClockCycles(dut.clk, 400)
    assert dut.uo_out[3].value == 1, "VSYNC should be high during display"

    # advance to vsync start: 480 display + 10 front porch lines, +1 for pipeline
    # each line is 800 clocks
    lines_to_vsync = 480 + 10 + 1
    await ClockCycles(dut.clk, lines_to_vsync * 800 - 400)
    assert dut.uo_out[3].value == 0, "VSYNC should be low during sync pulse"

    # after 2-line sync pulse, vsync should go high again
    await ClockCycles(dut.clk, 2 * 800)
    assert dut.uo_out[3].value == 1, "VSYNC should be high after sync pulse"

    dut._log.info("VSYNC timing test PASSED")

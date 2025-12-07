# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

# Note this test bench is not used for the testing of our project.
# You should use the verilator/* directory to test. This is because the verilator can handle live button inputs.
# This directory remains to keep the github actions in check.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    """Simple VGA sync sanity check, mirrored from tt08-vgademo style."""
    dut._log.info("Start")

    # 25MHz clock
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0xFF
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Set the input values you want to test
    dut.ui_in.value = 0xFF
    dut.uio_in.value = 0

    # skip first scanline for initialization
    await ClockCycles(dut.clk, 800)

    # hsync and vsync should be de-asserted (high for active-low sync)
    assert dut.uo_out[7].value == 1
    assert dut.uo_out[3].value == 1

    # hsync should go low after the front porch
    await ClockCycles(dut.clk, 640+16)
    assert dut.uo_out[7].value == 0

    # and high again
    await ClockCycles(dut.clk, 97)
    assert dut.uo_out[7].value == 1

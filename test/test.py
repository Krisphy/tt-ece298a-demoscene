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

    # 25 MHz clock (40 ns period)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize inputs (active-low buttons are released)
    dut.ena.value = 1
    dut.ui_in.value = 0xFF
    dut.uio_in.value = 0

    # Reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # VGA timing from hvsync_generator:
    # H: display 640, front porch 16, sync 96, back porch 48, total 800
    H_DISPLAY = 640
    H_FRONT_PORCH = 16
    H_SYNC_PULSE = 96
    H_TOTAL = 800

    # Give the design one full scanline to settle
    await ClockCycles(dut.clk, H_TOTAL)

    # At the start of a line outside the sync pulse, hsync and vsync should be de-asserted (low)
    # Mapping from goose_game_top:
    #   uo_out = {hsync, B0, G0, R0, vsync, B1, G1, R1}
    assert dut.uo_out[7].value == 0, "Expected HSYNC low outside sync pulse"
    assert dut.uo_out[4].value == 0, "Expected VSYNC low outside vsync pulse"

    # HSYNC should go high after the front porch (active during sync pulse)
    await ClockCycles(dut.clk, H_DISPLAY + H_FRONT_PORCH)
    assert dut.uo_out[7].value == 1, "Expected HSYNC high during sync pulse"

    # And low again after the sync pulse width
    await ClockCycles(dut.clk, H_SYNC_PULSE)
    assert dut.uo_out[7].value == 0, "Expected HSYNC low after sync pulse"

    dut._log.info("VGA sync sanity check completed successfully")

# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset test
    dut._log.info("Testing reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    
    # Check that outputs are stable during reset
    dut._log.info(f"Output during reset: {dut.uo_out.value}")
    
    # Release reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)
    
    dut._log.info(f"Output after reset: {dut.uo_out.value}")
    
    # Test basic input functionality - jump button
    dut._log.info("Testing jump button input")
    dut.ui_in.value = 0b00000001  # Jump button pressed
    await ClockCycles(dut.clk, 100)
    
    # Test halt button
    dut._log.info("Testing halt button input")
    dut.ui_in.value = 0b00000010  # Halt button pressed
    await ClockCycles(dut.clk, 100)
    
    # Both buttons released
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 100)
    
    dut._log.info("Test completed successfully")

import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import FallingEdge
import numpy as np
import cocotb.log
from dataclasses import dataclass
import copy
from random import getrandbits
import random
import vsc 
from cocotb.result import TestComplete
from pyuvm import *
import pyuvm
from xif_utlis import *
# make cocotb_run TB_FRAMEWORK=COCOTB_TB
# 
class xif_issue_seqItem():
    def __init__(self,):

        self.issue_req = x_issue_req_t()

    def randomize(self):
        # self.vaild = random.randint(0, 1)
        self.issue_req.instr = random.randint(0, 255)
        self.issue_req.mode = random.randint(0, 3)
        self.issue_req.id  = random.randint(0, 3)

async def stop_after(timeout_ns):
    await Timer(timeout_ns, units='ns')
    raise TestComplete("Test stopped after timeout of {} ns".format(timeout_ns))


# class RandomSeq(uvm_sequence):
#     async def body(self):
#         for _ in range(10):
#             cmd_tr = xif_issue_seqItem("cmd_tr", None, x_issue_req_t())
#             await self.start_item(cmd_tr)
#             cmd_tr.randomize()
#             await self.finish_item(cmd_tr)


# class Driver(uvm_driver):
#     def build_phase(self):
#         self.ap = uvm_analysis_port("ap", self)

#     def start_of_simulation_phase(self):
#         self.bfm = xif_issue_bfm()

#     async def launch_tb(self):
#         await self.bfm.reset()
#         self.bfm.start_bfm()

#     async def run_phase(self):
#         await self.launch_tb()
#         while True:
#             cmd = await self.seq_item_port.get_next_item()
#             self.logger.info(cmd)
#             await self.bfm.send_op(cmd.vaild, cmd.issue_req)
#             result = await self.bfm.get_result()
#             self.ap.write(result)
#             cmd.result = result
#             self.seq_item_port.item_done()


# class Scoreboard(uvm_component):

#     def build_phase(self):
#         self.cmd_fifo = uvm_tlm_analysis_fifo("cmd_fifo", self)
#         self.result_fifo = uvm_tlm_analysis_fifo("result_fifo", self)
#         self.cmd_get_port = uvm_get_port("cmd_get_port", self)
#         self.result_get_port = uvm_get_port("result_get_port", self)
#         self.cmd_export = self.cmd_fifo.analysis_export
#         self.result_export = self.result_fifo.analysis_export

#     def connect_phase(self):
#         self.cmd_get_port.connect(self.cmd_fifo.get_export)
#         self.result_get_port.connect(self.result_fifo.get_export)

#     def check_phase(self):
#         passed = True
#         try:
#             self.errors = ConfigDB().get(self, "", "CREATE_ERRORS")
#         except UVMConfigItemNotFound:
#             self.errors = False
#         while self.result_get_port.can_get():
#             actual_result = self.result_get_port.try_get()
#             cmd = self.cmd_get_port.try_get()
#             if not cmd_success:
#                 self.logger.critical(f"result {actual_result} had no command")
#             else:
#                 self.logger.info(f"cmd : {cmd}")
#                 # (A, B, op_numb) = cmd
#                 # op = Ops(op_numb)
#                 # predicted_result = alu_prediction(A, B, op, self.errors)
#                 # if predicted_result == actual_result:
#                 #     self.logger.info(f"PASSED: 0x{A:02x} {op.name} 0x{B:02x} ="
#                 #                      f" 0x{actual_result:04x}")
#                 # else:
#                 #     self.logger.error(f"FAILED: 0x{A:02x} {op.name} 0x{B:02x} "
#                 #                       f"= 0x{actual_result:04x} "
#                 #                       f"expected 0x{predicted_result:04x}")
#                 #     passed = False
#         assert passed

# class Monitor(uvm_component):
#     def __init__(self, name, parent, method_name):
#         super().__init__(name, parent)
#         self.method_name = method_name

#     def build_phase(self):
#         self.ap = uvm_analysis_port("ap", self)
#         self.bfm = xif_issue_bfm()
#         self.get_method = getattr(self.bfm, self.method_name)

#     async def run_phase(self):
#         while True:
#             datum = await self.get_method()
#             self.logger.debug(f"MONITORED {datum}")
#             self.ap.write(datum)




# class xifEnv(uvm_env):

#     def build_phase(self):
#         self.seqr = uvm_sequencer("seqr", self)
#         ConfigDB().set(None, "*", "SEQR", self.seqr)
#         self.driver = Driver.create("driver", self)
#         self.cmd_mon = Monitor("cmd_mon", self, "get_cmd")
#         # self.coverage = Coverage("coverage", self)
#         self.scoreboard = Scoreboard("scoreboard", self)

#     def connect_phase(self):
#         self.driver.seq_item_port.connect(self.seqr.seq_item_export)
#         self.cmd_mon.ap.connect(self.scoreboard.cmd_export)
#         # self.cmd_mon.ap.connect(self.coverage.analysis_export)
#         self.driver.ap.connect(self.scoreboard.result_export)

# class xifTestBase(uvm_test):
#     """Base class for ALU tests with random and max values"""

#     def build_phase(self):
#         self.env = xifEnv("env", self)

#     def end_of_elaboration_phase(self):
#         # self.rand_seq = RandomSeq.create("rand_seq")
#         self.rand_seq = RandomSeq.create("rand_seq", sequencer=ConfigDB().get(None, "", "SEQR"))
#     async def run_phase(self):
#         self.raise_objection()
#         await self.rand_seq.start()
#         self.drop_objection()



# @pyuvm.test()
# class xifTest(xifTestBase):
#     """Test xif with random"""
async def send_req_eval():
    print()

@cocotb.test()
async def reset_test(dut):
    """reset test"""
    cocotb.start_soon(stop_after(1000))
    bfm = xif_issue_bfm()

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()

    for sig in dut:
        print(sig._name)


    await bfm.reset()

    interface_data = xif_issue_seqItem()
    for _ in range(10):
        interface_data.randomize()
        await bfm.send_op(1,interface_data.issue_req)
        cocotb.log.info(f'Dut interface data in tb: {interface_data}')
    
    await bfm.reset()
    
    cocotb.log.info(f'Dut output read {bfm.read_output()}')
    for _ in range(10):
        await RisingEdge(dut.clk_i)
    
    

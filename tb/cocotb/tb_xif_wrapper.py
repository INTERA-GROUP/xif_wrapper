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
from typing import Optional
from cocotb.triggers import Combine

sync_fix=0

instructions = [
    {
        "instr": 0b00000000000000000010000000001011,
        "mask":  0b11111111111100000111000001111111,
        "rs_valid_mask": 0b001,
        "resp": x_issue_resp_t(
            accept=True,
            writeback=False,
            dualwrite=False,
            dualread=0,
            loadstore=False,
            ecswrite=False,
            exc=False
        )
    },
    {
        "instr": 0b00000000000000000011000000001011,
        "mask":  0b11111110000000000111000001111111,
        "rs_valid_mask": 0b011,
        "resp": x_issue_resp_t(True, False, False, 0, False, False, False)
    },
    {
        "instr": 0b00101000000000000011000000001011,
        "mask":  0b11111110000000000111000001111111,
        "rs_valid_mask": 0b011,
        "resp": x_issue_resp_t(True, False, False, 0, False, False, False)
    },
    {
        "instr": 0b01010000000000000011000000001011,
        "mask":  0b11111110000000000111000001111111,
        "rs_valid_mask": 0b011,
        "resp": x_issue_resp_t(True, False, False, 0, False, False, False)
    },
    {
        "instr": 0b00000000000000000100000000001011,
        "mask":  0b10000000000000000111000001111111,
        "rs_valid_mask": 0b000,
        "resp": x_issue_resp_t(True, True, False, 0, False, False, False)
    },
    {
        "instr": 0b10000000000000000100000000001011,
        "mask":  0b10000000000000000111000001111111,
        "rs_valid_mask": 0b000,
        "resp": x_issue_resp_t(True, True, False, 0, False, False, False)
    },
    {
        "instr": 0b00000000000000000000000000000000,
        "mask":  0b11111111111111111111111111111111,
        "rs_valid_mask": 0b000,
        "resp": x_issue_resp_t(False, False, False, 0, False, False, False)
    }

]


# make cocotb_run TB_FRAMEWORK=COCOTB_TB
# 
class xif_issue_seqItem():
    def __init__(self,):

        self.issue_req = x_issue_req_t()
        self.sel_instr = 0
        self.rd = 0
    def randomize(self):
        # self.vaild = random.randint(0, 1)
        self.sel_instr = random.randint(0, len(instructions)-1) 
        temp_mask= (instructions[self.sel_instr]["instr"]|instructions[self.sel_instr]["mask"])^ instructions[self.sel_instr]["mask"]
        instr= temp_mask&random.randint(0,2**32) | instructions[self.sel_instr]["instr"]
        self.issue_req.instr = instr
        self.issue_req.mode = random.randint(0, 3)
        self.issue_req.id  = random.randint(0, 3)
        self.issue_req.rs_valid = instructions[self.sel_instr]["rs_valid_mask"]

    def randomize_illegal(self):
        self.sel_instr = len(instructions)-1
        temp_mask= instructions[self.sel_instr]["instr"]^instructions[self.sel_instr]["mask"]
        instr= temp_mask&random.randint(0,2**32) | instructions[self.sel_instr]["instr"]
        self.issue_req.instr = instr
        self.issue_req.mode = random.randint(0, 3)
        self.issue_req.id  = random.randint(0, 3)
        self.issue_req.rs_valid = instructions[self.sel_instr]["rs_valid_mask"]
    
    def randomize_valid(self):
        # self.vaild = random.randint(0, 1)
        self.sel_instr = random.randint(0, len(instructions)-2) 
        temp_mask= (instructions[self.sel_instr]["instr"]|instructions[self.sel_instr]["mask"])^ instructions[self.sel_instr]["mask"]
        instr= temp_mask&random.randint(0,2**32) | instructions[self.sel_instr]["instr"]
        self.rd =  random.randint(0, 31)
        instr = instr| (self.rd<<7)
        self.issue_req.instr = instr
        self.issue_req.mode = random.randint(0, 3)
        self.issue_req.id  = random.randint(0, 3)
        self.issue_req.rs_valid = instructions[self.sel_instr]["rs_valid_mask"]

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


def read_result_intf(dut):
    req = x_issue_req_t()
    resp = x_issue_resp_t()
    req.instr = int (dut.wrapper_exe_instr_issue_req_instr.value)
    req.mode = int (dut.wrapper_exe_instr_issue_req_mode.value)
    req.id = int (dut.wrapper_exe_instr_issue_req_id.value)
    req.rs = int (dut.wrapper_exe_instr_issue_req_rs.value)
    req.rs_valid = int (dut.wrapper_exe_instr_issue_req_rs_valid.value)
    req.ecs = int (dut.wrapper_exe_instr_issue_req_ecs.value)
    req.ecs_valid = int (dut.wrapper_exe_instr_issue_req_ecs_valid.value)
    resp.accept = int (dut.wrapper_exe_instr_issue_resp_accept.value)
    resp.writeback = int (dut.wrapper_exe_instr_issue_resp_writeback.value)
    resp.dualwrite = int (dut.wrapper_exe_instr_issue_resp_dualwrite.value)
    resp.dualread = int (dut.wrapper_exe_instr_issue_resp_dualread.value)
    resp.loadstore = int (dut.wrapper_exe_instr_issue_resp_loadstore.value)
    resp.ecswrite = int (dut.wrapper_exe_instr_issue_resp_ecswrite.value)
    resp.exc = int (dut.wrapper_exe_instr_issue_resp_exc.value    )

    return (req ,resp)


async def populate_commit_interface(dut, interface_data,kill=0):
    # await FallingEdge(dut.clk_i)
    issue_bfm=xif_issue_bfm()
    commit_bfm = xif_commit_bfm()
    result = issue_bfm.read_output()
    cocotb.log.info(f'Dut resp: {result}')
    cocotb.log.info(f'Data passing to the commit interface: {interface_data.issue_req}')
    commit_req = x_commit_t()
    commit_req.commit_kill= kill
    commit_req.id= interface_data.issue_req.id
    await commit_bfm.send_op(1,commit_req)


async def compare_aync_issue_result(dut, interface_data):
    bfm  = xif_issue_bfm()
    await FallingEdge(dut.clk_i)
    await Timer(1,units='ns')
    issue_resp = bfm.read_output()
    assert issue_resp == instructions[interface_data.sel_instr]["resp"] , \
            f"Resp is diffrent then the expected one"


async def exe_interface_dut(dut, interface_data):

    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    await Timer(1,units='ns')
    dut.exe_wrapper_recv_instr_ready.value = 1
    req,resp = read_result_intf(dut)
    cocotb.log.info(f'exe_interface_dut req: {req}')
    cocotb.log.info(f'exe_interface_dut resp: {resp}')
    cocotb.log.info(f'issue_interface resp: {interface_data.issue_req}')
    await FallingEdge(dut.clk_i)
    dut.exe_wrapper_recv_instr_ready.value = 0
    # issue_resp = bfm.read_output()
    assert resp == instructions[interface_data.sel_instr]["resp"] , \
            f"Resp is diffrent then the expected at the exe_interface_dut"
    assert req == interface_data.issue_req , \
            f"Req is diffrent then the expected at the exe_interface_dut"        


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
    for id in range(4):
        interface_data.randomize_valid()
        interface_data.issue_req.id = id
        await bfm.send_op(1,interface_data.issue_req)
        cocotb.log.info(f'Dut interface data in tb: {interface_data}')
        cocotb.start_soon(populate_commit_interface(dut,copy.deepcopy(interface_data)))

    

    for _ in range(2):
        await FallingEdge(dut.clk_i)

    await bfm.reset()
    try:
        assert get_int(dut.ext_if_coproc_issue_ready) == 1,\
                f" After reset this should 1 "
        assert get_int(dut.wrapper_exe_instr_vaild) == 0,  \
                f"  After reset this should 0"
    except AssertionError as e:
        cocotb.log.error(f"ASSERT FAILED: {e}")
        # Optionally set a debug signal or flag
        dut.debug_signal.value = 1

        # Wait some time before re-raising or continuing
        await Timer(100, units="ns")

        raise




@cocotb.test()
async def all_issue_illegel_without_commit(dut):
    """All the instrucations passed are not accepted by the dut. There is not corresponding commit Vaild"""

    cocotb.start_soon(stop_after(1000))
    bfm = xif_issue_bfm()

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()

    for sig in dut:
        print(sig._name)


    await bfm.reset()

    interface_data = xif_issue_seqItem()
    
    for id in range(10):
        interface_data.randomize_illegal()
        interface_data.issue_req.id = id
        await bfm.send_op(1,interface_data.issue_req)
        issue_resp = bfm.read_output()
        assert issue_resp == instructions[interface_data.sel_instr]["resp"] , \
            f"Resp is diffenrt then the expected one"
        cocotb.log.info(f'Dut interface data in tb: {interface_data}')
    
   
    
    cocotb.log.info(f'Dut output read {bfm.read_output()}')
    for _ in range(10):
        await RisingEdge(dut.clk_i)


@cocotb.test()
async def commit_interface_neg(dut):
    """ send invaild commit signal"""
    cocotb.start_soon(stop_after(1000))
    bfm = xif_issue_bfm()
    bfm_commit = xif_commit_bfm()

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()
    bfm_commit.start_bfm()

    for sig in dut:
        print(sig._name)


    await bfm.reset()
    for _ in range(3):
        await RisingEdge(dut.clk_i)

    interface_data = xif_issue_seqItem()
    for id in range(4):
        print(id)
        interface_data.randomize_valid()
        # interface_data.randomize_illegal()
        interface_data.issue_req.id = id
        await bfm.send_op(1,copy.deepcopy(interface_data.issue_req))
        cocotb.log.info(f'Dut interface data in tb: {interface_data.issue_req}')
        interface_data.issue_req.id = 0b1111

        cocotb.start_soon(populate_commit_interface(dut,copy.deepcopy(interface_data)))
        # await send_req_eval(bfm,interface_data)
        cocotb.log.info(f'instrucation select tb: {interface_data.sel_instr}')
        cocotb.start_soon(compare_aync_issue_result(dut,copy.deepcopy(interface_data)))  
        
        print(" ")
    for _ in range(2): #for syncing
        await FallingEdge(dut.clk_i)

    
    try:
        assert get_int(dut.wrapper_exe_instr_vaild) == 0,  \
                f" Wrapper_exe_instr shouldnt be set as the commit_vaild isnt for the same instrucations instrucation_dispatched"
    except AssertionError as e:
        cocotb.log.error(f"ASSERT FAILED: {e}")
        # Optionally set a debug signal or flag
        dut.debug_signal.value = 1

        # Wait some time before re-raising or continuing
        await Timer(100, units="ns")

        raise



@cocotb.test()
async def commit_interface_porperly(dut):
    """ send commit signal properly without kill"""
    cocotb.start_soon(stop_after(1000))
    bfm = xif_issue_bfm()
    bfm_commit = xif_commit_bfm()

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()
    bfm_commit.start_bfm()

    for sig in dut:
        print(sig._name)


    await bfm.reset()
    for _ in range(3):
        await RisingEdge(dut.clk_i)

    interface_data = xif_issue_seqItem()
    for id in range(4):
        print(id)
        interface_data.randomize_valid()
        # interface_data.randomize_illegal()
        interface_data.issue_req.id = id
        await bfm.send_op(1,copy.deepcopy(interface_data.issue_req))
        cocotb.log.info(f'Dut interface data in tb: {interface_data.issue_req}')
        cocotb.start_soon(populate_commit_interface(dut,copy.deepcopy(interface_data),0))
        # await send_req_eval(bfm,interface_data)
        cocotb.log.info(f'instrucation select tb: {interface_data.sel_instr}')
        cocotb.start_soon(compare_aync_issue_result(dut,copy.deepcopy(interface_data)))  
        
        print(" ")
    
    for _ in range(2):
        await FallingEdge(dut.clk_i)
    
    try:
        assert get_int(dut.ext_if_coproc_issue_ready) == 0,\
                f" Wrapper_exe_instr shouldnt be set as the commit_vaild isnt to instrucation_dispatched"
        assert get_int(dut.wrapper_exe_instr_vaild) == 1,  \
                f" Wrapper_exe_instr shouldnt be set as the commit_vaild isnt to instrucation_dispatched"
    
    except AssertionError as e:
        cocotb.log.error(f"ASSERT FAILED: {e}")
        # Optionally set a debug signal or flag
        dut.debug_signal.value = 1

        # Wait some time before re-raising or continuing
        await Timer(100, units="ns")
        raise
    # await bfm.reset()



@cocotb.test()
async def commit_interface_kill_correct_id(dut):
    """ send commit signal properly with kill"""
    cocotb.start_soon(stop_after(1000))
    bfm = xif_issue_bfm()
    bfm_commit = xif_commit_bfm()

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()
    bfm_commit.start_bfm()

    for sig in dut:
        print(sig._name)


    await bfm.reset()
    for _ in range(3):
        await RisingEdge(dut.clk_i)

    interface_data = xif_issue_seqItem()
    for id in range(4):
        print(id)
        interface_data.randomize_valid()
        # interface_data.randomize_illegal()
        interface_data.issue_req.id = id
        await bfm.send_op(1,copy.deepcopy(interface_data.issue_req))
        cocotb.log.info(f'Dut interface data in tb: {interface_data.issue_req}')
        cocotb.start_soon(populate_commit_interface(dut,copy.deepcopy(interface_data),1))
        # await send_req_eval(bfm,interface_data)
        cocotb.log.info(f'instrucation select tb: {interface_data.sel_instr}')
        cocotb.start_soon(compare_aync_issue_result(dut,copy.deepcopy(interface_data)))  
        
        print(" ")
    
    for _ in range(2):
        await FallingEdge(dut.clk_i)
    
    try:
        assert get_int(dut.ext_if_coproc_issue_ready) == 1,\
                f"All instrucation got killed "
        assert get_int(dut.wrapper_exe_instr_vaild) == 0,  \
                f"All instrucation got killed"
    
    except AssertionError as e:
        cocotb.log.error(f"ASSERT FAILED: {e}")
        # Optionally set a debug signal or flag
        dut.debug_signal.value = 1

        # Wait some time before re-raising or continuing
        await Timer(100, units="ns")
        raise
    # await bfm.reset()


@cocotb.test()
async def commit_interface_kill_worng_id(dut):
    """ send commit signal properly with wrong id kill"""
    cocotb.start_soon(stop_after(1000))
    bfm = xif_issue_bfm()
    bfm_commit = xif_commit_bfm()

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()
    bfm_commit.start_bfm()

    for sig in dut:
        print(sig._name)


    await bfm.reset()
    for _ in range(3):
        await RisingEdge(dut.clk_i)

    interface_data = xif_issue_seqItem()
    for id in range(4):
        print(id)
        interface_data.randomize_valid()
        # interface_data.randomize_illegal()
        interface_data.issue_req.id = id
        await bfm.send_op(1,copy.deepcopy(interface_data.issue_req))
        cocotb.log.info(f'Dut interface data in tb: {interface_data.issue_req}')
        interface_data.issue_req.id = 0b1111
        cocotb.start_soon(populate_commit_interface(dut,copy.deepcopy(interface_data),1))
        # await send_req_eval(bfm,interface_data)
        cocotb.log.info(f'instrucation select tb: {interface_data.sel_instr}')
        cocotb.start_soon(compare_aync_issue_result(dut,copy.deepcopy(interface_data)))  
        
        print(" ")
    
    for _ in range(2):
        await FallingEdge(dut.clk_i)
    
    try:
        assert get_int(dut.ext_if_coproc_issue_ready) == 0,\
                f"Didnt send the correct commit id  ext_if_coproc_issue_ready should set to zero"
        assert get_int(dut.wrapper_exe_instr_vaild) == 0,  \
                f"Didnt send the correct commit id  wrapper_exe_instr_vaild should set to zero"
    
    except AssertionError as e:
        cocotb.log.error(f"ASSERT FAILED: {e}")
        # Wait some time before re-raising or continuing
        for _ in range(10):
            await FallingEdge(dut.clk_i)
        raise



@cocotb.test()
async def issue_commit_exe_interface_porperly(dut):
    """ send commit signal properly without kill"""
    cocotb.start_soon(stop_after(10000))
    bfm = xif_issue_bfm()
    bfm_commit = xif_commit_bfm()

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()
    bfm_commit.start_bfm()

    for sig in dut:
        print(sig._name)


    await bfm.reset()
    for _ in range(3):
        await RisingEdge(dut.clk_i)

    interface_data = xif_issue_seqItem()
    for id in range(100):
        print(id)
        interface_data.randomize_valid()
        # interface_data.randomize_illegal()
        interface_data.issue_req.id = id%16
        await bfm.send_op(1,copy.deepcopy(interface_data.issue_req))
        cocotb.log.info(f'Dut interface data in tb: {interface_data.issue_req}')
        f1 = cocotb.start_soon(populate_commit_interface(dut,copy.deepcopy(interface_data),0))
        f2 = cocotb.start_soon(exe_interface_dut(dut,copy.deepcopy(interface_data)))
        # await send_req_eval(bfm,interface_data)
        cocotb.log.info(f'instrucation select tb: {interface_data.sel_instr}')
        f3 = cocotb.start_soon(compare_aync_issue_result(dut,copy.deepcopy(interface_data)))  
        
        print(" ")
    
    await Combine(f1,f2,f3)

    for _ in range(10):
        await FallingEdge(dut.clk_i)
    




# @cocotb.test()
# async def test_instr(dut):
#     """Test instr"""
#     cocotb.start_soon(stop_after(1000))
#     bfm = xif_issue_bfm()
#     bfm_commit = xif_commit_bfm()

#     clock = Clock(dut.clk_i, 10, units="ns")
#     cocotb.start_soon(clock.start())
#     bfm.start_bfm()
#     bfm_commit.start_bfm()

#     for sig in dut:
#         print(sig._name)


#     await bfm.reset()
#     for _ in range(3):
#         await RisingEdge(dut.clk_i)

#     interface_data = xif_issue_seqItem()
#     for id in range(10):
#         print(id)
#         interface_data.randomize()
#         # interface_data.randomize_illegal()
#         interface_data.issue_req.id = id
#         await bfm.send_op(1,copy.deepcopy(interface_data.issue_req))
#         cocotb.start_soon(eval_issue_resp(dut,copy.deepcopy(interface_data)))
#         # await send_req_eval(bfm,interface_data)
#         cocotb.log.info(f'Dut interface data in tb: {interface_data.issue_req}')
#         cocotb.log.info(f'instrucation select tb: {interface_data.sel_instr}')
#         print(" ")
    
#     await bfm.reset()
    
#     cocotb.log.info(f'Dut output read {bfm.read_output()}')
#     for _ in range(10):
#         await RisingEdge(dut.clk_i)

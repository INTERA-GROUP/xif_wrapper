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
        self.valid = 1
    def randomize(self):
        # self.valid = random.randint(0, 1)
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
        # self.valid = random.randint(0, 1)
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


class exe_result_seqItem():
    def __init__(self,):
        self.issue_seq = xif_issue_seqItem()
        self.result_pkt = x_issue_fifo_res_t()
        self.result_data = 0
        self.result_valid = 0
        # self.req = x_issue_req_t()
        # self.resp = x_issue_req_t() 
    def randomize(self):
        self.result_pkt.result_data = random.randint(0,2**32)
        self.issue_seq.randomize_valid()
        self.result_pkt.req = self.issue_seq.issue_req
        self.result_pkt.resp = instructions[self.issue_seq.sel_instr]["resp"]



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


def read_xif_result_intf(dut):
    print(123)
    result = x_result_t()   
    result.id = int(dut.ext_if_coproc_result_id.value) 
    result.data = int(dut.ext_if_coproc_result_data.value)
    result.rd = int(dut.ext_if_coproc_result_rd.value) 
    result.we = int(dut.ext_if_coproc_result_we.value) 
    result.ecsdata = int(dut.ext_if_coproc_result_ecsdata.value)   
    result.ecswe = int(dut.ext_if_coproc_result_ecswe.value)   
    result.exc = int(dut.ext_if_coproc_result_exc.value)   
    result.exccode = int(dut.ext_if_coproc_result_exccode.value)    
    result.err = int(dut.ext_if_coproc_result_err.value)    
    result.dbg = int(dut.ext_if_coproc_result_dbg.value)
    return result


async def populate_commit_interface(dut, interface_data,kill=0):
    # await FallingEdge(dut.clk_i)
    # issue_bfm=xif_issue_bfm()
    commit_bfm = xif_commit_bfm()
    # result = issue_bfm.read_output()
    # cocotb.log.info(f'Dut resp: {result}')
    # cocotb.log.info(f'Data passing to the commit interface: {interface_data.issue_req}')
    commit_req = x_commit_t()
    commit_req.commit_kill= kill
    commit_req.id= interface_data.issue_req.id
    await commit_bfm.send_op(1,commit_req)


async def compare_aync_issue_result(dut, interface_data):
    bfm  = xif_issue_bfm()
    await FallingEdge(dut.clk_i)
    await Timer(1,units='ns')
    issue_resp = bfm.read_output()

    cocotb.log.info(f'compare_aync_issue_result expected: requset: {interface_data.issue_req}')

    if interface_data.valid == 1:
        excepted_resp = instructions[interface_data.sel_instr]["resp"]
    else:
        excepted_resp = x_issue_resp_t(accept=0x0, writeback=0x0, dualwrite=0x0, dualread=0x0, loadstore=0x0, ecswrite=0x0, exc=0x0)
    

    assert issue_resp == excepted_resp , \
            f"Resp is diffrent then the expected one"


async def exe_interface_dut(dut, interface_data):

    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)
    await Timer(1,units='ns')
    if interface_data.valid == 1:
        dut.exe_wrapper_recv_instr_ready.value = 1
        
        req,resp = read_result_intf(dut)
        cocotb.log.info(f'exe_interface_dut req: {req}')
        cocotb.log.info(f'exe_interface_dut resp: {resp}')
        cocotb.log.info(f'issue_interface expected: resp: {interface_data.issue_req}')
        cocotb.log.info(f'issue_interface expected: sel_instr: {interface_data.sel_instr}')

        await FallingEdge(dut.clk_i)

        dut.exe_wrapper_recv_instr_ready.value = 0

        # issue_resp = bfm.read_output()
        assert resp == instructions[interface_data.sel_instr]["resp"] , \
                f"Resp is diffrent then the expected at the exe_interface_dut"
        assert req == interface_data.issue_req , \
                f"Req is diffrent then the expected at the exe_interface_dut"        




async def xif_result_interface_dut(dut, interface_data, delay_cycles=1):

    expected_resp = x_result_t()
    expected_resp.id = interface_data.result_pkt.req.id
    expected_resp.data = interface_data.result_pkt.result_data
    expected_resp.rd = interface_data.issue_seq.rd
    expected_resp.we = interface_data.result_pkt.resp.writeback
    expected_resp.ecsdata = 0
    expected_resp.ecswe = 0
    expected_resp.exc = 0
    expected_resp.exccode = 0 
    expected_resp.err = 0
    expected_resp.dbg = 0
    if interface_data.result_pkt.result_valid == 1:
        await FallingEdge(dut.clk_i)
        for _ in range(delay_cycles):
            await FallingEdge(dut.clk_i)
        await Timer(1,units='ns')

        dut.ext_if_coproc_result_ready.value = 1
        resp = read_xif_result_intf(dut)
        # cocotb.log.info(f'exe_interface_dut req: {}')
        cocotb.log.info(f'result_interface resp: {resp}')
        await FallingEdge(dut.clk_i)
        dut.ext_if_coproc_result_ready.value = 0

        print("comparison needed")
        assert resp == expected_resp, \
                f"Resp is diffrent then the expected at the exe_interface_dut"


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
    dut.exe_wrapper_recv_instr_ready.value = 0
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
    await FallingEdge(dut.clk_i)
    try:
        assert get_int(dut.ext_if_coproc_issue_ready) == 1,\
                f" After reset this should 1 "
        assert get_int(dut.wrapper_exe_instr_valid) == 0,  \
                f"  After reset this should 0"
    except AssertionError as e:
        cocotb.log.error(f"ASSERT FAILED: {e}")
        # Optionally set a debug signal or flag
        dut.debug_signal.value = 1

        # Wait some time before re-raising or continuing
        await Timer(100, units="ns")

        raise
    
    for _ in range(10):
        await RisingEdge(dut.clk_i)



@cocotb.test()
async def all_issue_illegel_without_commit(dut):
    """All the instrucations passed are not accepted by the dut. There is not corresponding commit valid"""

    cocotb.start_soon(stop_after(1000))
    bfm = xif_issue_bfm()

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()

    for sig in dut:
        print(sig._name)


    await bfm.reset()
    dut.exe_wrapper_recv_instr_ready.value = 0
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
    """ send invalid commit signal"""
    cocotb.start_soon(stop_after(1000))
    bfm = xif_issue_bfm()
    bfm_commit = xif_commit_bfm()

    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()
    bfm_commit.start_bfm()

    for sig in dut:
        print(sig._name)

    dut.exe_wrapper_recv_instr_ready.value = 0
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
        assert get_int(dut.wrapper_exe_instr_valid) == 0,  \
                f" Wrapper_exe_instr shouldnt be set as the commit_valid isnt for the same instrucations instrucation_dispatched"
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
    dut.exe_wrapper_recv_instr_ready.value = 0
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
                f" Wrapper_exe_instr shouldnt be set as the commit_valid isnt to instrucation_dispatched"
        assert get_int(dut.wrapper_exe_instr_valid) == 1,  \
                f" Wrapper_exe_instr shouldnt be set as the commit_valid isnt to instrucation_dispatched"
    
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

    dut.exe_wrapper_recv_instr_ready.value = 0
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
        assert get_int(dut.wrapper_exe_instr_valid) == 0,  \
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

    dut.exe_wrapper_recv_instr_ready.value = 0
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
        assert get_int(dut.wrapper_exe_instr_valid) == 0,  \
                f"Didnt send the correct commit id  wrapper_exe_instr_valid should set to zero"
    
    except AssertionError as e:
        cocotb.log.error(f"ASSERT FAILED: {e}")
        # Wait some time before re-raising or continuing
        for _ in range(10):
            await FallingEdge(dut.clk_i)
        raise




async def _issue_commit_exe_interface_porperly(dut):
    """ send commit signal properly without kill"""
    cocotb.start_soon(stop_after(10000))
    bfm = xif_issue_bfm()
    bfm_commit = xif_commit_bfm()
    dut.exe_wrapper_recv_instr_ready.value = 0
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm.start_bfm()
    bfm_commit.start_bfm()



    await bfm.reset()
    for _ in range(3):
        await RisingEdge(dut.clk_i)

    interface_data = xif_issue_seqItem()
    for id in range(100):
        print(id)
        interface_data.randomize_valid()
        # interface_data.randomize_illegal()
        interface_data.issue_req.id = id%16
        valid= random.choice([0,1])
        print("valid; ", valid)
        interface_data.valid =  valid
        await bfm.send_op(copy.deepcopy(interface_data.valid),copy.deepcopy(interface_data.issue_req))
        cocotb.log.info(f'Dut interface data in tb: {interface_data.issue_req}')
        cocotb.log.info(f'Dut interface req valid in tb: {interface_data.valid}')
        f1 = cocotb.start_soon(populate_commit_interface(dut,copy.deepcopy(interface_data),0))
        f2 = cocotb.start_soon(exe_interface_dut(dut,copy.deepcopy(interface_data)))
        # await send_req_eval(bfm,interface_data)
        cocotb.log.info(f'instrucation select tb: {interface_data.sel_instr}')
        f3 = cocotb.start_soon(compare_aync_issue_result(dut,copy.deepcopy(interface_data)))  
        
        print(" ")
    
    await Combine(f1,f2,f3)

    for _ in range(10):
        await FallingEdge(dut.clk_i)

@cocotb.test()
async def issue_commit_exe_interface_porperly(dut):
    await _issue_commit_exe_interface_porperly(dut)


    


@cocotb.test()
async def exe_result_interface_fifo_fill(dut):
    """ send commit signal properly without kill"""
    cocotb.start_soon(stop_after(1000))
    bfm = exe_result_bfm()
    bfm.start_bfm()
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm_issue = xif_issue_bfm()
    dut.exe_wrapper_recv_instr_ready.value = 0
    dut.ext_if_coproc_result_ready.value = 0
    await bfm_issue.reset()

    for _ in range(3):
        await RisingEdge(dut.clk_i)

    result_data = exe_result_seqItem()
    for id in range(4):
        print(id)
        result_data.randomize()
        result_data.result_pkt.req.id = id
        result_data.result_pkt.result_valid = 1
        await bfm.send_op(1,copy.deepcopy(result_data.result_pkt))

    for _ in range(2):
        await FallingEdge(dut.clk_i)
    
    try:
        assert get_int(dut.wrapper_exe_recv_result_ready) == 0,\
                f"Fifo should be full"
    
    except AssertionError as e:
        cocotb.log.error(f"ASSERT FAILED: {e}")
        # Wait some time before re-raising or continuing
        for _ in range(10):
            await FallingEdge(dut.clk_i)
        raise



async def _exe_result_xif_interface(dut):
    """ send commit signal properly without kill"""
    cocotb.start_soon(stop_after(10000))
    bfm = exe_result_bfm()
    bfm.start_bfm()
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())
    bfm_issue = xif_issue_bfm()
    dut.exe_wrapper_recv_instr_ready.value = 0
    dut.ext_if_coproc_result_ready.value = 0
    await bfm_issue.reset()

    for _ in range(3):
        await RisingEdge(dut.clk_i)

    result_data = exe_result_seqItem()
    task_arr=[]
    for id in range(100):
        print(id)
        result_data.randomize()
        result_data.result_pkt.req.id = id%16
        result_data.result_pkt.result_valid = random.randint(0,1)
        await bfm.send_op(copy.deepcopy(result_data.result_pkt.result_valid),copy.deepcopy(result_data.result_pkt))
        task_arr.append(cocotb.start_soon(xif_result_interface_dut(dut,copy.deepcopy(result_data))))

    await Combine(*task_arr)
    for _ in range(2):
        await FallingEdge(dut.clk_i)
    

@cocotb.test()
async def exe_result_xif_interface(dut):
        await _exe_result_xif_interface(dut)



@cocotb.test()
async def combine_all_working_test(dut):
    await Combine (
         cocotb.start_soon(_exe_result_xif_interface(dut)),
   cocotb.start_soon( _issue_commit_exe_interface_porperly(dut)))

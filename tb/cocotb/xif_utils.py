import cocotb
from cocotb.triggers import FallingEdge,Timer,RisingEdge
from cocotb.queue import QueueEmpty, Queue
import enum
import logging
from typing import Optional
from dataclasses import dataclass
from dataclasses import field, fields
from pyuvm import utility_classes
from multipledispatch import dispatch
import copy


def get_int(signal):
    try:
        sig = int(signal.value)
    except ValueError:
        sig = 0
    return sig


@dataclass
class x_issue_req_t:
    # x_issue_req_t
    instr:      int = 0
    mode:       int = 0
    id:         int = 0
    rs :        int = 0
    rs_valid:   int = 0
    ecs:        int = 0
    ecs_valid:  bool = 0

    def __repr__(self):
        return (
            f"x_issue_req_t("
            f"instr=0x{self.instr:X}, "
            f"mode=0x{self.mode:X}, "
            f"id=0x{self.id:X}, "
            f"rs=0x{self.rs:X}, "
            f"rs_valid=0x{self.rs_valid:X}, "
            f"ecs=0x{self.ecs:X}, "
            f"ecs_valid=0x{int(self.ecs_valid):X})"
        )

@dataclass
class x_issue_resp_t:
    accept:     Optional[bool] = None
    writeback:  Optional[bool] = None
    dualwrite:  Optional[bool] = None
    dualread:   Optional[int]  = None
    loadstore:  Optional[bool] = None
    ecswrite:   Optional[bool] = None
    exc:        Optional[bool] = None

    def __repr__(self):
        def fmt(val):
            return f"0x{int(val):X}" if val is not None else "None"

        return (
            f"x_issue_resp_t("
            f"accept={fmt(self.accept)}, "
            f"writeback={fmt(self.writeback)}, "
            f"dualwrite={fmt(self.dualwrite)}, "
            f"dualread={fmt(self.dualread)}, "
            f"loadstore={fmt(self.loadstore)}, "
            f"ecswrite={fmt(self.ecswrite)}, "
            f"exc={fmt(self.exc)})"
        )

            
    def __eq__(self, other):
        if not isinstance(other, x_issue_resp_t):
            return NotImplemented
        if self.accept  == other.accept:
            if self.accept  == True and other.accept == True:
                for f in fields(self):
                    a = getattr(self, f.name)
                    b = getattr(other, f.name)

                    # None means don't care
                    if a is None or b is None:
                        continue

                    if int(a) != int(b):
                        return False
        else:
            return False

        return True



@dataclass
class x_result_t:
    id: int = 0
    data: int = 0
    rd: int = 0
    we: int = 0
    ecsdata: int = 0
    ecswe: int = 0
    exc: bool = False
    exccode: int = 0
    err: bool = False
    dbg: bool = False

    def __repr__(self):
        return (
            f"x_result_t("
            f"id=0x{self.id:X}, "
            f"data=0x{self.data:X}, "
            f"rd=0x{self.rd:X}, "
            f"we=0x{self.we:X}, "
            f"ecsdata=0x{self.ecsdata:X}, "
            f"ecswe=0x{self.ecswe:X}, "
            f"exc=0x{int(self.exc):X}, "
            f"exccode=0x{self.exccode:X}, "
            f"err=0x{int(self.err):X}, "
            f"dbg=0x{int(self.dbg):X})"
        )

@dataclass
class x_commit_t:
    # x_commit_t
    id:         int = 0
    commit_kill:  bool = 0

    def __repr__(self):
        return (
            f"x_commit_t("
            f"id=0x{self.id:X}, "
            f"commit_kill=0x{int(self.commit_kill):X})"
        )
@dataclass
class x_issue_fifo_res_t:
    # x_commit_t

    result_data: int = 0
    result_valid: bool = 0
    req : x_issue_req_t = field(default_factory=x_issue_req_t)
    resp : x_issue_resp_t = field(default_factory=x_issue_resp_t)

    def __repr__(self):
        return (
            f"x_issue_fifo_res_t("
            f"result_data=0x{self.result_data:X}, "
            f"result_valid=0x{int(self.result_valid):X}, "
            f"req={self.req}, "
            f"resp={self.resp})"
        )
    
    def __eq__(self, other):
        if not isinstance(other, x_issue_fifo_res_t):
            return False
        return (
            self.result_valid == other.result_valid and
            self.result_data == other.result_data and
            self.req == other.req and
            self.resp == other.resp
        )


@dataclass
class x_issue_t:
    req : x_issue_req_t = field(default_factory=x_issue_req_t)
    resp : x_issue_resp_t = field(default_factory=x_issue_resp_t)

    def __repr__(self):
        return (
            f"x_issue_t("
            f"req={self.req}, "
            f"resp={self.resp})"
        )


class xif_issue_bfm(metaclass=utility_classes.Singleton):
    def __init__(self):
        self.dut = cocotb.top
        self.driver_queue = Queue(maxsize=1)
        self.cmd_mon_queue = Queue(maxsize=0)
        self.result_mon_queue = Queue(maxsize=0)
    
    async def send_op(self, issue_valid:bool ,inf):
        input_tuple = (issue_valid,inf)
        await self.driver_queue.put((issue_valid,inf))
    
    async def get_cmd(self):
        cmd = await self.cmd_mon_queue.get()
        return cmd

    async def get_result(self):
        result = await self.result_mon_queue.get()
        return result
        
    async def reset(self):
        await FallingEdge(self.dut.clk_i)
        self.dut.rst_ni.value = 0
        interface_data = x_issue_req_t()
        self.apply_input(0,interface_data)
        await FallingEdge(self.dut.clk_i)
        self.dut.rst_ni.value = 1
        self.driver_queue = Queue(maxsize=1)
        self.cmd_mon_queue = Queue(maxsize=0)
    
    def apply_input(self, issue_valid:bool ,inf ):
        issue_valid = bool(issue_valid)

        if isinstance(inf, x_issue_req_t):
            req = inf
        elif isinstance(inf, x_issue_t):
            req = inf.req
        else:
            raise TypeError(f"Unsupported type: {type(inf)}")

        self.dut.ext_if_coproc_issue_valid.value      = issue_valid
        self.dut.ext_if_coproc_issue_req_instr.value = req.instr
        self.dut.ext_if_coproc_issue_req_mode.value  = req.mode
        self.dut.ext_if_coproc_issue_req_id.value    = req.id
        self.dut.ext_if_coproc_issue_req_rs.value    = req.rs
        self.dut.ext_if_coproc_issue_req_rs_valid.value = req.rs_valid
        self.dut.ext_if_coproc_issue_req_ecs.value   = req.ecs
        self.dut.ext_if_coproc_issue_req_ecs_valid.value = req.ecs_valid


    def read_output(self):
        resp = x_issue_resp_t()
        resp.accept = get_int(self.dut.ext_if_coproc_issue_resp_accept)
        resp.writeback = get_int(self.dut.ext_if_coproc_issue_resp_writeback)
        resp.dualwrite = get_int(self.dut.ext_if_coproc_issue_resp_dualwrite)
        resp.dualread = get_int(self.dut.ext_if_coproc_issue_resp_dualread)
        resp.loadstore = get_int(self.dut.ext_if_coproc_issue_resp_loadstore)
        resp.ecswrite = get_int(self.dut.ext_if_coproc_issue_resp_ecswrite)
        resp.exc = get_int(self.dut.ext_if_coproc_issue_resp_exc)
        return resp
            

    async def driver_bfm(self):
        interface_data = x_issue_req_t()
        self.apply_input(0,interface_data)
        while True:
            await RisingEdge(self.dut.clk_i)
            # if  get_int(self.dut.ext_if_coproc_issue_ready)== 0:
            #     try:
            #         (_,_) = self.driver_queue.get_nowait()
            #     except QueueEmpty:
            #         continue
            await FallingEdge(self.dut.clk_i)
            dut_ready =  get_int(self.dut.ext_if_coproc_issue_ready)
            if dut_ready == 1:
                try:
                    (issue_valid, interface_data) =  self.driver_queue.get_nowait()
                    cocotb.log.info(f'Dut interface data in xif_issue_bfm: {interface_data}')
                    self.apply_input(issue_valid,interface_data)
                    if issue_valid ==1:
                        cocotb.log.info(f"{interface_data}")
                        self.cmd_mon_queue.put_nowait(copy.deepcopy(interface_data))
                except QueueEmpty:
                    self.dut.ext_if_coproc_issue_valid.value = 0
            else:
                self.dut.ext_if_coproc_issue_valid.value = 0
                        
                
    
    async def cmd_mon_bfm(self):
        prev_ready = 0
        while True:
            await FallingEdge(self.dut.clk_i)
            ready = get_int(self.dut.ext_if_coproc_issue_ready)
            if ready == 1 :
                input_data = x_issue_req_t()
                
                input_data.instr     = get_int(self.dut.ext_if_coproc_issue_req_instr)
                input_data.mode      = get_int(self.dut.ext_if_coproc_issue_req_mode)
                input_data.id        = get_int(self.dut.ext_if_coproc_issue_req_id)
                input_data.rs        = get_int(self.dut.ext_if_coproc_issue_req_rs)
                input_data.rs_valid  = get_int(self.dut.ext_if_coproc_issue_req_rs_valid)
                input_data.ecs       = get_int(self.dut.ext_if_coproc_issue_req_ecs)
                input_data.ecs_valid = get_int(self.dut.ext_if_coproc_issue_req_ecs_valid)

                cmd_tuple = (get_int(self.dut.ext_if_coproc_issue_valid),
                            input_data)
                
            prev_ready = ready
    
    async def result_mon_bfm(self):
        prev_accept = 0
        while True:
            await FallingEdge(self.dut.clk_i)
            resp = x_issue_resp_t() 
            accept = get_int(self.dut.ext_if_coproc_issue_resp_accept)
            if accept == 1:
                resp = self.read_output()
                self.result_mon_queue.put_nowait(resp)

    def start_bfm(self):
        cocotb.start_soon(self.driver_bfm())
        # cocotb.start_soon(self.cmd_mon_bfm())
        # cocotb.start_soon(self.result_mon_bfm())

class xif_commit_bfm(metaclass=utility_classes.Singleton):
    def __init__(self):
        self.dut = cocotb.top
        self.driver_queue = Queue(maxsize=1)
        self.cmd_mon_queue =  Queue(maxsize=0)

    
    async def send_op(self, issue_valid:bool ,inf:x_commit_t):
        input_tuple = (issue_valid,inf)
        await self.driver_queue.put((issue_valid,inf))
    
    async def get_cmd(self):
        cmd = await self.cmd_mon_queue.get()
        return cmd

    def apply_input(self, valid:bool ,inf:x_commit_t ):
        self.dut.ext_if_coproc_commit_valid.value = valid
 
        self.dut.ext_if_coproc_commit_id.value = inf.id
        self.dut.ext_if_coproc_commit_kill.value = inf.commit_kill
    
    async def reset(self):
        self.driver_queue = Queue(maxsize=1)
        self.cmd_mon_queue = Queue(maxsize=0)


    async def driver_bfm(self):
        interface_data = x_commit_t()
        self.apply_input(0,interface_data)
        while True:
            await RisingEdge(self.dut.clk_i)
            # if  get_int(self.dut.ext_if_coproc_issue_ready)== 0:
            #     try:
            #         (_,_) = self.driver_queue.get_nowait()
            #     except QueueEmpty:
            #         continue

            await FallingEdge(self.dut.clk_i)
            dut_ready =  get_int(self.dut.ext_if_coproc_issue_ready)
            await Timer(1, units="step")
            dut_ready =  get_int(self.dut.ext_if_coproc_issue_ready)
            if dut_ready == 1:
                try:
                    (issue_valid, interface_data) =  self.driver_queue.get_nowait()
                    cocotb.log.info(f'Dut interface data in xif_commit_bfm: {interface_data}')
                    self.apply_input(issue_valid,interface_data)
                    if issue_valid == 1:
                        self.cmd_mon_queue.put_nowait(copy.deepcopy(interface_data))
                except QueueEmpty:
                    self.dut.ext_if_coproc_commit_valid.value = 0
            else:
                self.dut.ext_if_coproc_commit_valid.value = 0



    def start_bfm(self):
        cocotb.start_soon(self.driver_bfm())


class exe_result_bfm(metaclass=utility_classes.Singleton):
    def __init__(self):
        self.dut = cocotb.top
        self.driver_queue = Queue(maxsize=1)

    
    async def send_op(self, issue_valid:bool ,inf):
        input_tuple = (issue_valid,inf)
        await self.driver_queue.put((issue_valid,inf))


    def apply_input(self,valid:bool, data:x_issue_fifo_res_t):
        self.dut.exe_wrapper_result_result_data_exec_o.value = data.result_data
        self.dut.exe_wrapper_result_result_valid_exec_o.value = data.result_valid
        self.dut.exe_wrapper_result_issue_exec_o_req_instr.value = data.req.instr 
        self.dut.exe_wrapper_result_issue_exec_o_req_mode.value = data.req.mode 
        self.dut.exe_wrapper_result_issue_exec_o_req_id.value = data.req.id
        self.dut.exe_wrapper_result_issue_exec_o_req_rs.value = data.req.rs
        self.dut.exe_wrapper_result_issue_exec_o_req_rs_valid.value = data.req.rs_valid
        self.dut.exe_wrapper_result_issue_exec_o_req_ecs.value = data.req.ecs
        self.dut.exe_wrapper_result_issue_exec_o_req_ecs_valid.value = data.req.ecs_valid
        self.dut.exe_wrapper_result_issue_exec_o_resp_accept.value = data.resp.accept
        self.dut.exe_wrapper_result_issue_exec_o_resp_writeback.value = data.resp.writeback
        self.dut.exe_wrapper_result_issue_exec_o_resp_dualwrite.value = data.resp.dualwrite
        self.dut.exe_wrapper_result_issue_exec_o_resp_dualread.value = data.resp.dualread
        self.dut.exe_wrapper_result_issue_exec_o_resp_loadstore.value = data.resp.loadstore
        self.dut.exe_wrapper_result_issue_exec_o_resp_ecswrite.value = data.resp.ecswrite
        self.dut.exe_wrapper_result_issue_exec_o_resp_exc.value = data.resp.exc

    async def driver_bfm(self):
        interface_data = x_issue_fifo_res_t()


        self.dut.exe_wrapper_result_result_valid_exec_o.value = 0
        while True:
            await FallingEdge(self.dut.clk_i)
            dut_ready =  get_int(self.dut.wrapper_exe_recv_result_ready)
            if dut_ready == 1:
                try:
                    (issue_valid, interface_data) =  self.driver_queue.get_nowait()
                    cocotb.log.info(f'Dut interface data in exe_result_bfm: {interface_data}')
                    self.apply_input(issue_valid,interface_data)
                except QueueEmpty:
                    self.dut.exe_wrapper_result_result_valid_exec_o.value = 0


    def start_bfm(self):
        cocotb.start_soon(self.driver_bfm())

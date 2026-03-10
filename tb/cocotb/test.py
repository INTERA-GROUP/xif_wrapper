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

from cocotb.result import TestComplete


from typing import Optional

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

    
    # def __eq__(self, other):
    #     if not isinstance(other, x_issue_resp_t):
    #         return NotImplemented
    #     if self.accept  == other.accept:
    #         if self.accept  == True and other.accept == True:
    #             for f in fields(self):
    #                 a = getattr(self, f.name)
    #                 b = getattr(other, f.name)

    #                 # None means don't care
    #                 if a is None or b is None:
    #                     continue

    #                 if int(a) != int(b):
    #                     return False
    #     else:
    #         return False

    #     return True


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


print("length :",len(instructions))

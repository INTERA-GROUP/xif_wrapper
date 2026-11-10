# X-IF Copro Wrapper

The `xif_wrapper` connects a processor using **CV-X-IF v1.0** to a custom execution block. It handles instruction decoding, register values and commit decisions, then returns the execution results to the processor.

The design uses a collection buffer, an instruction FIFO and a result FIFO so that several instructions can remain pending while the processor and execution block work at different rates.

![MAC example](<doc/x-if-v1.0 MAC.png>)

*Example with a MAC accelerator.*

## How It Works

1. **Issue:** the predecoder checks the instruction and returns `accept`, `register_read` and `writeback`. Accepted instructions reserve a collection buffer slot; rejected instructions do not
2. **Registers:** source values arrive through the register channel and are matched to their instruction using `(hartid, id)`
3. **Commit:** the processor tells the wrapper which waiting instructions to keep or cancel:

   - `commit_kill = 0`: keep this instruction and the ones sent before it so they can execute.
   - `commit_kill = 1`: cancel this instruction and the ones sent after it.

   This only applies to waiting instructions from the same hardware thread (`hartid`).

4. **Execution:** once an accepted instruction has its required operands and a non kill commit, it enters the instruction FIFO and waits for the execution block.
5. **Result:** the execution block returns the result and its instruction packet. The result FIFO holds them until the processor is ready.


## Configuration

Connect the processor's issue, register, commit and result channels to the wrapper and connect the execution block through [`if_xif_exe`](pkg/if_xif_exe.sv). All interfaces share `clk_i` and the active low reset `rst_ni`.

Register values are the input data used by an instruction, such as the two numbers in an addition.

| Parameter | Default | What it controls |
|-----------|---------|------------------|
| `ISSUE_REGISTER_SPLIT` | `0` | When input data arrives: `0` = together with the instruction; `1` = after the instruction has been accepted |
| `INSTR_DEPTH` | `20` | Storage space: 20 slots in the collection buffer, 20 in the instruction FIFO and 20 in the result FIFO |
| `XIF_NUM_HARTS` | `1` | How many processor hardware threads the wrapper can track; `1` means instructions from one thread |

A hart is a hardware thread of the processor, with its own sequence of instructions.

In split mode, register transfers may arrive in a different order from issue, and registers and commit may arrive in either order. In non split mode, the required matching register values must be valid before issue is accepted.

The supplied configuration uses **4-bit instruction IDs, three source registers and 32-bit data**. Processor packets are defined in [`cvxif_v1_pkg.sv`](pkg/cvxif_v1_pkg.sv); instruction and execution types are defined in [`cvxif_instr_pkg.sv`](pkg/cvxif_instr_pkg.sv). Keep their widths consistent and compile both packages before the interface and RTL modules.

## Instruction Predecoder

The [`instr_predecoder`](rtl/instr_predecoder/instr_predecoder.sv) is combinational. It compares each instruction against the encodings and masks in `CoproInstr`, then provides the decoder response and required register mask. An instruction with no match is rejected.

To add an instruction, add its encoding, mask, register requirements and response to `CoproInstr_def`, and update `NbInstr_def`. For a custom table, pass `CoproInstr` and its size through `NbInstr`. Keep encoding masks from overlapping and implement the operation in the execution block.

## Run the Testbench

The testbench (TB) acts as a processor sending instructions and uses a small MAC model as the accelerator. It checks that the wrapper passes the right instructions, input data and results between them.

Install **Verilator**, a **C++ compiler**, **make** and **Bash**. Open a terminal in the repository folder and run:

```bash
./regressions/regress_v1_tb.sh
```

This command builds and runs [`tb_xif_wrapper_v1.sv`](tb/tb_wrapper/tb_xif_wrapper_v1.sv). No Bender or Cocotb setup is needed.

### What Happens During the Test

1. The TB sends instructions until the wrapper is holding **20**. It has not sent their input data or commit decisions yet, so they stay waiting
2. It tries to send the **21st instruction (ID 20)**. The buffer is full, so the wrapper sets `ready = 0` and keeps this instruction waiting
3. The TB starts sending **register values** (the numbers used by each instruction) and **commit decisions** (permission to run or a request to cancel). As buffer slots become free, the remaining instructions can enter
4. Instructions allowed to run go to the **MAC model**. The model calculates a result and sends it back through the wrapper to the processor

All **25 instructions** receive register and commit packets, including the rejected ones. The wrapper ignores the register values of rejected instructions. For some accepted instructions, commit arrives first; for others, register values arrive first.

The default test rejects **2 unsupported instructions** and cancels **1 accepted instruction**. Those three must never reach the accelerator, so the expected result is **25 − 2 − 1 = 22 completed instructions**.

### How to Read the Output

Each message shows where the data comes from and where it goes. Follow the same **ID** to see one instruction throughout the test:

- `CPU -> WRAPPER` → an instruction, its input data or its commit decision enters the wrapper
- `WRAPPER -> CPU ISSUE` → `accept=1` means accepted, `accept=0` means rejected
- `WRAPPER -> CPU WAIT` → the instruction is waiting for buffer space
- `WRAPPER -> ACCELERATOR` → the wrapper sends an instruction and its input data to the accelerator
- `MAC MODEL -> WRAPPER` → the simulated accelerator returns its calculated result
- `WRAPPER -> CPU RESULT` → the wrapper delivers that result to the processor

`BUFFER FULL` shows that the test reached the 20 slot limit and made the next instruction wait. 

At the end, **`PASS`** means all checks passed. The summary counts what actually happened. **`FAIL`** stops the test and shows the instruction ID, opcode and reason.

### Try a Smaller Test

For **10 instructions** and **4 buffer slots**, run:

```bash
./regressions/regress_v1_tb.sh -GNUM_INSTRUCTIONS=10 -GBUFFER_DEPTH=4
```

`NUM_INSTRUCTIONS` is how many instructions to send. `BUFFER_DEPTH` is how many collection slots the wrapper has.

The script uses **5-bit IDs**, giving labels from **0 to 31**, so all 25 instructions can have different labels. The project default remains 4 bits, which gives labels from 0 to 15. The MAC and FIFOs used here are simulation models.

## Credits

- **Original wrapper:** Gonzalo Salinas Hernando, <gonzalo.salinas@nvision.es>, **NVISION**
- **CV-X-IF v1.0 adaptation and testbench:** Maryana Pyzh, <maryana.pyzh@irvmic.com>,  **INNOVA IRV Microelectronics SL**


Reference: [CV-X-IF v1.0 specification](https://docs.openhwgroup.org/projects/openhw-group-core-v-xif/en/v1.0.0/x_ext.html).

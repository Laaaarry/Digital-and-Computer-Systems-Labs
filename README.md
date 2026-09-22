# Digital and Computer Systems Labs (ECE253)

SystemVerilog hardware designs and RISC-V assembly programs written for ECE253 (Digital and Computer Systems) at the University of Toronto, Fall 2025. These lab were completed with my lab partner for the course Jacky Li.

The work runs from gate-level logic up to a small processor, then switches to software on a RISC-V soft processor: subroutines, memory-mapped I/O, and hardware timers.

| Area | What's in this repo | Tools |
|---|---|---|
| **RTL design** | Arithmetic and logic units, shift registers, parameterized counters, finite state machines, a 16-bit processor with separate control path and datapath, a restoring divider | SystemVerilog, ModelSim |
| **Verification** | ModelSim `.do` simulation scripts written for each design | ModelSim, `.do` scripts |
| **Assembly** | RISC-V programs using the standard calling convention: list processing, bit manipulation, in-place bubble sort | RV32 (Nios V), CPUlator |
| **Embedded I/O** | Polled pushbutton input, LED output, edge-capture registers, hardware interval timer, run on a DE1-SoC board | Nios V on DE1-SoC, Intel FPGA Monitor Program |

---

## Repository layout

| Folder | Topic | Language |
|---|---|---|
| [`Lab1`](Lab1) | Toolchain and autograder setup (course-provided code) | SystemVerilog |
| [`Lab2`](Lab2) | Hierarchy, multiplexers, simulation scripts | SystemVerilog |
| [`Lab3`](Lab3) | Ripple-carry adder, combinational and sequential ALUs | SystemVerilog |
| [`Lab4`](Lab4) | Rotating shift register, parameterized rate divider and counter | SystemVerilog |
| [`Lab5`](Lab5) | FSMs, a simple processor, a restoring divider | SystemVerilog |
| [`Lab6`](Lab6) | Introduction to RISC-V assembly | RISC-V assembly |
| [`Lab7`](Lab7) | Subroutines and calling convention | RISC-V assembly |
| [`Lab8`](Lab8) | Memory-mapped I/O, polling, hardware timers | RISC-V assembly |

**Provided vs. What I wrote** is noted for every lab below. Unless stated otherwise, module signatures (port names and widths) were fixed by the course so the autograder could test them.

Labs 1 and 6 are more introductory labs and won't be discussed here.


---

## Lab 2 — Hierarchy, Multiplexers, and Simulation

**Task.** Rebuild the 7400-series logic chips from a breadboard lab as HDL modules, then compose them into a working circuit.

**What I wrote**
- `v7404`, `v7408`, `v7432`: pin-accurate models of a hex inverter, quad AND, and quad OR chip, with every gate implemented even where unused.
- `mux2to1`: a 2-to-1 multiplexer built *structurally* from one instance of each chip module, wired with named port connections.
- `mux7to1`: a 7-to-1 multiplexer described *behaviourally* with a `case` statement in `always_comb`, including a `default` branch.
- A separate `.do` simulation script for each of the chip modules and the top-level multiplexer.

**Provided.** A reference `mux.sv` and example `.do` script (Part I), used as the starting pattern.

---

## Lab 3 — Ripple-Carry Adder and ALUs

**Task.** Build an adder from full adders, use it inside an arithmetic logic unit (ALU), then add a register so the ALU can operate on its own previous result.

**What I wrote**
- **4-bit ripple-carry adder:** a full-adder module instantiated four times, with carries chained between stages and every intermediate carry exposed as an output.
- **Combinational ALU:** a 2-bit function select choosing between the adder output, an OR reduction across both inputs, an AND reduction across both inputs, and a concatenation of the inputs into an 8-bit output. The adder is instantiated outside the `always_comb` block and its result fed into the selection logic.
- **Sequential ALU:** an 8-bit register with active-high synchronous reset stores the ALU output, and its lower 4 bits feed back as one of the ALU's operands. Repeated clock edges accumulate a running add, multiply, or left-shift, or hold the current value.

**Provided.** A reference D flip-flop module, used as the model for the register.

---

## Lab 4 — Shift Registers and Rate-Divided Counters

**Task.** Build sequential datapath elements, and count at human-visible speeds from a clock that runs millions of times faster.

**What I wrote**
- **4-bit rotating register with parallel load:** each bit is a flip-flop plus two multiplexers (one for load, one for direction). Supports parallel load, rotate left, rotate right, and arithmetic shift right (sign bit preserved).
- **Parameterized rate divider:** a down-counter that emits a one-cycle enable pulse at full speed, 1 Hz, 0.5 Hz, or 0.25 Hz. The clock frequency is a module parameter, and the counter width is derived from it with `$clog2`, so the same code runs at 500 Hz in simulation or 50 MHz on the board.
- **Display counter:** a 4-bit counter that advances only when the enable pulse is high, composed with the rate divider in a top-level module.

**Provided.** The D flip-flop pattern from Lab 3 and the module signatures.

---

## Lab 5 — Finite State Machines and a Simple Processor

**Task.** Write an FSMs, then use an FSM as the controller for a datapath using an ALU.

### Part 1 — Sequence detector
An FSM that outputs 1 after seeing either `1111` or `1101` on a serial input, with overlapping matches allowed. Separate `always_comb` next-state logic and `always_ff` state register, states defined with a `typedef enum`.

**Provided:** template with the module structure, state encoding, and the first state's transitions. **I wrote:** the remaining state transitions, the default case, and the reset behaviour.

### Part 2 — 16-bit processor
A processor that executes `mv`, `add`, `sub`, and `mult`, each with either a register or a sign-extended 12-bit immediate as the source operand.

- **Datapath:** instruction register, two general-purpose registers (R0, R1), an operand register (A), a result register (R), a multiplexer onto a shared bus, and an ALU.
- **Control path:** an FSM that decodes the 16-bit instruction and steps through up to four cycles (fetch instruction → load first operand → compute → write back), asserting multiplexer selects and register enables for each step and raising `Done` at the end.

**Provided:** skeleton code with module boundaries, the control-signal table, and an initial `.do` script with expected waveforms. **I wrote:** the control FSM logic, the datapath module, and additional `.do` scripts beyond the provided one.

### Part 3 — 4-bit restoring divider (bonus)
A hardware divider designed from scratch in a single module: a three-state controller (idle, run, done) sequences a datapath made of a 5-bit remainder register, a 4-bit dividend/quotient shift register, a divisor register, and a 2-bit step counter.
 
- On `Go`, it registers the divisor and dividend in one cycle, then performs one shift-and-subtract step per bit over exactly four cycles.
- Each step shifts the remainder and dividend left together and trial-subtracts the divisor. If the result is negative, the shifted remainder is kept unchanged (restoring by discarding the subtraction rather than adding the divisor back), and a 0 enters the quotient; otherwise the difference is kept and a 1 enters.
- When done, it holds the quotient and remainder with `ResultValid` asserted until the next `Go`; `Go` during a division in progress is ignored.
**Provided:** the algorithm description and module signature only.
 
---


## Lab 7 — Subroutines and Calling Convention

**What I wrote**
- **Part 1:** refactored the Lab 6 longest-run-of-1s code into a subroutine (`ONES`, argument and return value in `a0`), then called it in a loop over a list of words to find the maximum. Saves and restores callee-saved registers on the stack per the RISC-V calling convention.
- **Part 2:** in-place bubble sort of an unsigned 32-bit list whose first word is the item count. The main loop calls a `SWAP` subroutine that takes the address of an element, compares it with the next one, swaps them in memory if out of order, and returns whether a swap happened.

**Provided:** the original ones-counting routine (Part 1 starting point) and the file outline required by the autograder.

---

## Lab 8 — Memory-Mapped I/O, Polling, and Timers

Run and demonstrated on a **DE1-SoC board** with the Nios V (RISC-V) soft processor.

**What I wrote**
- **Part 1 — Polled button input:** reads the pushbutton data register in a polling loop to set, increment (capped at 15), decrement (floored at 1), or blank a binary value on the LEDs, waiting for button release to avoid repeat triggers.
- **Part 2 — Counter with software delay:** an 8-bit LED counter that wraps at 255, paced by a busy-wait delay loop, with start/stop on any button press. Uses the port's edge-capture register so presses during the delay aren't missed, clearing captured edges by writing 1 to the corresponding bits.
- **Part 3 — Counter with hardware timer:** replaces the delay loop with the board's interval timer. Loads a count for an exact 0.25 s period at the timer's 100 MHz rate into its two 16-bit start registers, enables continuous mode, and polls the timeout bit.

**Provided:** register addresses and bit layouts, and an example delay-loop snippet.

---
## Lab 5 Personal Extension - Simple Processor Synthesis 

The Lab 5 processor was only ever simulated behaviourally in ModelSim. This section takes it through synthesis, place and route, and static timing analysis in Quartus Prime, and documents a design flaw that synthesis exposed and simulation had not.

**Tools and target:** Quartus Prime 18.0 Lite Edition, Cyclone V `5CSEMA5F31C6` (the DE1-SoC's FPGA, C6 speed grade). The design was synthesized and timed, not programmed onto a board.

### What synthesis found

Synthesis warned that the instruction register `Instr` was assigned a value but never read and removed it. The control path was decoding the opcode, register fields, and immediate directly from the `INSTRin` input port, so the instruction register was dead logic. The design passed simulation only because the submission checker for the course held `INSTRin` constant for the whole instruction.

This had two consequences:
1. **Correctness:** the processor gives wrong results if the instruction input changes after the instruction starts, which any real memory interface would do.
2. **Timing:** the decode logic started at an input pin, so it was never timed. The baseline Fmax excluded it.

### Fixing the bug

The datapath now exposes the instruction register, and the control path decodes from it. The immediate is sign-extended from the register rather than the port. No other logic changed. The instruction now only has to be valid on the clock edge that loads it.

| Metric | Baseline | Fixed |
|---|---|---|
| Registers | 68 | 84 |
| Logic (ALMs) | 52 | 56 |
| DSP blocks | 1 | 1 |
| Fmax, worst corner (Slow 1100mV 0C) | 134.14 MHz | 123.61 MHz |
| Unconstrained input port paths | 731 | 119 |

### Verification
`tb/tb_ir_disturbance.sv` runs both versions side by side. One test compared outputs with known results. A second test ran 2000 random instructions with a stable input. With the instruction input held constant for each whole instruction, as in the lab, both versions agree on 2,000 random instructions. A final test changed the instruction input after it loads. When changing the instructions mid-process, the unfixed version diverges 196 out of 200 times.

---

## Notes

- Lab handouts are course material and are not included here.

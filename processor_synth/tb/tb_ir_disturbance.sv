`timescale 1ns/1ns
// Self-checking comparison testbench for the ECE253 processor IR fix.
// Instantiates the baseline design (part2_baseline, decodes from the INSTRin port)
// and the fixed design (part2, decodes from the instruction register) side by side.
//   Test 1: directed program with known expected results (fixed design).
//   Test 2: 2000 random instructions, INSTRin held stable -> designs must agree.
//   Test 3: INSTRin changed right after the IR loads, applied to the FIXED design
//           -> it must still agree with an undisturbed baseline.
//   Test 4: same disturbance applied to the BASELINE design -> expected to diverge,
//           which reproduces the original bug.
module tb_ir_disturbance;
  logic clk = 0, reset = 1, run = 0;
  logic [15:0] instr_b, instr_f;
  logic done_b, done_f;
  logic [15:0] r0b, r1b, ab, rb, r0f, r1f, af, rf;

  part2_baseline B(.INSTRin(instr_b), .reset(reset), .clk(clk), .run(run), .done(done_b),
                   .r0_out(r0b), .r1_out(r1b), .a_out(ab), .r_out(rb));
  part2          F(.INSTRin(instr_f), .reset(reset), .clk(clk), .run(run), .done(done_f),
                   .r0_out(r0f), .r1_out(r1f), .a_out(af), .r_out(rf));

  always #5 clk = ~clk;

  int t2_err = 0, t3_err = 0, t4_div = 0;
  bit directed_ok;

  task automatic do_reset();
    reset = 1; run = 0; instr_b = 0; instr_f = 0;
    repeat (2) @(posedge clk); #1 reset = 0;
  endtask

  // Execute one instruction. disturb = 0: none, 1: fixed design, 2: baseline design.
  // run is pulsed for one cycle; 4 idle cycles is enough for the longest instruction.
  task automatic exec(input logic [15:0] ins, input int disturb);
    instr_b = ins; instr_f = ins; run = 1;
    @(posedge clk); #1;                    // edge leaving C0: IR captures the instruction
    run = 0;
    if (disturb == 1) instr_f = $urandom;  // input changes mid-instruction
    if (disturb == 2) instr_b = $urandom;
    repeat (4) @(posedge clk); #1;
  endtask

  function automatic logic [15:0] mv_imm(input bit rx, input logic [11:0] d);
    return {2'b00, 1'b1, rx, d};
  endfunction

  initial begin
    // ---- Test 1: directed program ----
    do_reset();
    exec(16'b00_1_0_000000000101, 0);  // mv   r0, #5
    exec(16'b00_1_1_111111111101, 0);  // mv   r1, #-3
    exec(16'b01_0_0_000000000001, 0);  // add  r0, r1   -> r0 = 2
    exec(16'b10_1_1_000000000010, 0);  // sub  r1, #2   -> r1 = -5
    exec(16'b11_0_0_000000000001, 0);  // mult r0, r1   -> r0 = -10
    directed_ok = ($signed(r0f) == -10) && ($signed(r1f) == -5);
    $display("Test 1 directed: r0=%0d r1=%0d (expect -10, -5) %s",
             $signed(r0f), $signed(r1f), directed_ok ? "PASS" : "FAIL");

    // ---- Test 2: random, stable input ----
    do_reset();
    repeat (2000) begin
      exec($urandom, 0);
      if ({r0b, r1b} !== {r0f, r1f}) t2_err++;
    end
    $display("Test 2 random, stable input: %0d mismatches of 2000 %s",
             t2_err, (t2_err == 0) ? "PASS" : "FAIL");

    // ---- Tests 3 and 4: disturbance after IR load ----
    // Each trial starts from reset with random register contents, so a divergence
    // in one trial can't carry into the next.
    repeat (200) begin
      do_reset();
      exec(mv_imm(0, $urandom), 0); exec(mv_imm(1, $urandom), 0);
      exec($urandom, 1);
      if ({r0b, r1b} !== {r0f, r1f}) t3_err++;
    end
    $display("Test 3 fixed design, input disturbed: %0d of 200 diverged %s",
             t3_err, (t3_err == 0) ? "PASS" : "FAIL");

    repeat (200) begin
      do_reset();
      exec(mv_imm(0, $urandom), 0); exec(mv_imm(1, $urandom), 0);
      exec($urandom, 2);
      if ({r0b, r1b} !== {r0f, r1f}) t4_div++;
    end
    $display("Test 4 baseline design, input disturbed: %0d of 200 diverged (bug reproduced: %s)",
             t4_div, (t4_div > 0) ? "YES" : "NO");

    if (directed_ok && t2_err == 0 && t3_err == 0 && t4_div > 0)
      $display("OVERALL: PASS");
    else
      $display("OVERALL: FAIL");
    $stop;
  end
endmodule

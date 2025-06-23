`timescale 1ns/1ps
import elliptic_curve_structs::*;

module tb_modular_inverse;

  // Clock and reset
  logic clk;
  logic Reset;

  // Inputs/outputs for DUT
  logic [255:0] in;
  logic [255:0] out;
  logic Done;
  logic [255:0] expected;
  
  // Instantiate the DUT
  modular_inverse dut (
    .clk(clk),
    .Reset(Reset),
    .in(in),
    .out(out),
    .Done(Done)
  );

  // Clock generation: 10ns period
  always #5 clk = ~clk;

  // Test procedure
  initial begin
    $display("Starting modular inverse test...");
    clk = 0;
    Reset = 1;
    in = 0;

    // Apply reset
    #20;
    Reset = 0;

    // Apply input (example value)
    in = 256'h5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A;

    wait (Done); // Wait for Done
    $display("Input  : %h", in);
    $display("Output : %h", out);

    // Compare with reference (optional)
    expected = 256'hd5555554aaaaaaaa00000000d555555455555555aaaaaaa92aaaaaab55555552;
    $display("Expected: %h", expected);

    if (out === expected)
      $display("✅ Test PASSED");
    else
      $display("❌ Test FAILED");

    $finish;
  end

endmodule

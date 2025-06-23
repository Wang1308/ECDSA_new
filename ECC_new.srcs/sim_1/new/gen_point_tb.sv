`timescale 1ns / 1ps
import elliptic_curve_structs::*;

module gen_point_tb();

  logic clk, Reset;
  logic [255:0] privKey;
  logic [255:0] in_point_x, in_point_y;
  logic [255:0] out_point_x, out_point_y;
  logic Done;

  // Instantiate the DUT
  gen_point uut (
    .clk(clk),
    .Reset(Reset),
    .privKey(privKey),
    .in_point_x(in_point_x),
    .in_point_y(in_point_y),
    .out_point_x(out_point_x),
    .out_point_y(out_point_y),
    .Done(Done)
  );
    
   logic [255:0] expected_x, expected_y;
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100 MHz clock
  end

  // Stimulus
  initial begin
    $display("Starting gen_point testbench...");

    // Initial state
    Reset = 1;
    privKey = 256'h0000000000000000000000000000000000000000000000000000000000000005; // d = 5
    in_point_x = 256'h6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296; 
    in_point_y = 256'h4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5; 

    #20; // Hold reset for a few cycles
    Reset = 0;

    // Wait for Done
    wait (Done == 1);

    $display("Computation complete.");
    $display("Public key X = %h", out_point_x);
    $display("Public key Y = %h", out_point_y);
    
    expected_x = 256'h51590b7a515140d2d784c85608668fdfef8c82fd1f5be52421554a0dc3d033ed;
    expected_y = 256'he0c17da8904a727d8ae1bf36bf8a79260d012f00d4d80888d1d0bb44fda16da4;
    // Compare to expected (if known)
    $display("Expected_x: %h", expected_x);
    $display("Expected_y: %h", expected_y);

    if (out_point_x === expected_x || out_point_y === expected_y )
      $display("✅ Test PASSED");
    else
      $display("❌ Test FAILED");
    #20;
    $stop;
  end

endmodule

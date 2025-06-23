`timescale 1ns/1ps
import elliptic_curve_structs::*;

module point_add_tb;

    // Clock and reset
    logic clk;
    logic Reset;

    // Inputs
    logic [255:0] P_x, P_y, Q_x, Q_y;

    // Outputs
    logic Done;
    logic [255:0] R_x, R_y;
    logic [255:0] expected_x, expected_y;
    curve_parameters_t params;
    // Instantiate DUT (Device Under Test)
    point_add dut (
    .clk(clk),
    .Reset(Reset),
    .P_x(P_x), .P_y(P_y),
    .Q_x(Q_x), .Q_y(Q_y),
    .params(params),
    .R_x(R_x), .R_y(R_y),
    .Done(Done)
  );
  // Task to wait for done
  task automatic wait_for_done(input string tag);
    int timeout = 100000;
    repeat (timeout) @(posedge clk) if (Done) begin
      $display("[%s] Done at time %0t", tag, $time);
      return;
    end
    $fatal("[%s] ❌ TIMEOUT waiting for point_add to complete", tag);
  endtask


    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        Reset = 1;
        P_x = 0;
        P_y = 0;
        Q_x = 0;
        Q_y = 0;
        
        params.p = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
        params.n = 256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
        params.a = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC;
        params.b = 256'h5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B;
        params.base_point.x = 256'h6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
        params.base_point.y = 256'h4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;
        // Wait a few cycles
        #20;
        Reset = 0;

        // Set test vectors (example inputs, replace with real elliptic curve points)
        P_x = 256'h05;
        P_y = 256'h01;
        Q_x = 256'h0C;
        Q_y = 256'h03;

        // Wait for Done
        wait(Done);
        #10;
        // Display result
        $display("P + Q Result:");
        $display("R_x = %h", R_x);
        $display("R_y = %h", R_y);
        
        expected_x = 256'hf0539781ac687d64343eb1a1f58d0fac687d6344db6db6db6db6db6db6db6da5;
        expected_y = 256'h290cb023aa2b49e3cc805f889545693c746e75ecc14e5e0a72f05397829cbc1a;
        // Compare to expected (if known)
        $display("Expected_x: %h", expected_x);
        $display("Expected_y: %h", expected_y);

        if (R_x === expected_x || R_y === expected_y )
          $display("✅ Test PASSED");
        else
          $display("❌ Test FAILED");
        #20;
        $finish;
    end

endmodule

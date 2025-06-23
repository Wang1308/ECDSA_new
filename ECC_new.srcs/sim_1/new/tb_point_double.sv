`timescale 1ns/1ps
import elliptic_curve_structs::*;

module point_double_tb;

    // Clock & reset
    logic clk;
    logic Reset;

    // Input & output points
    curve_point_t P;
    curve_point_t R;

    // Done signal
    logic Done;

    // Instantiate DUT
    point_double dut (
        .clk(clk),
        .Reset(Reset),
        .P(P),
        .R(R),
        .Done(Done)
    );
    
    logic [255:0] expected_x, expected_y;
    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        // Initialize clock and reset
        clk = 0;
        Reset = 1;
        P = '{default:0};

        #20;
        Reset = 0;

        // === Test vector: Base point G of secp256k1 ===
        P.x = 256'h6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
        P.y = 256'h4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;

        // Wait for point doubling to complete
        wait(Done);
        #10 
        // Print result
        $display("Point Doubling Result:");
        $display("R.x = %h", R.x);
        $display("R.y = %h", R.y);

        expected_x = 256'h7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978;
        expected_y = 256'h7775510db8ed040293d9ac69f7430dbba7dade63ce982299e04b79d227873d1;
        // Compare to expected (if known)
        $display("Expected_x: %h", expected_x);
        $display("Expected_y: %h", expected_y);

        if (R.x === expected_x || R.y === expected_y )
          $display("✅ Test PASSED");
        else
          $display("❌ Test FAILED");
        #20;
        $finish;
    end

endmodule

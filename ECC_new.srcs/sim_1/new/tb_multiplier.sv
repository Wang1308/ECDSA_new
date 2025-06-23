`timescale 1ns/1ps
import elliptic_curve_structs::*;

module tb_multiplier;

    // Inputs
    logic clk, Reset;
    logic [255:0] a, b;

    // Outputs
    logic Done;
    logic [255:0] product;

    // Instantiate the multiplier
    multiplier uut (
        .clk(clk),
        .Reset(Reset),
        .a(a),
        .b(b),
        .Done(Done),
        .product(product)
    );

    // Clock generation
    always #5 clk = ~clk;  // 100 MHz clock

    // Reference product
    logic [255:0] ref_product;

    initial begin
        // Initialize
        clk = 0;
        Reset = 1;
        a = 0;
        b = 0;

        // Wait some time then deassert Reset
        #20;
        Reset = 0;

        // Test vector 1
        a = 256'h123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0;
        b = 256'h0FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA98765432;

        // Reference calculation using SystemVerilog mod operator
        ref_product = 256'h163aca4d46126ab65e0bd2a17a9104c5895cd66db2567b3263af3ba27c1bda52;

        // Wait for Done
        wait (Done == 1);
        #10;

        $display("Input A      = %h", a);
        $display("Input B      = %h", b);
        $display("Product      = %h", product);
        $display("Expected     = %h", ref_product);

        if (product === ref_product)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");

        $finish;
    end

endmodule

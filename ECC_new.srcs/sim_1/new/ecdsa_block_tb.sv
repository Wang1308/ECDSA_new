`timescale 1ns/1ps

import elliptic_curve_structs::*;

module ecdsa_block_tb;

  // Clock
  logic clk, rst_n;
  logic wr_en;
  logic [3:0] addr;
  logic [255:0] data_in;

  initial clk = 0;
  always #5 clk = ~clk; // 100MHz clock

  // Inputs
  logic in_gen_point_reset;
  logic [255:0] in_point_x, in_point_y, in_S;

//  logic in_modInv_reset;
//  logic [255:0] in_modInv;

//  logic in_reset_modmult;
//  logic [255:0] in_a_modmult, in_b_modmult;

//  logic in_reset_add;
//  logic [255:0] in_p_x, in_p_y, in_q_x, in_q_y;

  // Outputs
  logic [255:0] out_point_x, out_point_y, expected_gen_point_x, expected_gen_point_y;
  logic done_point;

//  logic [255:0] out_modInv, expected_modInv;
//  logic done_modInv;

//  logic [255:0] out_modmult, expected_modmult;
//  logic done_modmult;

//  logic [255:0] out_r_x, out_r_y, expected_r_x, expected_r_y;
//  logic done_add;

  // DUT
  ecdsa_block dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .addr(addr),
        .data_in(data_in),
        .in_gen_point_reset(in_gen_point_reset),
        .in_point_x(in_point_x),
        .in_point_y(in_point_y),
        .in_S(in_S),
        .out_point_x(out_point_x),
        .out_point_y(out_point_y),
        .done_point(done_point)
//        .in_modInv_reset(in_modInv_reset),
//        .in_modInv(in_modInv),
//        .out_modInv(out_modInv),
//        .done_modInv(done_modInv),
//        .in_reset_modmult(in_reset_modmult),
//        .in_a_modmult(in_a_modmult),
//        .in_b_modmult(in_b_modmult),
//        .done_modmult(done_modmult),
//        .out_modmult(out_modmult),
//        .in_reset_add(in_reset_add),
//        .in_p_x(in_p_x),
//        .in_p_y(in_p_y),
//        .in_q_x(in_q_x),
//        .in_q_y(in_q_y),
//        .done_add(done_add),
//        .out_r_x(out_r_x),
//        .out_r_y(out_r_y)
    );
    
    // Task: cấu hình tham số đường cong
  task config_curve_params(curve_parameters_t p);
        begin
            wr_en = 1;
            addr = 0; data_in = p.p;         @(posedge clk);
            addr = 1; data_in = p.n;         @(posedge clk);
            addr = 2; data_in = p.a;         @(posedge clk);
            addr = 3; data_in = p.b;         @(posedge clk);
            addr = 4; data_in = p.base_point.x; @(posedge clk);
            addr = 5; data_in = p.base_point.y; @(posedge clk);
            wr_en = 0;
        end
    endtask

    curve_parameters_t curve_params;
  initial begin
    // Khởi tạo
        clk = 0;
        rst_n = 1;
        wr_en = 0;
        in_gen_point_reset = 0;
//        in_modInv_reset = 0;
//        in_reset_modmult = 0;
//        in_reset_add = 0;

        #20 rst_n = 0;

        // Khởi tạo tham số SECP256K1
        curve_params.p = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
        curve_params.n = 256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
        curve_params.a = 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC;
        curve_params.b = 256'h5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B;
        curve_params.base_point.x = 256'h6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
        curve_params.base_point.y = 256'h4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;

        // Nạp cấu hình
        config_curve_params(curve_params);
    #80
    // Reset all inputs
    in_gen_point_reset   = 1;
//    in_modInv_reset      = 1;
//    in_reset_modmult     = 1;
//    in_reset_add         = 1;

    in_S                 = 256'h5;  // Private key = 5 (test case)
    in_point_x           = curve_params.base_point.x;
    in_point_y           = curve_params.base_point.y;

//    in_modInv            = 256'h5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A;
//    in_a_modmult         = 256'h6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
//    in_b_modmult         = 256'h4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;

//    in_p_x               = 256'h05;
//    in_p_y               = 256'h01;
//    in_q_x               = 256'h0C;
//    in_q_y               = 256'h03;

    #20;

    // Test gen_point
    in_gen_point_reset = 0;
    expected_gen_point_x = 256'h51590b7a515140d2d784c85608668fdfef8c82fd1f5be52421554a0dc3d033ed;
    expected_gen_point_y = 256'he0c17da8904a727d8ae1bf36bf8a79260d012f00d4d80888d1d0bb44fda16da4;
    #1000;
    wait(done_point);
    $display(">> gen_point Done:\n X = %h\n Y = %h", out_point_x, out_point_y);
    // Compare to expected (if known)
    $display("Expected_gen_point_x: %h", expected_gen_point_x);
    $display("Expected_gen_point_y: %h", expected_gen_point_y);

    if (out_point_x === expected_gen_point_x && out_point_y === expected_gen_point_y )
      $display("Test gen_point PASSED\n");
    else
      $display("Test gen_point FAILED\n");
      
    // Test modular inverse
//    in_modInv_reset = 0;
//    #1000;
//    wait(done_modInv);
//    $display(">> modInv Done:\n In = %h\n  Out = %h", in_modInv, out_modInv);
//    // Compare with reference (optional)
//    expected_modInv = 256'hc730816a4a30b8fbd7c20c89b14729a06d682e6a4382e13b3223847402d988a7;
//    $display("Expected_modInv: %h", expected_modInv);

//    if (out_modInv === expected_modInv)
//      $display("✅ Test modInv PASSED\n");
//    else
//      $display("❌ Test modInv FAILED\n");

//    // Test modular multiply
//    in_reset_modmult = 0;
//    #1000;
//    wait(done_modmult);
//    $display(">> modmult Done:\n A = %h\n B = %h\n Result = %h", in_a_modmult, in_b_modmult, out_modmult);
//    // Compare with reference (optional)
//    expected_modmult = 256'h1543b5272ef9466b6179ca8d535b2e2af16b758c41da31d772eca81accce4d18;
//    $display("Expected_modmult: %h", expected_modmult);

//    if (out_modmult === expected_modmult)
//      $display("✅ Test modmult PASSED\n");
//    else
//      $display("❌ Test modmult FAILED\n");
    
//    // Test point addition
//    in_reset_add = 0;
//    #1000;
//    wait(done_add);
//    #10
//    $display(">> point_add Done:\n Rx = %h\n Ry = %h", out_r_x, out_r_y);
//    expected_r_x = 256'hf0539781ac687d64343eb1a1f58d0fac687d6344db6db6db6db6db6db6db6da5;
//    expected_r_y = 256'h290cb023aa2b49e3cc805f889545693c746e75ecc14e5e0a72f05397829cbc1a;
//    // Compare to expected (if known)
//    $display("Expected_r_x: %h", expected_r_x);
//    $display("Expected_r_y: %h", expected_r_y);

//    if (out_r_x === expected_r_x && out_r_y === expected_r_y )
//      $display("✅ Test point_add PASSED\n");
//    else
//      $display("❌ Test point_add FAILED\n");

    $finish;
  end

endmodule

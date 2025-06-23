`timescale 1ns/1ps
import elliptic_curve_structs::*;

module tb_curve_config_regs;

    logic clk, rst_n;
    logic wr_en;
    logic [3:0] addr;
    logic [255:0] data_in;
    curve_parameters_t params;

    // Clock generator
    always #5 clk = ~clk;

    // Instantiate DUT
    curve_config_regs dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .addr(addr),
        .data_in(data_in),
        .params(params)
    );

    // Task to write register
    task write_reg(input [3:0] addr_t, input [255:0] data);
        begin
            @(negedge clk);
            wr_en   = 1;
            addr    = addr_t;
            data_in = data;
            @(negedge clk);
            wr_en = 0;
        end
    endtask

    initial begin
        // Init
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        addr = 0;
        data_in = 0;

        // Reset
        #10;
        rst_n = 1;

        // Write test values
        write_reg(4'h0, 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF); // p
        write_reg(4'h1, 256'hFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551); // n
        write_reg(4'h2, 256'hFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC); // a
        write_reg(4'h3, 256'h5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B); // b
        write_reg(4'h4, 256'h6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296); // Gx
        write_reg(4'h5, 256'h4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5); // Gy

        // Wait a few cycles
        #20;

        // Display results
        $display("===== Curve Parameters Loaded =====");
        $display("p  = %h", params.p);
        $display("n  = %h", params.n);
        $display("a  = %h", params.a);
        $display("b  = %h", params.b);
        $display("Gx = %h", params.base_point.x);
        $display("Gy = %h", params.base_point.y);
        $display("===================================");

        $finish;
    end

endmodule

`timescale 1ns / 1ps
import elliptic_curve_structs::*;

module curve_config_regs (
    input logic clk,
    input logic rst_n,

    // Interface với bus hoặc config logic
    input logic wr_en,
    input logic [3:0] addr,
    input logic [255:0] data_in,

    // Output struct
    output curve_parameters_t params
);

    // Thanh ghi lưu các giá trị
    logic [255:0] reg_p, reg_n, reg_a, reg_b;
    logic [255:0] reg_gx, reg_gy;

    always_ff @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_p  <= '0;
            reg_n  <= '0;
            reg_a  <= '0;
            reg_b  <= '0;
            reg_gx <= '0;
            reg_gy <= '0;
        end else if (wr_en) begin
            case (addr)
                4'h0: reg_p  <= data_in;
                4'h1: reg_n  <= data_in;
                4'h2: reg_a  <= data_in;
                4'h3: reg_b  <= data_in;
                4'h4: reg_gx <= data_in;
                4'h5: reg_gy <= data_in;
            endcase
        end
    end

    assign params = '{p:reg_p, n:reg_n, a:reg_a, b:reg_b, base_point:'{x:reg_gx, y:reg_gy}};

endmodule

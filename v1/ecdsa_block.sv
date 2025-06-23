import elliptic_curve_structs::*;

module ecdsa_block(
	// Common
	input logic clk,
	input logic rst_n,
	// Đầu vào cấu hình tham số
    input logic wr_en,
    input logic [3:0] addr,
    input logic [255:0] data_in,
	//Gen point
	input logic in_gen_point_reset,
	input logic [255:0] in_point_x,
	input logic [255:0] in_point_y,
	input logic [255:0] in_S,
	output logic [255:0] out_point_x,
	output logic [255:0] out_point_y,
	output logic  done_point,
	//modInv
	input logic in_modInv_reset,
	input logic [255:0] in_modInv,
	output logic [255:0] out_modInv,
	output logic  done_modInv,
	//multmod
	input logic in_reset_modmult,
	input logic [255:0] in_a_modmult, 
	input logic [255:0] in_b_modmult,
	output logic done_modmult,
	output logic [255:0] out_modmult,
	//add point a != b
	input logic in_reset_add,
	input logic [255:0] in_p_x,
	input logic [255:0] in_p_y,
	input logic [255:0] in_q_x,
	input logic [255:0] in_q_y,
	output logic done_add,
	output logic [255:0] out_r_x,
	output logic [255:0] out_r_y
);

    // Kết nối với module cấu hình tham số
    curve_parameters_t curve_params;
    
curve_config_regs cfg (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(wr_en),
    .addr(addr),
    .data_in(data_in),
    .params(curve_params)
);
gen_point init_point (
	.clk(clk), 
	.Reset(in_gen_point_reset),
	.privKey(in_S),
	.in_point_x(in_point_x),
	.in_point_y(in_point_y),
	.params(curve_params),
	.out_point_y(out_point_y),
	.out_point_x(out_point_x),
	.Done(done_point)
);
modular_inverse_n modular_inverse_n (
	.clk(clk), 
	.Reset(in_modInv_reset),
	.in(in_modInv),
	.params(curve_params),
	.out(out_modInv),
	.Done(done_modInv)
);
multiplier_n multmod_n (
	.clk(clk), 
	.Reset(in_reset_modmult),
	.a(in_a_modmult), 
	.b(in_b_modmult),
	.params(curve_params),
	.Done(done_modmult),
	.product(out_modmult)
);
point_add point_add (
	.clk(clk), 
	.Reset(in_reset_add),
	//input  	curve_point_t 	P, Q,
	.P_x(in_p_x),
	.P_y(in_p_y),
	.Q_x(in_q_x),
	.Q_y(in_q_y),
	.params(curve_params),
	.Done(done_add),
	//output 	curve_point_t 	R
	.R_x(out_r_x),
	.R_y(out_r_y)
);
endmodule


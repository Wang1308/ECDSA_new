package elliptic_curve_structs;

typedef struct packed {
    logic [255:0] x;
    logic [255:0] y;
} curve_point_t;


typedef struct packed {
    logic [255:0] p;
    logic [255:0] n;
    logic [255:0] a;
    logic [255:0] b;
    curve_point_t base_point;
} curve_parameters_t;

typedef struct packed {
    logic m;            
    logic k;           
} barrett_constants_t;

typedef struct packed {
    logic [255:0] r;
    logic [255:0] s;
} signature_t;

endpackage : elliptic_curve_structs

import elliptic_curve_structs::*;


module regfile_2r1w(
    input         clk,

    input  [ 4:0] ra1,
    output [31:0] rd1,

    input  [ 4:0] ra2,
    output [31:0] rd2,

    input         we1,
    input  [ 4:0] wa1,
    input  [31:0] wd1
);

reg  [31:0] heap [31:0];

assign rd1 = (|ra1) ? heap[ra1] : 32'd0;
assign rd2 = (|ra2) ? heap[ra2] : 32'd0;

always @(posedge clk)
    if (we1)
        heap[wa1] <= wd1;

endmodule //regfile_2r1w


module reg_HILO(
    input  wire        clk,

    output wire [31:0] rd_HI,
    output wire [31:0] rd_LO,

    input  wire        we_HI,
    input  wire [31:0] wd_HI,
    input  wire        we_LO,
    input  wire [31:0] wd_LO
);

reg  [31:0] HI;
reg  [31:0] LO;

assign rd_HI = HI;
assign rd_LO = LO;

always @(posedge clk) begin
    if (we_HI)
        HI <= wd_HI;
    if (we_LO)
        LO <= wd_LO;
end

endmodule

module reg_CP0(
    input         clk,
    input         resetn,

    output [31:0] rd_8,
    output [31:0] rd_9,
    output [31:0] rd_11,
    output [31:0] rd_12,
    output [31:0] rd_13,
    output [31:0] rd_14,

    input  [31:0] we,
    input  [31:0] wd_8,
    input  [31:0] wd_9,
    input  [31:0] wd_11,
    input  [31:0] wd_12,
    input  [31:0] wd_13,
    input  [31:0] wd_14,

    output [31:0] rd_0,
    output [31:0] rd_1,
    output [31:0] rd_2,
    output [31:0] rd_3,
    output [31:0] rd_5,
    output [31:0] rd_10,

    input  [31:0] wd_0,
    input  [31:0] wd_2,
    input  [31:0] wd_3,
    input  [31:0] wd_5,
    input  [31:0] wd_10
);

reg  [31:0] heap [31:0];

assign rd_8  = heap[ 8];
assign rd_9  = heap[ 9];
assign rd_11 = heap[11];
assign rd_12 = heap[12];
assign rd_13 = heap[13];
assign rd_14 = heap[14];

assign rd_0  = heap[ 0]; // Index
assign rd_1  = heap[ 9]; // Random
assign rd_2  = heap[ 2]; // EntryLo0
assign rd_3  = heap[ 3]; // EntryLo1
assign rd_5  = heap[ 5]; // PageMask
assign rd_10 = heap[10]; // EntryHi

integer i;
always @(posedge clk) begin
    if(resetn) begin
        if (we[ 8]) heap[ 8] <= wd_8;
        if (we[ 9]) heap[ 9] <= wd_9;
        if (we[11]) heap[11] <= wd_11;
        if (we[12]) heap[12] <= wd_12;
        if (we[13]) heap[13] <= wd_13;
        if (we[14]) heap[14] <= wd_14;

        if (we[ 0]) heap[ 0] <= wd_0;
        if (we[ 2]) heap[ 2] <= wd_2;
        if (we[ 3]) heap[ 3] <= wd_3;
        if (we[ 5]) heap[ 5] <= wd_5;
        if (we[10]) heap[10] <= wd_10;
    end else begin
        heap[ 8] <= 32'd0;
        heap[ 9] <= 32'd0;
        heap[11] <= 32'hffffffff;
        heap[12] <= 32'h0040ff01;
        heap[13] <= 32'd0;
        heap[14] <= 32'hbfc00000;

        heap[ 0] <= 32'd0;
        heap[ 2] <= 32'd0;
        heap[ 3] <= 32'd0;
        heap[ 5] <= 32'd0;
        heap[10] <= 32'd0;
    end
end

endmodule

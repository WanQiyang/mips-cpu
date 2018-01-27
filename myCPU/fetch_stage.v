
module fetch_stage(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] ctrl_nextpc,
    output wire        inst_req,
    output wire [31:0] inst_addr,
    input  wire [ 1:0] inst_ex,
    input  wire        inst_addr_ok,

    output reg  [31:0] fe_pc,
    output reg  [ 6:0] fe_exc,
    output wire [31:0] fe_badvaddr,

    output reg         fe_valid,
    output wire        fe_allowin,
    output wire        fe_to_de_valid,
    input  wire        de_allowin,

    input  wire        ctrl_fe_wait,
    input  wire        ctrl_fe_disable
);

wire        fe_ready_go;
wire        AdEL;
wire        TLBL_Refill;
wire        TLBL_Invalid;
reg         inst_req_r;
reg         inst_addr_ok_r;

always @(posedge clk) begin
    if(!resetn) begin
        fe_pc          <= 32'hbfc00000;
        fe_valid       <= 1'b0;
    end
    else if (fe_allowin) begin
        fe_valid       <= 1'b1;
    end
    if(fe_allowin) begin
        fe_pc          <= ctrl_nextpc;
        inst_req_r     <= 1'b1;
    end
    if(inst_req_r && inst_addr_ok) begin
        inst_req_r     <= de_allowin;
    end
    if(fe_allowin || inst_req_r && inst_addr_ok) begin
        inst_addr_ok_r <= !fe_allowin;
    end
end

always @(*) begin
    if(fe_valid && !AdEL && !TLBL_Refill && !TLBL_Invalid)
        fe_exc = 7'd0;
    else if(fe_valid && AdEL)
        fe_exc = 7'b10_00100;
    else if(fe_valid && TLBL_Refill)
        fe_exc = 7'b11_00010;
    else if(fe_valid && TLBL_Invalid)
        fe_exc = 7'b10_00010;
    else
        fe_exc = 7'd11_00010;
end

// assign fe_pc          = ctrl_nextpc;
assign inst_req       = fe_valid && !ctrl_fe_disable && inst_req_r && !fe_exc[6];
assign inst_addr      = fe_pc;

assign AdEL           = |fe_pc[1:0];
assign TLBL_Refill    = (inst_ex == 2'b01);
assign TLBL_Invalid   = (inst_ex == 2'b10);
assign fe_badvaddr    = fe_valid && (AdEL || TLBL_Refill || TLBL_Invalid) ? fe_pc : 32'd0;

assign fe_ready_go    = !ctrl_fe_wait && ((inst_req && inst_addr_ok || inst_addr_ok_r) || fe_exc[6]);
assign fe_allowin     = resetn && (!fe_valid || fe_ready_go && de_allowin || ctrl_fe_disable);
assign fe_to_de_valid = fe_valid && fe_ready_go && (!ctrl_fe_disable);

endmodule

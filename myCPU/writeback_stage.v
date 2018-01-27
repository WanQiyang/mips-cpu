
module writeback_stage(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] mem_pc,
    input  wire [31:0] mem_inst,
    output reg  [31:0] wb_pc,
    output reg  [31:0] wb_inst,

    input  wire [19:0] mem_out_op,
    input  wire [ 4:0] mem_dest,
    input  wire [31:0] mem_value,

    output wire [19:0] wb_out_op,
    output wire [ 3:0] wb_rf_wen,
    output wire [ 4:0] wb_rf_waddr,
    output wire [31:0] wb_rf_wdata,

    output reg         wb_valid,
    input  wire        mem_to_wb_valid,
    output wire        wb_allowin,

    input  wire        ctrl_wb_wait,

    output wire        we_HI,
    output wire [31:0] wd_HI,
    output wire        we_LO,
    output wire [31:0] wd_LO,

    input  wire [65:0] mult_p,

    input  wire        div_p_valid,
    input  wire [79:0] div_p_data
);

wire        wb_ready_go;

wire        op_Mult;
wire        op_Div;
wire        op_HIWrite;
wire        op_LOWrite;
wire        op_RegWrite;

reg  [ 4:0] wb_dest;
reg  [19:0] wb_op;
reg  [31:0] wb_value;

always @(posedge clk) begin
    if(!resetn) begin
        wb_pc       <= 32'hbfc00000;
        wb_inst     <= 32'd0;
        wb_dest     <= 5'd0;
        wb_op       <= 20'd0;
        wb_value    <= 32'd0;
        wb_valid    <= 1'b0;
    end
    else if(wb_allowin) begin
        wb_valid    <= mem_to_wb_valid;
    end
    if(mem_to_wb_valid && wb_allowin) begin
        wb_pc       <= mem_pc;
        wb_inst     <= mem_inst;
        wb_dest     <= mem_dest;
        wb_op       <= mem_out_op;
        wb_value    <= mem_value;
    end
end

assign op_Mult       = wb_op[15];
assign op_Div        = wb_op[14];
assign op_HIWrite    = wb_op[12];
assign op_LOWrite    = wb_op[11];
assign op_RegWrite   = wb_op[10];

assign wb_out_op     = wb_op;
assign wb_rf_wen     = {4{wb_valid & op_RegWrite}};
assign wb_rf_waddr   = wb_dest;
assign wb_rf_wdata   = wb_value;

assign we_HI         = wb_valid & op_HIWrite;
assign we_LO         = wb_valid & op_LOWrite;
assign wd_HI         = op_Mult  ? mult_p[63:32]
                     : op_Div   ? div_p_data[31:0]
                     : wb_value ;
assign wd_LO         = op_Mult  ? mult_p[31:0]
                     : op_Div   ? div_p_data[71:40]
                     : wb_value ;

assign wb_ready_go   = !ctrl_wb_wait && (!op_Div || div_p_valid);
assign wb_allowin    = !wb_valid || wb_ready_go;

endmodule

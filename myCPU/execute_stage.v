
module execute_stage(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] de_pc,           //pc @decode_stage
    input  wire [31:0] de_inst,         //instr code @decode_stage
    input  wire [ 6:0] de_exc,
    input  wire [31:0] de_badvaddr,
    output reg  [31:0] exe_pc,          //pc @execute_stage
    output reg  [31:0] exe_inst,        //instr code @execute_stage
    output wire [ 6:0] exe_exc,
    output wire [31:0] exe_badvaddr,

    input  wire [19:0] de_out_op,       //control signals used in EXE, MEM, WB stages
    input  wire [ 4:0] de_dest,         //reg No. of dest operand, zero if no dest
    input  wire [31:0] de_vsrc1,        //value of source operand 1
    input  wire [31:0] de_vsrc2,        //value of source operand 2
    input  wire [ 4:0] de_vshift,
    input  wire [31:0] de_st_value,     //value stored to memory

    input  wire [31:0] de_bsrc1,
    input  wire [31:0] de_bsrc2,

    output wire [19:0] exe_out_op,      //control signals used in MEM, WB stages
    output reg  [ 4:0] exe_dest,        //reg num of dest operand
    output wire [31:0] exe_value,       //alu result from exe_stage or other intermediate
                                        //value for the following stages
    output wire [31:0] exe_ld_value,
    output wire        exe_br_taken,

    output wire        data_req     ,
    output wire        data_wr      ,
    output reg  [ 2:0] data_size    ,
    output wire [31:0] data_addr    ,
    input  wire [ 1:0] data_ex      ,
    output wire [31:0] data_wdata   ,
    input  wire        data_addr_ok ,

    output reg         exe_valid,
    input  wire        de_to_exe_valid,
    output wire        exe_allowin,
    output wire        exe_to_pm_valid,
    input  wire        pm_allowin,

    input  wire        ctrl_exe_wait,
    input  wire        ctrl_exe_disable
);

wire        exe_ready_go;
reg         data_req_r;
reg         data_addr_ok_r;
reg         ctrl_exe_disable_r;

reg  [19:0] exe_op;
reg  [31:0] exe_vsrc1;
reg  [31:0] exe_vsrc2;
reg  [ 4:0] exe_vshift;
reg  [31:0] exe_prev_value;

wire        op_AllowOF;
wire        op_Branch;
wire [ 2:0] op_SaveMem;
wire [ 2:0] op_LoadMem;
wire [ 3:0] op_aluop;

wire [ 2:0] deop_SaveMem;
wire [ 2:0] deop_LoadMem;

wire [31:0] exe_result;
wire        exe_of;

reg  [ 3:0] exe_wen;
reg  [31:0] exe_st_value;

reg  [31:0] exe_bsrc1;
reg  [31:0] exe_bsrc2;
wire [31:0] exe_br;

wire        br_ez;
wire        br_lz;
reg         br_taken;

reg  [ 6:0] exc_op;
reg  [ 6:0] prev_exc;
reg  [31:0] prev_badvaddr;

always @(posedge clk) begin
    if(!resetn) begin
        exe_pc         <= 32'hbfc00000;
        exe_inst       <= 32'd0;
        exe_dest       <= 5'd0;
        exe_op         <= 20'd0;
        exe_vsrc1      <= 32'd0;
        exe_vsrc2      <= 32'd0;
        exe_vshift     <= 5'd0;
        exe_prev_value <= 32'd0;
        exe_bsrc1      <= 32'd0;
        exe_bsrc2      <= 32'd0;
        prev_exc       <= 7'd0;
        prev_badvaddr  <= 32'd0;
        exe_valid      <= 1'b0;
    end
    else if(exe_allowin) begin
        exe_valid      <= de_to_exe_valid;
    end
    if(de_to_exe_valid && exe_allowin) begin
        exe_pc         <= de_pc;
        exe_inst       <= de_inst;
        exe_dest       <= de_dest;
        exe_op         <= de_out_op;
        exe_vsrc1      <= de_vsrc1;
        exe_vsrc2      <= de_vsrc2;
        exe_vshift     <= de_vshift;
        exe_prev_value <= de_st_value;
        exe_bsrc1      <= de_bsrc1;
        exe_bsrc2      <= de_bsrc2;
        prev_exc       <= de_exc;
        prev_badvaddr  <= de_badvaddr;
    end
    if(de_to_exe_valid && exe_allowin || data_req_r && data_addr_ok) begin
        data_req_r     <= |(deop_LoadMem | deop_SaveMem) && !exe_exc[6] && de_to_exe_valid && exe_allowin;
    end
    if(de_to_exe_valid && exe_allowin || data_req_r && data_addr_ok) begin
        data_addr_ok_r <= !exe_allowin;
    end
    if(de_to_exe_valid && exe_allowin || !ctrl_exe_disable_r && ctrl_exe_disable) begin
        ctrl_exe_disable_r <= ctrl_exe_disable;
    end
end
/*
always @(*) begin
    casex({op_SaveMem, exe_result[1:0]})
    5'b001_??: exe_wen = 4'b1111;
    5'b010_00: exe_wen = 4'b0001;
    5'b010_01: exe_wen = 4'b0011;
    5'b010_10: exe_wen = 4'b0111;
    5'b010_11: exe_wen = 4'b1111;
    5'b011_00: exe_wen = 4'b1111;
    5'b011_01: exe_wen = 4'b1110;
    5'b011_10: exe_wen = 4'b1100;
    5'b011_11: exe_wen = 4'b1000;
    5'b110_00: exe_wen = 4'b0001;
    5'b110_01: exe_wen = 4'b0010;
    5'b110_10: exe_wen = 4'b0100;
    5'b110_11: exe_wen = 4'b1000;
    5'b111_0?: exe_wen = 4'b0011;
    5'b111_1?: exe_wen = 4'b1100;
    default  : exe_wen = 4'b0000;
    endcase
end
*/
always @(*) begin
    casex({op_SaveMem, exe_result[1:0]})
    5'b001_??: exe_st_value = exe_prev_value;
    5'b010_00: exe_st_value = {24'd0, exe_prev_value[31:24]       };
    5'b010_01: exe_st_value = {16'd0, exe_prev_value[31:16]       };
    5'b010_10: exe_st_value = { 8'd0, exe_prev_value[31: 8]       };
    5'b010_11: exe_st_value = {       exe_prev_value[31: 0]       };
    5'b011_00: exe_st_value = {       exe_prev_value[31: 0]       };
    5'b011_01: exe_st_value = {       exe_prev_value[23: 0],  8'd0};
    5'b011_10: exe_st_value = {       exe_prev_value[15: 0], 16'd0};
    5'b011_11: exe_st_value = {       exe_prev_value[ 7: 0], 24'd0};
    5'b110_00: exe_st_value = {24'd0, exe_prev_value[ 7: 0]       };
    5'b110_01: exe_st_value = {16'd0, exe_prev_value[ 7: 0],  8'd0};
    5'b110_10: exe_st_value = { 8'd0, exe_prev_value[ 7: 0], 16'd0};
    5'b110_11: exe_st_value = {       exe_prev_value[ 7: 0], 24'd0};
    5'b111_0?: exe_st_value = {16'd0, exe_prev_value[15: 0]       };
    5'b111_1?: exe_st_value = {       exe_prev_value[15: 0], 16'd0};
    default  : exe_st_value = 32'd0;
    endcase
end

always @(*) begin
    casex({op_AllowOF, op_LoadMem, op_SaveMem, exe_result[1:0], exe_of, data_ex})
    12'b1_???_???_??_1_??: exc_op = 7'b10_01100;
    12'b0_001_000_01_?_??: exc_op = 7'b10_00100;
    12'b0_001_000_10_?_??: exc_op = 7'b10_00100;
    12'b0_001_000_11_?_??: exc_op = 7'b10_00100;
    12'b0_1?1_000_?1_?_??: exc_op = 7'b10_00100;
    12'b0_000_001_01_?_??: exc_op = 7'b10_00101;
    12'b0_000_001_10_?_??: exc_op = 7'b10_00101;
    12'b0_000_001_11_?_??: exc_op = 7'b10_00101;
    12'b0_000_111_?1_?_??: exc_op = 7'b10_00101;
    12'b0_001_000_??_?_01: exc_op = 7'b11_00010; // TLBL_Refill
    12'b0_01?_000_??_?_01: exc_op = 7'b11_00010; // TLBL_Refill
    12'b0_1??_000_??_?_01: exc_op = 7'b11_00010; // TLBL_Refill
    12'b0_001_000_??_?_10: exc_op = 7'b10_00010; // TLBL_Invalid
    12'b0_01?_000_??_?_10: exc_op = 7'b10_00010; // TLBL_Invalid
    12'b0_1??_000_??_?_10: exc_op = 7'b10_00010; // TLBL_Invalid
    12'b0_000_001_??_?_01: exc_op = 7'b11_00011; // TLBS_Refill
    12'b0_000_01?_??_?_01: exc_op = 7'b11_00011; // TLBS_Refill
    12'b0_000_1??_??_?_01: exc_op = 7'b11_00011; // TLBS_Refill
    12'b0_000_001_??_?_10: exc_op = 7'b10_00011; // TLBS_Invalid
    12'b0_000_01?_??_?_10: exc_op = 7'b10_00011; // TLBS_Invalid
    12'b0_000_1??_??_?_10: exc_op = 7'b10_00011; // TLBS_Invalid
    12'b0_000_001_??_?_11: exc_op = 7'b10_00001; // TLBS_Modified
    12'b0_000_01?_??_?_11: exc_op = 7'b10_00001; // TLBS_Modified
    12'b0_000_1??_??_?_11: exc_op = 7'b10_00001; // TLBS_Modified
    default              : exc_op = 7'd0;
    endcase
end

/*
always @(*) begin
    casex({exe_inst[31:26], exe_inst[20:16]})
    11'b000100_?????: br_taken = br_ez;
    11'b000101_?????: br_taken = ~br_ez;
    11'b000001_00001: br_taken = ~br_lz;
    11'b000111_00000: br_taken = ~(br_ez | br_lz);
    11'b000110_00000: br_taken = br_ez | br_lz;
    11'b000001_00000: br_taken = br_lz;
    11'b000001_10000: br_taken = br_lz;
    11'b000001_10001: br_taken = ~br_lz;
    default         : br_taken = 1'b0;
    endcase
end
*/
assign op_AllowOF       = exe_op[16];
assign op_Branch        = exe_op[13];
assign op_SaveMem       = exe_op[9:7];
assign op_LoadMem       = exe_op[6:4];
assign op_aluop         = exe_op[3:0];

assign deop_SaveMem     = de_out_op[9:7];
assign deop_LoadMem     = de_out_op[6:4];

/*
assign br_ez            = ~|exe_br;
assign br_lz            = exe_br[31];
*/
assign exe_out_op       = exe_op;
assign exe_value        = exe_result;
assign exe_ld_value     = exe_prev_value;
// assign exe_br_taken     = op_Branch & br_taken;
assign exe_br_taken     = 1'b0;

// assign data_sram_en     = exe_valid;
// assign data_sram_en     = 1'b1;
// assign data_sram_wen    = {4{exe_valid & ~exe_exc[5] & ~ctrl_exe_disable}} & exe_wen;
// assign data_sram_addr   = exe_result;
// assign data_sram_wdata  = exe_st_value;

always @(*) begin
    casex({op_LoadMem, op_SaveMem})
    6'b001_000: data_size = 3'b010; // LW
    6'b01?_000: data_size = 3'b010; // LWL/LWR
    6'b1?0_000: data_size = 3'b000; // LB
    6'b1?1_000: data_size = 3'b001; // LH
    6'b000_001: data_size = 3'b010; // SW
    6'b000_010: data_size = 3'b100; // SWL
    6'b000_011: data_size = 3'b101; // SWR
    6'b000_110: data_size = 3'b000; // SB
    6'b000_111: data_size = 3'b001; // SH
    default   : data_size = 3'd0;
    endcase
end

assign data_req         = exe_valid && !ctrl_exe_disable && data_req_r && !exe_exc[6];
assign data_wr          = | op_SaveMem;
assign data_addr        = exe_result;
assign data_wdata       = exe_st_value;

assign exe_exc          = prev_exc[6] ? prev_exc : exc_op;
assign exe_badvaddr     = (prev_exc[6] || op_AllowOF) ? prev_badvaddr : exe_result;

assign exe_ready_go     = !ctrl_exe_wait && (!(|(op_LoadMem | op_SaveMem)) || (data_req && data_addr_ok || data_addr_ok_r) || exe_exc[6]);
assign exe_allowin      = !exe_valid || exe_ready_go && pm_allowin || ctrl_exe_disable || ctrl_exe_disable_r;
assign exe_to_pm_valid  = exe_valid && exe_ready_go && (!ctrl_exe_disable) && (!ctrl_exe_disable_r);

alu valu
    (
    .aluop    (op_aluop  ),
    .vsrc1    (exe_vsrc1 ),
    .vsrc2    (exe_vsrc2 ),
    .vshift   (exe_vshift),
    .result   (exe_result),
    .overflow (exe_of    )
    );
/*
alu balu
    (
    .aluop  (4'b0001   ),
    .vsrc1  (exe_bsrc1 ),
    .vsrc2  (exe_bsrc2 ),
    .vshift (5'd0      ),
    .result (exe_br    )
    );
*/
endmodule

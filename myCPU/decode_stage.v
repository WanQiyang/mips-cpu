
module decode_stage(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] inst_rdata,
    input  wire        inst_data_ok,

    input  wire [31:0] fe_pc,
    input  wire [ 6:0] fe_exc,
    input  wire [31:0] fe_badvaddr,
    output reg  [31:0] de_pc,
    output reg  [31:0] de_inst,
    output wire [ 6:0] de_exc,
    output wire [31:0] de_badvaddr,

    input  wire [31:0] ctrl_rdata1,
    input  wire [31:0] ctrl_rdata2,

    output wire [19:0] de_out_op,
    output wire [ 4:0] de_dest,
    output wire [31:0] de_vsrc1,
    output wire [31:0] de_vsrc2,
    output wire [ 4:0] de_vshift,
    output wire [31:0] de_st_value,
    output wire [31:0] de_nextpc,
    output wire        de_jmp,

    output wire [31:0] de_bsrc1,
    output wire [31:0] de_bsrc2,

    output reg         de_valid,
    input  wire        fe_to_de_valid,
    output wire        de_allowin,
    output wire        de_to_exe_valid,
    input  wire        exe_allowin,

    input  wire        ctrl_de_wait,
    input  wire        ctrl_de_disable
);

wire        de_ready_go;
reg         ctrl_de_disable_r;
reg         inst_data_ok_r;

reg  [ 6:0] prev_exc;
reg  [31:0] prev_badvaddr;

reg  [ 3:0] int_op;
reg  [ 6:0] exc_op;
reg  [18:0] ext_op;

// Internal Op
wire        op_NextDelaySlot;
wire        op_ZeroBranch;
wire        op_Extend;
wire        op_Rtype;

// External Op
reg         op_DelaySlot;
wire        op_MTC0;
wire        op_MFC0;
wire        op_AllowOF;
wire        op_Mult;
wire        op_Div;
wire        op_Branch;
wire        op_HIWrite;
wire        op_LOWrite;
wire        op_RegWrite;
wire [ 2:0] op_SaveMem;  // '011-SWR '010-SWL '001-SW  '000-None
                         // '111-SH  '110-SB
wire [ 2:0] op_LoadMem;  // '011-LWR '010-LWL '001-LW  '000-None
                         // '111-LH  '110-LB  '101-LHU '100-LBU
wire [ 3:0] op_aluop;


wire [31:0] sign_extend;
wire [31:0] zero_extend;

// More Op
wire        op_j;
wire        op_jr;
wire        op_Link;
wire        op_jmp;

always @(posedge clk) begin
    if(!resetn) begin
        de_pc          <= 32'hbfc00000;
        prev_exc       <= 7'd0;
        prev_badvaddr  <= 32'd0;
        op_DelaySlot   <= 1'b0;
        de_valid       <= 1'b0;
    end
    else if(de_allowin) begin
        de_valid       <= fe_to_de_valid;
    end
    if(fe_to_de_valid && de_allowin) begin
        de_pc          <= fe_pc;
        prev_exc       <= fe_exc;
        prev_badvaddr  <= fe_badvaddr;
        op_DelaySlot   <= op_NextDelaySlot & ~fe_exc[6];
    end
    if((!inst_data_ok_r || fe_to_de_valid && de_allowin) && (inst_data_ok || de_pc != 32'hbfc00000 && de_inst != inst_rdata)) begin
        de_inst        <= inst_rdata;
    end
    if(!inst_data_ok_r || fe_to_de_valid && de_allowin) begin
        inst_data_ok_r <= (inst_data_ok || (de_pc != 32'hbfc00000 && de_inst != inst_rdata)) && !ctrl_de_disable && !ctrl_de_disable_r;
    end
    if(fe_to_de_valid && de_allowin || !ctrl_de_disable_r && ctrl_de_disable) begin
        ctrl_de_disable_r <= ctrl_de_disable;
    end
end

always @(*) begin
    casex(de_inst)
    32'b001111_00000_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0000_00_00000_000000001_000_000_1011; // LUI
    32'b000000_?????_?????_?????_00000_100001: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0000; // ADDU
    32'b001001_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_000_0000; // ADDIU
    32'b000100_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1001_00_00000_000001000_000_000_0000; // BEQ
    32'b000101_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1001_00_00000_000001000_000_000_0000; // BNE
    32'b100011_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_001_0000; // LW
    32'b000000_?????_?????_?????_00000_100101: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0110; // OR
    32'b000000_?????_?????_?????_00000_101010: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0010; // SLT
    32'b001010_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_000_0010; // SLTI
    32'b001011_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_000_0011; // SLTIU
    32'b000000_00000_?????_?????_?????_000000: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_1000; // SLL
    32'b101011_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000000_001_000_0000; // SW
    32'b000010_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1000_00_00000_000000000_000_000_0000; // J
    32'b000011_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1000_00_00000_000000001_000_000_0000; // JAL
    32'b000000_?????_00000_00000_00000_001000: {int_op, exc_op, ext_op} = 30'b1001_00_00000_000000000_000_000_0000; // JR
    32'b000000_?????_?????_?????_00000_100000: {int_op, exc_op, ext_op} = 30'b0001_00_00000_001000001_000_000_0000; // ADD
    32'b001000_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_001000001_000_000_0000; // ADDI
    32'b000000_?????_?????_?????_00000_100010: {int_op, exc_op, ext_op} = 30'b0001_00_00000_001000001_000_000_0001; // SUB
    32'b000000_?????_?????_?????_00000_100011: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0001; // SUBU
    32'b000000_?????_?????_?????_00000_101011: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0011; // SLTU
    32'b000000_?????_?????_?????_00000_100100: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0100; // AND
    32'b001100_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0000_00_00000_000000001_000_000_0100; // ANDI
    32'b000000_?????_?????_?????_00000_100111: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0101; // NOR
    32'b001101_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0000_00_00000_000000001_000_000_0110; // ORI
    32'b000000_?????_?????_?????_00000_100110: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0111; // XOR
    32'b001110_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0000_00_00000_000000001_000_000_0111; // XORI
    32'b000000_?????_?????_?????_00000_000100: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_1000; // SLLV
    32'b000000_00000_?????_?????_?????_000011: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_1010; // SRA
    32'b000000_?????_?????_?????_00000_000111: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_1010; // SRAV
    32'b000000_00000_?????_?????_?????_000010: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_1001; // SRL
    32'b000000_?????_?????_?????_00000_000110: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_1001; // SRLV
    32'b000000_?????_?????_00000_00000_011010: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000010110_000_000_0000; // DIV
    32'b000000_?????_?????_00000_00000_011011: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000010110_000_000_0000; // DIVU
    32'b000000_?????_?????_00000_00000_011000: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000100110_000_000_0000; // MULT
    32'b000000_?????_?????_00000_00000_011001: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000100110_000_000_0000; // MULTU
    32'b000000_00000_00000_?????_?????_010000: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0000; // MFHI
    32'b000000_00000_00000_?????_?????_010010: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000001_000_000_0000; // MFLO
    32'b000000_?????_00000_00000_00000_010001: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000100_000_000_0000; // MTHI
    32'b000000_?????_00000_00000_00000_010011: {int_op, exc_op, ext_op} = 30'b0001_00_00000_000000010_000_000_0000; // MTLO
    32'b000001_?????_00000_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1101_00_00000_000001000_000_000_0000; // BLTZ
    32'b000001_?????_00001_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1101_00_00000_000001000_000_000_0000; // BGEZ
    32'b000001_?????_10000_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1101_00_00000_000001001_000_000_0000; // BLTZAL
    32'b000001_?????_10001_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1101_00_00000_000001001_000_000_0000; // BGEZAL
    32'b000111_?????_00000_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1101_00_00000_000001000_000_000_0000; // BGTZ
    32'b000110_?????_00000_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b1101_00_00000_000001000_000_000_0000; // BLEZ
    32'b000000_?????_00000_?????_00000_001001: {int_op, exc_op, ext_op} = 30'b1001_00_00000_000000001_000_000_0000; // JALR
    32'b100000_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_110_0000; // LB
    32'b100100_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_100_0000; // LBU
    32'b100001_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_111_0000; // LH
    32'b100101_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_101_0000; // LHU
    32'b100010_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_010_0000; // LWL
    32'b100110_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000001_000_011_0000; // LWR
    32'b101000_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000000_110_000_0000; // SB
    32'b101001_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000000_111_000_0000; // SH
    32'b101010_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000000_010_000_0000; // SWL
    32'b101110_?????_?????_?????_?????_??????: {int_op, exc_op, ext_op} = 30'b0010_00_00000_000000000_011_000_0000; // SWR
    32'b010000_00100_?????_?????_00000_000???: {int_op, exc_op, ext_op} = 30'b0001_00_00000_100000000_000_000_0000; // MTC0
    32'b010000_00000_?????_?????_00000_000???: {int_op, exc_op, ext_op} = 30'b0000_00_00000_010000001_000_000_0000; // MFC0
    32'b010000_10000_00000_00000_00000_011000: {int_op, exc_op, ext_op} = 30'b0000_00_00000_000000000_000_000_0000; // ERET
    32'b000000_?????_?????_?????_?????_001100: {int_op, exc_op, ext_op} = 30'b0000_10_01000_000000000_000_000_0000; // SYSCALL
    32'b000000_?????_?????_?????_?????_001101: {int_op, exc_op, ext_op} = 30'b0000_10_01001_000000000_000_000_0000; // BREAK
    32'b010000_10000_00000_00000_00000_001000: {int_op, exc_op, ext_op} = 30'b0000_00_00000_000000000_000_000_0000; // TLBP
    32'b010000_10000_00000_00000_00000_000001: {int_op, exc_op, ext_op} = 30'b0000_00_00000_000000000_000_000_0000; // TLBR
    32'b010000_10000_00000_00000_00000_000010: {int_op, exc_op, ext_op} = 30'b0000_00_00000_000000000_000_000_0000; // TLBWI
    32'b010000_10000_00000_00000_00000_000110: {int_op, exc_op, ext_op} = 30'b0000_00_00000_000000000_000_000_0000; // TLBWR
    default                                  : {int_op, exc_op, ext_op} = 30'b0000_10_01010_000000000_000_000_0000; // RI
    endcase
end

assign op_NextDelaySlot = int_op[3];
assign op_ZeroBranch    = int_op[2];
assign op_Extend        = int_op[1];
assign op_Rtype         = int_op[0];

// assign op_DelaySlot  = ext_op[19];
assign op_MTC0       = ext_op[18];
assign op_MFC0       = ext_op[17];
assign op_AllowOF    = ext_op[16];
assign op_Mult       = ext_op[15];
assign op_Div        = ext_op[14];
assign op_Branch     = ext_op[13];
assign op_HIWrite    = ext_op[12];
assign op_LOWrite    = ext_op[11];
assign op_RegWrite   = ext_op[10];
assign op_SaveMem    = ext_op[9:7];
assign op_LoadMem    = ext_op[6:4];
assign op_aluop      = ext_op[3:0];

assign op_j    = (de_inst[31:27] == 5'b00001);
assign op_jr   = (de_inst[31:26] == 6'd0 && de_inst[5:1] == 5'b00100 );
assign op_Link = (de_inst[31:26] == 6'b000011)
              || (de_inst[31:26] == 6'd0 && de_inst[5:0] == 6'b001001)
              || (de_inst[31:26] == 6'd1 && de_inst[20]  == 1'b1     );

assign sign_extend = {{16{de_inst[15]}}, de_inst[15:0]};
assign zero_extend = {16'd0, de_inst[15:0]};

assign de_out_op   = {op_DelaySlot, ext_op};
assign de_dest     = {5{op_RegWrite}} & ((op_Link & ~op_jr) ? 5'd31 :
                     op_Rtype ? de_inst[15:11] : de_inst[20:16]);

assign de_vsrc1    = op_Link ? de_pc : ctrl_rdata1;
assign de_vsrc2    = op_Link       ? 32'd8 :
                     op_Rtype      ? ctrl_rdata2 :
                     op_Extend     ? sign_extend : zero_extend;

assign de_bsrc1    = ctrl_rdata1;
assign de_bsrc2    = op_ZeroBranch ? 32'd0 : ctrl_rdata2;

wire [31:0] de_bresult;
wire        br_ez;
wire        br_lz;
reg         br_taken;

assign de_bresult  = de_bsrc1 - de_bsrc2;
assign br_ez            = ~|de_bresult;
assign br_lz            = de_bresult[31];

always @(*) begin
    casex({de_inst[31:26], de_inst[20:16]})
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

assign de_vshift   = (|de_inst[25:21]) ? ctrl_rdata1[4:0] : de_inst[10:6];
assign de_st_value = ctrl_rdata2;
assign de_nextpc   = (br_taken & op_Branch) ? fe_pc + {{14{de_inst[15]}}, de_inst[15:0], 2'd0}:
                     op_j      ? {de_pc[31:28], de_inst[25:0], 2'd0}:
                     op_jr     ? ctrl_rdata1 : fe_pc + 32'd4;
assign op_jmp      = op_j | op_jr;
assign de_jmp      = op_jmp;

assign de_exc      = prev_exc[6] ? prev_exc : exc_op;
assign de_badvaddr = prev_exc[6] ? prev_badvaddr : 32'd0;

// assign de_ready_go     = !ctrl_de_wait && (inst_data_ok || inst_data_ok_r);
assign de_ready_go     = !ctrl_de_wait && (inst_data_ok_r || prev_exc[6]);
assign de_allowin      = !de_valid || de_ready_go && exe_allowin || ctrl_de_disable || ctrl_de_disable_r;
assign de_to_exe_valid = de_valid && de_ready_go && (!ctrl_de_disable) && (!ctrl_de_disable_r);

endmodule

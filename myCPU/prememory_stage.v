
module prememory_stage(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] exe_pc,          //pc @execute_stage
    input  wire [31:0] exe_inst,        //instr code @execute_stage
    input  wire [ 6:0] exe_exc,
    input  wire [31:0] exe_badvaddr,
    output reg  [31:0] pm_pc,          //pc @prememory_stage
    output reg  [31:0] pm_inst,        //instr code @prememory_stage

    input  wire [19:0] exe_out_op,      //control signals used in MEM, WB stages
    input  wire [ 4:0] exe_dest,        //reg num of dest operand
    input  wire [31:0] exe_value,       //alu result from exe_stage or other intermediate
                                        //value for the following stages
    input  wire [31:0] exe_ld_value,

    input  wire [31:0] data_rdata,
    input  wire        data_data_ok,
    output reg  [31:0] pm_rdata,

    output wire [19:0] pm_out_op,      //control signals used in WB stage
    output reg  [ 4:0] pm_dest,        //reg num of dest operand
    output wire [31:0] pm_value,       //pm_stage final result
    output reg  [31:0] pm_ld_value,

    input  wire [31:0] rd_8_CP0,
    input  wire [31:0] rd_9_CP0,
    input  wire [31:0] rd_11_CP0,
    input  wire [31:0] rd_12_CP0,
    input  wire [31:0] rd_13_CP0,
    input  wire [31:0] rd_14_CP0,

    output wire [31:0] we_CP0,
    output reg  [31:0] wd_8_CP0,
    output reg  [31:0] wd_9_CP0,
    output reg  [31:0] wd_11_CP0,
    output reg  [31:0] wd_12_CP0,
    output reg  [31:0] wd_13_CP0,
    output reg  [31:0] wd_14_CP0,

    input  wire [31:0] rd_0_CP0,
    input  wire [31:0] rd_1_CP0,
    input  wire [31:0] rd_2_CP0,
    input  wire [31:0] rd_3_CP0,
    input  wire [31:0] rd_5_CP0,
    input  wire [31:0] rd_10_CP0,

    output reg  [31:0] wd_0_CP0,
    output reg  [31:0] wd_2_CP0,
    output reg  [31:0] wd_3_CP0,
    output reg  [31:0] wd_5_CP0,
    output reg  [31:0] wd_10_CP0,

    output wire        ResponseExc,
    output wire [31:0] ExcVector,
    output wire        ERET,
    output wire [31:0] EPC,
    input  wire [ 5:0] int_n_i,

    input  wire [31:0] tlbp_index,
    input  wire [89:0] tlbr_tlb,
    output wire        tlbwi,
    output wire        tlbwr,

    output reg         pm_valid,
    input  wire        exe_to_pm_valid,
    output wire        pm_allowin,
    output wire        pm_to_mem_valid,
    input  wire        mem_allowin,

    input  wire        ctrl_pm_wait,
    input  wire        ctrl_pm_disable
);

wire        pm_ready_go;
reg         data_data_ok_r;

reg  [19:0] pm_op;
reg  [31:0] pm_prev_value;

reg  [ 6:0] prev_exc;
reg  [31:0] prev_badvaddr;

reg         tick_tock;

reg  [31:0] MTC0_we;

wire        op_DelaySlot;
wire        op_MTC0;
wire        op_MFC0;
wire [ 2:0] op_SaveMem;
wire [ 2:0] op_LoadMem;

wire        int_req;
wire        int_pending;

wire        TI;
wire [ 5:0] HWInt;

wire        TLBP;
wire        TLBR;
wire        TLBWI;
wire        TLBWR;

wire        exc_tlb;

always @(posedge clk) begin
    if(!resetn) begin
        pm_pc          <= 32'hbfc00000;
        pm_inst        <= 32'd0;
        pm_dest        <= 5'd0;
        pm_op          <= 20'd0;
        pm_prev_value  <= 32'd0;
        pm_ld_value    <= 32'd0;
        prev_exc       <= 7'd0;
        prev_badvaddr  <= 32'd0;
        pm_valid       <= 1'b0;
    end
    else if(pm_allowin) begin
        pm_valid       <= exe_to_pm_valid;
    end
    if(exe_to_pm_valid && pm_allowin) begin
        pm_pc          <= exe_pc;
        pm_inst        <= exe_inst;
        pm_dest        <= exe_dest;
        pm_op          <= exe_out_op;
        pm_prev_value  <= exe_value;
        pm_ld_value    <= exe_ld_value;
        prev_exc       <= exe_exc;
        prev_badvaddr  <= exe_badvaddr;
    end
    if((!data_data_ok_r || exe_to_pm_valid && pm_allowin) && data_data_ok) begin
        pm_rdata       <= data_rdata;
    end
    if(!data_data_ok_r || exe_to_pm_valid && pm_allowin) begin
        data_data_ok_r <= data_data_ok;
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        tick_tock     <= 1'b0;

    end
    else begin
        tick_tock     <= (op_MTC0 && pm_inst[15:11] == 5'h09) ? 1'b0 : ~tick_tock;

    end
end

always @(*) begin
    case(pm_inst[15:11])
    5'h00:   MTC0_we = 32'h00000001;
    5'h01:   MTC0_we = 32'h00000002;
    5'h02:   MTC0_we = 32'h00000004;
    5'h03:   MTC0_we = 32'h00000008;
    5'h04:   MTC0_we = 32'h00000010;
    5'h05:   MTC0_we = 32'h00000020;
    5'h06:   MTC0_we = 32'h00000040;
    5'h07:   MTC0_we = 32'h00000080;
    5'h08:   MTC0_we = 32'h00000000; // BadVAddr
    5'h09:   MTC0_we = 32'h00000200;
    5'h0a:   MTC0_we = 32'h00000400;
    5'h0b:   MTC0_we = 32'h00002800; // Compare
    5'h0c:   MTC0_we = 32'h00001000;
    5'h0d:   MTC0_we = 32'h00002000;
    5'h0e:   MTC0_we = 32'h00004000;
    5'h0f:   MTC0_we = 32'h00008000;
    5'h10:   MTC0_we = 32'h00010000;
    5'h11:   MTC0_we = 32'h00020000;
    5'h12:   MTC0_we = 32'h00040000;
    5'h13:   MTC0_we = 32'h00080000;
    5'h14:   MTC0_we = 32'h00100000;
    5'h15:   MTC0_we = 32'h00200000;
    5'h16:   MTC0_we = 32'h00400000;
    5'h17:   MTC0_we = 32'h00800000;
    5'h18:   MTC0_we = 32'h01000000;
    5'h19:   MTC0_we = 32'h02000000;
    5'h1a:   MTC0_we = 32'h04000000;
    5'h1b:   MTC0_we = 32'h08000000;
    5'h1c:   MTC0_we = 32'h10000000;
    5'h1d:   MTC0_we = 32'h20000000;
    5'h1e:   MTC0_we = 32'h40000000;
    5'h1f:   MTC0_we = 32'h80000000;
    default: MTC0_we = 32'h00000000;
    endcase
end

assign op_DelaySlot = pm_op[19];
assign op_MTC0      = pm_op[18];
assign op_MFC0      = pm_op[17];
assign op_SaveMem   = pm_op[9:7];
assign op_LoadMem   = pm_op[6:4];

assign int_pending = rd_12_CP0[0] & (|(rd_13_CP0[9:8] & rd_12_CP0[9:8]) | |(rd_13_CP0[15:10] & rd_12_CP0[15:10]) | rd_13_CP0[30]);

wire   exc_resp;
reg    exc_resp_r;

assign exc_resp    = pm_valid && !rd_12_CP0[1] && (int_pending || prev_exc[6]);

always @(posedge clk) begin
    if(!resetn) begin
        exc_resp_r <= 1'b0;
    end else begin
        exc_resp_r <= pm_valid && (exc_resp || exc_resp_r) & !ctrl_pm_wait;
    end
end

assign ResponseExc = exc_resp || exc_resp_r;

assign ERET        = pm_valid && (pm_inst == 32'b010000_10000_00000_00000_00000_011000) && !ResponseExc;

assign TLBP        = pm_valid && (pm_inst == 32'b010000_10000_00000_00000_00000_001000);
assign TLBR        = pm_valid && (pm_inst == 32'b010000_10000_00000_00000_00000_000001);
assign TLBWI       = pm_valid && (pm_inst == 32'b010000_10000_00000_00000_00000_000010);
assign TLBWR       = pm_valid && (pm_inst == 32'b010000_10000_00000_00000_00000_000110);

assign exc_tlb     = prev_exc[4:0] == 5'd1 || prev_exc[4:0] == 5'd2 || prev_exc[4:0] == 5'd3;

assign tlbwi       = TLBWI;
assign tlbwr       = TLBWR;

assign TI          = rd_9_CP0 == rd_11_CP0;

assign we_CP0      = {32{pm_valid}} & (({32{op_MTC0 && !ctrl_pm_wait}} & MTC0_we)
                   | ({32{ResponseExc && !ctrl_pm_wait}} & 32'h00007100)
                   | ({32{ResponseExc && exc_tlb && !ctrl_pm_wait}} & 32'h00000400)
                   | ({32{ERET && !ctrl_pm_wait}} & 32'h00001000)
                   | ({32{!ResponseExc && TLBP && !ctrl_pm_wait}} & 32'h00000001)
                   | ({32{!ResponseExc && TLBR && !ctrl_pm_wait}} & 32'h0000042c))
                   | {18'd0, resetn, 3'd0, tick_tock, 9'd0};

always @(*) begin
    wd_8_CP0 = prev_badvaddr;
end

always @(*) begin
    if(op_MTC0 && pm_inst[15:11] == 5'h09 && !ctrl_pm_wait) begin
        wd_9_CP0 = pm_ld_value;
    end else begin
        wd_9_CP0 = rd_9_CP0 + 32'd1;
    end
end

always @(*) begin
    wd_11_CP0 = pm_ld_value;
end

always @(*) begin
    if(ERET && !ctrl_pm_wait) begin
        wd_12_CP0 = rd_12_CP0 & 32'hfffffffd;
    end else if(ResponseExc && !ctrl_pm_wait) begin
        wd_12_CP0 = rd_12_CP0 | 32'h00000002;
    end else if(op_MTC0 && pm_inst[15:11] == 5'h0c && !ctrl_pm_wait) begin
        wd_12_CP0 = (rd_12_CP0 & 32'hffff00fc) | (pm_ld_value & 32'h0000ff03);
    end else begin
        wd_12_CP0 = rd_12_CP0;
    end
end

always @(*) begin
    if(ResponseExc && !ctrl_pm_wait) begin
        if(int_pending) begin
            wd_13_CP0 = (rd_13_CP0 & 32'h7fff0383) | {op_DelaySlot, TI, 14'd0, HWInt, 10'd0};
        end else begin
            wd_13_CP0 = (rd_13_CP0 & 32'h7fff0383) | {op_DelaySlot, TI, 14'd0, HWInt, 3'd0, prev_exc[4:0], 2'd0};
        end
    end else if(op_MTC0 && pm_inst[15:11] == 5'h0d && !ctrl_pm_wait) begin
        wd_13_CP0 = (rd_13_CP0 & 32'hf73f00ff) | (pm_ld_value & 32'h08c00300) | {1'b0, TI, 14'd0, HWInt, 10'd0};
    end else if(op_MTC0 && pm_inst[15:11] == 5'h0b && !ctrl_pm_wait) begin
        wd_13_CP0 = (rd_13_CP0 & 32'hbfff03ff) | {16'd0, HWInt, 10'd0};
    end else begin
        wd_13_CP0 = {rd_13_CP0 & 32'hffff03ff} | {1'b0, TI, 14'd0, HWInt, 10'd0};
    end
end

always @(*) begin
    if(ResponseExc && !ctrl_pm_wait) begin
        wd_14_CP0 = op_DelaySlot ? pm_pc - 32'd4 : pm_pc;
    end else begin
        wd_14_CP0 = pm_ld_value;
    end
end

always @(*) begin
    if(!ResponseExc && TLBP && !ctrl_pm_wait) begin
        wd_0_CP0 = tlbp_index;
    end else begin
        wd_0_CP0 = {rd_0_CP0[31:5], pm_ld_value[4:0]};
    end
end

always @(*) begin
    if(!ResponseExc && TLBR && !ctrl_pm_wait) begin
        wd_2_CP0 = {6'd0, tlbr_tlb[49:42], tlbr_tlb[41:30] & ~tlbr_tlb[62:51], tlbr_tlb[29:25], tlbr_tlb[50]};
        wd_3_CP0 = {6'd0, tlbr_tlb[24:17], tlbr_tlb[16: 5] & ~tlbr_tlb[62:51], tlbr_tlb[ 4: 0], tlbr_tlb[50]};
    end else begin
        wd_2_CP0 = {rd_2_CP0[31:26], pm_ld_value[25:0]};
        wd_3_CP0 = {rd_3_CP0[31:26], pm_ld_value[25:0]};
    end
end

always @(*) begin
    if(!ResponseExc && TLBR && !ctrl_pm_wait) begin
        wd_5_CP0 = {7'd0, tlbr_tlb[62:51], 13'd0};
    end else begin
        wd_5_CP0 = {rd_5_CP0[31:29], pm_ld_value[28:11], rd_5_CP0[10:0]};
    end
end

always @(*) begin
    if(ResponseExc && exc_tlb && !ctrl_pm_wait) begin
        wd_10_CP0 = {prev_badvaddr[31:13], rd_10_CP0[12:0]};
    end else if(!ResponseExc && TLBR && !ctrl_pm_wait) begin
        wd_10_CP0 = {tlbr_tlb[89:71], 5'd0, tlbr_tlb[70:63]};
    end else begin
        wd_10_CP0 = {pm_ld_value[31:13], rd_10_CP0[12:8], pm_ld_value[7:0]};
    end
end

assign ExcVector   = prev_exc[5] ? 32'hbfc00200 : 32'hbfc00380;
assign EPC         = rd_14_CP0;

assign HWInt[5]    = ~int_n_i[5] | TI;
assign HWInt[4:0]  = ~int_n_i[4:0];

assign pm_out_op       = pm_op;
assign pm_value        = op_MFC0 ?
                         pm_inst[15:11] == 5'd8  ? rd_8_CP0  :
                         pm_inst[15:11] == 5'd9  ? rd_9_CP0  :
                         pm_inst[15:11] == 5'd11 ? rd_11_CP0 :
                         pm_inst[15:11] == 5'd12 ? rd_12_CP0 :
                         pm_inst[15:11] == 5'd13 ? rd_13_CP0 :
                         pm_inst[15:11] == 5'd14 ? rd_14_CP0 :
                         pm_inst[15:11] == 5'd0  ? rd_0_CP0  :
                         pm_inst[15:11] == 5'd1  ? rd_1_CP0  :
                         pm_inst[15:11] == 5'd2  ? rd_2_CP0  :
                         pm_inst[15:11] == 5'd3  ? rd_3_CP0  :
                         pm_inst[15:11] == 5'd5  ? rd_5_CP0  :
                         pm_inst[15:11] == 5'd10 ? rd_10_CP0 :
                         32'd0 : pm_prev_value;

// assign pm_ready_go     = !ctrl_pm_wait && (|(op_LoadMem | op_SaveMem) ? (data_data_ok || data_data_ok_r) : 1'b1);
assign pm_ready_go     = !ctrl_pm_wait && (|(op_LoadMem | op_SaveMem) && !prev_exc[6] ? data_data_ok_r : 1'b1);
assign pm_allowin      = !pm_valid || pm_ready_go && mem_allowin || ctrl_pm_disable;
assign pm_to_mem_valid = pm_valid && pm_ready_go && (!ctrl_pm_disable);

endmodule

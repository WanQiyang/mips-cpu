
module memory_stage(
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] pm_pc,          //pc @prememory_stage
    input  wire [31:0] pm_inst,        //instr code @prememory_stage
    output reg  [31:0] mem_pc,          //pc @memory_stage
    output reg  [31:0] mem_inst,        //instr code @memory_stage

    input  wire [19:0] pm_out_op,      //control signals used in MEM, WB stages
    input  wire [ 4:0] pm_dest,        //reg num of dest operand
    input  wire [31:0] pm_value,       //alu result from prememory_stage or other intermediate
                                        //value for the following stages
    input  wire [31:0] pm_ld_value,

//    input  wire [31:0] data_sram_rdata,
    input  wire [31:0] pm_rdata,

    output wire [19:0] mem_out_op,      //control signals used in WB stage
    output reg  [ 4:0] mem_dest,        //reg num of dest operand
    output reg  [31:0] mem_value,       //mem_stage final result

    output reg         mem_valid,
    input  wire        pm_to_mem_valid,
    output wire        mem_allowin,
    output wire        mem_to_wb_valid,
    input  wire        wb_allowin,

    input  wire        ctrl_mem_wait,
    input  wire        ctrl_mem_disable
);

wire        mem_ready_go;

reg  [19:0] mem_op;
reg  [31:0] mem_prev_value;

wire [ 2:0] op_LoadMem;
reg  [31:0] mem_ld_value;
reg  [ 3:0] mem_wen;

always @(posedge clk) begin
    if(!resetn) begin
        mem_pc         <= 32'hbfc00000;
        mem_inst       <= 32'd0;
        mem_dest       <= 5'd0;
        mem_op         <= 20'd0;
        mem_prev_value <= 32'd0;
        mem_ld_value   <= 32'd0;
        mem_valid      <= 1'b0;
    end
    else if(mem_allowin) begin
        mem_valid      <= pm_to_mem_valid;
    end
    if(pm_to_mem_valid && mem_allowin) begin
        mem_pc         <= pm_pc;
        mem_inst       <= pm_inst;
        mem_dest       <= pm_dest;
        mem_op         <= pm_out_op;
        mem_prev_value <= pm_value;
        mem_ld_value   <= pm_ld_value;
    end
end

always @(*) begin
    casex({op_LoadMem, mem_prev_value[1:0]})
    5'b001_?? : mem_value = pm_rdata;
    5'b010_00 : mem_value = {pm_rdata[ 7: 0], mem_ld_value[23: 0]};
    5'b010_01 : mem_value = {pm_rdata[15: 0], mem_ld_value[15: 0]};
    5'b010_10 : mem_value = {pm_rdata[23: 0], mem_ld_value[ 7: 0]};
    5'b010_11 : mem_value = {pm_rdata[31: 0]                     };
    5'b011_00 : mem_value = {                     pm_rdata[31: 0]};
    5'b011_01 : mem_value = {mem_ld_value[31:24], pm_rdata[31: 8]};
    5'b011_10 : mem_value = {mem_ld_value[31:16], pm_rdata[31:16]};
    5'b011_11 : mem_value = {mem_ld_value[31: 8], pm_rdata[31:24]};
    5'b100_00 : mem_value = {24'd0, pm_rdata[ 7: 0]};
    5'b100_01 : mem_value = {24'd0, pm_rdata[15: 8]};
    5'b100_10 : mem_value = {24'd0, pm_rdata[23:16]};
    5'b100_11 : mem_value = {24'd0, pm_rdata[31:24]};
    5'b101_0? : mem_value = {16'd0, pm_rdata[15: 0]};
    5'b101_1? : mem_value = {16'd0, pm_rdata[31:16]};
    5'b110_00 : mem_value = {{24{pm_rdata[ 7]}}, pm_rdata[ 7: 0]};
    5'b110_01 : mem_value = {{24{pm_rdata[15]}}, pm_rdata[15: 8]};
    5'b110_10 : mem_value = {{24{pm_rdata[23]}}, pm_rdata[23:16]};
    5'b110_11 : mem_value = {{24{pm_rdata[31]}}, pm_rdata[31:24]};
    5'b111_0? : mem_value = {{16{pm_rdata[15]}}, pm_rdata[15: 0]};
    5'b111_1? : mem_value = {{16{pm_rdata[31]}}, pm_rdata[31:16]};
    default   : mem_value = mem_prev_value;
    endcase
end

assign op_LoadMem      = mem_op[6:4];

assign mem_out_op      = mem_op;

assign mem_ready_go    = !ctrl_mem_wait;
assign mem_allowin     = !mem_valid || mem_ready_go && wb_allowin || ctrl_mem_disable;
assign mem_to_wb_valid = mem_valid && mem_ready_go && (!ctrl_mem_disable);

endmodule

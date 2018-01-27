
module controller(
    input  wire        clk,
    input  wire        resetn,

    input  wire        de_valid,
    input  wire [31:0] ctrl_pc,
    input  wire [31:0] ctrl_inst,
    input  wire [19:0] ctrl_op,
    input  wire        exe_valid,
    input  wire [19:0] exe_op,
    input  wire [ 4:0] exe_dest,
    input  wire        pm_valid,
    input  wire [19:0] pm_op,
    input  wire [ 4:0] pm_dest,
    input  wire        mem_valid,
    input  wire [19:0] mem_op,
    input  wire [ 4:0] mem_dest,
    input  wire        wb_valid,
    input  wire [19:0] wb_op,
    input  wire [ 4:0] wb_dest,

    output wire [ 4:0] ctrl_rf_raddr1,
    input  wire [31:0] ctrl_rf_rdata1,
    output wire [ 4:0] ctrl_rf_raddr2,
    input  wire [31:0] ctrl_rf_rdata2,

    input  wire [31:0] exe_value,
    input  wire [31:0] pm_value,
    input  wire [31:0] mem_value,
    input  wire [31:0] wb_value,

    output wire [31:0] ctrl_rdata1,
    output wire [31:0] ctrl_rdata2,

    input  wire [31:0] rd_HI,
    input  wire [31:0] rd_LO,
    input  wire [31:0] wd_HI,
    input  wire [31:0] wd_LO,

    output wire [32:0] mult_a,
    output wire [32:0] mult_b,

    output wire        div_a_valid,
    output wire [39:0] div_a_data,
    input  wire        div_a_ready,
    output wire        div_b_valid,
    output wire [39:0] div_b_data,
    input  wire        div_b_ready,
    input  wire        div_p_valid,

    output wire        ctrl_fe_wait,
    output wire        ctrl_fe_disable,
    output wire        ctrl_de_wait,
    output wire        ctrl_de_disable,
    output wire        ctrl_exe_wait,
    output wire        ctrl_exe_disable,
    output wire        ctrl_pm_wait,
    output wire        ctrl_pm_disable,
    output wire        ctrl_mem_wait,
    output wire        ctrl_mem_disable,
    output wire        ctrl_wb_wait,

    input  wire [31:0] de_nextpc,
    input  wire        de_jmp,
    input  wire        exe_br_taken,
    input  wire        fe_valid,
    input  wire [31:0] fe_pc,
    input  wire        fe_allowin,

    output reg  [31:0] ctrl_nextpc,

    input  wire        ResponseExc,
    input  wire [31:0] ExcVector,
    input  wire        ERET,
    input  wire [31:0] EPC,

    input  wire        de_to_exe_valid
);

    wire [ 5:0] opcode;
    wire        rs_read;
    wire        rt_read;
    wire        HI_read;
    wire        LO_read;

    wire        exe_ld;
    wire        pm_ld;
    wire        mem_ld;
    wire        wb_ld;

    wire        rs_exe_hazard;
    wire        rt_exe_hazard;
    wire        HI_exe_hazard;
    wire        LO_exe_hazard;
    wire        rs_pm_hazard;
    wire        rt_pm_hazard;
    wire        HI_pm_hazard;
    wire        LO_pm_hazard;
    wire        rs_mem_hazard;
    wire        rt_mem_hazard;
    wire        HI_mem_hazard;
    wire        LO_mem_hazard;
    wire        rs_wb_hazard;
    wire        rt_wb_hazard;
    wire        HI_wb_hazard;
    wire        LO_wb_hazard;

    wire        exe_mult;
    wire        pm_mult;
    wire        mem_mult;

    wire        op_mult;
    wire        op_multu;
    wire        op_div;
    wire        op_divu;

    wire [39:0] md_a;
    wire [39:0] md_b;
    wire [31:0] wb_real_value;

    reg         dividing;
    wire        next_dividing;
    wire        div_valid;

    always @(posedge clk) begin
        // if(!(resetn && de_valid && ctrl_pc != 32'hbfc00000))
        if(!(resetn && ctrl_pc != 32'hbfc00000))
            dividing <= 1'b0;
        else
            dividing <= next_dividing;
    end

    assign opcode        = ctrl_inst[31:26];
    assign rs_read       = ctrl_rf_raddr1 != 5'd0 &&
                           opcode != 6'b000010 &&
                           opcode != 6'b000011 ;
    assign rt_read       = ctrl_rf_raddr2 != 5'd0 && (
                           opcode == 6'b000000 || // SPECIAL
                           opcode == 6'b000100 || // BEQ
                           opcode == 6'b000101 || // BNE
                           opcode == 6'b101011 || // SW
                           opcode == 6'b100010 || // LWL
                           opcode == 6'b100110 || // LWR
                           opcode == 6'b101000 || // SB
                           opcode == 6'b101001 || // SH
                           opcode == 6'b101010 || // SWL
                           opcode == 6'b101110 || // SWR
                           opcode == 6'b010000 ); // MTC0

    assign exe_ld        = | exe_op[6:4];
    assign exe_mfc0      = exe_op[17];
    assign pm_ld         = | pm_op[6:4];
    assign mem_ld        = | mem_op[6:4];
    assign wb_ld         = | wb_op[6:4];
    assign exe_mult      = exe_op[15];
    assign pm_mult       = pm_op[15];
    assign mem_mult      = mem_op[15];

    assign rs_exe_hazard = (rs_read && exe_valid && (ctrl_rf_raddr1 == exe_dest))
                        || HI_exe_hazard || LO_exe_hazard;
    assign rt_exe_hazard = rt_read && exe_valid && (ctrl_rf_raddr2 == exe_dest);

    assign rs_pm_hazard  = (rs_read && pm_valid && (ctrl_rf_raddr1 == pm_dest))
                        || HI_pm_hazard || LO_pm_hazard;
    assign rt_pm_hazard  = rt_read && pm_valid && (ctrl_rf_raddr2 == pm_dest);

    assign rs_mem_hazard = (rs_read && mem_valid && (ctrl_rf_raddr1 == mem_dest))
                        || HI_mem_hazard || LO_mem_hazard;
    assign rt_mem_hazard = rt_read && mem_valid && (ctrl_rf_raddr2 == mem_dest);

    assign rs_wb_hazard  = (rs_read && wb_valid  && (ctrl_rf_raddr1 == wb_dest))
                        || HI_wb_hazard || LO_wb_hazard;
    assign rt_wb_hazard  = rt_read && wb_valid  && (ctrl_rf_raddr2 == wb_dest);

    // assign HI_read       = de_valid && de_to_exe_valid && opcode == 6'b000000 && ctrl_inst[5:0] == 6'b010000; // MFHI
    // assign LO_read       = de_valid && de_to_exe_valid && opcode == 6'b000000 && ctrl_inst[5:0] == 6'b010010; // MFLO

    assign HI_read       = de_valid && opcode == 6'b000000 && ctrl_inst[5:0] == 6'b010000; // MFHI
    assign LO_read       = de_valid && opcode == 6'b000000 && ctrl_inst[5:0] == 6'b010010; // MFLO

    assign HI_exe_hazard = HI_read && exe_valid && exe_op[12];
    assign LO_exe_hazard = LO_read && exe_valid && exe_op[11];
    assign HI_pm_hazard  = HI_read && pm_valid  && pm_op[12];
    assign LO_pm_hazard  = LO_read && pm_valid  && pm_op[11];
    assign HI_mem_hazard = HI_read && mem_valid && mem_op[12];
    assign LO_mem_hazard = LO_read && mem_valid && mem_op[11];
    assign HI_wb_hazard  = HI_read && wb_valid  && wb_op[12];
    assign LO_wb_hazard  = LO_read && wb_valid  && wb_op[11];

    assign op_mult  = (opcode == 6'b000000 && ctrl_inst[5:0] == 6'b011000);
    assign op_multu = (opcode == 6'b000000 && ctrl_inst[5:0] == 6'b011001);
    assign op_div   = (opcode == 6'b000000 && ctrl_inst[5:0] == 6'b011010);
    assign op_divu  = (opcode == 6'b000000 && ctrl_inst[5:0] == 6'b011011);

    assign md_a = (op_mult  || op_div)  ? {{8{ctrl_rdata1[31]}}, ctrl_rdata1}
                : (op_multu || op_divu) ? {8'b0, ctrl_rdata1}
                : 40'd0 ;
    assign md_b = (op_mult  || op_div)  ? {{8{ctrl_rdata2[31]}}, ctrl_rdata2}
                : (op_multu || op_divu) ? {8'b0, ctrl_rdata2}
                : 40'd0 ;

    assign wb_real_value = HI_wb_hazard ? wd_HI
                         : LO_wb_hazard ? wd_LO
                         : wb_value ;


    assign next_dividing = dividing  ? ~div_p_valid
                         : div_valid ? (div_a_ready & div_b_ready)
                         : 1'b0 ;
    // assign div_valid     = de_valid && de_to_exe_valid && (op_div || op_divu);
    assign div_valid     = de_valid && (op_div || op_divu);

    assign ctrl_rf_raddr1 = ctrl_inst[25:21];
    assign ctrl_rf_raddr2 = ctrl_inst[20:16];
    assign ctrl_rdata1    = rs_exe_hazard ? exe_value
                          : rs_pm_hazard  ? pm_value
                          : rs_mem_hazard ? mem_value
                          : rs_wb_hazard  ? wb_real_value
                          : HI_read       ? rd_HI
                          : LO_read       ? rd_LO
                          : ctrl_rf_rdata1;
    assign ctrl_rdata2    = rt_exe_hazard ? exe_value
                          : rt_pm_hazard  ? pm_value
                          : rt_mem_hazard ? mem_value
                          : rt_wb_hazard  ? wb_value
                          : ctrl_rf_rdata2;

    assign ctrl_fe_wait   = 1'b0;
    assign ctrl_de_wait   = ((rs_exe_hazard || rt_exe_hazard) && exe_valid && (exe_ld || exe_mfc0))
                         || ((rs_pm_hazard  || rt_pm_hazard)  && pm_valid  && pm_ld )
                         || ((rs_mem_hazard || rt_mem_hazard) && mem_valid && mem_ld)
                         || ((HI_read || LO_read) && exe_valid && exe_mult)
                         || ((HI_read || LO_read) && pm_valid  && pm_mult )
                         || ((HI_read || LO_read) && mem_valid && mem_mult)
                         || (div_valid && !next_dividing) || dividing ;
    assign ctrl_exe_wait  = 1'b0;
    assign ctrl_pm_wait   = (pm_valid && ResponseExc && fe_pc != ExcVector)
                         || (pm_valid && ERET && fe_pc != EPC );
    assign ctrl_mem_wait  = 1'b0;
    assign ctrl_wb_wait   = 1'b0;

    // assign ctrl_fe_disable  = exe_valid & exe_op[13] & ~exe_br_taken;
    assign ctrl_fe_disable  = pm_valid && (ResponseExc || ERET);
    assign ctrl_de_disable  = pm_valid && (ResponseExc || ERET);
    assign ctrl_exe_disable = pm_valid && (ResponseExc || ERET);
    assign ctrl_pm_disable  = pm_valid && (ResponseExc || ERET) && !ctrl_pm_wait;
    assign ctrl_mem_disable = 1'b0;

    assign mult_a = md_a[32:0];
    assign mult_b = md_b[32:0];

    assign div_a_valid = dividing ? 1'b0 : div_valid;
    assign div_a_data  = md_a;
    assign div_b_valid = dividing ? 1'b0 : div_valid;
    assign div_b_data  = md_b;

    always @(posedge clk) begin
        if(!resetn) begin
            ctrl_nextpc <= 32'hbfc00000;
        end else if (pm_valid && ResponseExc) begin
            ctrl_nextpc <= ExcVector;
        end else if (pm_valid && ERET) begin
            ctrl_nextpc <= EPC;
        end else if (de_valid) begin
            ctrl_nextpc <= de_nextpc;
        end else if (!fe_valid) begin
            ctrl_nextpc <= 32'hbfc00000;
        end else begin
            ctrl_nextpc <= fe_pc + 32'd4;
        end
    end

endmodule

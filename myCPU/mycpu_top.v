
`define SIMU_DEBUG

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    input  wire [ 5:0] int_n_i,
/*
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
*/
    output wire        inst_req     ,
    output wire        inst_wr      ,
    output wire [ 2:0] inst_size    ,
    output wire [31:0] inst_addr    ,
    output wire [31:0] inst_wdata   ,
    input  wire [31:0] inst_rdata   ,
    input  wire        inst_addr_ok ,
    input  wire        inst_data_ok ,
/*
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata
*/
    output wire        data_req     ,
    output wire        data_wr      ,
    output wire [ 2:0] data_size    ,
    output wire [31:0] data_addr    ,
    output wire [31:0] data_wdata   ,
    input  wire [31:0] data_rdata   ,
    input  wire        data_addr_ok ,
    input  wire        data_data_ok

  `ifdef SIMU_DEBUG
   ,output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_wen,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
  `endif
);

wire [31:0] fe_pc;
wire [ 6:0] fe_exc;
wire [31:0] fe_badvaddr;
wire [31:0] de_pc;
wire [31:0] de_inst;
wire [ 6:0] de_exc;
wire [31:0] de_badvaddr;
wire [31:0] exe_pc;
wire [31:0] exe_inst;
wire [ 6:0] exe_exc;
wire [31:0] exe_badvaddr;
wire [31:0] pm_pc;
wire [31:0] pm_inst;
wire [31:0] mem_pc;
wire [31:0] mem_inst;
wire [31:0] wb_pc;
wire [31:0] wb_inst;

wire        fe_valid;
wire        fe_allowin;
wire        fe_to_de_valid;
wire        de_valid;
wire        de_allowin;
wire        de_to_exe_valid;
wire        exe_valid;
wire        exe_allowin;
wire        exe_to_pm_valid;
wire        pm_valid;
wire        pm_allowin;
wire        pm_to_mem_valid;
wire        mem_valid;
wire        mem_allowin;
wire        mem_to_wb_valid;
wire        wb_valid;
wire        wb_allowin;

wire [32:0] mult_a;
wire [32:0] mult_b;
wire [65:0] mult_p;

wire        div_a_valid;
wire [39:0] div_a_data;
wire        div_a_ready;
wire        div_b_valid;
wire [39:0] div_b_data;
wire        div_b_ready;
wire        div_p_valid;
wire [79:0] div_p_data;

wire        ctrl_fe_wait;
wire        ctrl_fe_disable;
wire        ctrl_de_wait;
wire        ctrl_de_disable;
wire        ctrl_exe_wait;
wire        ctrl_exe_disable;
wire        ctrl_pm_wait;
wire        ctrl_pm_disable;
wire        ctrl_mem_wait;
wire        ctrl_mem_disable;
wire        ctrl_wb_wait;

wire [19:0] de_out_op;
wire [ 4:0] de_dest;
wire [31:0] de_vsrc1;
wire [31:0] de_vsrc2;
wire [ 4:0] de_vshift;
wire [31:0] de_st_value;
wire [31:0] de_nextpc;
wire        de_jmp;

wire [31:0] de_bsrc1;
wire [31:0] de_bsrc2;

wire [19:0] exe_out_op;
wire [ 4:0] exe_dest;
wire [31:0] exe_value;
wire [31:0] exe_ld_value;
wire        exe_br_taken;

wire [19:0] pm_out_op;
wire [ 4:0] pm_dest;
wire [31:0] pm_value;
wire [31:0] pm_ld_value;
wire [31:0] pm_rdata;

wire [19:0] mem_out_op;
wire [ 4:0] mem_dest;
wire [31:0] mem_value;

wire [19:0] wb_out_op;
wire [ 3:0] wb_rf_wen;
wire [ 4:0] wb_rf_waddr;
wire [31:0] wb_rf_wdata;

wire [ 4:0] ctrl_rf_raddr1;
wire [31:0] ctrl_rf_rdata1;
wire [ 4:0] ctrl_rf_raddr2;
wire [31:0] ctrl_rf_rdata2;
wire [31:0] ctrl_rdata1;
wire [31:0] ctrl_rdata2;
wire [31:0] ctrl_nextpc;

wire [31:0] rd_HI;
wire [31:0] rd_LO;
wire        we_HI;
wire [31:0] wd_HI;
wire        we_LO;
wire [31:0] wd_LO;

wire [31:0] rd_8_CP0;
wire [31:0] rd_9_CP0;
wire [31:0] rd_11_CP0;
wire [31:0] rd_12_CP0;
wire [31:0] rd_13_CP0;
wire [31:0] rd_14_CP0;

wire [31:0] we_CP0;
wire [31:0] wd_8_CP0;
wire [31:0] wd_9_CP0;
wire [31:0] wd_11_CP0;
wire [31:0] wd_12_CP0;
wire [31:0] wd_13_CP0;
wire [31:0] wd_14_CP0;

wire [31:0] rd_0_CP0;
wire [31:0] rd_1_CP0;
wire [31:0] rd_2_CP0;
wire [31:0] rd_3_CP0;
wire [31:0] rd_5_CP0;
wire [31:0] rd_10_CP0;

wire [31:0] wd_0_CP0;
wire [31:0] wd_2_CP0;
wire [31:0] wd_3_CP0;
wire [31:0] wd_5_CP0;
wire [31:0] wd_10_CP0;

wire        ResponseExc;
wire [31:0] ExcVector;
wire        ERET;
wire [31:0] EPC;

wire [31:0] inst_vaddr;
wire [31:0] inst_paddr;
wire [ 1:0] inst_ex;
wire [31:0] data_vaddr;
wire [31:0] data_paddr;
wire [ 1:0] data_ex;
wire [31:0] tlbp_index;
wire [89:0] tlbr_tlb;
wire        tlbwi;
wire        tlbwr;

assign inst_wr    = 1'b0;
assign inst_size  = 2'b10;
assign inst_wdata = 32'b0;

assign inst_addr  = inst_paddr;
assign data_addr  = data_paddr;

fetch_stage fe
    (
    .clk              (clk            ),
    .resetn           (resetn         ),

    .ctrl_nextpc      (ctrl_nextpc    ),
    .inst_req         (inst_req       ),
    .inst_addr        (inst_vaddr     ),
    .inst_ex          (inst_ex        ),
    .inst_addr_ok     (inst_addr_ok   ),

    .fe_pc            (fe_pc          ),
    .fe_exc           (fe_exc         ),
    .fe_badvaddr      (fe_badvaddr    ),

    .fe_valid         (fe_valid       ),
    .fe_allowin       (fe_allowin     ),
    .fe_to_de_valid   (fe_to_de_valid ),
    .de_allowin       (de_allowin     ),

    .ctrl_fe_wait     (ctrl_fe_wait   ),
    .ctrl_fe_disable  (ctrl_fe_disable)
    );

decode_stage de
    (
    .clk              (clk            ),
    .resetn           (resetn         ),

    .inst_rdata       (inst_rdata     ),
    .inst_data_ok     (inst_data_ok   ),

    .fe_pc            (fe_pc          ),
    .fe_exc           (fe_exc         ),
    .fe_badvaddr      (fe_badvaddr    ),
    .de_pc            (de_pc          ),
    .de_inst          (de_inst        ),
    .de_exc           (de_exc         ),
    .de_badvaddr      (de_badvaddr    ),

    .ctrl_rdata1      (ctrl_rdata1    ),
    .ctrl_rdata2      (ctrl_rdata2    ),

    .de_out_op        (de_out_op      ),
    .de_dest          (de_dest        ),
    .de_vsrc1         (de_vsrc1       ),
    .de_vsrc2         (de_vsrc2       ),
    .de_vshift        (de_vshift      ),
    .de_st_value      (de_st_value    ),
    .de_nextpc        (de_nextpc      ),
    .de_jmp           (de_jmp         ),

    .de_bsrc1         (de_bsrc1       ),
    .de_bsrc2         (de_bsrc2       ),

    .de_valid         (de_valid       ),
    .fe_to_de_valid   (fe_to_de_valid ),
    .de_allowin       (de_allowin     ),
    .de_to_exe_valid  (de_to_exe_valid),
    .exe_allowin      (exe_allowin    ),

    .ctrl_de_wait     (ctrl_de_wait   ),
    .ctrl_de_disable  (ctrl_de_disable)
    );

execute_stage exe(
    .clk              (clk             ),
    .resetn           (resetn          ),

    .de_pc            (de_pc           ),
    .de_inst          (de_inst         ),
    .de_exc           (de_exc          ),
    .de_badvaddr      (de_badvaddr     ),
    .exe_pc           (exe_pc          ),
    .exe_inst         (exe_inst        ),
    .exe_exc          (exe_exc         ),
    .exe_badvaddr     (exe_badvaddr    ),


    .de_out_op        (de_out_op       ),
    .de_dest          (de_dest         ),
    .de_vsrc1         (de_vsrc1        ),
    .de_vsrc2         (de_vsrc2        ),
    .de_vshift        (de_vshift       ),
    .de_st_value      (de_st_value     ),

    .de_bsrc1         (de_bsrc1        ),
    .de_bsrc2         (de_bsrc2        ),

    .exe_out_op       (exe_out_op      ),
    .exe_dest         (exe_dest        ),
    .exe_value        (exe_value       ),

    .exe_ld_value     (exe_ld_value    ),
    .exe_br_taken     (exe_br_taken    ),

    .data_req         (data_req        ),
    .data_wr          (data_wr         ),
    .data_size        (data_size       ),
    .data_addr        (data_vaddr      ),
    .data_ex          (data_ex         ),
    .data_wdata       (data_wdata      ),
    .data_addr_ok     (data_addr_ok    ),

    .exe_valid        (exe_valid       ),
    .de_to_exe_valid  (de_to_exe_valid ),
    .exe_allowin      (exe_allowin     ),
    .exe_to_pm_valid  (exe_to_pm_valid ),
    .pm_allowin       (pm_allowin      ),

    .ctrl_exe_wait    (ctrl_exe_wait   ),
    .ctrl_exe_disable (ctrl_exe_disable)
    );

prememory_stage pm
    (
    .clk              (clk            ),
    .resetn           (resetn         ),

    .exe_pc           (exe_pc         ),
    .exe_inst         (exe_inst       ),
    .pm_pc            (pm_pc          ),
    .pm_inst          (pm_inst        ),

    .exe_out_op       (exe_out_op     ),
    .exe_dest         (exe_dest       ),
    .exe_exc          (exe_exc        ),
    .exe_badvaddr     (exe_badvaddr   ),
    .exe_value        (exe_value      ),
    .exe_ld_value     (exe_ld_value   ),

    .data_rdata       (data_rdata     ),
    .data_data_ok     (data_data_ok   ),
    .pm_rdata         (pm_rdata       ),

    .pm_out_op        (pm_out_op      ),
    .pm_dest          (pm_dest        ),
    .pm_value         (pm_value       ),
    .pm_ld_value      (pm_ld_value    ),

    .rd_8_CP0         (rd_8_CP0       ),
    .rd_9_CP0         (rd_9_CP0       ),
    .rd_11_CP0        (rd_11_CP0      ),
    .rd_12_CP0        (rd_12_CP0      ),
    .rd_13_CP0        (rd_13_CP0      ),
    .rd_14_CP0        (rd_14_CP0      ),
    .we_CP0           (we_CP0         ),
    .wd_8_CP0         (wd_8_CP0       ),
    .wd_9_CP0         (wd_9_CP0       ),
    .wd_11_CP0        (wd_11_CP0      ),
    .wd_12_CP0        (wd_12_CP0      ),
    .wd_13_CP0        (wd_13_CP0      ),
    .wd_14_CP0        (wd_14_CP0      ),

    .rd_0_CP0         (rd_0_CP0       ),
    .rd_1_CP0         (rd_1_CP0       ),
    .rd_2_CP0         (rd_2_CP0       ),
    .rd_3_CP0         (rd_3_CP0       ),
    .rd_5_CP0         (rd_5_CP0       ),
    .rd_10_CP0        (rd_10_CP0      ),

    .wd_0_CP0         (wd_0_CP0       ),
    .wd_2_CP0         (wd_2_CP0       ),
    .wd_3_CP0         (wd_3_CP0       ),
    .wd_5_CP0         (wd_5_CP0       ),
    .wd_10_CP0        (wd_10_CP0      ),

    .ResponseExc      (ResponseExc    ),
    .ExcVector        (ExcVector      ),
    .ERET             (ERET           ),
    .EPC              (EPC            ),
    .int_n_i          (int_n_i        ),

    .tlbp_index       (tlbp_index     ),
    .tlbr_tlb         (tlbr_tlb       ),
    .tlbwi            (tlbwi          ),
    .tlbwr            (tlbwr          ),

    .pm_valid         (pm_valid       ),
    .exe_to_pm_valid  (exe_to_pm_valid),
    .pm_allowin       (pm_allowin     ),
    .pm_to_mem_valid  (pm_to_mem_valid),
    .mem_allowin      (mem_allowin    ),

    .ctrl_pm_wait     (ctrl_pm_wait   ),
    .ctrl_pm_disable  (ctrl_pm_disable)
    );

memory_stage mem
    (
    .clk              (clk             ),
    .resetn           (resetn          ),

    .pm_pc            (pm_pc           ),
    .pm_inst          (pm_inst         ),
    .mem_pc           (mem_pc          ),
    .mem_inst         (mem_inst        ),

    .pm_out_op        (pm_out_op       ),
    .pm_dest          (pm_dest         ),
    .pm_value         (pm_value        ),
    .pm_ld_value      (pm_ld_value     ),

//    .data_sram_rdata  (data_sram_rdata ),
    .pm_rdata         (pm_rdata        ),

    .mem_out_op       (mem_out_op      ),
    .mem_dest         (mem_dest        ),
    .mem_value        (mem_value       ),

    .mem_valid        (mem_valid       ),
    .pm_to_mem_valid  (pm_to_mem_valid ),
    .mem_allowin      (mem_allowin     ),
    .mem_to_wb_valid  (mem_to_wb_valid ),
    .wb_allowin       (wb_allowin      ),

    .ctrl_mem_wait    (ctrl_mem_wait   ),
    .ctrl_mem_disable (ctrl_mem_disable)
    );

writeback_stage wb
    (
    .clk              (clk             ),
    .resetn           (resetn          ),

    .mem_pc           (mem_pc          ),
    .mem_inst         (mem_inst        ),
    .wb_pc            (wb_pc           ),
    .wb_inst          (wb_inst         ),

    .mem_out_op       (mem_out_op      ),
    .mem_dest         (mem_dest        ),
    .mem_value        (mem_value       ),

    .wb_out_op        (wb_out_op       ),
    .wb_rf_wen        (wb_rf_wen       ),
    .wb_rf_waddr      (wb_rf_waddr     ),
    .wb_rf_wdata      (wb_rf_wdata     ),

    .wb_valid         (wb_valid        ),
    .mem_to_wb_valid  (mem_to_wb_valid ),
    .wb_allowin       (wb_allowin      ),

    .ctrl_wb_wait     (ctrl_wb_wait    ),

    .we_HI            (we_HI           ),
    .wd_HI            (wd_HI           ),
    .we_LO            (we_LO           ),
    .wd_LO            (wd_LO           ),

    .mult_p           (mult_p          ),

    .div_p_valid      (div_p_valid     ),
    .div_p_data       (div_p_data      )
    );

controller ctrl
    (
    .clk              (clk             ),
    .resetn           (resetn          ),

    .de_valid         (de_valid        ),
    .ctrl_pc          (de_pc           ),
    .ctrl_inst        (de_inst         ),
    .ctrl_op          (de_out_op       ),
    .exe_valid        (exe_valid       ),
    .exe_op           (exe_out_op      ),
    .exe_dest         (exe_dest        ),
    .pm_valid         (pm_valid        ),
    .pm_op            (pm_out_op       ),
    .pm_dest          (pm_dest         ),
    .mem_valid        (mem_valid       ),
    .mem_op           (mem_out_op      ),
    .mem_dest         (mem_dest        ),
    .wb_valid         (wb_valid        ),
    .wb_op            (wb_out_op       ),
    .wb_dest          (wb_rf_waddr     ),

    .ctrl_rf_raddr1   (ctrl_rf_raddr1  ),
    .ctrl_rf_rdata1   (ctrl_rf_rdata1  ),
    .ctrl_rf_raddr2   (ctrl_rf_raddr2  ),
    .ctrl_rf_rdata2   (ctrl_rf_rdata2  ),

    .exe_value        (exe_value       ),
    .pm_value         (pm_value        ),
    .mem_value        (mem_value       ),
    .wb_value         (wb_rf_wdata     ),

    .ctrl_rdata1      (ctrl_rdata1     ),
    .ctrl_rdata2      (ctrl_rdata2     ),

    .rd_HI            (rd_HI           ),
    .rd_LO            (rd_LO           ),
    .wd_HI            (wd_HI           ),
    .wd_LO            (wd_LO           ),

    .mult_a           (mult_a          ),
    .mult_b           (mult_b          ),

    .div_a_valid      (div_a_valid     ),
    .div_a_data       (div_a_data      ),
    .div_a_ready      (div_a_ready     ),
    .div_b_valid      (div_b_valid     ),
    .div_b_data       (div_b_data      ),
    .div_b_ready      (div_b_ready     ),
    .div_p_valid      (div_p_valid     ),

    .ctrl_fe_wait     (ctrl_fe_wait    ),
    .ctrl_fe_disable  (ctrl_fe_disable ),
    .ctrl_de_wait     (ctrl_de_wait    ),
    .ctrl_de_disable  (ctrl_de_disable ),
    .ctrl_exe_wait    (ctrl_exe_wait   ),
    .ctrl_exe_disable (ctrl_exe_disable),
    .ctrl_pm_wait     (ctrl_pm_wait    ),
    .ctrl_pm_disable  (ctrl_pm_disable ),
    .ctrl_mem_wait    (ctrl_mem_wait   ),
    .ctrl_mem_disable (ctrl_mem_disable),
    .ctrl_wb_wait     (ctrl_wb_wait    ),

    .de_nextpc        (de_nextpc       ),
    .de_jmp           (de_jmp          ),
    .exe_br_taken     (exe_br_taken    ),
    .fe_valid         (fe_valid        ),
    .fe_pc            (fe_pc           ),
    .fe_allowin       (fe_allowin      ),
    .ctrl_nextpc      (ctrl_nextpc     ),

    .ResponseExc      (ResponseExc     ),
    .ExcVector        (ExcVector       ),
    .ERET             (ERET            ),
    .EPC              (EPC             ),

    .de_to_exe_valid  (de_to_exe_valid )
    );

regfile_2r1w reg_general
    (
    .clk              (clk           ),

    .ra1              (ctrl_rf_raddr1),
    .rd1              (ctrl_rf_rdata1),

    .ra2              (ctrl_rf_raddr2),
    .rd2              (ctrl_rf_rdata2),

    .we1              (|wb_rf_wen    ),
    .wa1              (wb_rf_waddr   ),
    .wd1              (wb_rf_wdata   )
    );

reg_HILO reg_HILO
    (
    .clk              (clk             ),

    .rd_HI            (rd_HI           ),
    .rd_LO            (rd_LO           ),

    .we_HI            (we_HI           ),
    .wd_HI            (wd_HI           ),
    .we_LO            (we_LO           ),
    .wd_LO            (wd_LO           )
    );

reg_CP0 reg_CP0
    (
    .clk              (clk             ),
    .resetn           (resetn          ),

    .rd_8             (rd_8_CP0        ),
    .rd_9             (rd_9_CP0        ),
    .rd_11            (rd_11_CP0       ),
    .rd_12            (rd_12_CP0       ),
    .rd_13            (rd_13_CP0       ),
    .rd_14            (rd_14_CP0       ),

    .we               (we_CP0          ),
    .wd_8             (wd_8_CP0        ),
    .wd_9             (wd_9_CP0        ),
    .wd_11            (wd_11_CP0       ),
    .wd_12            (wd_12_CP0       ),
    .wd_13            (wd_13_CP0       ),
    .wd_14            (wd_14_CP0       ),

    .rd_0             (rd_0_CP0        ),
    .rd_1             (rd_1_CP0        ),
    .rd_2             (rd_2_CP0        ),
    .rd_3             (rd_3_CP0        ),
    .rd_5             (rd_5_CP0        ),
    .rd_10            (rd_10_CP0       ),

    .wd_0             (wd_0_CP0        ),
    .wd_2             (wd_2_CP0        ),
    .wd_3             (wd_3_CP0        ),
    .wd_5             (wd_5_CP0        ),
    .wd_10            (wd_10_CP0       )
    );

mult_ip mult
    (
    .CLK              (clk             ),
    .A                (mult_a          ),
    .B                (mult_b          ),
    .P                (mult_p          )
    );

div_ip div
    (
    .aclk                   (clk         ),

    .s_axis_dividend_tvalid (div_a_valid ),
    .s_axis_dividend_tdata  (div_a_data  ),
    .s_axis_dividend_tready (div_a_ready ),

    .s_axis_divisor_tvalid  (div_b_valid ),
    .s_axis_divisor_tdata   (div_b_data  ),
    .s_axis_divisor_tready  (div_b_ready ),

    .m_axis_dout_tvalid     (div_p_valid ),
    .m_axis_dout_tdata      (div_p_data  )
    );

TLB TLB (
    .clk          ( clk          ),
    .inst_vaddr   ( inst_vaddr   ),
    .inst_paddr   ( inst_paddr   ),
    .inst_ex      ( inst_ex      ),
    .data_vaddr   ( data_vaddr   ),
    .data_paddr   ( data_paddr   ),
    .data_ex      ( data_ex      ),
    .cp0_index    ( rd_0_CP0     ),
    .cp0_entryhi  ( rd_10_CP0    ),
    .cp0_pagemask ( rd_5_CP0     ),
    .cp0_entrylo0 ( rd_2_CP0     ),
    .cp0_entrylo1 ( rd_3_CP0     ),
    .cp0_random   ( rd_1_CP0     ),
    .tlbp_index   ( tlbp_index   ),
    .tlbr_tlb     ( tlbr_tlb     ),
    .tlbwi        ( tlbwi        ),
    .tlbwr        ( tlbwr        )
);

`ifdef SIMU_DEBUG
assign debug_wb_pc       = wb_pc;
assign debug_wb_rf_wen   = wb_rf_wen;
assign debug_wb_rf_wnum  = wb_rf_waddr;
assign debug_wb_rf_wdata = wb_rf_wdata;
`endif

endmodule

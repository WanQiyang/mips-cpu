module cpu_axi_interface (
    input wire         clk          ,
    input wire         resetn       ,

    //inst sram-like
    input  wire        inst_req     ,
    input  wire        inst_wr      ,
    input  wire [ 2:0] inst_size    ,
    input  wire [31:0] inst_addr    ,
    input  wire [31:0] inst_wdata   ,
    output reg  [31:0] inst_rdata   ,
    output wire        inst_addr_ok ,
    output wire        inst_data_ok ,

    //data sram-like
    input  wire        data_req     ,
    input  wire        data_wr      ,
    input  wire [ 2:0] data_size    ,
    input  wire [31:0] data_addr    ,
    input  wire [31:0] data_wdata   ,
    output reg  [31:0] data_rdata   ,
    output wire        data_addr_ok ,
    output wire        data_data_ok ,

    //axi
    //ar
    output wire [ 3:0] arid         ,
    output wire [31:0] araddr       ,
    output wire [ 7:0] arlen        ,
    output wire [ 2:0] arsize       ,
    output wire [ 1:0] arburst      ,
    output wire [ 1:0] arlock       ,
    output wire [ 3:0] arcache      ,
    output wire [ 2:0] arprot       ,
    output wire        arvalid      ,
    input  wire        arready      ,
    //r
    input  wire [ 3:0] rid          ,
    input  wire [31:0] rdata        ,
    input  wire [ 1:0] rresp        ,
    input  wire        rlast        ,
    input  wire        rvalid       ,
    output wire        rready       ,
    //aw
    output wire [ 3:0] awid         ,
    output wire [31:0] awaddr       ,
    output wire [ 7:0] awlen        ,
    output wire [ 2:0] awsize       ,
    output wire [ 1:0] awburst      ,
    output wire [ 1:0] awlock       ,
    output wire [ 3:0] awcache      ,
    output wire [ 2:0] awprot       ,
    output wire        awvalid      ,
    input  wire        awready      ,
    //w
    output wire [ 3:0] wid          ,
    output wire [31:0] wdata        ,
    output reg  [ 3:0] wstrb        ,
    output wire        wlast        ,
    output wire        wvalid       ,
    input  wire        wready       ,
    //b
    input  wire [ 3:0] bid          ,
    input  wire [ 1:0] bresp        ,
    input  wire        bvalid       ,
    output wire        bready
);

reg  [ 1:0] r_status; // 0-free 1-read_req 2-reading 3-read_fin
reg         r_from;   // 0-inst 1-data
reg  [ 2:0] r_size;
reg  [31:0] r_addr;

reg  [ 1:0] w_status; // 0-free 1-write_req 2-writing 3-write_fin
reg         w_from;   // 0-inst 1-data
reg  [ 2:0] w_size;
reg  [31:0] w_addr;
reg  [31:0] w_data;

reg         wr_hazard;
reg         rw_hazard;
reg         en_arvalid;
reg         en_awvalid;
reg         en_wvalid;

always @(posedge clk) begin
    if(!resetn) begin
        r_status     <= 2'd0;
        r_from       <= 1'b0;
        r_size       <= 3'd0;
        r_addr       <= 32'd0;
        en_arvalid   <= 1'b0;
        wr_hazard    <= 1'b0;

    end else begin
        if(r_status == 2'b00) begin
            if(data_req && !data_wr) begin
                r_status     <= 2'b01;
                r_from       <= 1'b1;
            end else if(inst_req && !inst_wr) begin
                r_status     <= 2'b01;
                r_from       <= 1'b0;
            end

        end else if(r_status == 2'b01) begin
            if(r_from && data_addr_ok && !en_arvalid) begin
                r_size       <= data_size;
                r_addr       <= data_addr;
                en_arvalid   <= 1'b1;
                wr_hazard    <= ^w_status && data_addr[31:2] == w_addr[31:2];
            end else if(!r_from && inst_addr_ok && !en_arvalid) begin
                r_size       <= inst_size;
                r_addr       <= inst_addr;
                en_arvalid   <= 1'b1;
                wr_hazard    <= ^w_status && inst_addr[31:2] == w_addr[31:2];
            end
            if(r_from && wr_hazard) begin
                wr_hazard    <= ^w_status;
            end else if(!r_from && wr_hazard) begin
                wr_hazard    <= ^w_status;
            end
            if(arvalid && arready) begin
                en_arvalid   <= 1'b0;
                r_status     <= 2'b10;
            end

        end else if(r_status == 2'b10) begin
            if(rvalid && r_from) begin
                r_status     <= 2'b11;
                data_rdata   <= rdata;
            end else if(rvalid && !r_from) begin
                r_status     <= 2'b11;
                inst_rdata   <= rdata;
            end

        end else if(r_status == 2'b11) begin
            if(r_from != w_from || w_status != 2'b11) begin
                r_status         <= 2'b00;
            end
        end
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        w_status     <= 2'd0;
        w_from       <= 1'b0;
        w_size       <= 3'd0;
        w_addr       <= 32'd0;
        w_data       <= 32'd0;
        en_awvalid   <= 1'b0;
        en_wvalid    <= 1'b0;
        rw_hazard    <= 1'b0;

    end else begin
        if(w_status == 2'b00) begin
            if(data_req && data_wr) begin
                w_status     <= 2'b01;
                w_from       <= 1'b1;
            end else if(inst_req && inst_wr) begin
                w_status     <= 2'b01;
                w_from       <= 1'b0;
            end

        end else if(w_status == 2'b01) begin
            if(w_from && data_addr_ok && !en_awvalid && !en_wvalid) begin
                w_size       <= data_size;
                w_addr       <= data_addr;
                w_data       <= data_wdata;
                en_awvalid   <= 1'b1;
                en_wvalid    <= 1'b1;
                rw_hazard    <= ^r_status && data_addr[31:2] == r_addr[31:2];
            end else if(!w_from && inst_addr_ok && !en_awvalid && !en_wvalid) begin
                w_size       <= inst_size;
                w_addr       <= inst_addr;
                w_data       <= inst_wdata;
                en_awvalid   <= 1'b1;
                en_wvalid    <= 1'b1;
                rw_hazard    <= ^r_status && inst_addr[31:2] == r_addr[31:2];
            end
            if(w_from && rw_hazard) begin
                rw_hazard    <= ^r_status;
            end else if(!w_from && rw_hazard) begin
                rw_hazard    <= ^r_status;
            end
            if(awvalid && awready) begin
                en_awvalid   <= 1'b0;
            end
            if(wvalid && wready) begin
                en_wvalid    <= 1'b0;
            end
            if((awvalid && awready && wvalid && wready) || (awvalid && awready && !wvalid) || (wvalid && wready && !awvalid)) begin
                w_status     <= 2'b10;
            end

        end else if(w_status == 2'b10) begin
            if(bvalid && w_from) begin
                w_status     <= 2'b11;
            end else if(bvalid && !w_from) begin
                w_status     <= 2'b11;
            end

        end else if(w_status == 2'b11) begin
            w_status         <= 2'b00;
        end
    end
end

always @(*) begin
    case({w_size, w_addr[1:0]})
    5'b000_00: wstrb = 4'b0001; // SB
    5'b000_01: wstrb = 4'b0010; // SB
    5'b000_10: wstrb = 4'b0100; // SB
    5'b000_11: wstrb = 4'b1000; // SB
    5'b001_00: wstrb = 4'b0011; // SH
    5'b001_10: wstrb = 4'b1100; // SH
    5'b010_00: wstrb = 4'b1111; // SW
    5'b100_00: wstrb = 4'b0001; // SWL
    5'b100_01: wstrb = 4'b0011; // SWL
    5'b100_10: wstrb = 4'b0111; // SWL
    5'b100_11: wstrb = 4'b1111; // SWL
    5'b101_00: wstrb = 4'b1111; // SWR
    5'b101_01: wstrb = 4'b1110; // SWR
    5'b101_10: wstrb = 4'b1100; // SWR
    5'b101_11: wstrb = 4'b1000; // SWR
    default :  wstrb = 4'b0000;
    endcase
end

assign inst_addr_ok = (r_status == 2'b01 && r_from == 1'b0 && arvalid == 1'b0 && !wr_hazard) ||
                      (w_status == 2'b01 && w_from == 1'b0 && awvalid == 1'b0 && wvalid == 1'b0 && !rw_hazard);

assign inst_data_ok = (r_status == 2'b11 && r_from == 1'b0) ||
                      (w_status == 2'b11 && w_from == 1'b0) ;

assign data_addr_ok = (r_status == 2'b01 && r_from == 1'b1 && arvalid == 1'b0 && !wr_hazard) ||
                      (w_status == 2'b01 && w_from == 1'b1 && awvalid == 1'b0 && wvalid == 1'b0 && !rw_hazard);

assign data_data_ok = (r_status == 2'b11 && r_from == 1'b1) ||
                      (w_status == 2'b11 && w_from == 1'b1) ;

assign araddr  = r_addr;
assign arsize  = {1'b0, r_size[2] ? 2'b10 : r_size[1:0]};
assign arvalid = en_arvalid && !wr_hazard;
assign rready  = (r_status == 2'b10);

assign awaddr  = w_addr;
assign awsize  = {1'b0, w_size[2] ? 2'b10 : w_size[1:0]};
assign wdata   = w_data;
assign awvalid = en_awvalid && !rw_hazard;
assign wvalid  = en_wvalid  && !rw_hazard;
assign bready  = (w_status == 2'b10);

assign arid    = 4'd0 ;
assign arlen   = 8'd0 ;
assign arburst = 2'b01;
assign arlock  = 2'd0 ;
assign arcache = 4'd0 ;
assign arprot  = 3'd0 ;

assign awid    = 4'd0 ;
assign awlen   = 8'd0 ;
assign awburst = 2'b01;
assign awlock  = 2'd0 ;
assign awcache = 4'd0 ;
assign awprot  = 3'd0 ;

assign wid     = 4'd0 ;
assign wlast   = 1'b1 ;

endmodule

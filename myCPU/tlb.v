
module TLB (
    input  wire        clk,
    input  wire [31:0] inst_vaddr,
    output wire [31:0] inst_paddr,
    output wire [ 1:0] inst_ex, // 0-normal 1-refill 2-invalid 3-modified
    input  wire [31:0] data_vaddr,
    output wire [31:0] data_paddr,
    output wire [ 1:0] data_ex, // 0-normal 1-refill 2-invalid 3-modified
    input  wire [31:0] cp0_index,
    input  wire [31:0] cp0_entryhi,
    input  wire [31:0] cp0_pagemask,
    input  wire [31:0] cp0_entrylo0,
    input  wire [31:0] cp0_entrylo1,
    input  wire [31:0] cp0_random,
    output wire [31:0] tlbp_index,
    output wire [89:0] tlbr_tlb,
    input  wire        tlbwi,
    input  wire        tlbwr
);
    reg  [89:0] heap [31:0];

    wire [89:0] cp0_tlb;
    assign cp0_tlb = {cp0_entryhi[31:13], cp0_entryhi[7:0], cp0_pagemask[24:13], cp0_entrylo0[0]
                    & cp0_entrylo1[0], cp0_entrylo0[25:1], cp0_entrylo1[25:1]};

    always @(posedge clk) begin
        if(tlbwi) begin
            heap[cp0_index[4:0]]  <= cp0_tlb;
        end
        if(tlbwr) begin
            heap[cp0_random[4:0]] <= cp0_tlb;
        end
    end

    genvar i;

    wire [31:0] inst_found;
    wire [ 4:0] inst_index;
    wire [89:0] inst_tlb;
    wire [19:0] inst_pfn;
    wire [31:0] data_found;
    wire [ 4:0] data_index;
    wire [89:0] data_tlb;
    wire [19:0] data_pfn;
    wire [31:0] tlbp_found;

    generate
    for(i=0;i<32;i=i+1)
    begin: inst_f
        assign inst_found[i] = ((heap[i][89:71] & ~{7'd0, heap[i][62:51]}) == (inst_vaddr[31:13] & ~{7'd0, heap[i][62:51]}))
                            && (heap[i][50] || heap[i][70:63] == cp0_entryhi[7:0]);
    end
    endgenerate

    encoder inst_encoder (.in(inst_found), .out(inst_index));
    assign  inst_tlb   = heap[inst_index];
    assign  inst_pfn   = inst_vaddr[12] ? inst_tlb[24:5] : inst_tlb[49:30];
    assign  inst_paddr = !inst_vaddr[31] ? {inst_pfn, inst_vaddr[11:0]} :
                         !inst_vaddr[30] ? {3'd0, inst_vaddr[28:0]} :
                         inst_vaddr ;
    assign  inst_ex    = inst_vaddr[31] ? 2'd0 :
                         (!(|inst_found)) ? 2'd1 :
                         (inst_vaddr[12] && !inst_tlb[0] || ~inst_vaddr[12] && !inst_tlb[25]) ? 2'd2 :
                         (inst_vaddr[12] && !inst_tlb[1] || ~inst_vaddr[12] && !inst_tlb[26]) ? 2'd3 :
                         2'd0;

    generate
    for(i=0;i<32;i=i+1)
    begin: data_f
        assign data_found[i] = ((heap[i][89:71] & ~{7'd0, heap[i][62:51]}) == (data_vaddr[31:13] & ~{7'd0, heap[i][62:51]}))
                            && (heap[i][50] || heap[i][70:63] == cp0_entryhi[7:0]);
    end
    endgenerate

    encoder data_encoder (.in(data_found), .out(data_index));
    assign  data_tlb   = heap[data_index];
    assign  data_pfn   = data_vaddr[12] ? data_tlb[24:5] : data_tlb[49:30];
    assign  data_paddr = !data_vaddr[31] ? {data_pfn, data_vaddr[11:0]} :
                         !data_vaddr[30] ? {3'd0, data_vaddr[28:0]} :
                         data_vaddr ;
    assign  data_ex    = data_vaddr[31] ? 2'd0 :
                         (!(|data_found)) ? 2'd1 :
                         (data_vaddr[12] && !data_tlb[0] || ~data_vaddr[12] && !data_tlb[25]) ? 2'd2 :
                         (data_vaddr[12] && !data_tlb[1] || ~data_vaddr[12] && !data_tlb[26]) ? 2'd3 :
                         2'd0;

    generate
    for(i=0;i<32;i=i+1)
    begin: tlbp
        assign tlbp_found[i] = ((heap[i][89:71] & ~{7'd0, heap[i][62:51]}) == (cp0_entryhi[31:13] & ~cp0_pagemask[31:13]))
                            && (heap[i][50] || heap[i][70:63] == cp0_entryhi[7:0]);
    end
    endgenerate

    encoder tlbp_encoder (.in(tlbp_found), .out(tlbp_index[4:0]));
    assign  tlbp_index[31:5] = {~|tlbp_found, 26'd0};
    assign  tlbr_tlb         = heap[cp0_index[4:0]];

endmodule

module encoder(
    input  wire [31:0] in,
    output reg  [ 4:0] out
);
    always @(*) begin
        case(in)
        32'h8000_0000: out = 5'd31;
        32'h4000_0000: out = 5'd30;
        32'h2000_0000: out = 5'd29;
        32'h1000_0000: out = 5'd28;
        32'h0800_0000: out = 5'd27;
        32'h0400_0000: out = 5'd26;
        32'h0200_0000: out = 5'd25;
        32'h0100_0000: out = 5'd24;
        32'h0080_0000: out = 5'd23;
        32'h0040_0000: out = 5'd22;
        32'h0020_0000: out = 5'd21;
        32'h0010_0000: out = 5'd20;
        32'h0008_0000: out = 5'd19;
        32'h0004_0000: out = 5'd18;
        32'h0002_0000: out = 5'd17;
        32'h0001_0000: out = 5'd16;
        32'h0000_8000: out = 5'd15;
        32'h0000_4000: out = 5'd14;
        32'h0000_2000: out = 5'd13;
        32'h0000_1000: out = 5'd12;
        32'h0000_0800: out = 5'd11;
        32'h0000_0400: out = 5'd10;
        32'h0000_0200: out = 5'd9 ;
        32'h0000_0100: out = 5'd8 ;
        32'h0000_0080: out = 5'd7 ;
        32'h0000_0040: out = 5'd6 ;
        32'h0000_0020: out = 5'd5 ;
        32'h0000_0010: out = 5'd4 ;
        32'h0000_0008: out = 5'd3 ;
        32'h0000_0004: out = 5'd2 ;
        32'h0000_0002: out = 5'd1 ;
        32'h0000_0001: out = 5'd0 ;
        default      : out = 5'd0 ;
        endcase
    end
endmodule

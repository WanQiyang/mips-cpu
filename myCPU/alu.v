
module alu(
  input  wire [ 3:0] aluop,
  input  wire [31:0] vsrc1,
  input  wire [31:0] vsrc2,
  input  wire [ 4:0] vshift,
  output wire [31:0] result,
  output wire        overflow
);

wire alu_add;
wire alu_sub;
wire alu_slt;
wire alu_sltu;
wire alu_and;
wire alu_nor;
wire alu_or;
wire alu_xor;
wire alu_sll;
wire alu_srl;
wire alu_sra;
wire alu_lui;

assign alu_add  = (aluop == 4'b0000) ? 1'b1 : 1'b0;
assign alu_sub  = (aluop == 4'b0001) ? 1'b1 : 1'b0;
assign alu_slt  = (aluop == 4'b0010) ? 1'b1 : 1'b0;
assign alu_sltu = (aluop == 4'b0011) ? 1'b1 : 1'b0;
assign alu_and  = (aluop == 4'b0100) ? 1'b1 : 1'b0;
assign alu_nor  = (aluop == 4'b0101) ? 1'b1 : 1'b0;
assign alu_or   = (aluop == 4'b0110) ? 1'b1 : 1'b0;
assign alu_xor  = (aluop == 4'b0111) ? 1'b1 : 1'b0;
assign alu_sll  = (aluop == 4'b1000) ? 1'b1 : 1'b0;
assign alu_srl  = (aluop == 4'b1001) ? 1'b1 : 1'b0;
assign alu_sra  = (aluop == 4'b1010) ? 1'b1 : 1'b0;
assign alu_lui  = (aluop == 4'b1011) ? 1'b1 : 1'b0;

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] sll_result;
wire [31:0] sr_result;
wire [31:0] lui_result;
wire [63:0] sr64_result;

assign and_result = vsrc1 & vsrc2;
assign or_result  = vsrc1 | vsrc2;
assign nor_result = ~or_result;
assign xor_result = vsrc1 ^ vsrc2;
assign lui_result = {vsrc2[15:0], 16'd0};

wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [32:0] adder_result;
wire        adder_cout;

assign adder_a   = vsrc1;
assign adder_b   = vsrc2 ^ {32{alu_sub | alu_slt | alu_sltu}};
assign adder_cin = alu_sub | alu_slt | alu_sltu;
assign {adder_cout, adder_result} = {adder_a[31], adder_a} + {adder_b[31], adder_b} + {32'd0, adder_cin};

assign add_sub_result = adder_result[31:0];

assign slt_result[31:1] = 31'd0;
assign slt_result[0]    = (vsrc1[31] & ~vsrc2[31])
                        | (~(vsrc1[31] ^ vsrc2[31]) & adder_result[31]);

assign sltu_result[31:1] = 31'd0;
assign sltu_result[0]    = ~adder_cout;

assign sll_result = vsrc2 << vshift;

assign sr64_result = {{32{alu_sra & vsrc2[31]}}, vsrc2[31:0]} >> vshift;
assign sr_result   = sr64_result[31:0];

assign result = ({32{alu_add | alu_sub}} & add_sub_result)
              | ({32{alu_slt          }} & slt_result    )
              | ({32{alu_sltu         }} & sltu_result   )
              | ({32{alu_and          }} & and_result    )
              | ({32{alu_nor          }} & nor_result    )
              | ({32{alu_or           }} & or_result     )
              | ({32{alu_xor          }} & xor_result    )
              | ({32{alu_sll          }} & sll_result    )
              | ({32{alu_srl | alu_sra}} & sr_result     )
              | ({32{alu_lui          }} & lui_result    );

assign overflow = (alu_add | alu_sub) & (adder_result[32] ^ adder_result[31]);

endmodule

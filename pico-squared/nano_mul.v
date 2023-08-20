// nanoV style mul instruction for PicoRV32
// This is a 32x16 MUL using the standard MUL opcode

module picorv32_pcpi_nanoV_mul (
	input clk, resetn,

	input             pcpi_valid,
	input      [31:0] pcpi_insn,
	input      [31:0] pcpi_rs1,
	input      [31:0] pcpi_rs2,
	output            pcpi_wr,
	output     [31:0] pcpi_rd,
	output            pcpi_wait,
	output            pcpi_ready
);
	wire pcpi_insn_valid = pcpi_valid && pcpi_insn[6:0] == 7'b0110011 && pcpi_insn[31:25] == 7'b0000001 && pcpi_insn[14:12] == 3'b000;
    reg active;
    reg [31:0] rd;

	always @(posedge clk) begin
        if (!resetn) begin
            active <= 0;
        end else begin
            if (active)
                active <= 0;
            else if (pcpi_insn_valid)
                active <= 1;
        end
	end

    always @(posedge clk) begin
        rd <= pcpi_rs1 * pcpi_rs2[15:0];
    end

	assign pcpi_wr = active;
	assign pcpi_wait = 0;
	assign pcpi_ready = active;
	assign pcpi_rd = rd;
endmodule
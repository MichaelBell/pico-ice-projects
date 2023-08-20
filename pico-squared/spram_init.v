module spram_init(
    input clk,
    input rstn,

    // External SPI interface
    input  spi_miso,
    output spi_select,
    output spi_clk_out,
    output spi_mosi,

    // SPRAM write interface
	output reg [3:0] spram_we,
	output [15:0] spram_addr,
	output [31:0] spram_wdat,

    // Finished
    output reg done
);

    reg [23:0] spi_addr;
    wire [31:0] spi_data_out;
    wire spi_busy;
    reg spi_start_read;
    reg reading;

    spi_ram_controller #(.ADDR_BITS(24)) i_spi(
        .clk(clk),
        .rstn(rstn),
        .spi_miso(spi_miso),
        .spi_select(spi_select),
        .spi_clk_out(spi_clk_out),
        .spi_mosi(spi_mosi),

        .addr_in(spi_addr),
        .data_in(32'd0),
        .start_read(spi_start_read),
        .start_write(1'b0),
        .data_out(spi_data_out),
        .busy(spi_busy)
    );

    wire [16:0] next_spi_addr = {1'b0, spi_addr[15:0]} + 4;

    always @(posedge clk) begin
        if (!rstn) begin
            spram_we <= 0;
            spi_addr <= 0;
            spi_start_read <= 0;
            reading <= 0;
            done <= 0;
        end else if (!done) begin
            if (spram_we[0]) begin
                spram_we <= 0;
                {done, spi_addr[13:0]} <= next_spi_addr[14:0];
            end else if (!reading && !spi_busy) begin
                spi_start_read <= 1;
                reading <= 1;
            end else if (spi_start_read) begin
                spi_start_read <= !spi_busy;
            end else if (reading && !spi_busy) begin
                spram_we <= 4'b1111;
                reading <= 0;
            end
        end
    end

    assign spram_addr = spi_addr[15:0];

    genvar i;
    generate
        for (i=0; i < 32; i=i+1) assign spram_wdat[i] = spi_data_out[31-i];
    endgenerate

endmodule
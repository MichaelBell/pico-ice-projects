
module tb_top_with_ram (
    input clk,
    input rstn,

    input uart_rxd,
    output uart_txd
);

`ifdef COCOTB_SIM
initial begin
  $dumpfile ("tb.vcd");
  $dumpvars (0, tb_top_with_ram);
  #1;
end
`endif

    wire spi_miso, spi_select, spi_clk, spi_mosi;
    femto_test_top top (
        .ICE_CLK(clk),
        .ICE_PB(rstn),
        .ICE_SI(spi_miso),
        .SRAM_SS(spi_select),
        .ICE_SCK(spi_clk),
        .ICE_SO(spi_mosi),
        .ICE_27(uart_rxd),
        .ICE_25(uart_txd)
    );

    wire debug_clk;
    wire [23:0] debug_addr;
    wire [31:0] debug_data;
    sim_spi_ram spi_ram(
        spi_clk,
        spi_mosi,
        !spi_select,
        spi_miso,

        debug_clk,
        debug_addr,
        debug_data
    );

    defparam spi_ram.INIT_FILE = `PROG_FILE;
    wire [23:0] start_sig = 24'h`START_SIG;
    wire [23:0] end_sig = 24'h`END_SIG;

    wire is_buffered = 1;

endmodule
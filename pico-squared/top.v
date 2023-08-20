//`define USE_PICO_EMU_RAM

module pico_squared_top(
    input ICE_CLK,  // cpu_clk
    input ICE_PB,   // rstn

`ifndef USE_PICO_EMU_RAM
    input ICE_SI,   // spi_miso
    output ICE_SO,  // spi_mosi
    output ICE_SCK, // spi_clk_out
    output SRAM_SS, // spi_select
`else
    input ICE_20_G3,   // spi_miso
    output ICE_19,  // spi_mosi
    output ICE_26, // spi_clk_out
    output ICE_23, // spi_select
`endif
    output ICE_SSN, // Flash select

    input ICE_27,   // uart_rxd
    output ICE_25,  // uart_txd
    output ICE_21,  // uart_rts

    output ICE_4,   // out0
    output ICE_2,   // out1
    output ICE_47,  // out2
    output ICE_45,  // out3
    output ICE_3,   // out4
    output ICE_48,  // out5
    output ICE_46,  // out6
    output ICE_44_G6,  // out7

    input ICE_43,   // in0
    input ICE_38,   // in1
    input ICE_34,   // in2
    input ICE_31,   // in3
    input ICE_42,   // in4
    input ICE_36,   // in5
    input ICE_32,   // in6
    input ICE_28,   // in7

    output LED_R,
    output LED_G,
    output LED_B
);

    wire cpu_clk = ICE_CLK;
    wire rstn = ICE_PB;

`ifndef USE_PICO_EMU_RAM
    wire spi_miso = ICE_SI;
    wire spi_clk_out;
    assign ICE_SCK = spi_clk_out;
    reg spi_select, spi_mosi;
    assign ICE_SO = spi_mosi;
    assign SRAM_SS = !spi_select;
`else
    wire spi_miso = ICE_20_G3;
    wire spi_clk_out;
    assign ICE_26 = spi_clk_out;
    reg spi_select, spi_mosi;
    assign ICE_19 = spi_mosi;
    assign ICE_23 = spi_select;
`endif
    assign ICE_SSN = 1'b1;

    wire uart_rxd = ICE_27;
    wire uart_txd, uart_rts;
    assign ICE_25 = uart_txd;
    assign ICE_21 = uart_rts;

    wire ram_sel;
    wire [3:0] ram_we;
    wire [15:0] ram_addr;
    wire [31:0] ram_wdata;
	wire [31:0] ram_rdata;
	spram_16kx32 uram(
		.clk(cpu_clk),
		.sel(ram_sel),
		.we(ram_we),
		.addr(ram_addr),
		.wdat(ram_wdata),
		.rdat(ram_rdata)
	);

    wire [3:0] ram_init_we;
    wire [15:0] ram_init_addr;
    wire [31:0] ram_init_wdata;
    wire ram_init_done;
    spram_init initram(
        .clk(cpu_clk),
        .rstn(rstn),
        .spi_miso(spi_miso),
        .spi_select(spi_select),
        .spi_clk_out(spi_clk_out),
        .spi_mosi(spi_mosi),

        .spram_we(ram_init_we),
        .spram_addr(ram_init_addr),
        .spram_wdat(ram_init_wdata),

        .done(ram_init_done)
    );

	// CPU
	wire        mem_valid;
	wire        mem_instr;
	wire        mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_rdata;
	wire [31:0] mem_wdata;
	wire [ 3:0] mem_wstrb;
	picorv32 #(
		.PROGADDR_RESET(32'h 0000_0000),	// start or ROM
		.STACKADDR(32'h 1001_0000),			// end of SPRAM
		.BARREL_SHIFTER(0),
		.COMPRESSED_ISA(0),
		.ENABLE_COUNTERS(1),
        .ENABLE_REGS_16_31(0),
		.ENABLE_MUL(0),
		.ENABLE_DIV(0),
		.ENABLE_IRQ(0),
		.ENABLE_IRQ_QREGS(0),
		.CATCH_MISALIGN(0),
		.CATCH_ILLINSN(0)
	) cpu_I (
		.clk       (cpu_clk),
		.resetn    (rstn && ram_init_done),
		.mem_valid (mem_valid),
		.mem_instr (mem_instr),
		.mem_ready (mem_ready),
		.mem_addr  (mem_addr),
		.mem_wdata (mem_wdata),
		.mem_wstrb (mem_wstrb),
		.mem_rdata (mem_rdata)
	);

    assign ram_sel   = ram_init_done ? (mem_addr[31:28] == 0 ? mem_valid : 1'b0) : 1'b1;
    assign ram_we    = ram_init_done ? mem_wstrb : ram_init_we;
    assign ram_addr  = ram_init_done ? mem_addr  : ram_init_addr;
    assign ram_wdata = ram_init_done ? mem_wdata : ram_init_wdata;
    
    wire peri_sel = (mem_addr[31:28] == 4'h1) ? mem_valid : 1'b0;
    wire [31:0] peri_rdata;
    
    assign mem_rdata = peri_sel ? peri_rdata : ram_rdata;

    reg ram_read_done;
    always @(posedge cpu_clk)
        if (!rstn)
            ram_read_done <= 0;
        else
            // Always ready the cycle after valid
            ram_read_done <= ram_sel && ~ram_read_done;

    assign mem_ready = (ram_read_done && mem_valid) || (mem_wstrb != 4'h0 && ram_sel) || peri_sel;

    // Peripherals (GPIO, LEDs, UART)
    reg [7:0] output_data;
    reg [2:0] led_data;
    always @(posedge cpu_clk) begin
        if (!rstn) begin
            led_data <= 0;
            output_data <= 0;
        end else if (peri_sel && mem_wstrb[0]) begin
            if (mem_addr[7:0] == 8'h08) led_data <= mem_wdata[2:0];
            else if (mem_addr[7:0] == 8'h00) output_data <= mem_wdata[7:0];
        end
    end

    assign { ICE_44_G6, ICE_46, ICE_48, ICE_3, ICE_45, ICE_47, ICE_2, ICE_4 } = output_data;
    wire led_r, led_g, led_b;
    assign { led_r, led_g, led_b } = led_data;

    wire uart_tx_busy;
    wire uart_rx_valid;
    wire [7:0] uart_rx_data;
    assign peri_rdata[31:8] = 0;
    assign peri_rdata[7:0] = (mem_addr[7:0] == 8'h00) ? output_data :
                          (mem_addr[7:0] == 8'h04) ? {ICE_28, ICE_32, ICE_36, ICE_42, ICE_31, ICE_34, ICE_38, ICE_43} :
                          (mem_addr[7:0] == 8'h08) ? {5'b0, led_data} :
                          (mem_addr[7:0] == 8'h10) ? uart_rx_data :
                          (mem_addr[7:0] == 8'h14) ? {6'b0, uart_rx_valid, uart_tx_busy} : 0;

    wire uart_tx_start = peri_sel && (mem_addr[7:0] == 8'h10);
    wire [7:0] uart_tx_data = mem_wdata[7:0];

    uart_tx #(.CLK_HZ(24_000_000), .BIT_RATE(115_200)) i_uart_tx(
        .clk(cpu_clk),
        .resetn(rstn),
        .uart_txd(uart_txd),
        .uart_tx_en(uart_tx_start),
        .uart_tx_data(uart_tx_data),
        .uart_tx_busy(uart_tx_busy) 
    );

    uart_rx #(.CLK_HZ(24_000_000), .BIT_RATE(115_200)) i_uart_rx(
        .clk(cpu_clk),
        .resetn(rstn),
        .uart_rxd(uart_rxd),
        .uart_rts(uart_rts),
        .uart_rx_read((mem_addr[7:0] == 8'h10) && peri_sel),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_data(uart_rx_data) 
    );    

    SB_RGBA_DRV #(
    .CURRENT_MODE("0b1"),       // half current
    .RGB0_CURRENT("0b000001"),  // 4 mA
    .RGB1_CURRENT("0b000001"),  // 4 mA
    .RGB2_CURRENT("0b000001")   // 4 mA
  ) rgba_drv (
    .CURREN(1'b1),
    .RGBLEDEN(1'b1),
    .RGB0(LED_G), .RGB0PWM(led_g),
    .RGB1(LED_B), .RGB1PWM(led_b),
    .RGB2(LED_R), .RGB2PWM(led_r)
  );

endmodule
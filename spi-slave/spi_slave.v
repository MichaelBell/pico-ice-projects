// SPI RAM that accepts reads and writes using
// commands 03h and 02h.

module spi_slave (
    input spi_clk,
    input spi_mosi,
    input spi_select,
    output spi_miso,
    input clear_err,
    output reg ind_err,
    output reg cur_err
);

`ifdef COCOTB_SIM
initial begin
  $dumpfile ("spi.vcd");
  $dumpvars (0, spi_slave);
  #1;
end
`endif

    reg [30:0] cmd;
    reg [26:0] addr;
    reg [5:0] start_count;
    reg reading;
    reg writing;

    reg [15:0] data [0:127];
    reg [15:0] data_out;
    reg [3:0] bit_addr;

    always @(posedge spi_clk) begin
        if (writing) begin
            data[addr[10:4]][addr[3] * 8 + (7 - addr[2:0])] <= spi_mosi;
        end
    end

    always @(negedge spi_clk) begin
        data_out <= data[addr[10:4]];
        bit_addr <= {addr[3], 3'd7 - addr[2:0]};
    end
    assign spi_miso = reading ? data_out[bit_addr] : 0;

    parameter INIT_FILE = "asm_blink/pwm_blink.hex";
    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, data);
        else
            data[0] = 0;
        ind_err = 0;
    end

    wire [5:0] next_start_count = start_count + 1;
    wire [31:0] next_cmd = {cmd[30:0],spi_mosi};

    always @(posedge spi_clk or posedge spi_select) begin
        if (spi_select) begin
            start_count <= 0;
            cmd <= 0;
            reading <= 0;
            writing <= 0;
            cur_err <= 0;
        end else begin
            start_count <= next_start_count;

            if (!reading && !writing && !cur_err) begin
                cmd <= next_cmd[30:0];
                if (next_start_count == 32) begin
                    addr[26:3] <= next_cmd[23:0];
                    addr[2:0] <= 0;
                    if (next_cmd[31:24] == 3)
                        reading <= 1;
                    else if (next_cmd[31:24] == 2)
                        writing <= 1;
                    else
                        cur_err <= 1;
                end
            end else if (reading || writing) begin
                addr <= addr + 1;
            end
        end
    end

    always @(negedge clear_err or negedge spi_clk) begin
        if (!clear_err)
            ind_err <= 0;
        else if (cur_err)
            ind_err <= 1;
    end
endmodule
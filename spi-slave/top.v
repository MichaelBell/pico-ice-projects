module spi_slave_top(
  input   ICE_CLK,
  input   ICE_PB,
  output  LED_R,
  output  LED_G,
  output  LED_B,
  input   PV_SCK,
  input   PV_MOSI,
  output  PV_MISO,
  input   PV_CS,
  output  ICE_PMOD2B_IO1,
  output  ICE_PMOD2B_IO2,
  output  ICE_PMOD2B_IO3,
  output  ICE_PMOD2B_IO4,
  output ICE_19
  );

    // LEDs    
    wire clk = ICE_CLK;
    wire button = ICE_PB;

    reg[15:0] counter;
    wire[16:0] counter_next = {1'b0,counter} + 1;
    always @(posedge clk)
        counter <= counter_next[15:0];

    wire led_r, led_g, led_b;
    wire led_on = counter[15:13] == 0;  // Dim
  SB_RGBA_DRV #(
    .CURRENT_MODE("0b1"),       // half current
    .RGB0_CURRENT("0b000001"),  // 4 mA
    .RGB1_CURRENT("0b000001"),  // 4 mA
    .RGB2_CURRENT("0b000001")   // 4 mA
  ) rgba_drv (
    .CURREN(1'b1),
    .RGBLEDEN(1'b1),
    .RGB0(LED_G), .RGB0PWM(led_g && led_on),
    .RGB1(LED_B), .RGB1PWM(led_b && led_on),
    .RGB2(LED_R), .RGB2PWM(led_r && led_on)
  );

  assign led_r = !PV_CS;
  assign led_g = PV_CS;

/*
  localparam MAX_BUFFER = 1;
  wire [MAX_BUFFER:0] buffer_cs_in;
  wire [MAX_BUFFER:0] buffer_cs_out;
  assign buffer_cs_in = {buffer_cs_out[MAX_BUFFER-1:0], PV_CS};
  SB_LUT4 #(
 .LUT_INIT(16'd2)
 ) buffers [MAX_BUFFER:0] (
 .O(buffer_cs_out),
 .I0(buffer_cs_in),
 .I1(1'b0),
 .I2(1'b0),
 .I3(1'b0)
 );

  wire cur_cs = PV_CS & buffer_cs_out[MAX_BUFFER];

  spi_slave spi_ram(PV_SCK, PV_MOSI, cur_cs, PV_MISO, button, led_b, ICE_19);
*/

  spi_slave spi_ram(PV_SCK, PV_MOSI, PV_CS, PV_MISO, button, led_b, ICE_19);

  assign ICE_PMOD2B_IO1 = cur_cs;
  assign ICE_PMOD2B_IO2 = PV_SCK;
  assign ICE_PMOD2B_IO3 = PV_MOSI;
  assign ICE_PMOD2B_IO4 = PV_MISO;
endmodule

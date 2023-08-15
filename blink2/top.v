module blink2_top(
  input   ICE_CLK,
  input   ICE_PB,
  output  LED_R,
  output  LED_G,
  output  LED_B);
    
    wire clk = ICE_CLK;
    wire button = ICE_PB;

    reg[15:0] counter;
    wire[16:0] counter_next = {1'b0,counter} + 1;
    always @(posedge clk)
        counter <= counter_next[15:0];
    reg[9:0] counter2;
    always @(posedge clk)
        if (counter_next[16] && button)
            counter2 <= counter2 + 1;

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

    assign led_r = counter2[6];
    assign led_g = counter2[7];
    assign led_b = counter2[8];
endmodule

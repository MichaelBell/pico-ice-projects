
module tb_top (
    input clk,
    input rstn,
    input [31:0] debug_counter
);

`ifdef COCOTB_SIM
initial begin
  $dumpfile ("tb.vcd");
  $dumpvars (0, tb_top);
  #1;
end
`endif

    wire sample_clk, sample_in, sample_out, sample_sync;
    high_freq_fft_top top (
        .ICE_CLK(clk),
        .ICE_18(rstn),
        .ICE_21(sample_clk),
        .ICE_19(sample_in),
        .ICE_26(sample_out),
        .ICE_23(sample_out_sync),
        .ICE_27(1'b0)
    );


endmodule
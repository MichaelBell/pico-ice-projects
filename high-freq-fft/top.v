module high_freq_fft_top(
    input ICE_CLK,

    input ICE_18,  // Resetn

    input ICE_21,  // Sample clock
    input ICE_19,  // Sample in

    output ICE_26, // Sample out
    output ICE_23, // Sample out sync

    input ICE_27,  // UART RX
    output ICE_25 // UART TX
);

    assign ICE_25 = ICE_27;

    localparam FFT_IWDITH = 8;
    localparam FFT_OWDITH = 12;

    localparam sample_bias = 127;

    wire clk = ICE_CLK;
    wire resetn = ICE_18;

    wire sample_clk = ICE_21;
    wire sample_in = ICE_19;

    reg sample_out, sample_out_sync;
    assign ICE_26 = sample_out;
    assign ICE_23 = sample_out_sync;

    reg last_sample_clk;
    reg [FFT_IWDITH-1:0] sample;
    reg [3:0] counter;
    reg [FFT_OWDITH-1:0] bin;

    wire [FFT_IWDITH-1:0] sample_to_fft = sample - sample_bias;

    wire [2*FFT_OWDITH-1:0] fft_result;
    wire [FFT_OWDITH-1:0] fft_abs_re = fft_result[2*FFT_OWDITH-1] ? -fft_result[2*FFT_OWDITH-1:FFT_OWDITH] : fft_result[2*FFT_OWDITH-1:FFT_OWDITH];
    wire [FFT_OWDITH-1:0] fft_abs_im = fft_result[FFT_OWDITH-1] ? -fft_result[FFT_OWDITH-1:0] : fft_result[FFT_OWDITH-1:0];
    reg fft_re_gt;
    wire [FFT_OWDITH-1:0] fft_max_cpt = fft_re_gt ? fft_abs_re : fft_abs_im;
    wire [FFT_OWDITH-1:0] fft_min_cpt = fft_re_gt ? fft_abs_im : fft_abs_re;
    reg [FFT_OWDITH-1:0] bin_from_fft;
    wire sync_from_fft;
    reg sample_ready;

    always @(posedge clk) begin
        if (!resetn) begin
            sample_out <= 0;
            sample_out_sync <= 0;
            last_sample_clk <= sample_clk;
            sample <= 0;
            sample_ready <= 0;
            counter <= 0;
            bin <= 0;
        end else begin
            if (sample_clk == 1 && last_sample_clk == 0) begin
                sample <= {sample_in, sample[FFT_IWDITH-1:1]};
                sample_out <= bin[0];

                sample_ready <= (counter == 4'd11);

                if (counter == 4'b1110) begin
                    bin <= bin_from_fft;
                end else begin
                    bin <= {1'b0, bin[FFT_OWDITH-1:1]};
                end
                if (counter == 4'b1111) begin
                    sample_out_sync <= sync_from_fft;
                end else begin
                    sample_out_sync <= 0;
                end

                counter <= counter + 4'd1;
            end
            else begin
                sample_ready <= 0;
            end

            last_sample_clk <= sample_clk;
            fft_re_gt <= fft_abs_re > fft_abs_im;
            bin_from_fft <= fft_max_cpt + (fft_min_cpt >> 1);
        end
    end

    wire [2*FFT_IWDITH-1:0] fft_in = {sample_to_fft, {FFT_IWDITH{1'b0}}};
    fftmain i_fftmain(
        .i_clk(clk),
        .i_reset(!resetn),
        .i_ce(sample_ready),
        .i_sample(fft_in),
        .o_result(fft_result),
        .o_sync(sync_from_fft)
        );

endmodule
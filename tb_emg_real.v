`timescale 1ns/1ps
`default_nettype none
// Golden-reference comparison using the two 8000-sample EMG recordings.
// Expected results are calculated independently from the input samples.
module tb_emg_real;
  reg clk = 1'b0;
  always #500 clk = ~clk; // 1 MHz, under Silicluster's 10 MHz maximum
  reg rst = 1'b1;
  reg enable = 1'b1;
  reg write_strobe = 1'b0;
  reg command_mode = 1'b0;
  reg [1:0] view = 2'b00;
  reg byte_select = 1'b0;
  reg [7:0] data_in = 8'h00;
  wire [7:0] data_out;
  wire activity, result_toggle, ack_toggle, data_valid, error_flag;

  reg [11:0] rest_samples [0:7999];
  reg [11:0] close_samples [0:7999];
  integer i, w, k, sum_abs, difference, expected_mav;
  integer windows_rest, windows_close, active_rest, active_close;
  integer last_mav;
  reg expected_activity, expected_toggle;
  reg [15:0] observed_mav;

  silicluster_emg_top dut (
    .clk(clk), .rst(rst), .enable(enable),
    .write_strobe(write_strobe), .command_mode(command_mode),
    .view(view), .byte_select(byte_select), .data_in(data_in),
    .data_out(data_out), .activity(activity),
    .result_toggle(result_toggle), .ack_toggle(ack_toggle),
    .data_valid(data_valid), .error_flag(error_flag)
  );

  task write_byte;
    input [7:0] value;
    input is_command;
    begin
      @(negedge clk); data_in=value; command_mode=is_command; write_strobe=0;
      @(negedge clk); write_strobe=1;
      @(negedge clk); write_strobe=0;
    end
  endtask

  task write_word;
    input [7:0] address;
    input [11:0] value;
    begin
      write_byte(address,1'b1);
      write_byte(value[7:0],1'b0);
      write_byte({4'b0000,value[11:8]},1'b0);
    end
  endtask

  task snapshot_mav;
    begin
      write_byte(8'd4,1'b1);
      view=2'b10; byte_select=0; #1;
      observed_mav[7:0]=data_out;
      byte_select=1; #1;
      observed_mav[15:8]=data_out;
      byte_select=0;
    end
  endtask

  task reset_dut;
    begin
      @(negedge clk); rst=1; write_strobe=0; command_mode=0;
      repeat(3) @(negedge clk);
      rst=0;
      expected_activity=0;
      expected_toggle=0;
      if (data_valid !== 1'b0 || activity !== 1'b0 || error_flag !== 1'b0)
        $fatal(1,"Reset did not clear status");
    end
  endtask

  task run_recording;
    input integer recording_id; // 0=rest, 1=close
    begin
      reset_dut();
      // Defaults from core: offset=1995, low=10, high=16.
      for (w=0;w<125;w=w+1) begin
        sum_abs=0;
        for (k=0;k<64;k=k+1) begin
          i=w*64+k;
          if (recording_id==0) begin
            difference=rest_samples[i]-1995;
            write_word(8'd0,rest_samples[i]);
          end else begin
            difference=close_samples[i]-1995;
            write_word(8'd0,close_samples[i]);
          end
          if (difference<0) difference=-difference;
          sum_abs=sum_abs+difference;
        end
        expected_mav=sum_abs/64; // Hardware uses truncating >> 6.
        if (expected_mav>16) expected_activity=1;
        else if (expected_mav<10) expected_activity=0;
        expected_toggle=~expected_toggle;
        snapshot_mav();
        if (data_valid !== 1'b1 || error_flag !== 1'b0)
          $fatal(1,"Recording %0d, window %0d: invalid status",recording_id,w);
        if (observed_mav !== expected_mav)
          $fatal(1,"Recording %0d, window %0d: MAV got %0d expected %0d",recording_id,w,observed_mav,expected_mav);
        if (activity !== expected_activity)
          $fatal(1,"Recording %0d, window %0d: activity got %b expected %b (MAV=%0d)",recording_id,w,activity,expected_activity,expected_mav);
        if (result_toggle !== expected_toggle)
          $fatal(1,"Recording %0d, window %0d: result_toggle mismatch",recording_id,w);
        if (recording_id==0) begin
          windows_rest=windows_rest+1;
          if (activity) active_rest=active_rest+1;
        end else begin
          windows_close=windows_close+1;
          if (activity) active_close=active_close+1;
        end
        last_mav=expected_mav;
      end
      if (recording_id==0) $display("REST: %0d windows, %0d active, last MAV=%0d",windows_rest,active_rest,last_mav);
      else $display("CLOSE: %0d windows, %0d active, last MAV=%0d",windows_close,active_close,last_mav);
    end
  endtask

  initial begin
    $readmemh("test/reposo_ch0.hex",rest_samples);
    $readmemh("test/cierre_ch0.hex",close_samples);
    windows_rest=0; windows_close=0; active_rest=0; active_close=0;
    run_recording(0);
    run_recording(1);
    if (windows_rest != 125 || windows_close != 125)
      $fatal(1,"Expected 125 windows per recording");
    if (active_rest != 0 || active_close == 0)
      $fatal(1,"Unexpected activity profile for provided recordings");
    $display("PASS: 16000 real EMG samples; 250 MAV64 windows matched golden reference");
    $finish;
  end
  initial begin
    #1000000000; // 1 second simulation-time watchdog
    $fatal(1,"Timeout: testbench did not complete");
  end
endmodule
`default_nettype wire

`timescale 1ns/1ps
`default_nettype none
module tb_silicluster;
    reg clk=0;
    always #500 clk=~clk; // 1 MHz
    reg rst=1, enable=1, write_strobe=0, command_mode=0, byte_select=0;
    reg [1:0] view=0;
    reg [7:0] data_in=0;
    wire [7:0] data_out;
    wire activity, result_toggle, ack_toggle, data_valid, error_flag;
    integer k;
    silicluster_emg_top dut( .clk(clk),.rst(rst),.enable(enable),
      .write_strobe(write_strobe),.command_mode(command_mode),.view(view),
      .byte_select(byte_select),.data_in(data_in),.data_out(data_out),
      .activity(activity),.result_toggle(result_toggle),.ack_toggle(ack_toggle),
      .data_valid(data_valid),.error_flag(error_flag));
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
    initial begin
      $dumpfile("silicluster_emg.vcd"); $dumpvars(0,tb_silicluster);
      repeat (2) @(negedge clk); rst=0;
      if (data_valid !== 1'b0 || error_flag !== 1'b0 || activity !== 1'b0) begin
        $display("FAIL: incorrect reset status"); $finish_and_return(1);;
      end
      // Defaults: offset=1995, high=16. 64 samples of 2015 => MAV=20, active=1.
      for (k=0;k<64;k=k+1) write_word(8'd0,12'd2015);
      if (data_valid !== 1'b1 || error_flag !== 1'b0) begin
        $display("FAIL: valid/error status after full window"); $finish_and_return(1);;
      end
      if (activity !== 1'b1) begin
        $display("FAIL: activity expected 1"); $finish_and_return(1);;
      end
      write_byte(8'd4,1'b1); // snapshot
      view=2'b10; byte_select=0;
      #1;
      if (data_out !== 8'd20) begin
        $display("FAIL: MAV expected 20, obtained %d",data_out); $finish_and_return(1);;
      end
      // 64 samples at offset => MAV=0 => inactive.
      for (k=0;k<64;k=k+1) write_word(8'd0,12'd1995);
      if (activity !== 1'b0) begin
        $display("FAIL: activity expected 0"); $finish_and_return(1);;
      end
      if (data_valid !== 1'b1) begin
        $display("FAIL: data_valid unexpectedly low"); $finish_and_return(1);;
      end
      write_byte(8'd99,1'b1); // Invalid command must flag an error.
      if (error_flag !== 1'b1) begin
        $display("FAIL: invalid command not flagged"); $finish_and_return(1);;
      end
      write_byte(8'd5,1'b1); // Clear error.
      if (error_flag !== 1'b0) begin
        $display("FAIL: error did not clear"); $finish_and_return(1);;
      end
      $display("PASS: Silicluster wrapper + status smoke test"); $finish;
    end
endmodule
`default_nettype wire

`default_nettype none
// Silicluster v3 candidate interface: 14 digital inputs, 11 digital outputs,
// plus external clock and active-high reset.
// Only translates the TinyTapeout interface; arithmetic core unchanged.
module silicluster_emg_top (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire write_strobe,
    input wire command_mode,
    input wire [1:0] view,
    input wire byte_select,
    input wire enable,
    output wire [7:0] data_out,
    output wire activity,
    output wire result_toggle,
    output wire ack_toggle,
    output wire data_valid,
    output wire error_flag
);
    wire [7:0] ti_uio_in;
    wire [7:0] ti_uio_out;
    wire [7:0] ti_uio_oe;
    assign ti_uio_in = {3'b000, byte_select, view, command_mode, write_strobe};
    silicluster_emg_core core (
        .ui_in(data_in), .uo_out(data_out),
        .uio_in(ti_uio_in), .uio_out(ti_uio_out), .uio_oe(ti_uio_oe),
        .ena(enable), .clk(clk), .rst_n(~rst)
    );
    assign activity = ti_uio_out[5];
    assign result_toggle = ti_uio_out[6];
    assign ack_toggle = ti_uio_out[7];
    assign data_valid = ti_uio_out[4];
    assign error_flag = ti_uio_out[3];
endmodule
`default_nettype wire

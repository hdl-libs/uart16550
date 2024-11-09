// ---------------------------------------------------------------------------------------
// Copyright (c) 2024 john_tito All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// ---------------------------------------------------------------------------------------
// +FHEADER-------------------------------------------------------------------------------
// Author        : john_tito
// Module Name   : uart_wrapper
// ---------------------------------------------------------------------------------------
// Revision      : 1.0
// Description   : File Created
// ---------------------------------------------------------------------------------------
// Synthesizable : Yes
// Clock Domains : clk
// Reset Strategy: sync reset
// -FHEADER-------------------------------------------------------------------------------

// verilog_format: off
`resetall
`timescale 1ns / 1ps
`default_nettype none
// verilog_format: on

module uart_wrapper #(
    parameter integer BASE_BAUD_DIV = 8 // no less than 8
) (
    input wire clk,
    input wire rst,

    input wire tx_en,
    input wire rx_en,

    input wire [ 6:0] line_config,
    input wire [11:0] baud_freq,
    input wire [15:0] baud_limit,

    input  wire [7:0] s_tdata,
    input  wire       s_tvalid,
    output wire       s_tready,

    output wire [7:0] m_tdata,
    output wire       m_tvalid,
    input  wire       m_tready,

    output wire txd,
    input  wire rxd

);

    reg [2:0] rxd_i = 3'b111;

    uart_transmitter #(
        .BASE_BAUD_DIV(BASE_BAUD_DIV)
    ) uart_transmitter_inst (
        .clk         (clk),
        .rst         (rst),
        .enable      (tx_en),
        .clr         (1'b0),
        .lcr         (line_config),
        .baud_freq   (baud_freq),
        .baud_limit  (baud_limit),
        .oe_wait_time(16),
        .oe_hold_time(16),
        .sts_busy    (),
        .sts_txcnt   (),
        .tx_oe       (),
        .tx_d        (txd),
        .tx_clk      (),
        .s_tdata     (s_tdata),
        .s_tvalid    (s_tvalid),
        .s_tready    (s_tready)
    );

    uart_receiver #(
        .BASE_BAUD_DIV(BASE_BAUD_DIV)
    ) uart_receiver_inst (
        .clk              (clk),
        .rst              (rst),
        .enable           (rx_en),
        .clr              (1'b0),
        .lcr              (line_config[5:0]),
        .baud_freq        (baud_freq),
        .baud_limit       (baud_limit),
        .srx_i            (rxd_i[0]),
        .sts_rxcnt        (),
        .sts_overflow     (),
        .sts_break_error  (),
        .sts_parity_error (),
        .sts_framing_error(),
        .sts_busy         (),
        .m_tdata          (m_tdata),
        .m_tvalid         (m_tvalid),
        .m_tready         (m_tready)
    );

    always @(posedge clk) begin
        if (rst) begin
            rxd_i <= 3'b111;
        end else begin
            rxd_i <= {rxd, rxd_i[2:1]};
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on

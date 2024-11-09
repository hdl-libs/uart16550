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
// Module Name   : uart_top
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

module uart_top #(
    parameter integer C_APB_DATA_WIDTH = 32,
    parameter integer C_APB_ADDR_WIDTH = 16,
    parameter integer C_S_BASEADDR     = 0,
    parameter integer C_S_HIGHADDR     = 255,
    parameter integer BASE_BAUD_DIV    = 8     // not less than 8
) (
    //
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_apb:s:m, ASSOCIATED_RESET rstn" *)
    input  wire                          clk,        //  (required)
    //
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rstn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                          rstn,       //  (required)
    //
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PADDR" *)
    input  wire [(C_APB_ADDR_WIDTH-1):0] s_paddr,    // Address (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PSEL" *)
    input  wire                          s_psel,     // Slave Select (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PENABLE" *)
    input  wire                          s_penable,  // Enable (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PWRITE" *)
    input  wire                          s_pwrite,   // Write Control (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PWDATA" *)
    input  wire [(C_APB_DATA_WIDTH-1):0] s_pwdata,   // Write Data (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PREADY" *)
    output wire                          s_pready,   // Slave Ready (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PRDATA" *)
    output wire [(C_APB_DATA_WIDTH-1):0] s_prdata,   // Read Data (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:apb:1.0 s_apb PSLVERR" *)
    output wire                          s_pslverr,  // Slave Error Response (required)

    input  wire [7:0] s_tdata,
    input  wire       s_tvalid,
    output wire       s_tready,

    output wire [7:0] m_tdata,
    output wire       m_tvalid,
    input  wire       m_tready,

    output wire        txd,
    output wire        txclk,
    input  wire        rxd,
    output wire        tx_oe,
    output wire        rx_ie,
    //
    (* X_INTERFACE_INFO = "xilinx.com:interface:gpio:1.0 gpio TRI_T" *)
    output wire [31:0] user_gpie,  //
    (* X_INTERFACE_INFO = "xilinx.com:interface:gpio:1.0 gpio TRI_I" *)
    input  wire [31:0] user_gpi,   //
    (* X_INTERFACE_INFO = "xilinx.com:interface:gpio:1.0 gpio TRI_O" *)
    output wire [31:0] user_gpo    //
);

    wire        soft_rst;
    wire [ 6:0] line_config;
    wire [11:0] baud_freq;
    wire [15:0] baud_limit;
    wire        echo_enable;
    wire        tx_enable;
    wire        rx_enable;
    wire        tx_clr;
    wire        rx_clr;
    wire [31:0] user_gpoe;
    wire [31:0] oe_wait_time;
    wire [31:0] oe_hold_time;

    wire [31:0] sts_tx_cnt;
    wire        sts_tx_busy;
    wire [31:0] sts_rx_overflow;
    wire [31:0] sts_rx_cnt;
    wire        sts_rx_break_error;
    wire        sts_rx_parity_error;
    wire        sts_rx_framing_error;
    wire        sts_rx_busy;

    reg  [ 2:0] rxd_i = 3'b111;

    assign rx_ie     = ~sts_tx_busy;
    assign user_gpie = ~user_gpoe;

    uart_apb #(
        .C_APB_DATA_WIDTH(C_APB_DATA_WIDTH),
        .C_APB_ADDR_WIDTH(C_APB_ADDR_WIDTH),
        .C_S_BASEADDR    (C_S_BASEADDR),
        .C_S_HIGHADDR    (C_S_HIGHADDR)
    ) uart_apb_inst (
        .clk                 (clk),
        .rstn                (rstn),
        .s_paddr             (s_paddr),
        .s_psel              (s_psel),
        .s_penable           (s_penable),
        .s_pwrite            (s_pwrite),
        .s_pwdata            (s_pwdata),
        .s_pready            (s_pready),
        .s_prdata            (s_prdata),
        .s_pslverr           (s_pslverr),
        .soft_rst            (soft_rst),
        .tx_enable           (tx_enable),
        .rx_enable           (rx_enable),
        .tx_clr              (tx_clr),
        .rx_clr              (rx_clr),
        .line_config         (line_config),
        .baud_freq           (baud_freq),
        .baud_limit          (baud_limit),
        .oe_wait_time        (oe_wait_time),
        .oe_hold_time        (oe_hold_time),
        .echo_enable         (echo_enable),
        .sts_tx_cnt          (sts_tx_cnt),
        .sts_tx_busy         (sts_tx_busy),
        .sts_rx_overflow     (sts_rx_overflow),
        .sts_rx_cnt          (sts_rx_cnt),
        .sts_rx_break_error  (sts_rx_break_error),
        .sts_rx_parity_error (sts_rx_parity_error),
        .sts_rx_framing_error(sts_rx_framing_error),
        .sts_rx_busy         (sts_rx_busy),
        .user_gpoe           (user_gpoe),
        .user_gpi            (user_gpi),
        .user_gpo            (user_gpo)
    );

    uart_transmitter #(
        .BASE_BAUD_DIV(BASE_BAUD_DIV)
    ) uart_transmitter_inst (
        .clk         (clk),
        .rst         (soft_rst),
        .enable      (tx_enable),
        .clr         (tx_clr),
        .lcr         (line_config),
        .baud_freq   (baud_freq),
        .baud_limit  (baud_limit),
        .oe_wait_time(oe_wait_time),
        .oe_hold_time(oe_hold_time),
        .sts_busy    (sts_tx_busy),
        .sts_txcnt   (sts_tx_cnt),
        .tx_oe       (tx_oe),
        .tx_d        (txd),
        .tx_clk      (txclk),
        .s_tdata     (s_tdata),
        .s_tvalid    (s_tvalid),
        .s_tready    (s_tready)
    );

    uart_receiver #(
        .BASE_BAUD_DIV(BASE_BAUD_DIV)
    ) uart_receiver_inst (
        .clk              (clk),
        .rst              (soft_rst),
        .enable           (rx_enable),
        .clr              (tx_clr),
        .lcr              (line_config[5:0]),
        .baud_freq        (baud_freq),
        .baud_limit       (baud_limit),
        .srx_i            (rxd_i[0]),
        .sts_rxcnt        (sts_rx_cnt),
        .sts_overflow     (sts_rx_overflow),
        .sts_break_error  (sts_rx_break_error),
        .sts_parity_error (sts_rx_parity_error),
        .sts_framing_error(sts_rx_framing_error),
        .sts_busy         (sts_rx_busy),
        .m_tdata          (m_tdata),
        .m_tvalid         (m_tvalid),
        .m_tready         (m_tready)
    );

    always @(posedge clk) begin
        if (soft_rst) begin
            rxd_i <= 3'b111;
        end else begin
            if (echo_enable) begin
                rxd_i <= {txd, rxd_i[2:1]};
            end else begin
                rxd_i <= {rxd, rxd_i[2:1]};
            end
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on

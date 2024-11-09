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
// Module Name   : uart_apb
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

module uart_apb #(
    parameter integer C_APB_DATA_WIDTH = 32,
    parameter integer C_APB_ADDR_WIDTH = 16,
    parameter integer C_S_BASEADDR     = 0,
    parameter integer C_S_HIGHADDR     = 255
) (
    //
    input  wire                          clk,
    input  wire                          rstn,
    //
    input  wire [(C_APB_ADDR_WIDTH-1):0] s_paddr,
    input  wire                          s_psel,
    input  wire                          s_penable,
    input  wire                          s_pwrite,
    input  wire [(C_APB_DATA_WIDTH-1):0] s_pwdata,
    output wire                          s_pready,
    output wire [(C_APB_DATA_WIDTH-1):0] s_prdata,
    output wire                          s_pslverr,
    //
    output reg                           soft_rst,
    output wire                          tx_enable,
    output wire                          rx_enable,
    output wire                          tx_clr,
    output wire                          rx_clr,
    output wire [                   6:0] line_config,
    output wire                          echo_enable,
    output reg  [                  11:0] baud_freq,
    output reg  [                  15:0] baud_limit,
    output reg  [                  31:0] oe_wait_time,
    output reg  [                  31:0] oe_hold_time,
    //
    input  wire [                  31:0] sts_tx_cnt,
    input  wire                          sts_tx_busy,
    //
    input  wire [                  31:0] sts_rx_overflow,
    input  wire [                  31:0] sts_rx_cnt,
    input  wire                          sts_rx_break_error,
    input  wire                          sts_rx_parity_error,
    input  wire                          sts_rx_framing_error,
    input  wire                          sts_rx_busy,

    output reg  [31:0] user_gpoe,
    input  wire [31:0] user_gpi,
    output reg  [31:0] user_gpo
);

    //------------------------------------------------------------------------------------
    // verilog_format: off
    localparam [7:0] ADDR_CTRL          = C_S_BASEADDR;
    localparam [7:0] ADDR_STATUS        = ADDR_CTRL         + 8'h4;
    localparam [7:0] ADDR_BAUD_FREQ     = ADDR_STATUS       + 8'h4;
    localparam [7:0] ADDR_BAUD_LIMIT    = ADDR_BAUD_FREQ    + 8'h4;
    localparam [7:0] ADDR_TX_CNT        = ADDR_BAUD_LIMIT   + 8'h4;
    localparam [7:0] ADDR_RX_CNT        = ADDR_TX_CNT       + 8'h4;
    localparam [7:0] ADDR_RX_OVERFLOW   = ADDR_RX_CNT       + 8'h4;
    localparam [7:0] ADDR_USER_GPOE     = ADDR_RX_OVERFLOW  + 8'h4;
    localparam [7:0] ADDR_USER_GPO      = ADDR_USER_GPOE    + 8'h4;
    localparam [7:0] ADDR_USER_GPI      = ADDR_USER_GPO     + 8'h4;
    localparam [7:0] ADDR_OE_WAIT_TIME  = ADDR_USER_GPI     + 8'h4;
    localparam [7:0] ADDR_OE_HOLD_TIME  = ADDR_OE_WAIT_TIME + 8'h4;
    // verilog_format: on

    reg [31:0] config_reg;
    reg [31:0] status_reg;

    //------------------------------------------------------------------------------------

    localparam [31:0] IPIDENTIFICATION = 32'hF7DEC7A5;
    localparam [31:0] REVISION = "V1.0";
    localparam [31:0] BUILDTIME = 32'h20231013;

    reg  [                31:0] test_reg;
    wire                        wr_active;
    wire                        rd_active;

    wire                        user_reg_rreq;
    wire                        user_reg_wreq;
    reg                         user_reg_rack = 1'b0;
    reg                         user_reg_wack = 1'b0;
    wire [C_APB_ADDR_WIDTH-1:0] user_reg_raddr;
    reg  [C_APB_DATA_WIDTH-1:0] user_reg_rdata;
    wire [C_APB_ADDR_WIDTH-1:0] user_reg_waddr;
    wire [C_APB_DATA_WIDTH-1:0] user_reg_wdata;

    assign user_reg_rreq  = ~s_pwrite & s_psel & s_penable;
    assign user_reg_wreq  = s_pwrite & s_psel & s_penable;
    assign s_pready       = user_reg_rack | user_reg_wack;
    assign user_reg_raddr = s_paddr;
    assign user_reg_waddr = s_paddr;
    assign s_prdata       = user_reg_rdata;
    assign user_reg_wdata = s_pwdata;
    assign s_pslverr      = 1'b0;

    assign rd_active      = user_reg_rreq;
    assign wr_active      = user_reg_wreq & user_reg_wack;

    always @(posedge clk) begin
        user_reg_rack <= user_reg_rreq & ~user_reg_rack;
        user_reg_wack <= user_reg_wreq & ~user_reg_wack;
    end

    //------------------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            soft_rst <= 1'b1;
        end else begin
            if (wr_active && (user_reg_waddr == ADDR_CTRL) && user_reg_wdata[31]) begin
                soft_rst <= 1'b1;
            end else begin
                soft_rst <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (soft_rst) begin
            user_reg_rdata <= 0;
        end else begin
            user_reg_rdata <= 0;
            if (user_reg_rreq) begin
                case (user_reg_raddr)
                    ADDR_CTRL:         user_reg_rdata <= config_reg;
                    ADDR_STATUS:       user_reg_rdata <= status_reg;
                    ADDR_BAUD_FREQ:    user_reg_rdata <= baud_freq;
                    ADDR_BAUD_LIMIT:   user_reg_rdata <= baud_limit;
                    ADDR_TX_CNT:       user_reg_rdata <= sts_tx_cnt;
                    ADDR_RX_CNT:       user_reg_rdata <= sts_rx_cnt;
                    ADDR_RX_OVERFLOW:  user_reg_rdata <= sts_rx_overflow;
                    ADDR_USER_GPOE:    user_reg_rdata <= user_gpoe;
                    ADDR_USER_GPO:     user_reg_rdata <= user_gpo;
                    ADDR_USER_GPI:     user_reg_rdata <= user_gpi;
                    ADDR_OE_WAIT_TIME: user_reg_rdata <= oe_wait_time;
                    ADDR_OE_HOLD_TIME: user_reg_rdata <= oe_hold_time;
                    default:           ;
                endcase
            end
        end
    end

    assign tx_enable   = config_reg[0];
    assign rx_enable   = config_reg[1];
    assign tx_clr      = config_reg[2];
    assign rx_clr      = config_reg[3];
    assign line_config = config_reg[8+:7];
    assign echo_enable = config_reg[15];

    always @(posedge clk) begin
        if (soft_rst) begin
            config_reg   <= 31'h00000300;  // {stop[0],data[7:0],stop[0]}
            baud_freq    <= 2;
            baud_limit   <= 7;
            user_gpo     <= 0;
            user_gpoe    <= 0;
            oe_wait_time <= 32;
            oe_hold_time <= 32;
        end else begin
            config_reg   <= config_reg;
            baud_freq    <= baud_freq;
            baud_limit   <= baud_limit;
            user_gpoe    <= user_gpoe;
            user_gpo     <= user_gpo;
            oe_wait_time <= oe_wait_time;
            oe_hold_time <= oe_hold_time;
            if (wr_active) begin
                case (user_reg_waddr)
                    ADDR_CTRL:         config_reg <= user_reg_wdata;
                    ADDR_BAUD_FREQ:    baud_freq <= user_reg_wdata;
                    ADDR_BAUD_LIMIT:   baud_limit <= user_reg_wdata;
                    ADDR_USER_GPOE:    user_gpoe <= user_reg_wdata;
                    ADDR_USER_GPO:     user_gpo <= user_reg_wdata;
                    ADDR_OE_WAIT_TIME: oe_wait_time <= user_reg_wdata;
                    ADDR_OE_HOLD_TIME: oe_hold_time <= user_reg_wdata;
                    default:           ;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (soft_rst) begin
            status_reg <= 0;
        end else begin
            if (wr_active && (user_reg_waddr == ADDR_STATUS)) begin
                status_reg <= status_reg & user_reg_wdata;
            end else begin
                status_reg[0] <= sts_tx_busy;
                status_reg[4] <= sts_rx_busy;
                status_reg[5] <= status_reg[5] | sts_rx_break_error;
                status_reg[6] <= status_reg[6] | sts_rx_parity_error;
                status_reg[7] <= status_reg[7] | sts_rx_framing_error;
            end
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on

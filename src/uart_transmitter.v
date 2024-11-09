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
// Module Name   : uart_transmitter
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
`include "uart_defines.vh"
// verilog_format: on

module uart_transmitter #(
    parameter integer BASE_BAUD_DIV = 16
) (
    input wire        clk,
    input wire        rst,
    input wire        enable,
    input wire        clr,
    input wire [ 6:0] lcr,
    input wire [11:0] baud_freq,
    input wire [15:0] baud_limit,
    input wire [31:0] oe_wait_time,
    input wire [31:0] oe_hold_time,

    output reg        sts_busy,
    output reg [31:0] sts_txcnt,

    output reg  tx_oe,
    output reg  tx_clk,
    output wire tx_d,

    input  wire [7:0] s_tdata,
    input  wire       s_tvalid,
    output reg        s_tready
);

    reg  [31:0] oe_wait_cnt;

    reg  [ 6:0] cfg_lcr;
    reg  [11:0] cfg_baud_freq;
    reg  [15:0] cfg_baud_limit;
    wire [ 1:0] cfg_data_bits;
    wire        cfg_stop_bits;
    wire        cfg_parity_en;
    wire        cfg_even_parity;
    wire        cfg_stick_parity;
    wire [ 8:0] cfg_break;
    reg  [ 5:0] cfg_stop_bauds;

    reg  [15:0] prediv_cnt;
    reg         ce_16;

    reg  [ 5:0] baud_cnt;
    reg  [ 3:0] bit_cnt;

    reg  [ 8:0] shift_out;

    reg         pre_parity;

    wire        s_active;
    reg         new_data_latch;
    reg  [ 7:0] new_data;

    wire        baud_cnt_eq_0;
    wire        bit_cnt_eq_0;
    wire        bit_end;
    wire        byte_end;

    wire        oe_hold_end;
    wire        oe_wait_end;

    assign cfg_data_bits    = cfg_lcr[`UART_LC_BITS];  // bits in character
    assign cfg_stop_bits    = cfg_lcr[`UART_LC_SB];  // stop bits
    assign cfg_parity_en    = cfg_lcr[`UART_LC_PE];  // parity enable
    assign cfg_even_parity  = cfg_lcr[`UART_LC_EP];  // even parity
    assign cfg_stick_parity = cfg_lcr[`UART_LC_SP];  // stick parity
    assign cfg_break        = {8'hFF, ~lcr[`UART_LC_BC]};  // Break control

    assign s_active         = (s_tvalid & s_tready);

    assign oe_wait_end      = oe_wait_cnt >= oe_wait_time;
    assign oe_hold_end      = oe_wait_cnt >= oe_hold_time;

    assign baud_cnt_eq_0    = baud_cnt == 0;
    assign bit_cnt_eq_0     = bit_cnt == 0;

    assign bit_end          = ce_16 && baud_cnt_eq_0;
    assign byte_end         = bit_end && bit_cnt_eq_0;

    assign tx_d             = shift_out[0];

    // ***********************************************************************************
    // FSM logic
    // ***********************************************************************************

    localparam [15:0] FSM_IDLE = 16'h0000;
    localparam [15:0] FSM_WAITOE = 16'h0001;
    localparam [15:0] FSM_PREPAIR = 16'h0002;
    localparam [15:0] FSM_SS = 16'h0004;
    localparam [15:0] FSM_START = 16'h0008;
    localparam [15:0] FSM_DS = 16'h0010;
    localparam [15:0] FSM_DATA = 16'h0020;
    localparam [15:0] FSM_PS = 16'h0080;
    localparam [15:0] FSM_PARITY = 16'h0100;
    localparam [15:0] FSM_ES = 16'h0200;
    localparam [15:0] FSM_END = 16'h0400;
    localparam [15:0] FSM_HOLDOE = 16'h0800;

    reg [15:0] cstate;
    reg [15:0] nstate;

    always @(posedge clk) begin
        if (rst) begin
            cstate <= FSM_IDLE;
        end else begin
            cstate <= nstate;
        end
    end

    always @(*) begin
        if (rst) begin
            nstate = FSM_IDLE;
        end else begin
            case (cstate)
                FSM_IDLE: begin
                    if (enable & new_data_latch) begin
                        if (oe_wait_end) begin
                            nstate = FSM_PREPAIR;
                        end else begin
                            nstate = FSM_WAITOE;
                        end
                    end else begin
                        nstate = FSM_IDLE;
                    end
                end
                FSM_WAITOE: begin
                    if (oe_wait_end) begin
                        nstate = FSM_PREPAIR;
                    end else begin
                        nstate = FSM_WAITOE;
                    end
                end
                FSM_PREPAIR: begin
                    nstate = FSM_SS;
                end
                FSM_SS: begin
                    nstate = FSM_START;
                end
                FSM_START: begin
                    if (bit_end) begin
                        nstate = FSM_DS;
                    end else begin
                        nstate = FSM_START;
                    end
                end
                FSM_DS: begin
                    nstate = FSM_DATA;
                end
                FSM_DATA: begin
                    if (byte_end) begin
                        if (cfg_parity_en) begin
                            nstate = FSM_PS;
                        end else begin
                            nstate = FSM_ES;
                        end
                    end else if (bit_end) begin
                        nstate = FSM_DS;
                    end else begin
                        nstate = FSM_DATA;
                    end
                end
                FSM_PS: begin
                    nstate = FSM_PARITY;
                end
                FSM_PARITY: begin
                    if (bit_end) begin
                        nstate = FSM_ES;
                    end else begin
                        nstate = FSM_PARITY;
                    end
                end
                FSM_ES: begin
                    nstate = FSM_END;
                end
                FSM_END: begin
                    if (bit_end) begin
                        if (new_data_latch) begin
                            nstate = FSM_SS;
                        end else if (oe_hold_end) begin
                            nstate = FSM_IDLE;
                        end else begin
                            nstate = FSM_HOLDOE;
                        end
                    end else begin
                        nstate = FSM_END;
                    end
                end
                FSM_HOLDOE: begin
                    if (new_data_latch) begin
                        nstate = FSM_SS;
                    end else if (oe_hold_end) begin
                        nstate = FSM_IDLE;
                    end else begin
                        nstate = FSM_HOLDOE;
                    end
                end
                default: nstate = FSM_IDLE;
            endcase
        end
    end

    // ***********************************************************************************
    // request new data when in IDLE state or when in last bit
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            s_tready <= 1'b0;
        end else begin
            s_tready <= enable & ~s_active & ~new_data_latch;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            new_data_latch <= 1'b0;
        end else begin
            if (s_active) begin
                new_data_latch <= enable;
            end else if (nstate == FSM_ES) begin
                new_data_latch <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            new_data <= 8'hFF;
        end else begin
            if (s_active) begin
                new_data <= s_tdata;
            end
        end
    end

    // ***********************************************************************************
    // latch parity info before transmit
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            pre_parity = 1'b0;
        end else begin
            case (nstate)
                FSM_DS: begin
                    casex ({
                        cfg_parity_en, cfg_stick_parity, cfg_data_bits
                    })
                        4'b11xx: pre_parity = ~cfg_even_parity;
                        4'b1000: pre_parity = ^{cfg_even_parity, new_data[4:0]};
                        4'b1001: pre_parity = ^{cfg_even_parity, new_data[5:0]};
                        4'b1010: pre_parity = ^{cfg_even_parity, new_data[6:0]};
                        4'b1011: pre_parity = ^{cfg_even_parity, new_data[7:0]};
                        default: pre_parity = 1'b0;
                    endcase
                end
                default: pre_parity <= pre_parity;
            endcase
        end
    end

    // ***********************************************************************************
    // tx bit counter
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            bit_cnt <= 0;
        end else begin
            case (nstate)
                FSM_SS:              bit_cnt <= {1'b1, cfg_data_bits};
                FSM_DS:              if (cstate != FSM_START) bit_cnt <= bit_cnt - 1;
                FSM_START, FSM_DATA: bit_cnt <= bit_cnt;
                default:             bit_cnt <= 0;
            endcase
        end
    end

    // ***********************************************************************************
    // shift regsister
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            shift_out <= 9'h1FF;
        end else begin
            case (nstate)
                FSM_SS:                                   shift_out <= {new_data, 1'b0} & cfg_break;
                FSM_DS:                                   shift_out <= {1'b1, shift_out[8:1]} & cfg_break;
                FSM_PS:                                   shift_out <= {8'hFF, pre_parity} & cfg_break;
                FSM_START, FSM_DATA, FSM_PARITY, FSM_END: shift_out <= shift_out & cfg_break;
                default:                                  shift_out <= 9'h1FF & cfg_break;
            endcase
        end
    end

    // ***********************************************************************************
    // tx clk for sync uart
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            tx_clk <= 1'b0;
        end else begin
            case (nstate)
                FSM_START, FSM_DATA, FSM_PARITY: if (ce_16) tx_clk <= (baud_cnt > 0 && baud_cnt <= (BASE_BAUD_DIV / 2));
                FSM_END:                         if (ce_16) tx_clk <= (baud_cnt > 0 && baud_cnt <= cfg_stop_bauds[5:1]);
                default:                         tx_clk <= 1'b0;
            endcase
        end
    end

    // ***********************************************************************************
    // x16 baudrate generator
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            prediv_cnt <= 16'b0;
            ce_16      <= 1'b0;
        end else begin
            case (nstate)
                FSM_IDLE, FSM_WAITOE, FSM_HOLDOE: begin
                    prediv_cnt <= 16'b0;
                    ce_16      <= 1'b0;
                end
                default: begin
                    if (prediv_cnt >= cfg_baud_limit) begin
                        prediv_cnt <= prediv_cnt - cfg_baud_limit;
                    end else begin
                        prediv_cnt <= prediv_cnt + {4'h0, cfg_baud_freq};
                    end
                    ce_16 <= (prediv_cnt >= cfg_baud_limit);
                end
            endcase
        end
    end

    // ***********************************************************************************
    // x1 baudrate generateor
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            baud_cnt <= 0;
        end else begin
            case (nstate)
                FSM_SS, FSM_DS, FSM_PS:                   baud_cnt <= BASE_BAUD_DIV - 1;
                FSM_ES:                                   baud_cnt <= cfg_stop_bauds - 1;
                FSM_START, FSM_DATA, FSM_PARITY, FSM_END: if (ce_16) baud_cnt <= baud_cnt - 1;
                default:                                  baud_cnt <= 0;
            endcase
        end
    end

    // ***********************************************************************************
    // latch config when this module is disabled
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            cfg_baud_freq  <= 4;
            cfg_baud_limit <= 1;
            cfg_lcr        <= 3;
            cfg_stop_bauds <= BASE_BAUD_DIV;
        end else if (!enable) begin
            if (baud_freq > 0) begin
                cfg_baud_freq <= baud_freq;
            end

            if (baud_limit > 0) begin
                cfg_baud_limit <= baud_limit;
            end

            cfg_lcr <= lcr;

            casex ({
                cfg_stop_bits, cfg_data_bits
            })
                3'b100:  cfg_stop_bauds <= BASE_BAUD_DIV * 3 / 2;  // 1.5 stop bit, 5 data bits
                3'b0xx:  cfg_stop_bauds <= BASE_BAUD_DIV;  // 1 stop bit, 5/6/7/8 data bits
                default: cfg_stop_bauds <= BASE_BAUD_DIV * 2;  // 2 stop bits, 6/7/8 data bits
            endcase
        end
    end

    // ***********************************************************************************
    // Transmit data counter
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            sts_txcnt <= 0;
        end else begin
            if (clr) begin
                sts_txcnt <= 0;
            end else begin
                if (bit_end && (cstate == FSM_END)) sts_txcnt <= sts_txcnt + 1;
            end
        end
    end

    // ***********************************************************************************
    // Transmit busy flag
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            sts_busy <= 1'b1;
        end else begin
            case (nstate)
                FSM_IDLE: sts_busy <= 1'b0;
                default:  sts_busy <= 1'b1;
            endcase
        end
    end

    // ***********************************************************************************
    // output enable logic
    // ***********************************************************************************

    always @(posedge clk) begin
        if (rst) begin
            oe_wait_cnt <= 0;
        end else begin
            case (nstate)
                FSM_WAITOE: if (!oe_hold_end) oe_wait_cnt <= oe_wait_cnt + 1;
                FSM_HOLDOE: if (!oe_wait_end) oe_wait_cnt <= oe_wait_cnt + 1;
                default:    oe_wait_cnt <= 0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            tx_oe <= 1'b0;
        end else begin
            case (nstate)
                FSM_IDLE: tx_oe <= 1'b0;
                default:  tx_oe <= 1'b1;
            endcase
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on

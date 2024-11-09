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
// Module Name   : uart_receiver
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

module uart_receiver #(
    parameter integer BASE_BAUD_DIV = 16
) (
    input wire        clk,
    input wire        rst,
    input wire        enable,
    input wire        clr,
    input wire [ 5:0] lcr,
    input wire [11:0] baud_freq,
    input wire [15:0] baud_limit,

    input wire srx_i,

    output reg  [31:0] sts_rxcnt,
    output reg  [31:0] sts_overflow,
    output wire        sts_break_error,
    output reg         sts_parity_error,
    output reg         sts_framing_error,
    output reg         sts_busy,

    output reg  [7:0] m_tdata,
    output reg        m_tvalid,
    input  wire       m_tready
);

    reg  [ 6:0] cfg_lcr;
    reg  [11:0] cfg_baud_freq;
    reg  [15:0] cfg_baud_limit;
    wire [ 1:0] cfg_data_bits;
    wire        cfg_stop_bits;
    wire        cfg_parity_en;
    wire        cfg_even_parity;
    wire        cfg_stick_parity;
    reg  [ 5:0] cfg_stop_bauds;

    reg  [15:0] prediv_cnt;
    reg         ce_16;
    reg  [ 5:0] baud_cnt;
    reg  [ 2:0] bit_cnt;
    wire        bit_end;
    wire        byte_end;

    reg  [ 7:0] shift_in;

    reg  [ 7:0] break_period;
    reg  [ 7:0] break_timer;
    reg         break_error;

    wire        baud_cnt_eq_7 = (baud_cnt == (BASE_BAUD_DIV / 2 - 1));
    wire        baud_cnt_eq_0 = (baud_cnt == 0);
    wire        bit_cnt_eq_0 = (bit_cnt == 0);

    assign bit_end  = ce_16 && baud_cnt_eq_0;
    assign byte_end = bit_end && bit_cnt_eq_0;

    // ***********************************************************************************
    // FSM logic
    // ***********************************************************************************
    localparam [15:0] FSM_IDLE = 16'h0000;
    localparam [15:0] FSM_PREPAIR = 16'h0002;
    localparam [15:0] FSM_SS = 16'h0004;
    localparam [15:0] FSM_START = 16'h0008;
    localparam [15:0] FSM_DS = 16'h0010;
    localparam [15:0] FSM_DATA = 16'h0020;
    localparam [15:0] FSM_PS = 16'h0080;
    localparam [15:0] FSM_PARITY = 16'h0100;
    localparam [15:0] FSM_ES = 16'h0200;
    localparam [15:0] FSM_END = 16'h0400;

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
                    if (enable & ~break_error & ~srx_i) begin
                        nstate = FSM_PREPAIR;
                    end else begin
                        nstate = FSM_IDLE;
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
                        if (srx_i == 1'b0) begin
                            nstate = FSM_DS;
                        end else begin
                            nstate = FSM_IDLE;
                        end
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
                        nstate = FSM_IDLE;
                    end else begin
                        nstate = FSM_END;
                    end
                end
                default: nstate = FSM_IDLE;
            endcase
        end
    end

    // ***********************************************************************************
    // rx bit counter
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
    // x16 baudrate generator
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            prediv_cnt <= 16'b0;
            ce_16      <= 1'b0;
        end else begin
            case (nstate)
                FSM_IDLE: begin
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
                FSM_SS:                                   baud_cnt <= BASE_BAUD_DIV / 2 - 1;
                FSM_DS, FSM_PS:                           baud_cnt <= BASE_BAUD_DIV - 1;
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
                3'b100:  cfg_stop_bauds <= BASE_BAUD_DIV * 5 / 4;  // 1.5 stop bit, 5 data bits
                3'b0xx:  cfg_stop_bauds <= BASE_BAUD_DIV;  // 1 stop bit, 5/6/7/8 data bits
                default: cfg_stop_bauds <= BASE_BAUD_DIV * 3 / 2;  // 2 stop bits, 6/7/8 data bits
            endcase
        end
    end

    assign cfg_data_bits    = cfg_lcr[`UART_LC_BITS];  // bits in character
    assign cfg_stop_bits    = cfg_lcr[`UART_LC_SB];  // stop bits
    assign cfg_parity_en    = cfg_lcr[`UART_LC_PE];  // parity enable
    assign cfg_even_parity  = cfg_lcr[`UART_LC_EP];  // even parity
    assign cfg_stick_parity = cfg_lcr[`UART_LC_SP];  // stick parity

    always @(*) begin
        if (rst) begin
            break_period = 160;  // 10 bits
        end else begin
            case (cfg_lcr[3:0])
                4'b0000:                            break_period = (BASE_BAUD_DIV * 7);  //112,  7   bits
                4'b0100:                            break_period = (BASE_BAUD_DIV * 15 / 2);  //120,  7.5 bits
                4'b0001, 4'b1000:                   break_period = (BASE_BAUD_DIV * 8);  //128,  8   bits
                4'b1100:                            break_period = (BASE_BAUD_DIV * 16 / 2);  //136,  8.5 bits
                4'b0010, 4'b0101, 4'b1001:          break_period = (BASE_BAUD_DIV * 9);  //144,  9   bits
                4'b0011, 4'b0110, 4'b1010, 4'b1101: break_period = (BASE_BAUD_DIV * 10);  //160,  10  bits
                4'b0111, 4'b1011, 4'b1110:          break_period = (BASE_BAUD_DIV * 11);  //176,  11  bits
                4'b1111:                            break_period = (BASE_BAUD_DIV * 12);  //192,  12  bits
            endcase
        end
    end

    // ***********************************************************************************
    // shift serial data into register
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            shift_in <= 0;
        end else begin
            case (nstate)
                FSM_IDLE: shift_in <= 0;
                FSM_DATA: begin
                    if (ce_16 == 1'b1 && baud_cnt == 2) begin
                        shift_in <= {srx_i, shift_in[7:1]};
                    end
                end
                default:  shift_in <= shift_in;
            endcase
        end
    end

    // ***********************************************************************************
    // latch rx data
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            m_tvalid <= 0;
        end else begin
            case (cstate)
                FSM_END: begin
                    if (bit_end) begin
                        m_tvalid <= srx_i & ~sts_parity_error;
                    end
                end
                default: m_tvalid <= ~m_tready & m_tvalid;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            m_tdata <= 0;
        end else begin
            case (cstate)
                FSM_END: begin
                    if (bit_end) begin
                        case (cfg_data_bits)
                            2'b00:   m_tdata <= shift_in >> 3;
                            2'b01:   m_tdata <= shift_in >> 2;
                            2'b10:   m_tdata <= shift_in >> 1;
                            2'b11:   m_tdata <= shift_in >> 0;
                            default: m_tdata <= shift_in >> 0;
                        endcase
                    end
                end
                default: m_tdata <= m_tdata;
            endcase
        end
    end

    // ***********************************************************************************
    // check parity error
    // ***********************************************************************************

    always @(posedge clk) begin
        if (rst) begin
            sts_parity_error <= 1'b0;
        end else begin
            if (clr || !cfg_parity_en) begin
                sts_parity_error <= 1'b0;
            end else begin
                case (nstate)
                    FSM_IDLE: sts_parity_error <= 1'b0;
                    FSM_PARITY: begin
                        if (ce_16 == 1'b1 && baud_cnt == 2) begin
                            if (cfg_stick_parity) begin
                                sts_parity_error = ~cfg_even_parity ^ srx_i;
                            end else begin
                                sts_parity_error <= (^{cfg_even_parity, shift_in}) ^ srx_i;
                            end
                        end
                    end
                    default:  sts_parity_error <= sts_parity_error;
                endcase
            end
        end
    end

    // ***********************************************************************************
    // check frame error
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            sts_framing_error <= 1'b0;
        end else begin
            if (clr) begin
                sts_framing_error <= 1'b0;
            end else begin
                case (nstate)
                    FSM_END: begin
                        if (ce_16 == 1'b1 && baud_cnt == 2) begin
                            sts_framing_error <= ~srx_i;
                        end
                    end
                    default: sts_framing_error <= sts_framing_error;
                endcase
            end
        end
    end

    // ***********************************************************************************
    // Data overflow detection.
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            sts_overflow <= 0;
        end else begin
            if (clr) begin
                sts_overflow <= 0;
            end else begin
                case (cstate)
                    FSM_END: if (bit_end && ~(&sts_overflow) && m_tvalid) sts_overflow <= sts_overflow + 1;
                    default: sts_overflow <= sts_overflow;
                endcase
            end
        end
    end

    // ***********************************************************************************
    // Data overflow detection.
    // ***********************************************************************************

    always @(posedge clk) begin
        if (rst) begin
            sts_rxcnt <= 0;
        end else begin
            if (clr) begin
                sts_rxcnt <= 0;
            end else begin
                case (cstate)
                    FSM_END: if (bit_end) sts_rxcnt <= sts_rxcnt + 1;
                    default: sts_rxcnt <= sts_rxcnt;
                endcase
            end
        end
    end

    // ***********************************************************************************
    // Break condition detection.
    // ***********************************************************************************
    assign sts_break_error = break_error;
    always @(posedge clk) begin
        if (rst) begin
            break_timer <= 8'd160;  // 10 bits
            break_error <= 0;
        end else begin
            if (clr | srx_i) begin
                break_timer <= break_period;
                break_error <= 0;
            end else if (enable & break_timer > 0) begin
                if (ce_16) begin
                    break_timer <= break_timer - 1;
                    break_error <= (break_timer == 1);
                end
            end
        end
    end

    // ***********************************************************************************
    // Data overflow detection.
    // ***********************************************************************************
    always @(posedge clk) begin
        if (rst) begin
            sts_busy <= 1;
        end else begin
            case (nstate)
                FSM_IDLE: sts_busy <= 0;
                default:  sts_busy <= 1;
            endcase
        end
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on

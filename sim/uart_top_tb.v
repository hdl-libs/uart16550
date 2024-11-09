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
// Module Name   : uart_top_tb
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

module uart_top_tb;

    // Parameters
    localparam real TIMEPERIOD = 13.88888;
    localparam integer C_APB_DATA_WIDTH = 32;
    localparam integer C_APB_ADDR_WIDTH = 16;

    //Ports
    reg                           clk = 0;
    reg                           rstn = 0;

    wire [(C_APB_ADDR_WIDTH-1):0] s_paddr;
    wire                          s_psel;
    wire                          s_penable;
    wire                          s_pwrite;
    wire [(C_APB_DATA_WIDTH-1):0] s_pwdata;
    wire                          s_pready;
    wire [(C_APB_DATA_WIDTH-1):0] s_prdata;
    wire                          s_pslverr;

    reg  [                   7:0] s_tdata = 0;
    reg                           s_tvalid = 0;
    wire                          s_tready;
    wire [                   7:0] m_tdata;
    wire                          m_tvalid;
    reg                           m_tready = 1;

    wire                          txd;
    wire                          txclk;
    wire                          rxd;
    wire                          tx_oe;
    wire                          rx_ie;
    wire [                  31:0] user_gpie;
    reg  [                  31:0] user_gpi = 0;
    wire [                  31:0] user_gpo;

    apb_task #(
        .C_APB_ADDR_WIDTH(C_APB_ADDR_WIDTH),
        .C_APB_DATA_WIDTH(C_APB_DATA_WIDTH)
    ) apb_task_inst (
        .clk      (clk),
        .rstn     (rstn),
        .s_paddr  (s_paddr),
        .s_psel   (s_psel),
        .s_penable(s_penable),
        .s_pwrite (s_pwrite),
        .s_pwdata (s_pwdata),
        .s_pready (s_pready),
        .s_prdata (s_prdata),
        .s_pslverr(s_pslverr)
    );

    uart_top #(
        .C_APB_ADDR_WIDTH(C_APB_ADDR_WIDTH),
        .C_APB_DATA_WIDTH(C_APB_DATA_WIDTH),
        .BASE_BAUD_DIV   (8)
    ) uart_top_inst (
        .clk      (clk),
        .rstn     (rstn),
        .s_paddr  (s_paddr),
        .s_psel   (s_psel),
        .s_penable(s_penable),
        .s_pwrite (s_pwrite),
        .s_pwdata (s_pwdata),
        .s_pready (s_pready),
        .s_prdata (s_prdata),
        .s_pslverr(s_pslverr),
        .s_tdata  (s_tdata),
        .s_tvalid (s_tvalid),
        .s_tready (s_tready),
        .m_tdata  (m_tdata),
        .m_tvalid (m_tvalid),
        .m_tready (m_tready),
        .txd      (txd),
        .txclk    (txclk),
        .rxd      (rxd),
        .user_gpie(user_gpie),
        .user_gpi (user_gpi),
        .user_gpo (user_gpo)
    );

    assign rxd = txd;

    localparam UART_TEST_FROM = 0;
    localparam UART_TEST_TO = 255;
    always @(posedge clk) begin
        if (!rstn) begin
            s_tdata <= UART_TEST_FROM;
        end else begin
            if (s_tready & s_tvalid) begin
                s_tdata <= s_tdata + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (!rstn) begin
            s_tvalid <= 0;
        end else begin
            if (s_tdata >= UART_TEST_TO) begin
                if ((s_tready & s_tvalid)) begin
                    s_tvalid <= 1'b0;
                end
            end else begin
                s_tvalid <= 1'b1;
            end
        end
    end

    //------------------------------------------------------------------------------------
    // verilog_format: off
    localparam [7:0] ADDR_CTRL          = 0;
    localparam [7:0] ADDR_STATUS        = ADDR_CTRL         + 8'h4;
    localparam [7:0] ADDR_BAUD_FREQ     = ADDR_STATUS       + 8'h4;
    localparam [7:0] ADDR_BAUD_LIMIT    = ADDR_BAUD_FREQ    + 8'h4;
    localparam [7:0] ADDR_TX_CNT        = ADDR_BAUD_LIMIT   + 8'h4;
    localparam [7:0] ADDR_RX_CNT        = ADDR_TX_CNT       + 8'h4;
    localparam [7:0] ADDR_RX_OVERFLOW   = ADDR_RX_CNT       + 8'h4;
    localparam [7:0] ADDR_USER_GPOE     = ADDR_RX_CNT       + 8'h4;
    localparam [7:0] ADDR_USER_GPIO     = ADDR_USER_GPOE    + 8'h4;
    localparam [7:0] ADDR_OE_WAIT_TIME  = ADDR_USER_GPIO    + 8'h4;
    localparam [7:0] ADDR_OE_HOLD_TIME  = ADDR_OE_WAIT_TIME + 8'h4;
    // verilog_format: on

    reg  [ 1:0] cfg_data_bits = 2'b11;
    reg         cfg_stop_bits = 1;
    reg         cfg_parity_en = 1;
    reg         cfg_even_parity = 1;
    reg         cfg_stick_parity = 0;
    reg         cfg_break = 0;
    wire [ 6:0] line_config;

    reg         tx_enable = 0;
    reg         rx_enable = 0;
    reg         tx_clr = 0;
    reg         rx_clr = 0;
    reg         echo_enable = 0;

    wire [31:0] config_reg;

    assign line_config[1:0] = cfg_data_bits;
    assign line_config[2]   = cfg_stop_bits;
    assign line_config[3]   = cfg_parity_en;
    assign line_config[4]   = cfg_even_parity;
    assign line_config[5]   = cfg_stick_parity;
    assign line_config[6]   = cfg_break;

    assign config_reg       = {16'h0000, echo_enable, line_config, 4'h0, rx_clr, tx_clr, tx_enable, tx_enable};

    reg [(C_APB_ADDR_WIDTH-1):0] addr = 0;
    reg [(C_APB_DATA_WIDTH-1):0] data = 0;

    initial begin
        begin
            wait (rstn);

            addr = ADDR_CTRL;
            data = config_reg;
            apb_task_inst.write(addr, data);
            @(posedge clk);

            addr = ADDR_BAUD_FREQ;
            data = 32'd2;
            apb_task_inst.write(addr, data);
            @(posedge clk);

            addr = ADDR_BAUD_LIMIT;
            data = 32'd7;
            apb_task_inst.write(addr, data);
            @(posedge clk);

            addr = ADDR_OE_WAIT_TIME;
            data = 32'd0;
            apb_task_inst.write(addr, data);
            @(posedge clk);

            addr = ADDR_OE_HOLD_TIME;
            data = 32'd0;
            apb_task_inst.write(addr, data);
            @(posedge clk);

            // addr = ADDR_BAUD_FREQ;
            // data = 32'd8;
            // apb_task_inst.write(addr, data);
            // @(posedge clk);

            // addr = ADDR_BAUD_LIMIT;
            // data = 32'd1;
            // apb_task_inst.write(addr, data);
            // @(posedge clk);

            echo_enable = 1'b1;
            tx_enable   = 1'b1;
            rx_enable   = 1'b1;
            addr        = ADDR_CTRL;
            data        = config_reg;
            @(posedge clk);
            apb_task_inst.write(addr, data);

        end
    end

    reg [7:0] cmp_latch1;
    reg [7:0] cmp_latch2;
    reg       cmp_error;

    always @(posedge clk) begin
        if (!rstn) begin
            cmp_latch1 <= 0;
            cmp_latch2 <= 0;
            cmp_error  <= 0;
        end else begin
            if (s_tvalid & s_tready) begin
                cmp_latch1 <= s_tdata;
                cmp_latch2 <= cmp_latch1;
            end

            if (m_tvalid & m_tready) begin
                cmp_error <= cmp_latch2 != m_tdata;
            end
        end
    end

    always #(TIMEPERIOD / 2) clk = !clk;

    // reset block
    initial begin
        rstn = 1'b0;
        #(TIMEPERIOD * 32);
        rstn = 1'b1;
    end

    initial begin
        begin
            #40000;
            $finish;
        end
    end

    // record block
    initial begin
        $dumpfile("sim/test_tb.vcd");
        $dumpvars(0, uart_top_tb);
    end

endmodule

// verilog_format: off
`resetall
// verilog_format: on

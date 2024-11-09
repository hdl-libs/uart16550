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

// Register addresses
`define UART_REG_RB `UART_ADDR_WIDTH'd0	// receiver buffer
`define UART_REG_TR `UART_ADDR_WIDTH'd0	// transmitter
`define UART_REG_IE `UART_ADDR_WIDTH'd1	// Interrupt enable
`define UART_REG_II `UART_ADDR_WIDTH'd2	// Interrupt identification
`define UART_REG_FC `UART_ADDR_WIDTH'd2	// FIFO control
`define UART_REG_LC `UART_ADDR_WIDTH'd3	// Line Control
`define UART_REG_MC `UART_ADDR_WIDTH'd4	// Modem control
`define UART_REG_LS `UART_ADDR_WIDTH'd5	// Line status
`define UART_REG_MS `UART_ADDR_WIDTH'd6	// Modem status
`define UART_REG_SR `UART_ADDR_WIDTH'd7	// Scratch register
`define UART_REG_DL1 `UART_ADDR_WIDTH'd0	// Divisor latch bytes (1-2)
`define UART_REG_DL2 `UART_ADDR_WIDTH'd1

// Line Control register bits
`define UART_LC_BITS 1:0	// bits in character
`define UART_LC_SB 2	// stop bits
`define UART_LC_PE 3	// parity enable
`define UART_LC_EP 4	// even parity
`define UART_LC_SP 5	// stick parity
`define UART_LC_BC 6	// Break control

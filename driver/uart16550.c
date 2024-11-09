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
/**
 * @file uart16550.c
 * @brief
 * @author
 *
 * Revision History :
 * ----------  -------  -----------  ----------------------------
 * Date        Version  Author       Description
 * ----------  -------  -----------  ----------------------------
 * 2024.11.09  1.0.0    johntito
 * ----------  -------  -----------  ----------------------------
**/

#include "uart16550.h"
#include <stdlib.h>
#include "xil_io.h"

#define FPGA_CLK_FREQ 150E6f
#define UART_OVSR 8

int gcd(int m, int n)
{
    if (m == 0)
    {
        return abs(n);
    }
    if (n == 0)
    {
        return abs(m);
    }
    return gcd(n, m % n);
}

int uart16550_SetBaud(uart16550_t *dev, uint32_t baudrate)
{
    if (!dev)
        return -1;

    if (baudrate == 0 || baudrate > FPGA_CLK_FREQ / UART_OVSR)
        return -2;

    uint32_t baud_freq = UART_OVSR * baudrate / gcd(FPGA_CLK_FREQ, UART_OVSR * baudrate);
    uint32_t baud_limit = FPGA_CLK_FREQ / gcd(FPGA_CLK_FREQ, UART_OVSR * baudrate) - baud_freq;

    if (baud_freq == 0 || baud_freq > 0x00000FFF || baud_limit == 0 || baud_limit > 0x0000FFFF)
    {
        return -3;
    }

    bool old_state = dev->ctrl.tx_enable;
    if (old_state)
    {
        uart16550_SetEnable(dev, false);
    }

    dev->baud_freq = baud_freq;
    dev->baud_limit = baud_limit;

    Xil_Out32(dev->baseaddr + offsetof(uart16550_t, baud_freq), dev->baud_freq);
    Xil_Out32(dev->baseaddr + offsetof(uart16550_t, baud_limit), dev->baud_limit);

    dev->baud_freq = Xil_In32(dev->baseaddr + offsetof(uart16550_t, baud_freq));
    dev->baud_limit = Xil_In32(dev->baseaddr + offsetof(uart16550_t, baud_limit));

    if (old_state)
    {
        uart16550_SetEnable(dev, true);
    }

    return 0;
}

int uart16550_SetLineControlReg(uart16550_t *dev, uart16550_line_ctrl_t config)
{
    if (!dev)
        return -1;

    bool old_state = dev->ctrl.tx_enable;
    if (old_state)
    {
        uart16550_SetEnable(dev, false);
    }

    dev->ctrl.all = dev->ctrl.all | (config.all << 8);

    Xil_Out32(dev->baseaddr + offsetof(uart16550_t, ctrl), dev->ctrl.all);

    if (old_state)
    {
        uart16550_SetEnable(dev, true);
    }

    return 0;
}

int uart16550_GetStatus(uart16550_t *dev, uart16550_status_t *status)
{
    if (!dev)
        return -1;

    dev->status.all = Xil_In32(dev->baseaddr + offsetof(uart16550_t, status));

    status->all = dev->status.all;

    return 0;
}

int uart16550_SetEnable(uart16550_t *dev, bool enable)
{
    if (!dev)
        return -1;

    dev->ctrl.all = Xil_In32(dev->baseaddr + offsetof(uart16550_t, ctrl));

    if (enable)
    {
        dev->ctrl.all = dev->ctrl.all | 0x3;
    }
    else
    {
        dev->ctrl.all = dev->ctrl.all & 0xFFFFFFF0;
    }

    Xil_Out32(dev->baseaddr + offsetof(uart16550_t, ctrl), dev->ctrl.all);

    return 0;
}

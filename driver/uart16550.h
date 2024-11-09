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
 * @file uart16550.h
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

/******************************************************************************/
/************************ Copyright *******************************************/
/******************************************************************************/

#ifndef _UART16550_H_
#define _UART16550_H_

#ifdef __cplusplus
extern "C"
{
#endif

    /******************************************************************************/
    /************************ Include Files ***************************************/
    /******************************************************************************/

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

    /******************************************************************************/
    /************************ Marco Definitions ***********************************/
    /******************************************************************************/

    /******************************************************************************/
    /************************ Types Definitions ***********************************/
    /******************************************************************************/

typedef union uart16550_line_ctrl_t
{
    struct
    {
        uint8_t data_bits : 2;    // bit 8:9
        uint8_t stop_bits : 1;    // bit 10
        uint8_t parity_en : 1;    // bit 11
        uint8_t even_parity : 1;  // bit 12
        uint8_t stick_parity : 1; // bit 13
        uint8_t force_break : 1;  // bit 14
        uint8_t echo : 1;         // bit 15
    };
    uint8_t all;
} uart16550_line_ctrl_t;

typedef union uart16550_ctrl_t
{
    struct
    {
        uint32_t tx_enable : 1;          // bit 0
        uint32_t rx_enable : 1;          // bit 1
        uint32_t tx_clr : 1;             // bit 2
        uint32_t rx_clr : 1;             // bit 3
        uint32_t : 4;                    // bit 4:7
        uart16550_line_ctrl_t line_ctrl; // bit 8:15
        uint32_t : 16;                   // bit 16:31
    };
    uint32_t all;
} uart16550_ctrl_t;

typedef union uart16550_status_t
{
    struct
    {
        uint32_t sts_tx_busy : 1;          // bit 0
        uint32_t : 3;                      // bit 1:3
        uint32_t sts_rx_busy : 1;          // bit 4
        uint32_t sts_rx_break_error : 1;   // bit 5
        uint32_t sts_rx_parity_error : 1;  // bit 6
        uint32_t sts_rx_framing_error : 1; // bit 7
    };
    uint32_t all;
} uart16550_status_t;

typedef struct uart16550_t
{
    uart16550_ctrl_t ctrl;
    uart16550_status_t status;
    uint32_t baud_freq;
    uint32_t baud_limit;
    uint32_t tx_cnt;
    uint32_t rx_cnt;
    uint32_t rx_overflow;
    uint32_t user_gpoe;
    uint32_t user_gpo;
    uint32_t user_gpi;
    uint32_t oe_wait_time;
    uint32_t oe_hold_time;
    uint32_t baseaddr;
} uart16550_t;

    /******************************************************************************/
    /************************ Functions Declarations ******************************/
    /******************************************************************************/
extern int uart16550_SetEnable(uart16550_t *dev, bool enable);
extern int uart16550_SetBaud(uart16550_t *dev, uint32_t baudrate);
extern int uart16550_SetLineControlReg(uart16550_t *dev, union uart16550_line_ctrl_t config);
extern int uart16550_GetStatus(uart16550_t *dev, uart16550_status_t *status);

    /******************************************************************************/
    /************************ Variable Declarations *******************************/
    /******************************************************************************/

#ifdef __cplusplus
}
#endif

#endif // _UART16550_H_
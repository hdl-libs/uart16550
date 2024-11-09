
VVP_INCLUDEDIR=
VVP_INCLUDEDIR+=-I ./src
VVP_INCLUDEDIR+=-I ./sim

VVP_CFLAGS=
VVP_CFLAGS+=-g2005-sv

VVP_SRCS=

VVP_SRCS+= D:/ProgramFiles/modelsim_dlx64_10.6c/vivado2018.3_lib/sim_comm/apb_task.v
VVP_SRCS+= ./src/uart_top.v
VVP_SRCS+= ./src/uart_apb.v
VVP_SRCS+= ./src/uart_receiver.v
VVP_SRCS+= ./src/uart_transmitter.v
VVP_SRCS+= ./sim/uart_top_tb.v

// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Tue Mar 26 11:34:01 2024
// Host        : James-PC-AMD running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               {c:/Users/jrhol/OneDrive/Documents/University_Of_Nottingham/EEE/Year_4/EEEE4123_VHDL/VHDL
//               Project/MatProcCore/MatProcCore.srcs/sources_1/ip/dpram256x56/dpram256x56_stub.v}
// Design      : dpram256x56
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a15tcpg236-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_2,Vivado 2018.3" *)
module dpram256x56(clka, wea, addra, dina, clkb, enb, addrb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,wea[0:0],addra[7:0],dina[55:0],clkb,enb,addrb[7:0],doutb[55:0]" */;
  input clka;
  input [0:0]wea;
  input [7:0]addra;
  input [55:0]dina;
  input clkb;
  input enb;
  input [7:0]addrb;
  output [55:0]doutb;
endmodule

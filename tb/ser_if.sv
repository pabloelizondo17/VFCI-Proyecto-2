`ifndef SER_IF_SV
`define SER_IF_SV

interface ser_if (input logic clk, input logic rst);
  //Señales de control del bus serial
  logic srx_pad_i = 1'b1;
  logic stx_pad_o;

  //Contador de ciclos de reloj
  longint unsigned clk_counter       = 0;
  always @(posedge clk) clk_counter <= clk_counter + 1;

  //Clocking block para driver del bus serial
  clocking ser_driver_cb @(posedge clk);
    default input #1step output #1;
    output srx_pad_i;  
  endclocking 

  //Clocking block para el monitor del bus serial
  clocking ser_monitor_cb @(posedge clk);
        default input #1step;
        input srx_pad_i, stx_pad_o, clk_counter;  
  endclocking 

  //Modport para el driver el bus serial
  modport ser_driver_mp ( clocking ser_driver_cb,output srx_pad_i, input rst);

  //Modport para el monitor del bus serial
  modport ser_monitor_mp (clocking ser_monitor_cb, input rst);

endinterface: ser_if 
`endif //SER_IF_SV
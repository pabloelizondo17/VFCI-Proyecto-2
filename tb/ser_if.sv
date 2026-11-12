`ifndef SERIAL_IF_SV
`define SERIAL_IF_SV

interface serial_if (input logic clk, input logic rst);
  //Lineas de datos del puerto serial 
  logic srx_pad_i = 1'b1;
  logic stx_pad_o;

  //Contador de ciclos de reloj
  longint unsigned clk_counter       = 0;
  always @(posedge clk) clk_counter <= clk_counter + 1;

  //Clocking block para driver del bus serial
  clocking serial_driver_cb @(posedge clk);
    default input #1step output #1;
    output srx_pad_i;  
  endclocking 

  //Clocking block para el monitor del bus serial
  clocking serial_monitor_cb @(posedge clk);
        default input #1step;
        input srx_pad_i, stx_pad_o, clk_counter;  
  endclocking 

  //Modport para el driver el bus serial
  modport serial_driver_mp ( clocking serial_driver_cb,output srx_pad_i, input rst);

  //Modport para el monitor del bus serial
  modport serial_monitor_mp (clocking serial_monitor_cb, input rst);

endinterface: serial_if 
`endif //SERIAL_IF_SV
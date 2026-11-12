`ifndef SER_IF_SV
`define SER_IF_SV

interface ser_if (input logic clk, input logic rst);
  //Señales de control del bus serial

  //Contador de ciclos de reloj
  longint unsigned clk_counter       = 0;
  always @(posedge clk) clk_counter <= clk_counter + 1;

  //Clocking block para driver del bus serial
  clocking ser_driver_cb @(posedge clk);
    default input #1step output #1;
    output ;  
    input ;
  endclocking 

  //Clocking block para el monitor del bus serial
  clocking ser_monitor_cb @(posedge clk);
        default input #1step;
        input ;  
  endclocking 

  //Modport para el driver el bus serial
  serport ser_driver_mp ( clocking ser_driver_cb, input rst);

  //Modport para el monitor del bus serial
  serport ser_monitor_mp (clocking ser_monitor_cb, input rst);

endinterface: ser_if 
`endif //SER_IF_SV
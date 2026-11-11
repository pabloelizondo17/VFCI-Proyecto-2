`ifndef MOD_IF_SV
`define MOD_IF_SV

interface mod_if (input logic clk, input logic rst);
  //Señales de control del modem
  logic rts_pad_o;
  logic dtr_pad_o;
  logic ri_pad_i; 
  logic dsr_pad_i;
  logic cts_pad_i;
  logic dcd_pad_i;
  logic int_o;

  //Contador de ciclos de reloj
  longint unsigned clk_counter       = 0;
  always @(posedge clk) clk_counter <= clk_counter + 1;

  //Clocking block para driver del modem
  clocking mod_driver_cb @(posedge clk);
    default input #1step output #1;
    output cts_pad_i, dsr_pad_i, ri_pad_i, dcd_pad_i;  
    input rts_pad_o, dtr_pad_o, int_o;
  endclocking 

  //Clocking block para el monitor del modem
  clocking mod_monitor_cb @(posedge clk);
        default input #1step;
        input cts_pad_i, dsr_pad_i, ri_pad_i, dcd_pad_i, rts_pad_o, dtr_pad_o, int_o, clk_counter;  
  endclocking 

  //Modport para el driver el modem
  modport mod_driver_mp ( clocking mod_driver_cb, input rst);

  //Modport para el monitor del modem 
  modport mod_monitor_mp (clocking mod_monitor_cb, input rst);

endinterface: mod_if 
`endif //MOD_IF_SV
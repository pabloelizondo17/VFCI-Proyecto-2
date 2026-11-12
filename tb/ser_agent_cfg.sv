`ifndef SERIAL_AGENT_CFG_SV
`define SERIAL_AGENT_CFG_SV

class serial_agent_cfg extends uvm_object;
  
  //Registro en fábrica
  `uvm_object_utils(serial_agent_cfg)

  //Handle a la interfaz real
  virtual serial_if vif;

  //Modo del agente
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  //Line configuration
  bit [15:0]   dl   = 16'd0;  //Divisor (DL = 0: sin actividad serial)
  int unsigned data_bits = 8;      //5, 6, 7 u 8
  int unsigned stop_half   = 2;      //Bits de parada
  bit          pe   = 1'b0;   //LCR[3]
  bit          ep   = 1'b0;   //LCR[4]: 1 = par, 0 = impar
  bit          sp   = 1'b0;   //LCR[5]: paridad fija
  bit          bc   = 1'b0;   //LCR[6]: break en TX (stx forzado a 0)
 
  //Knobs
  //Porcentajes de caracteres RX con error: se sortean una vez por época
  int unsigned parity_err_pct_min = 5;   //Porcentaje de caracteres con error de paridad
  int unsigned parity_err_pct_max = 5;
  int unsigned frame_err_pct_min  = 5;   //Porcentaje de caracteres con el bit de frame en 0
  int unsigned frame_err_pct_max  = 5;
  int unsigned break_pct_min      = 2;   //Porcentaje de caracteres que en realidad son un break
  int unsigned break_pct_max      = 2;
  int unsigned glitch_pct_min     = 2;   //Porcentaje de caracteres que llevan un pulso corto
  int unsigned glitch_pct_max     = 2;
 
  //Desviación de baudios
  int unsigned baud_out_pct_min   = 10;  //Porcentaje de caracteres fuera de tolerancia (por época)
  int unsigned baud_out_pct_max   = 10;
  int unsigned baud_dev_min       = 0;   //Magnitud dentro de tolerancia (por carácter)
  int unsigned baud_dev_max       = 2;
  int unsigned baud_out_dev_min   = 4;   //Magnitud fuera de tolerancia (por carácter)
  int unsigned baud_out_dev_max   = 10;
 
  //Tiempos, en tiempos de bit (por carácter)
  int unsigned gap_min            = 0;   //Separación entre caracteres RX
  int unsigned gap_max            = 20;
  int unsigned break_len_min      = 1;   //Bits extra en 0 después de una trama completa
  int unsigned break_len_max      = 20;
 
  //Caracteres por época
  int unsigned n_items_min        = 20;  
  int unsigned n_items_max        = 100;
  
  //Agregar limitaciones para que se cumpla min menor que max

  //Constructor
  function new(string name = "serial_agent_cfg");
    super.new(name);
  endfunction

  // Decodifica LCR y DL a la configuración de línea
  function void set_line(bit [7:0] lcr, bit [15:0] dl);
    this.dl   = dl;
    data_bits = 5 + lcr[1:0];                    //00->5, 01->6, 10->7, 11->8
    if (lcr[2] == 1'b0)   stop_half = 2;         //1 bit de parada
    else if (data_bits == 5) stop_half = 3;      //1,5 bits con 5 bits de datos
    else                  stop_half = 4;         //2 bits en los demás casos
    pe = lcr[3];
    ep = lcr[4];
    sp = lcr[5];
    bc = lcr[6];
  endfunction
 
  //Ciclos de reloj por bit nominal (0 si DL = 0)
  function int unsigned bit_cycles();
    return 16 * dl;
  endfunction

endclass: serial_agent_cfg

`endif //SERIAL_AGENT_CFG_SV
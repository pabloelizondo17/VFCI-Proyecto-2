`ifndef SERIAL_SEQ_ITEM_SV
`define SERIAL_SEQ_ITEM_SV

typedef enum {SERIAL_TX, SERIAL_RX} serial_dir_e;  //Direccion de los datos
typedef enum {GLITCH_NONE, GLITCH_START} glitch_e; //Tipo de glith

class serial_seq_item extends uvm_sequence_item;

  //Señales de estímulo  
  rand bit [7:0] data; //Utiliza los bits mas bajos (la cantidad depende del formato)

  //Errores inyectados
  rand bit parity_err; //Invierte bit de paridad
  rand bit frame_err; //Primer bit de parada  0
  rand bit is_break; //Caracter es un break (anula pe y fe)
  rand int unsigned break_len;//Bits extra en 0 despues de trama

  //Estimulos de glitch
  rand glitch_e glitch; //Tipos de glitch 

  //Tiempos
  rand int baud_dev_pct; //Porcentaje de desviacion (-4% es un 4% mas lento)
  rand int unsigned gap; //Tiempo en reposo antes del caracter (tiempo en bit)

  //Señales que reporta el monitor 
  serial_dir_e dir; //Linea de la que viene el item
  int unsigned data_bits; //Formato de la deco (5,6,7,8)
  bit parity_bit; //Bit de paridad observado
  bit stop_bit_ok; //1 si el bit de parada fue 1
  bit break_visto; //Se activo break (linea en 0 mas de una trama completa)
  longint unsigned cycle; //clk_counter cuanod se termina el caracter

  //Registro en la fábrica
  `uvm_object_utils_begin(serial_seq_item)
    //Lo que produce el DUT: se compara
    `uvm_field_int (data,                     UVM_ALL_ON)
    `uvm_field_enum(serial_dir_e, dir,           UVM_ALL_ON)
    `uvm_field_int (data_bits,                UVM_ALL_ON |UVM_DEC)
    `uvm_field_int (parity_bit,               UVM_ALL_ON)
    `uvm_field_int (stop_bit_ok,              UVM_ALL_ON)
    `uvm_field_int (break_visto,              UVM_ALL_ON)
    `uvm_field_int (parity_err,               UVM_ALL_ON | UVM_NOCOMPARE )
    `uvm_field_int (frame_err,                UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int (is_break,                 UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int (break_len,                UVM_ALL_ON | UVM_NOCOMPARE|UVM_DEC)
    `uvm_field_enum(glitch_e, glitch,         UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int (baud_dev_pct,             UVM_ALL_ON | UVM_NOCOMPARE|UVM_DEC)
    `uvm_field_int (gap,                      UVM_ALL_ON | UVM_NOCOMPARE|UVM_DEC)
    `uvm_field_int (cycle,                    UVM_ALL_ON | UVM_NOCOMPARE|UVM_DEC)
  `uvm_object_utils_end

  //Constraints

  // Constructor
    function new(string name = "serial_seq_item"); 
        super.new(name); 
    endfunction


endclass: serial_seq_item
`endif //SERIAL_SEQ_ITEM_SV
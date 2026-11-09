`ifndef MOD_SEQ_ITEM_SV
`define MOD_SEQ_ITEM_SV

typedef enum {RI_NONE, RI_RISE, RI_FALL} ri_edge_e; //Activo en alto *Verificar

class mod_seq_item extends uvm_sequence_item;

  //Señales de estímulo  
  rand bit  dsr_pad_i; 
  rand bit  ri_pad_i;
  rand bit  cts_pad_i; 
  rand bit  dcd_pad_i; 
  rand int unsigned delay; //Ciclos antes de aplicar cambios de señales

  //Señales que reporta el monitor 
  bit  rts_pad_o;
  bit  dtr_pad_o; 
  ri_edge_e ri_edge; //Indica si hubo flanco de RI

  //Registro en la fábrica
  `uvm_object_utils_begin(mod_seq_item)
    `uvm_field_int(dsr_pad_i, UVM_ALL_ON)
    `uvm_field_int(ri_pad_i, UVM_ALL_ON)
    `uvm_field_int(cts_pad_i, UVM_ALL_ON)
    `uvm_field_int(dcd_pad_i, UVM_ALL_ON)
    `uvm_field_int(rts_pad_o, UVM_ALL_ON)
    `uvm_field_int(dtr_pad_o, UVM_ALL_ON)
    `uvm_field_int(delay, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_enum(ri_edge_e, ri_edge, UVM_ALL_ON)
  `uvm_object_utils_end

  //Constraints

  constraint c_delay {soft delay inside {[0:1000]};} //Retardo máximo de 1000 ciclos

  // Constructor
    function new(string name = "mod_seq_item"); 
        super.new(name); 
    endfunction


endclass: mod_seq_item

class mod_intr_item extends uvm_sequence_item;

  //Señal que lee del DUT
  bit  int_o; 
  longint unsigned cycle; //Ciclo de reloj en el que se detectó la interrupción

  //Registro en la fábrica
  `uvm_object_utils_begin(mod_intr_item)
    `uvm_field_int(int_o, UVM_ALL_ON)
    `uvm_field_int(cycle, UVM_ALL_ON | UVM_NOCOMPARE)
  `uvm_object_utils_end

  // Constructor
    function new(string name = "mod_intr_item"); 
        super.new(name); 
    endfunction
endclass : mod_intr_item

`endif //MOD_SEQ_ITEM_SV
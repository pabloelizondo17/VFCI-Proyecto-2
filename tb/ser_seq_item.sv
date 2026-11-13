`ifndef SER_SEQ_ITEM_SV
`define SER_SEQ_ITEM_SV

class ser_seq_item extends uvm_sequence_item;

  //Señales de estímulo  
  
  //Señales que reporta el monitor 

  longint unsigned cycle; //Ciclo (clk_counter) en el que el monitor vio el cambio

  //Registro en la fábrica
  `uvm_object_utils_begin(ser_seq_item)

  `uvm_object_utils_end

  //Constraints
  

  // Constructor
    function new(string name = "ser_seq_item"); 
        super.new(name); 
    endfunction


endclass: ser_seq_item
`endif //MOD_SEQ_ITEM_SV
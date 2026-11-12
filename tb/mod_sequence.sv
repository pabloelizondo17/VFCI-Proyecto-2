`ifndef MOD_SEQUENCE_SV
`define MOD_SEQUENCE_SV

class mod_trafico extends uvm_sequence #(mod_seq_item);
  `uvm_object_utils(mod_traffic_seq)

  //Configuración
  mod_agent_cfg mod_cfg;

  //Cantidad de intervalos a generar
  int unsigned n_items = 50;

  //Constructor
  

  task body();
  
  endtask

endclass: mod_trafico

`endif //MOD_SEQUENCE_SV
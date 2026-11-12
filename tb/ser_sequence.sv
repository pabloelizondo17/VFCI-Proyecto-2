`ifndef SER_SEQUENCE_SV
`define SER_SEQUENCE_SV

class ser_trafico extends uvm_sequence #(ser_seq_item);
  `uvm_object_utils(ser_traffic_seq)

  //Configuración
  ser_agent_cfg ser_cfg;

  //Constructor
  

  task body();
  
  endtask

endclass: ser_trafico

`endif //SER_SEQUENCE_SV
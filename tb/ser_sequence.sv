`ifndef SERIAL_SEQUENCE_SV
`define SERIAL_SEQUENCE_SV

class serial_trafico extends uvm_sequence #(serial_seq_item);
  `uvm_object_utils(serial_trafico)

  //Configuración
  serial_agent_cfg serial_cfg;

  //Constructor
  

  task body();
  
  endtask

endclass: serial_trafico

`endif //SERIAL_SEQUENCE_SV
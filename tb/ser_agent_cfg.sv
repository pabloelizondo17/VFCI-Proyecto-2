`ifndef SER_AGENT_CFG_SV
`define SER_AGENT_CFG_SV

class ser_agent_cfg extends uvm_object;
  
  //Registro en fábrica
  `uvm_object_utils(ser_agent_cfg)

  //Handle a la interfaz real
  virtual ser_if vif;

  //Modo del agente
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  //Knobs para el plan
  tipo nombre = valor;
  
  //Constructor
  function new(string name = "ser_agent_cfg");
    super.new(name);
  endfunction

endclass: ser_agent_cfg

`endif //SER_AGENT_CFG_SV
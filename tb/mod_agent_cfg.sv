`ifndef MOD_AGENT_CFG_SV
`define MOD_AGENT_CFG_SV

class mod_agent_cfg extends uvm_object;
  
  //Registro en fábrica
  `uvm_object_utils(mod_agent_cfg)

  //Handle a la interfaz real
  virtual mod_if vif;

  //Modo del agente
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  //Knobs para el plan
  int unsigned toggle_pct = 10;  //Probabilidad de cambio de señales
  int unsigned toggle_delay_max = 1000;  //Retardo máximo entre cambios de modem
  
  //Constructor
  function new(string name = "mod_agent_cfg");
    super.new(name);
  endfunction

endclass: mod_agent_cfg

`endif //MOD_AGENT_CFG_SV
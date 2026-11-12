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
  int unsigned toggle_porc_min = 0;  //Probabilidad de cambio de señales
  int unsigned toggle_porc_max = 10;  //Probabilidad de cambio de señales

  int unsigned toggle_delay_min = 0;  //Retardo mínimo entre cambios de modem
  int unsigned toggle_delay_max = 1000;  //Retardo máximo entre cambios de modem

  int unsigned n_items_min = 20;  //Mínima cantidad de transacciones
  int unsigned n_items_max = 100;  //Máxima cantidad de transacciones
  
  //Limitaciones para que min sea menor que max
  
  //Constructor
  function new(string name = "mod_agent_cfg");
    super.new(name);
  endfunction

endclass: mod_agent_cfg

`endif //MOD_AGENT_CFG_SV
//------------------------------------------------------------------------------------------
//Archivo para agente de modem
//------------------------------------------------------------------------------------------


//Secuenciador del Modem
uvm_sequencer #(mod_seq_item) mod_seqr;

//Driver del modem
class mod_driver extends uvm_driver #(mod_seq_item);

  `uvm_component_utils(mod_driver)

  //Handle del agente
  mod_agent agent_h;

  //Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  //Build
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(mod_agent)::get(this, "", "agent_h", agent_h))
      `uvm_fatal("AGENT_NOT_FOUND", "No se pudo obtener el handle del agente")
  endfunction
endclass: mod_driver 


//Monitor del modem 
class mod_monitor extends uvm_monitor;

endclass: mod_monitor


//Monitor de interrupciones modem
class intr_monitor extends uvm_monitor; 

endclass: intr_monitor


//Agente del modem
class mod_agent extends uvm_agent;

endclass: mod_agent

`endif //MOD_AGENT_SV
`ifndef MOD_AGENT_SV
`define MOD_AGENT_SV

//------------------------------------------------------------------------------------------
//Archivo para agente de modem
//------------------------------------------------------------------------------------------

//Secuenciador del Modem
uvm_sequencer #(mod_seq_item) mod_seqr;

//Driver del modem
class mod_driver extends uvm_driver #(mod_seq_item);
  `uvm_component_utils(mod_driver)

  //Constructor
  function new(string name = "mod_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual mod_if mod_vif; //Referencia  a la interfaz del modem
  mod_agent cfg; //Referencia al agente del modem 

  //Build
  function void build_phase(uvm_phase phase);
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
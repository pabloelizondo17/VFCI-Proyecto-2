`ifndef MOD_AGENT_SV
`define MOD_AGENT_SV

//------------------------------------------------------------------------------------------
//Archivo para agente de modem
//------------------------------------------------------------------------------------------

//Secuenciador del Modem
typedef uvm_sequencer #(mod_seq_item) mod_seqr;

//Driver del modem
class mod_driver extends uvm_driver #(mod_seq_item);

  `uvm_component_utils(mod_driver)
  mod_agent_cfg mod_cfg; //Referencia a la configuración del agente
  virtual mod_if mod_vif; //Referencia  a la interfaz del modem 

  //Constructor
  function new(string name = "mod_driver", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

  //Build phase del driver
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(mod_agent_cfg)::get(this, "", "cfg", mod_cfg)) begin
      `uvm_fatal("NO CFG", "Driver sin mod_cfg")
    end
    mod_vif = mod_cfg.vif; //Se obtiene la referencia a la interfaz del modem
    endfunction 

//Run phase del driver
  task run_phase(uvm_phase phase);

  endtask 
// 
endclass: mod_driver 


//Monitor del modem 
class mod_monitor extends uvm_monitor;
  `uvm_component_utils(mod_monitor)

  //Constructor
  function new(string name = "mod_monitor", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

  mod_agent_cfg mod_cfg;
  virtual mod_if mod_vif; //Referencia  a la interfaz del modem
  uvm_analysis_port #(mod_seq_item) mod_mon_ap; //Puerto de análisis para monitor

  //Build phase del monitor
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     mod_mon_ap = new("mod_mon_ap", this);
    if (!uvm_config_db#(mod_agent_cfg)::get(this, "", "cfg", mod_cfg)) begin
      `uvm_fatal("NO CFG", "Monitor sin mod_cfg")
    end
    mod_vif = mod_cfg.vif; //Se obtiene la referencia a la interfaz del modem
    endfunction 

    //Run phase del monitor
    task run_phase(uvm_phase phase);
    endtask


endclass: mod_monitor


//Monitor de interrupciones modem
class intr_monitor extends uvm_monitor; 

  `uvm_component_utils(intr_monitor)

  //Constructor
  function new(string name = "intr_monitor", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

  mod_agent_cfg mod_cfg;
  virtual mod_if mod_vif; //Referencia  a la interfaz del modem
  uvm_analysis_port #(mod_intr_item) mod_intr_mon_ap; //Puerto de análisis para interrupciones

  //Build phase del monitor de interrupciones
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mod_intr_mon_ap = new("mod_intr_mon_ap", this);
    if (!uvm_config_db#(mod_agent_cfg)::get(this, "", "cfg", mod_cfg)) begin
      `uvm_fatal("NO CFG", "Monitor de interrupciones sin mod_cfg")
    end
    mod_vif = mod_cfg.vif; //Se obtiene la referencia a la interfaz del modem
    endfunction

  //Run phase del monitor de interrupciones
  task run_phase(uvm_phase phase);

  //Variables 
  bit int_prev;
  bit int_now;
  longint unsigned cycle_count;

  forever begin
    @(mod_vif.mod_monitor_cb); //Se espera un flanco de reloj
    int_now = mod_vif.mod_monitor_cb.int_o;
    cycle_count++; 

    if (int_now != int_prev) begin

    end 


  end 
  endtask
endclass: intr_monitor


//Agente del modem
class mod_agent extends uvm_agent;

endclass: mod_agent

`endif //MOD_AGENT_SV
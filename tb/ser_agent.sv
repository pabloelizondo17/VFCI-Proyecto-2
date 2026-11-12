`ifndef SER_AGENT_SV
`define SER_AGENT_SV

//------------------------------------------------------------------------------------------
//Archivo para agente del bus serial
//------------------------------------------------------------------------------------------

//Secuenciador del agente serial
typedef uvm_sequencer #(ser_seq_item) ser_seqr;

//Driver del bus serial
class ser_driver extends uvm_driver #(ser_seq_item);

  `uvm_component_utils(ser_driver)
  ser_agent_cfg ser_cfg; //Referencia a la configuración del agente
  virtual ser_if ser_vif; //Referencia  a la interfaz del bu serial 

  //Constructor
  function new(string name = "ser_driver", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

    //Build phase del driver
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ser_agent_cfg)::get(this, "", "cfg", ser_cfg)) begin
      `uvm_fatal("NO CFG", "Driver sin ser_cfg")
    end
    ser_vif = ser_cfg.vif; //Se obtiene la referencia a la interfaz del bus serial
    endfunction

  //Valores cuando hay rst
  task reposo(); 
  endtask  

//Run phase del driver
  task run_phase(uvm_phase phase);


  endtask 
// 
endclass: ser_driver 


//Monitor del bus serial
class ser_monitor extends uvm_monitor;
  `uvm_component_utils(ser_monitor)

  //Constructor
  function new(string name = "ser_monitor", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

  ser_agent_cfg ser_cfg;
  virtual ser_if ser_vif; //Referencia  a la interfaz del bus serial

  //Build phase del monitor
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     ser_mon_ap = new("ser_mon_ap", this);
    if (!uvm_config_db#(ser_agent_cfg)::get(this, "", "cfg", ser_cfg)) begin
      `uvm_fatal("NO CFG", "Monitor sin ser_cfg")
    end

    ser_vif = ser_cfg.vif; //Se obtiene la referencia a la interfaz del bus serial
    endfunction 

    //Run phase del monitor
    task run_phase(uvm_phase phase);

    endtask

endclass: ser_monitor


//Agente del bus serial
class ser_agent extends uvm_agent;
  `uvm_component_utils(ser_agent)

  //Constructor
  function new(string name = "ser_agent", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

  //Configuracion  
  ser_agent_cfg ser_cfg;

  //Componentes
  ser_driver   ser_drvr;
  ser_monitor  ser_mon;
  ser_seqr     ser_sequencer;

  //Puertos hacia el ambiente
  uvm_analysis_port #(ser_seq_item) ser_agent_ap;

  //Build phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ser_agent_cfg)::get(this, "", "cfg", ser_cfg)) begin
      `uvm_fatal("NO CFG", "Agente sin ser_cfg")
    end

    //Creacion de los ap
    ser_agent_ap = new("ser_agent_ap", this);

    //Creacion de los monitores
    ser_mon = ser_monitor::type_id::create("ser_monitor", this);

    if (ser_cfg.is_active == UVM_ACTIVE) begin

      ser_drvr = ser_driver::type_id::create("ser_drvr", this);
      ser_sequencer = uvm_sequencer #(ser_seq_item)::type_id::create("ser_sequencer", this);

    end 
    
  endfunction
  //Connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

    endfunction

endclass: ser_agent

`endif //SER_AGENT_SV
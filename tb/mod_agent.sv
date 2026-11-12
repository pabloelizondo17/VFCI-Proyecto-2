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

  task reposo();
    mod_vif.dsr_pad_i <= 1'b0;
    mod_vif.ri_pad_i <= 1'b0;
    mod_vif.cts_pad_i <= 1'b0;
    mod_vif.dcd_pad_i <= 1'b0; 
  endtask  

//Run phase del driver
  task run_phase(uvm_phase phase);

    reposo(); //Se inicializan las señales de entrada del modem
    @(negedge mod_vif.rst); //Se espera a que termine el reset

    forever begin
      seq_item_port.get_next_item(req); //Se obtiene la transacción de la secuencia
      fork 

        //Hilo 1: Aplica el item
        begin
          repeat(req.delay) @(mod_vif.mod_driver_cb); //Se espera req.delay ciclos del cb
          
          @(mod_vif.mod_driver_cb); //Evita pisar el item anterior si delay = 0

          mod_vif.mod_driver_cb.dsr_pad_i <= req.dsr_pad_i;
          mod_vif.mod_driver_cb.ri_pad_i <= req.ri_pad_i;
          mod_vif.mod_driver_cb.cts_pad_i <= req.cts_pad_i;
          mod_vif.mod_driver_cb.dcd_pad_i <= req.dcd_pad_i;
      

        end

        //Hilo 2: Reset a mitad de la transaccion
        begin
          @(posedge mod_vif.rst);
        end  

      join_any
      disable fork;

      if (mod_vif.rst === 1'b1) begin 
        reposo();
        @(negedge mod_vif.rst);
      end

      seq_item_port.item_done();
    end 

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

    //Variables 
      logic rts_prev;
      logic rts_now; 

      logic dtr_prev;
      logic dtr_now;

      logic dsr_prev;
      logic dsr_now;

      logic ri_prev;
      logic ri_now;

      logic dcd_prev;
      logic dcd_now;

      logic cts_prev;
      logic cts_now;

      ri_edge_e ri_edge;

      @(negedge mod_vif.rst); //Se espera a que termine el reset

      //Se inicializan los valores previos con los valores actuales de las señales
      rts_prev = mod_vif.mod_monitor_cb.rts_pad_o;
      dtr_prev = mod_vif.mod_monitor_cb.dtr_pad_o; 
      dsr_prev = mod_vif.mod_monitor_cb.dsr_pad_i; 
      ri_prev = mod_vif.mod_monitor_cb.ri_pad_i; 
      dcd_prev = mod_vif.mod_monitor_cb.dcd_pad_i; 
      cts_prev = mod_vif.mod_monitor_cb.cts_pad_i;  

      forever begin
        @(mod_vif.mod_monitor_cb); //Se espera un flanco de reloj

        //Valor actual de las señales
        rts_now = mod_vif.mod_monitor_cb.rts_pad_o; 
        dtr_now = mod_vif.mod_monitor_cb.dtr_pad_o; 
        dsr_now = mod_vif.mod_monitor_cb.dsr_pad_i; 
        ri_now = mod_vif.mod_monitor_cb.ri_pad_i; 
        dcd_now = mod_vif.mod_monitor_cb.dcd_pad_i;
        cts_now = mod_vif.mod_monitor_cb.cts_pad_i;

        //En caso de que alguna señal cambie, crea transacción y envía a TLM 
        if (rts_now !== rts_prev || dtr_now !== dtr_prev || dsr_now !== dsr_prev || dcd_now !== dcd_prev || cts_now !== cts_prev || ri_now !== ri_prev) begin
          
          mod_seq_item mod_mon_item = mod_seq_item::type_id::create("mod_seq_item");

          //Se asignan valores a la transacción
          mod_mon_item.rts_pad_o = rts_now;
          mod_mon_item.dtr_pad_o = dtr_now;
          mod_mon_item.dsr_pad_i = dsr_now;
          mod_mon_item.ri_pad_i = ri_now;
          mod_mon_item.dcd_pad_i = dcd_now;
          mod_mon_item.cts_pad_i = cts_now;
  

          mod_mon_item.cycle = mod_vif.mod_monitor_cb.clk_counter; //Se obtiene el ciclo actual del reloj

          //Cálculo del flanco de RI
          if (ri_now !== ri_prev) begin
            if (ri_now === 1'b1) begin
              ri_edge = RI_RISE;
            end else begin
              ri_edge = RI_FALL;
            end
          end else begin
            ri_edge = RI_NONE;
          end

          mod_mon_item.ri_edge = ri_edge; //Se asigna el flanco de RI a la transacción
          mod_mon_ap.write(mod_mon_item); //Envía a TLM

          //Actualiza valores previos
          rts_prev = rts_now;
          dtr_prev = dtr_now;
          dsr_prev = dsr_now;
          ri_prev = ri_now;
          dcd_prev = dcd_now;
          cts_prev = cts_now;
        end
      end 

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
    logic int_prev;
    logic int_now;

    @(negedge mod_vif.rst); //Se espera a que termine el reset
    int_prev = mod_vif.mod_monitor_cb.int_o; //Valor inicial

    forever begin
      @(mod_vif.mod_monitor_cb); //Se espera un flanco de reloj
      int_now = mod_vif.mod_monitor_cb.int_o; //Valor actual 

      //Lo único que tiene que hacer es enviar el bit de interrupción y el ciclo en el que ocurrió. 
      if (int_now !== int_prev) begin
        
        mod_intr_item intr_item = mod_intr_item::type_id::create("intr_item");

        intr_item.int_o = int_now;
        intr_item.cycle = mod_vif.mod_monitor_cb.clk_counter; //Se obtiene el ciclo actual del reloj

        mod_intr_mon_ap.write(intr_item); //Envía a TLM

        int_prev = int_now; //Actualiza valor
      end 
    end 
  endtask
endclass: intr_monitor


//Agente del modem
class mod_agent extends uvm_agent;
  `uvm_component_utils(mod_agent)

  //Constructor
  function new(string name = "mod_agent", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

  //Configuracion  
  mod_agent_cfg mod_cfg;

  //Componentes
  intr_monitor intr_mon;
  mod_driver   mod_drvr;
  mod_monitor  mod_mon;
  mod_seqr     mod_sequencer; 

  //Puertos hacia el ambiente
  uvm_analysis_port #(mod_seq_item) mod_agent_ap;
  uvm_analysis_port #(mod_intr_item) mod_agent_intr_ap;

  //Build phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(mod_agent_cfg)::get(this, "", "cfg", mod_cfg)) begin
      `uvm_fatal("NO CFG", "Agente sin mod_cfg")
    end

    //Creacion de los ap
    mod_agent_ap = new("mod_agent_ap", this);
    mod_agent_intr_ap = new("mod_agent_intr_ap", this);

    //Creacion de los monitores
    mod_mon = mod_monitor::type_id::create("mod_monitor", this);
    intr_mon = intr_monitor::type_id::create("intr_monitor", this);

    if (mod_cfg.is_active == UVM_ACTIVE) begin

      mod_drvr = mod_driver::type_id::create("mod_drvr", this);
      mod_sequencer = uvm_sequencer #(mod_seq_item)::type_id::create("mod_sequencer", this);

    end 
    
  endfunction

  //Connect phase
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if(mod_cfg.is_active == UVM_ACTIVE) begin
            mod_drvr.seq_item_port.connect(mod_sequencer.seq_item_export);
        end

        //Conecion de los ap de monitores a los ap del agente
        mod_mon.mod_mon_ap.connect(this.mod_agent_ap);
        intr_mon.mod_intr_mon_ap.connect(this.mod_agent_intr_ap);
    endfunction

endclass: mod_agent

`endif //MOD_AGENT_SV
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
  uvm_analysis_port #(ser_seq_item) ser_drv_ap; //Para mandar lo que se manejó

  //Variables
  real t_clk;      //Periodo del reloj, medido al arrancar
  real t_bit;      //Duración de un bit de este carácter, ya con la desviación
  int unsigned data_bits;  //Copia local del formato (se carga al inicio de cada trama)
  int unsigned stop_half;
  int unsigned dl_ef;      //DL efectivo: DL, o 1 si DL = 0
  bit pe; 
  bit ep; 
  bit sp;

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
    ser_drv_ap = new("ser_drv_ap", this);
    endfunction
  
  //Funcion para obtener maximo de dos valores
  function int unsigned max (int unsigned a, int unsigned b);
    return (a > b) ? a : b;
  endfunction

  //Mide el periodo del reloj
  task medir_tclk();
    realtime t0;
    @(ser_vif.ser_driver_cb);//Primer flanco
    t0 = $realtime;
    @(ser_vif.ser_driver_cb);//Segundo flanco
    t_clk = $realtime - t0; 
    if (t_clk <= 0.0)
     `uvm_fatal("SER_DRV", "No se pudo medir el periodo del reloj")
    `uvm_info("SER_DRV", $sformatf("Periodo de reloj medido: %0.3f", t_clk), UVM_LOW)  
  endtask 

 //Agrega el bit y lo mantiene durante un tiempo determinado
  task poner (bit v, real t);
    ser_vif.srx_pad_i <= v; 
    if (t > 0.0) #(t); //Mantiene el valor durante un tiempo t 
  endtask

  function void cargar_formato (ser_seq_item item);
    //Copia local del formato
    data_bits = ser_cfg.data_bits;
    stop_half = ser_cfg.stop_half;
    pe = ser_cfg.pe;
    ep = ser_cfg.ep;
    sp = ser_cfg.sp;

    dl_ef = (ser_cfg.dl == 0) ? 1 : ser_cfg.dl;

    //Calculo del tiempo de un bit 
    t_bit = 16.0 * dl_ef * t_clk / (1.0 + item.baud_dev_pct / 100.0);
  
    //Lo que ocupa la cobertura 
    item.dir       = SER_RX;
    item.data_bits = data_bits;
  endfunction 

  //Task en el que se instera un glitch al inicio de tx del caracter
  task gap_y_glitch (ser_seq_item item);
    real width; //Tiempo del gap

    //Sin glitch: línea en reposo durante el gap
    if (item.glitch != GLITCH_START) begin
      poner(1'b1, item.gap * t_bit);
      return;
    end

    //De dos ciclos a medio bit
    width = t_clk * $urandom_range(max(8*dl_ef - 3, dl_ef + 2), dl_ef + 2);

    poner(1'b0, width); //El pulso falso

    //Protege el caso de gap < 2
    if (item.gap * t_bit > width)         
      poner(1'b1, item.gap * t_bit - width);

  endtask 

  task trama(ser_seq_item item);
    bit  par_bit;      //Bit de paridad a mandar

    //Pone la linea en 0 durante más de una trama
    if (item.is_break) begin
      poner(1'b0, (1 + data_bits + pe + item.break_len) * t_bit + stop_half * t_bit / 2.0);
      poner(1'b1, t_bit); //Fin del bit
      return;
    end

    //Bit de inicio 
    poner(1'b0, t_bit);

    //Bits de datos, LSB primero
    for (int i = 0; i < data_bits; i++)
      poner(item.data[i], t_bit);

    //Paridad en caso de estar habilitada
    if (pe) begin
      par_bit = ser_cfg.parity_of(item.data, data_bits, ep, sp) ^ item.parity_err; 
      poner(par_bit, t_bit);
    end

    //Parada, el primero lleva el error de trama y el resto se deja en 1
    poner(item.frame_err ? 1'b0 : 1'b1, t_bit);
    if (stop_half > 2)
      poner(1'b1, (stop_half - 2) * t_bit / 2.0); //Medio bit (1,5) o uno entero (2)

  endtask

//Run phase del driver
  task run_phase(uvm_phase phase);

    //Reposo desde el arranque
    ser_vif.srx_pad_i <= 1'b1;

    //Espera el reset completo
    wait (ser_vif.rst === 1'b1);
    wait (ser_vif.rst === 1'b0);

    //Periodo del reloj, una sola vez
    medir_tclk();

    forever begin
      seq_item_port.get_next_item(req);   //Siguiente carácter de la secuencia
      cargar_formato(req);                //Copia el formato y calcula t_bit

      fork
        //Hilo 1: manda el carácter
        begin
          gap_y_glitch(req);              //Gap (con o sin glitch de inicio)
          trama(req);                     //Inicio, datos, paridad y parada (o break)
        end
        //Hilo 2: reset a mitad del carácter
        begin
          @(posedge ser_vif.rst);
        end
      join_any
      disable fork;                       //Mata el hilo que no terminó

      if (ser_vif.rst === 1'b1) begin
        //Hubo reset: línea en reposo ya y esperar a que termine
        ser_vif.srx_pad_i <= 1'b1;
        wait (ser_vif.rst === 1'b0);
      end
      else begin
        //Carácter completo: se publica para la cobertura
        ser_drv_ap.write(req);
      end

      seq_item_port.item_done();        
    end

  endtask
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

  uvm_analysis_port #(ser_seq_item) ser_mon_ap;
  ser_dir_e linea = SER_RX;

  //Build phase del monitor
  virtual function void build_phase(uvm_phase phase);
   super.build_phase(phase);
   ser_mon_ap = new("ser_mon_ap", this);
   if (!uvm_config_db#(ser_agent_cfg)::get(this, "", "cfg", ser_cfg)) begin
      `uvm_fatal("NO CFG", "Monitor sin ser_cfg")
   end
   ser_vif = ser_cfg.vif; //Se obtiene la referencia a la interfaz del bus serial
  endfunction

  //Estado interno
  bit lin = 1'b1;//Último valor visto de la línea (reposo en 1)
  longint unsigned ciclo;//clk_counter del último flanco
  longint unsigned t_baja;//Ciclo en que empezó el carácter
  int unsigned nb;//Copia del formato: bits de datos
  int unsigned stop_half;//Copia del formato: parada en mitades de bit
  int unsigned bc;//Ciclos de reloj por bit nominal
  bit pe; //Copia del formato: paridad habilitada

  //Avanza un ciclo y actualiza la linea 
  task paso();
   @(ser_vif.ser_monitor_cb);
   ciclo = ser_vif.ser_monitor_cb.clk_counter;
   lin   = (linea == SER_RX) ? ser_vif.ser_monitor_cb.srx_pad_i : ser_vif.ser_monitor_cb.stx_pad_o;
  endtask

  //Espera n cantidad de ciclos para luego avanzar y actualizar linea
  task esperar(int unsigned n);
    repeat (n) paso();
  endtask

  //Carga el formato 
  function void cargar_formato();
    nb = ser_cfg.data_bits;
    stop_half = ser_cfg.stop_half;
    pe = ser_cfg.pe;
    bc = 16 * ((ser_cfg.dl == 0) ? 1 : ser_cfg.dl);   //Igual que el driver con DL = 0
  endfunction
  
  //Se pone en reposo
  task reposo();
    while (lin != 1'b0) paso(); //Espera a ver la línea en 0: el bit de inicio
    t_baja = ciclo; //Ciclo en que empezó el carácter
  endtask

  task decodificar(ser_seq_item it, output bit valido);
    cargar_formato(); //Formato congelado para este carácter

    //Validación del inicio a medio bit
    esperar(bc / 2);
    if (lin == 1'b1) begin //Volvió a 1: era un glitch, no un inicio
      valido = 1'b0;
      return;
    end

    //Datos, LSB primero, en el centro de cada bit
    for (int i = 0; i < nb; i++) begin
      esperar(bc);
      it.data[i] = lin;
    end

    //Paridad, si el formato la usa
    if (pe) begin
      esperar(bc);
      it.parity_bit = lin;
    end

    //Primer bit de parada
    esperar(bc);
    it.stop_ok = lin;

    //Etiqueta del item
    it.dir       = linea;
    it.data_bits = nb;
    valido       = 1'b1;
  endtask

  task cierre(ser_seq_item item);
    int unsigned trama; //Duración de una trama completa, en ciclos

    //Parada en 1: carácter normal
    if (item.stop_ok) begin
      reportar(item);
      return;
    end

    //Parada en 0: error de trama o break. Se espera mirando la línea.
    trama = (1 + nb + pe) * bc + stop_half * bc / 2;
    while (lin == 1'b0 && (ciclo - t_baja) < trama)
      paso();

    if (lin == 1'b0) begin
      //Siguió en 0 toda la trama: es un break
      item.break_visto = 1'b1;
      item.data        = '0;
      item.parity_bit  = 1'b0;
      reportar(item); //Se reporta ya, como hace el DUT
      while (lin == 1'b0) paso(); //Espera el fin del break
    end
    else begin
      //Subió antes: carácter con error de trama
      reportar(item);
    end
  endtask

  //Publica el item con el ciclo actual
  function void reportar(ser_seq_item it);
    it.cycle = ciclo;
    ser_mon_ap.write(it);
  endfunction

  //Run phase del bus serial
  task run_phase(uvm_phase phase);
    ser_seq_item it;
    bit valido;

    //Espera el reset completo
    wait (ser_vif.rst === 1'b1);
    wait (ser_vif.rst === 1'b0);

    forever begin
      fork
        //Hilo 1: decodifica caracteres uno tras otro
        forever begin
          reposo();//Espera un inicio
          it = ser_seq_item::type_id::create("ser_mon_item");
          decodificar(it, valido);//Lee los bits
          if (valido)
            cierre(it);//Trama, error o break, y reporta
        end
        //Hilo 2: reset en cualquier momento
        @(posedge ser_vif.rst);
      join_any
      disable fork;//Corta el carácter a medias

      //Hubo reset: se descarta lo que se estaba leyendo y se reinicia el estado
      wait (ser_vif.rst === 1'b0);
      lin = 1'b1;
    end
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
  ser_monitor  ser_mon_rx;
  ser_monitor  ser_mon_tx;
  ser_seqr     ser_sequencer;

  //Puertos hacia el ambiente
  uvm_analysis_port #(ser_seq_item) ser_rx_ap;
  uvm_analysis_port #(ser_seq_item) ser_tx_ap;
  uvm_analysis_port #(ser_seq_item) ser_drv_ap;

  //Build phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ser_agent_cfg)::get(this, "", "cfg", ser_cfg)) begin
      `uvm_fatal("NO CFG", "Agente sin ser_cfg")
    end

    //Creacion de los ap
    ser_rx_ap = new("ser_rx_ap", this);
    ser_tx_ap = new("ser_tx_ap", this);
    ser_drv_ap = new("ser_drv_ap", this);

    //Creacion de los monitores
    ser_mon_rx = ser_monitor::type_id::create("ser_monitor_rx", this);
    ser_mon_rx.linea = SER_RX;
    ser_mon_tx = ser_monitor::type_id::create("ser_monitor_tx", this);
    ser_mon_tx.linea = SER_TX;

    if (ser_cfg.is_active == UVM_ACTIVE) begin

      ser_drvr = ser_driver::type_id::create("ser_drvr", this);
      ser_sequencer = uvm_sequencer #(ser_seq_item)::type_id::create("ser_sequencer", this);

    end 
  endfunction

  //Connect phase
 virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    //Monitores hacia el ambiente
    ser_mon_rx.ser_mon_ap.connect(ser_rx_ap);
    ser_mon_tx.ser_mon_ap.connect(ser_tx_ap);

    if (ser_cfg.is_active == UVM_ACTIVE) begin
      ser_drvr.seq_item_port.connect(ser_sequencer.seq_item_export);
      ser_drvr.ser_drv_ap.connect(ser_drv_ap);
    end
 endfunction 

endclass: ser_agent

`endif //SER_AGENT_SV
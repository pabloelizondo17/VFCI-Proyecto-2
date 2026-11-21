`ifndef SERIAL_AGENT_SV
`define SERIAL_AGENT_SV

//------------------------------------------------------------------------------------------
//Archivo para agente del bus serial
//------------------------------------------------------------------------------------------

//Secuenciador del agente serial
typedef uvm_sequencer #(serial_seq_item) serial_seqr;

//Driver del bus serial
class serial_driver extends uvm_driver #(serial_seq_item);

  `uvm_component_utils(serial_driver)
  serial_agent_cfg serial_cfg; //Referencia a la configuración del agente
  virtual serial_if serial_vif; //Referencia  a la interfaz del bu serial
  uvm_analysis_port #(serial_seq_item) serial_drv_ap; //Para mandar lo que se manejó

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
  function new(string name = "serial_driver", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

  //Build phase del driver
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(serial_agent_cfg)::get(this, "", "cfg", serial_cfg)) begin
      `uvm_fatal("NO CFG", "Driver sin serial_cfg")
    end
    serial_vif = serial_cfg.vif; //Se obtiene la referencia a la interfaz del bus serial
    serial_drv_ap = new("serial_drv_ap", this);
    endfunction
  
  //Funcion para obtener maximo de dos valores
  function int unsigned max (int unsigned a, int unsigned b);
    return (a > b) ? a : b;
  endfunction

  //Mide el periodo del reloj
  task medir_tclk();
    realtime t0;
    @(serial_vif.serial_driver_cb);//Primer flanco
    t0 = $realtime;
    @(serial_vif.serial_driver_cb);//Segundo flanco
    t_clk = $realtime - t0; 
    if (t_clk <= 0.0)
     `uvm_fatal("SERIAL_DRV", "No se pudo medir el periodo del reloj")
    `uvm_info("SERIAL_DRV", $sformatf("Periodo de reloj medido: %0.3f", t_clk), UVM_LOW)  
  endtask 

 //Agrega el bit y lo mantiene durante un tiempo determinado
  task poner (bit v, real t);
    serial_vif.srx_pad_i <= v; 
    if (t > 0.0) #(t); //Mantiene el valor durante un tiempo t 
  endtask

  function void cargar_formato (serial_seq_item item);
    //Copia local del formato
    data_bits = serial_cfg.data_bits;
    stop_half = serial_cfg.stop_half;
    pe = serial_cfg.pe;
    ep = serial_cfg.ep;
    sp = serial_cfg.sp;

    dl_ef = (serial_cfg.dl == 0) ? 1 : serial_cfg.dl;

    //Calculo del tiempo de un bit 
    t_bit = 16.0 * dl_ef * t_clk / (1.0 + item.baud_dev_pct / 100.0);
  
    //Lo que ocupa la cobertura 
    item.dir       = SERIAL_RX;
    item.data_bits = data_bits;
  endfunction 

  //Task en el que se instera un glitch al inicio de tx del caracter
  task gap_y_glitch (serial_seq_item item);
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

  task trama(serial_seq_item item);
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
      par_bit = serial_cfg.parity_of(item.data, data_bits, ep, sp) ^ item.parity_err; 
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
    serial_vif.srx_pad_i <= 1'b1;

    //Espera el reset completo
    wait (serial_vif.rst === 1'b1);
    wait (serial_vif.rst === 1'b0);

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
          @(posedge serial_vif.rst);
        end
      join_any
      disable fork;                       //Mata el hilo que no terminó

      if (serial_vif.rst === 1'b1) begin
        //Hubo reset: línea en reposo ya y esperar a que termine
        serial_vif.srx_pad_i <= 1'b1;
        wait (serial_vif.rst === 1'b0);
      end
      else begin
        //Carácter completo: se publica para la cobertura
        serial_drv_ap.write(req);
      end

      seq_item_port.item_done();        
    end

  endtask
endclass: serial_driver 


//Monitor del bus serial
class serial_monitor extends uvm_monitor;
  `uvm_component_utils(serial_monitor)

  //Constructor
  function new(string name = "serial_monitor", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

  serial_agent_cfg serial_cfg;
  virtual serial_if serial_vif; //Referencia  a la interfaz del bus serial

  uvm_analysis_port #(serial_seq_item) serial_mon_ap;
  serial_dir_e linea = SERIAL_RX;

  //Build phase del monitor
  virtual function void build_phase(uvm_phase phase);
   super.build_phase(phase);
   serial_mon_ap = new("serial_mon_ap", this);
   if (!uvm_config_db#(serial_agent_cfg)::get(this, "", "cfg", serial_cfg)) begin
      `uvm_fatal("NO CFG", "Monitor sin serial_cfg")
   end
   serial_vif = serial_cfg.vif; //Se obtiene la referencia a la interfaz del bus serial
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
   @(serial_vif.serial_monitor_cb);
   ciclo = serial_vif.serial_monitor_cb.clk_counter;
   lin   = (linea == SERIAL_RX) ? serial_vif.serial_monitor_cb.srx_pad_i : serial_vif.serial_monitor_cb.stx_pad_o;
  endtask

  //Espera n cantidad de ciclos para luego avanzar y actualizar linea
  task esperar(int unsigned n);
    repeat (n) paso();
  endtask

  //Carga el formato 
  function void cargar_formato();
    nb = serial_cfg.data_bits;
    stop_half = serial_cfg.stop_half;
    pe = serial_cfg.pe;
    bc = 16 * ((serial_cfg.dl == 0) ? 1 : serial_cfg.dl);   //Igual que el driver con DL = 0
  endfunction
  
  //Se pone en reposo
  task reposo();
    while (lin != 1'b0) paso(); //Espera a ver la línea en 0: el bit de inicio
    t_baja = ciclo; //Ciclo en que empezó el carácter
  endtask

  task decodificar(serial_seq_item it, output bit valido);
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
    it.stop_bit_ok = lin;

    //Etiqueta del item
    it.dir       = linea;
    it.data_bits = nb;
    valido       = 1'b1;
  endtask

  task cierre(serial_seq_item item);
    int unsigned trama; //Duración de una trama completa, en ciclos

    //Parada en 1: carácter normal
    if (item.stop_bit_ok) begin
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
  function void reportar(serial_seq_item it);
    it.cycle = ciclo;
    serial_mon_ap.write(it);
  endfunction

  //Run phase del bus serial
  task run_phase(uvm_phase phase);
    serial_seq_item it;
    bit valido;

    //Espera el reset completo
    wait (serial_vif.rst === 1'b1);
    wait (serial_vif.rst === 1'b0);

    forever begin
      fork
        //Hilo 1: decodifica caracteres uno tras otro
        forever begin
          reposo();//Espera un inicio
          it = serial_seq_item::type_id::create("serial_mon_item");
          decodificar(it, valido);//Lee los bits
          if (valido)
            cierre(it);//Trama, error o break, y reporta
        end
        //Hilo 2: reset en cualquier momento
        @(posedge serial_vif.rst);
      join_any
      disable fork;//Corta el carácter a medias

      //Hubo reset: se descarta lo que se estaba leyendo y se reinicia el estado
      wait (serial_vif.rst === 1'b0);
      lin = 1'b1;
    end
  endtask
endclass: serial_monitor

//Agente del bus serial
class serial_agent extends uvm_agent;
  `uvm_component_utils(serial_agent)

  //Constructor
  function new(string name = "serial_agent", uvm_component parent = null); 
    super.new(name, parent); 
  endfunction

  //Configuracion  
  serial_agent_cfg serial_cfg;

  //Componentes
  serial_driver   serial_drvr;
  serial_monitor  serial_mon_rx;
  serial_monitor  serial_mon_tx;
  serial_seqr     serial_sequencer;

  //Puertos hacia el ambiente
  uvm_analysis_port #(serial_seq_item) serial_rx_ap;
  uvm_analysis_port #(serial_seq_item) serial_tx_ap;
  uvm_analysis_port #(serial_seq_item) serial_drv_ap;

  //Build phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(serial_agent_cfg)::get(this, "", "cfg", serial_cfg)) begin
      `uvm_fatal("NO CFG", "Agente sin serial_cfg")
    end

    //Creacion de los ap
    serial_rx_ap = new("serial_rx_ap", this);
    serial_tx_ap = new("serial_tx_ap", this);
    serial_drv_ap = new("serial_drv_ap", this);

    //Creacion de los monitores
    serial_mon_rx = serial_monitor::type_id::create("serial_monitor_rx", this);
    serial_mon_rx.linea = SERIAL_RX;
    serial_mon_tx = serial_monitor::type_id::create("serial_monitor_tx", this);
    serial_mon_tx.linea = SERIAL_TX;

    if (serial_cfg.is_active == UVM_ACTIVE) begin

      serial_drvr = serial_driver::type_id::create("serial_drvr", this);
      serial_sequencer = uvm_sequencer #(serial_seq_item)::type_id::create("serial_sequencer", this);

    end 
  endfunction

  //Connect phase
 virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    //Monitores hacia el ambiente
    serial_mon_rx.serial_mon_ap.connect(serial_rx_ap);
    serial_mon_tx.serial_mon_ap.connect(serial_tx_ap);

    if (serial_cfg.is_active == UVM_ACTIVE) begin
      serial_drvr.seq_item_port.connect(serial_sequencer.seq_item_export);
      serial_drvr.serial_drv_ap.connect(serial_drv_ap);
    end
 endfunction 

endclass: serial_agent

`endif //serial_AGENT_SV
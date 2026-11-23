`ifndef UART_SCOREBOARD_SV
`define UART_SCOREBOARD_SV

// uart_scoreboard.sv

//Un puerto de análisis por monitor
`uvm_analysis_imp_decl(_wb)
`uvm_analysis_imp_decl(_ser_drv)
`uvm_analysis_imp_decl(_ser_tx)
`uvm_analysis_imp_decl(_mod)

class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)

  //Puertos
  uvm_analysis_imp_wb #(wb_seq_item, uart_scoreboard) wb_imp; 
  uvm_analysis_imp_ser_drv #(serial_seq_item, uart_scoreboard) serial_drv_imp; 
  uvm_analysis_imp_ser_tx #(ser_seq_item, uart_scoreboard) serial_tx_imp; 
  uvm_analysis_imp_mod #(mod_seq_item, uart_scoreboard) mod_imp; 

  //Configuración
  uart_scoreboard_cfg cfg;
  virtual wb_if vif;

  //Tipos
  // Carácter recibido por srx
  typedef struct { bit [7:0] data; bit pe, fe, bi; bit compare;} rx_entry_t;

  // Carácter que debe salir por stx
  typedef struct {bit [7:0] data; bit compare;} tx_entry_t;

  //Registros del modelo
  bit [7:0] lcr, ier, mcr, scratch;
  bit [15:0] dl;
  bit [1:0] fcr_tl; // nivel de disparo RX
  bit in_reset;

  //Colas
  tx_entry_t exp_tx[$]; //escrito en THR que todavía no sale por stx
  rx_entry_t rx_q[$]; //recibido por srx que todavía no se lee de RBR

  //LSR y MSR
  bit lsr_oe; // overrun pendiente
  bit [3:0] msr_pins; // {dcd, ri, dsr, cts}
  bit [3:0] msr_delta; // {ddcd, teri, ddsr, dcts}

  //Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    wb_imp = new("wb_imp", this);
    ser_drv_imp = new("ser_drv_imp", this);
    ser_tx_imp = new("ser_tx_imp", this);
    mod_imp = new("mod_imp", this);
  endfunction

  //Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_scoreboard_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "Scoreboard no encontró su cfg")
    vif = cfg.vif;
    if (vif == null)
      `uvm_fatal("NOVIF", "la cfg del scoreboard no tiene vif")
    reset_model();
  endfunction 

  //Run phase
  task run_phase(uvm_phase phase);
    watch_reset();
  endtask

  //Entradas de los monitores

  // Escritura: actualiza el modelo. Lectura: llama al chequeo según la dirección
  function void write_wb(wb_seq_item t);
  endfunction

  // Carácter enviado por srx, entra a cola rx_q con sus errores
  function void write_ser_tx(serial_seq_item item);
    if (in_reset) return;
    if (item.break_visto) return; //Cuando hay un break no se trae un dato que comparar 
    check_tx(item);  
  endfunction

  // Carácter visto en stx, llama a check_tx
  function void write_ser_driver(serial_seq_item item);
    rx_entry_t entrada; //Entrada del scoreboard 
    int dev //Desviacion

    if (in_reset) return; 
    if (mcr[4]) return; //Cuanod hay loopback el receptor ignora srx
    if (dl == 0) return; //DL = 0, receptor detenido 

    //Con FIFO llena el caracter se pierde y queda overrun 
    if (rx_q.size() == 16) begin
      lsr_oe = 1;
      return;  
    end
    
    //Calculo valor absoulto de la desviación
    dev = (item.baud_dev_pct < 0) ? -item.baud_dev_pct : item.baud_dev_pct;

    //Break, DUT guarda 0x00 con BI = 1, sin error de paridad ni trama
    if (item.is_break) begin 
      entrada.data = 8'00;
      entrada.pe = 0;
      entrada.fe = 0;
      entrada.bi = 1; 
    end
    else begin
      entrada.data = item.data & ((1 << item.data_bits)-1) //bits altos en 0
      entrada.pe = item.parity_err;  
      entrada.fe = item.frame_err; 
      entrada.bi = 0;
    end
    entrada.compare = (dev <= cfg.baud_toñ); //No compara el dato si esta fuera de tolerancia       
  endfunction

  // Cambio en los pines del módem: actualiza msr_pins y msr_delta
  function void write_mod(mod_seq_item item);
    bit [3:0] pines_nuevos; 
    pines_nuevos = {item.dcd_pad_i, item.ri_pad_i, item.dst_pad_i, item.cts_pad_i};

    //Hubo un cambio en el pin desde la última lectuta de MSR
    if (!in_reset)
      msr_delta = msr_delta | (pines nuevos ^ msr_pins);
    msr_pins = pines_nuevos

  endfunction

  //Modelo de referencia

  // Cada flanco de rst reinicia el modelo
  task watch_reset();
    forever begin
      @(posedge vif.rst);
      in_reset = 1; 
      reset_model();
      @(negedge vif.rst);
      in_reset = 0; 
    end 
  endtask

  // Valores de los registros luego de reset
  function void reset_model();
    lcr = 8'h03;
    ier = 8'h00;
    mcr = 8'h00;
    scratch = 8'h00; 
    dl = 16'h0000;
    fcr_tl = 2'b11;
    exp_tx.delete(); //Borra cola, lo que había se pierde
    rx_q.delete();  //Borra cola, lo que había se pierde
    lsr_oe = 0;
    msr_delta = 4'h0;
  endfunction

  // Escritura por Wishbone: LCR, DL (con DLAB), IER, FCR, MCR, THR y scratch
  function void do_write(wb_seq_item item);
  endfunction

  // Efecto de una lectura: sacar de RBR, limpiar errores de LSR y deltas de MSR
  function void read_effects(wb_seq_item item);
  endfunction

  //Chequeos

  //El carácter en stx tiene el dato del primero de esperado, en orden
  function void check_tx(ser_seq_item item);
    tx_entry_t esperado; 
    bit [7:0] mascara;

    //Si el caracter que sale no tiene comapare = 0 queda eliminado
    while (esperado.size() > 0 && !esperado[0].compare && esperado[0].data != item.data)
      void'(esperado.pop_front());

      if (esperado.size() == 0) begin
        `uvm_error("CHECK_TX", $sformatf("Salio 0x%02h por stx y nadie lo escribió en THR", item.data))
        return;   
      end

      esperado = esperado.pop_front();
      mascara = (1 << item.data_bits) - 1; //Solo se transmiten los bits de LCR

      if ((item.data & mascara) != (esperado.data & mascara))
      `uvm_error("CHECK_TX", $sformatf("stx: salió 0x%02h, se esperaba 0x%02h", item.data & mascara, esperado.data & mascara))   
  endfunction

  //la lectura de RBR devuelve el primero de rx_q, en orden
  function void check_rbr(wb_seq_item t);
  endfunction

  //DR, errores (PE, FE, BI, OE), THRE y TEMT, solo los bits seguros
  function void check_lsr(wb_seq_item t);
  endfunction

  //Interrupción de mayor prioridad habilitada
  function void check_iir(wb_seq_item t);
  endfunction

  //Pines actuales y deltas; en loopback refleja MCR
  function void check_msr(wb_seq_item t);
  endfunction

  //LCR, IER, DL y scratch devuelven lo escrito; MCR se lee como 0
  function void check_reg(wb_seq_item t);
  endfunction

  //Verificacion de debug 1 y 2 coinciden con el modelo
  function void check_dbg(wb_seq_item t);
  endfunction

  //Check phase
  function void check_phase(uvm_phase phase);
  endfunction

  //Report phase
  function void report_phase(uvm_phase phase);
  endfunction

endclass
`endif //UART_SCOREBOARD_SV
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
  uvm_analysis_imp_wb #(wb_seq_item, uart_scoreboard) wb_imp; // wb_agent.wb_mon_ap
  uvm_analysis_imp_ser_drv #(ser_seq_item, uart_scoreboard) ser_drv_imp; // ser_agent.ser_drv_ap
  uvm_analysis_imp_ser_tx #(ser_seq_item, uart_scoreboard) ser_tx_imp; // ser_agent.ser_tx_ap
  uvm_analysis_imp_mod #(mod_seq_item, uart_scoreboard) mod_imp; // mod_agent.mod_agent_ap

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
  endfunction

  //Run phase
  // Vigila el reset de la vif
  task run_phase(uvm_phase phase);
  endtask

  //Entradas de los monitores

  // Escritura: actualiza el modelo. Lectura: llama al chequeo según la dirección
  function void write_wb(wb_seq_item t);
  endfunction

  // Carácter enviado por srx: entra a rx_q con sus errores
  function void write_ser_drv(ser_seq_item t);
  endfunction

  // Carácter visto en stx: llama a check_tx
  function void write_ser_tx(ser_seq_item t);
  endfunction

  // Cambio en los pines del módem: actualiza msr_pins y msr_delta
  function void write_mod(mod_seq_item t);
  endfunction

  //Modelo de referencia

  // Cada flanco de rst reinicia el modelo; las lecturas siguientes
  // verifican los valores de reset (CHK-RST)
  task watch_reset();
  endtask

  // Valores de reset: LCR = 0x03, IER = 0, MCR = 0, DL = 0, nivel 14, colas vacías
  function void reset_model();
  endfunction

  // Escritura por Wishbone: LCR, DL (con DLAB), IER, FCR, MCR, THR y scratch
  function void do_write(wb_seq_item t);
  endfunction

  // Efecto de una lectura: sacar de RBR, limpiar errores de LSR y deltas de MSR
  function void read_effects(wb_seq_item t);
  endfunction

  //Chequeos

  //El carácter en stx tiene el dato del primero de exp_tx, en orden
  function void check_tx(ser_seq_item t);
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
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
  uvm_analysis_imp_wb #(wb_item_t, uart_scoreboard) wb_imp; 
  uvm_analysis_imp_ser_drv #(serial_seq_item, uart_scoreboard) serial_drv_imp; 
  uvm_analysis_imp_ser_tx #(serial_seq_item, uart_scoreboard) serial_tx_imp; 
  uvm_analysis_imp_mod #(mod_seq_item, uart_scoreboard) mod_imp; 

  //Configuración
  uart_scoreboard_cfg cfg;
  virtual wb_if vif;

  //Tipos
  // Carácter recibido por srx
  typedef struct { bit [7:0] data; bit pe, fe, bi; bit compare; bit recibido; bit lb; longint unsigned t_pub;} rx_entry_t;

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
  bit lsr_oe; //Modelo vio un overrun
  longint unsigned lsr_oe_t; // ciclo en que lo vio
  longint unsigned last_tx_t; // ciclo del último carácter visto en stx
  longint unsigned t_actual; // ciclo de la lectura que se está revisando
  bit [3:0] msr_pins; // {dcd, ri, dsr, cts}
  bit [3:0] msr_delta; // {ddcd, teri, ddsr, dcts}

  //Contadores para reporte
  int unsigned n_comparaciones; //Lecturas y caracterres comparados 
  int unsigned n_resoluciones; //Veces que lo leído decidió entre dos estados válidos

  //Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    wb_imp = new("wb_imp", this);
    serial_drv_imp = new("serial_drv_imp", this);
    serial_tx_imp = new("serial_tx_imp", this);
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


  // Carácter visto en stx, llama a check_tx
  function void write_ser_tx(serial_seq_item item);
    if (in_reset) return;
    if (item.break_visto) return; //Cuando hay un break no se trae un dato que comparar 
    check_tx(item);  
  endfunction

  // Carácter enviado por srx, entra a cola rx_q con sus errores
  function void write_ser_drv(serial_seq_item item);
    rx_entry_t entrada; //Entrada del scoreboard 
    int dev; //Desviacion
    int unsigned nbits; //Bits de datos segpun el LCR del modelo

    if (in_reset) return; 
    if (mcr[4]) return; //Cuanod hay loopback el receptor ignora srx
    if (dl == 0) return; //DL = 0, receptor detenido 

    //Con FIFO llena el caracter se pierde y queda overrun 
    if (rx_q.size() == 16) begin
      lsr_oe = 1;
      lsr_oe_t = vif.clk_counter;
      return;  
    end

    nbits = 5 + lcr[1:0];
    
    //Calculo valor absoulto de la desviación
    dev = (item.baud_dev_pct < 0) ? -item.baud_dev_pct : item.baud_dev_pct;

    //Break, DUT guarda 0x00 con BI = 1, sin error de paridad ni trama
    if (item.is_break) begin 
      entrada.data = 8'h00;
      entrada.pe = 0;
      entrada.fe = 0;
      entrada.bi = 1; 
    end
    else begin
      entrada.data = item.data & ((1 << nbits)-1); //bits altos en 0
      entrada.pe = item.parity_err && lcr[3];  
      entrada.fe = item.frame_err; 
      entrada.bi = 0;
    end
    entrada.compare = (dev <= cfg.baud_tol); //No compara el dato si esta fuera de tolerancia
    entrada.recibido = 0; //Cuando el driver recien lo publica, puede estar o no en el DUT 
    entrada.lb = 0;
    entrada.t_pub = vif.clk_counter;

    rx_q.push_back(entrada);     
  endfunction

  // Cambio en los pines del módem: actualiza msr_pins y msr_delta
  function void write_mod(mod_seq_item item);
    bit [3:0] pines_nuevos; 
    pines_nuevos = {item.dcd_pad_i, item.ri_pad_i, item.dsr_pad_i, item.cts_pad_i};

    //Hubo un cambio en el pin desde la última lectuta de MSR
    if (!in_reset)
      msr_delta = msr_delta | (pines_nuevos ^ msr_pins);
    msr_pins = pines_nuevos;
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
    lsr_oe_t = 0;
    last_tx_t = 0;
  endfunction

  // Escritura por Wishbone: LCR, DL (con DLAB), IER, FCR, MCR, THR y scratch
  function void do_write(wb_seq_item item);
  endfunction

  // Efecto de una lectura: sacar de RBR, limpiar errores de LSR y deltas de MSR
  function void read_effects(bit [2:0] dir);
    if (!lcr[7] && dir == 3'd6) msr_delta = 4'h0;
  endfunction

  //Funciones de apoyo

  //Calculo de la cantidad de ciclos que un caracter puede estar en transito pero que todavia no este en DUT
  function longint unsigned ventana();
    return ((dl == 0) ? 1 : dl) + 6;
  endfunction 
  
  //Ciclos enyte el centro del primer bit de parada y el fin de la trama
  function longint unsigned tx_fin();
    int unsigned mitad_bp;
    mitad_bp = !lcr[2] ? 2 : (lcr[1:0] == 2'b00 ? 3 : 4); //En mitades de bit
    return (mitad_bp - 1)*8*((dl == 0) ? 1 : dl) + ventana(); 
  endfunction 

  //Un caracter ya va a estar en el DUT si el tiempo desde que se publico es mayor al de la ventana
  function void actualizar_recibidos();
    foreach (rx_q[i])
      if (!rx_q[i].recibido && !rx_q[i].lb && t_actual > rx_q[i].t_pub + ventana())
        rx_q[i].recibido = 1;
  endfunction

  //Calcula como se ve la parte de recepcion de LSR si el DUT tiene los primeros k caracteres
  function bit [7:0] lsr_rx (int unsigned k, bit cambio);
    bit [7:0] v;
    v = 8'h00;
    if (k == 0) return v;
    v[0] = 1;
    v[2] = rx_q[0].pe;
    v[3] = cambio ? rx_q[0].bi : rx_q[0].fe;
    v[4] = cambio ? rx_q[0].fe : rx_q[0].bi;
    for (int i = 0; i < k; i++)
      if (rx_q[i].pe || rx_q[i].fe || rx_q[i].bi) v[7] = 1; //Cualquier error de la FIFO
    return v;  
  endfunction

  //Los posibles casos de THRE y TEMT si quedan n caracteres por transmitir
  function bit tx_valido (bit thre, bit temt, int unsigned n);
    if (mcr[4]) return !(!thre && temt);
    if (n == 0) return thre && (temt || t_actual <= last_tx_t + tx_fin());
    if (n == 1) return !temt;
    return !thre && !temt;
  endfunction

  //Chequeos

  //El carácter en stx tiene el dato del primero de esperado, en orden
  function void check_tx(serial_seq_item item);
    tx_entry_t esperado; 
    bit [7:0] mascara;

    //Si el caracter que sale no tiene comapare = 0 queda eliminado
    while (exp_tx.size() > 0 && !exp_tx[0].compare && exp_tx[0].data != item.data)
      void'(exp_tx.pop_front());

      if (exp_tx.size() == 0) begin
        `uvm_error("CHECK_TX", $sformatf("Salio 0x%02h por stx y nadie lo escribió en THR", item.data))
        return;   
      end

      esperado = exp_tx.pop_front();
      mascara = (1 << (5 + lcr[1:0])) - 1; //Solo se transmiten los bits de LCR
      last_tx_t = item.cycle;

      n_comparaciones++;
      if ((item.data & mascara) != (esperado.data & mascara))
        `uvm_error("CHECK_TX", $sformatf("stx: salió 0x%02h, se esperaba 0x%02h", item.data & mascara, esperado.data & mascara))   
  endfunction

  //la lectura de RBR devuelve el primero de rx_q, en orden
  function void check_rbr(bit [7:0] dato);
    rx_entry_t esperado;
    
    //FIFO vacía, el dato no significa nada
    if (rx_q.size() == 0) return;

    //Si el dato coincide, el DUT ya lo tenía, si no, la FIFO del DUT todavía estaba vacía
    if (!rx_q[0].recibido) begin
      n_resoluciones++;
      if (rx_q[0].compare && dato != rx_q[0].data) return;
    end

    esperado = rx_q.pop_front();
    if (!esperado.compare) return;
    
    n_comparaciones++;
    //Error si el dato es diferente al esperado
    if (dato != esperado.data)
      `uvm_error("CHECK RBR", $sformatf("RBR: DUT 0x%02h, se esperaba 0x%02h", dato, esperado.data))
  endfunction

  //Cada vez que se lee LSR, determina cuales son los fields seguros de leer
  //DR[0],OE[1],PE[2],FE[3],BI[4],THRE[5],TEMT[6],-[7]
  function void check_lsr(bit [7:0] dato);
    
    int unsigned k_min;
    int unsigned n_min;
    int unsigned n_max;

    bit ok_rx;
    bit ok_oe;
    bit ok_tx;
    bit oe_transito;

    //eL DUT tiene seguro los primeros k_min bits, los demas tiene que ver
    k_min = 0;
    while (k_min < rx_q.size() && rx_q[k_min].recibido) k_min++;

    ok_rx = 0;
    for (int unsigned k = k_min; k <= rx_q.size(); k++)
     for (int c = 0; c < 2; c++)
      if ((dato & 8'h9D) == lsr_rx (k,c)) ok_rx = 1;

    //Si el overrun está en transito puede valor 0 o 1
    oe_transito = lsr_oe && t_actual <= lsr_oe_t + ventana();
    ok_oe = oe_transito || (dato[1] == lsr_oe);

    //Los caracteres con compare = 0 pueden estar o no
    n_max = exp_tx.size();
    n_min = 0;
    foreach (exp_tx[i]) if (exp_tx[i].compare) n_min++;
    ok_tx = 0;
    for (int unsigned n = n_min; n <= n_max; n++)
      if (tx_valido(dato[5], dato[6], n)) ok_tx = 1;

    n_comparaciones++;
    if (k_min < rx_q.size() || oe_transito) n_resoluciones++; //había más de un estado posible

    //Si ningun dato calza con el DUT
    if (!(ok_rx && ok_oe && ok_tx))
     `uvm_error("CHECK_LSR", $sformatf("LSR: DUT 0x%02h no coincide con ningún estado posible del modelo", dato))  

    //Lo leido decide el estado, si DR = 1, el DUT tenía el primer caracter
    if (dato[0] && rx_q.size() > 0) rx_q[0].recibido = 1;

    //Leer LSR borra el overrun y los errores del primer caracter
    if (!oe_transito || dato[1]) lsr_oe = 0;
    if (rx_q.size() > 0 && rx_q[0].recibido) begin
      rx_q[0].pe = 0;
      rx_q[0].fe = 0;
      rx_q[0].bi = 0;
    end  
  endfunction

  //Interrupción de mayor prioridad habilitada
  function void check_iir(wb_seq_item item);
  endfunction

  //Pines actuales y deltas; en loopback refleja MCR
  function void check_msr(wb_seq_item item);
  endfunction

  //LCR, IER, DL y scratch devuelven lo escrito; MCR se lee como 0
  function void check_reg(wb_seq_item item);
  endfunction

  //Verificacion de debug 1 y 2 coinciden con el modelo
  function void check_dbg(wb_seq_item item);
  endfunction

  //Check phase
  function void check_phase(uvm_phase phase);
  endfunction

  //Report phase
  function void report_phase(uvm_phase phase);
  endfunction

endclass
`endif //UART_SCOREBOARD_SV
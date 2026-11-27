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
  uart_env_cfg env_cfg;
  virtual wb_if vif;

  //Tipos
  // Carácter recibido por srx
  typedef struct { bit [7:0] data; bit pe, fe, bi; bit compare; bit recibido; bit lb; longint unsigned t_pub;} rx_entry_t;

  // Carácter que debe salir por stx
  typedef struct {bit [7:0] data; bit compare;} tx_entry_t;

  // Estado de una causa de interrupción
  typedef enum {EST_NO, EST_SI, EST_DUDA} estado_e;

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

  bit [3:0] msr_pins_ant; // pines antes del último cambio
  bit [3:0] msr_delta_ant; // deltas antes del último cambio

  bit thre_leido; // la interrupción THRE ya se limpió y la FIFO TX no se ha vuelto a llenar
  longint unsigned msr_chg_t; // ciclo del último cambio en los pines del módem

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
    if (!uvm_config_db#(uart_env_cfg)::get(this, "", "env_cfg", env_cfg))
      `uvm_fatal("NOCFG", "Scoreboard no encontró el objeto de configuracion del ambiente")
    vif = env_cfg.wb_cfg.wb_vif;
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
  function void write_wb(wb_item_t item);
    bit [2:0] dir; //registro del UART
    bit [7:0] dato; //byte que se escribió o leyó
    bit debug; //lectura de Debug 1 0 2
    bit sel_invalido; //sel con mas de un bit o ninguno

    if (item.kind == WB_RESET) return; 
    if (in_reset) return;

    t_actual = item.stamp;
    actualizar_recibidos(); //Marca los caracteres que ya seguro están en DUT

    //Ubicar el registro y byte
    debug = 0;
    sel_invalido = 0;
    // bus de 32 bits: addr[4:2] elige la palabra y sel elige el byte
    case (item.sel)

      4'b0001: begin 
        dir = {item.addr[2], 2'd0}; dato = item.data[7:0]; 
      end

      4'b0010: begin 
        dir = {item.addr[2], 2'd1}; dato = item.data[15:8]; 
      end

      4'b0100: begin 
        dir = {item.addr[2], 2'd2}; dato = item.data[23:16]; 
      end

      4'b1000: begin 
        dir = {item.addr[2], 2'd3}; dato = item.data[31:24]; 
      end

      4'b1111: debug = 1;

      default: begin 
        sel_invalido = 1;
        dir = {item.addr[2], 2'd0};
        dato = item.data[7:0];
      end
    endcase

    //Escritura
    if (item.we) begin
      if (!debug) do_write (dir,dato);
      return;  
    end

    //Lectura
    if (debug) begin
      check_dbg(item);
      return;
    end
    if (sel_invalido) begin
      if (item.data != 0)
        `uvm_error("CHECK_REG", $sformatf("lectura con sel = %b devolvió 0x%0h, se esperaba 0", item.sel, item.data))
    return;
    end

    case (dir)
      3'd0: if (!lcr[7]) check_rbr(dato);
            else         check_reg("DLL", dato, dl[7:0]);
      3'd1: if (!lcr[7]) check_reg("IER", dato, ier);
            else         check_reg("DLM", dato, dl[15:8]);
      3'd2: check_iir(dato);
      3'd3: check_reg("LCR", dato, lcr);
      3'd4: check_reg("MCR", dato, 8'h00); 
      3'd5: check_lsr(dato);
      3'd6: check_msr(dato);
      3'd7: check_reg("SR", dato, scratch);
    endcase
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
    entrada.compare = (dev <= env_cfg.serial_cfg.baud_tol); //No compara el dato si esta fuera de tolerancia
    entrada.recibido = 0; //Cuando el driver recien lo publica, puede estar o no en el DUT 
    entrada.lb = 0;
    entrada.t_pub = vif.clk_counter;

    rx_q.push_back(entrada);     
  endfunction

  // Cambio en los pines del módem: actualiza msr_pins y msr_delta
  function void write_mod(mod_seq_item item);
    bit [3:0] pines_nuevos; 
    pines_nuevos = {item.dcd_pad_i, item.ri_pad_i, item.dsr_pad_i, item.cts_pad_i};

    if ((pines_nuevos ^ msr_pins) == 0) return; // cambió solo rts/dtr: no afecta MSR

    // Se guarda el estado anterior
    msr_pins_ant = msr_pins;
    msr_delta_ant = msr_delta;
    msr_chg_t = item.cycle;

    //Hubo un cambio en el pin desde la última lectuta de MSR
    if (!in_reset)
      msr_delta = msr_delta | (pines_nuevos ^ msr_pins);
    msr_pins = pines_nuevos;
  endfunction

  //==================================Modelo de referencia==================================

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
    thre_leido = 0;
    msr_chg_t = 0;
    msr_delta_ant = 4'h0;
  endfunction

  // Escritura por Wishbone: LCR, DL (con DLAB), IER, FCR, MCR, THR y scratch
  function void do_write(bit [2:0] dir, bit [7:0] dato);
    tx_entry_t salida;
    rx_entry_t entrada;

    case (dir)
      3'd0: begin
        if (lcr[7]) dl[7:0] = dato; // con DLAB = 1 es DLL
        else if (mcr[4]) begin
          // loopback: lo escrito en THR llega al propio receptor
          entrada.data = dato & ((1 << (5 + lcr[1:0])) - 1);
          entrada.pe = 0;
          entrada.fe = 0;
          entrada.bi = 0;
          entrada.compare = 1;
          entrada.recibido = 0;
          entrada.lb = 1;
          entrada.t_pub = t_actual;
          if (rx_q.size() < 16) rx_q.push_back(entrada);
          else begin
            lsr_oe = 1;
            lsr_oe_t = t_actual;
          end
        end
        else begin
          // THR. La FIFO TX tiene 16 posiciones más el registro de desplazamiento
          if (exp_tx.size() >= 17) return; // llena seguro: el carácter se pierde
          salida.data = dato;
          // con 16 pendientes puede que haya cabido o no; durante un break no se ve
          salida.compare = !lcr[6] && (exp_tx.size() < 16);
          thre_leido = 0; //Escribir THR vuelve a armar la interrupcion
          exp_tx.push_back(salida);
        end
      end
      3'd1: begin
        if (lcr[7]) dl[15:8] = dato; // DLM
        else begin
          ier = dato & 8'h0F; // IER solo tiene 4 bits
          thre_leido = 0; // habilitar THRE con la FIFO vacía la vuelve a activar
        end
      end
      3'd2: begin
        // FCR
        fcr_tl = dato[7:6];
        if (dato[1]) rx_q.delete(); // limpiar FIFO RX
        if (dato[2] && exp_tx.size() > 0) begin
          // limpiar FIFO TX: el que ya se estaba enviando puede salir o no
          salida = exp_tx[0];
          salida.compare = 0;
          exp_tx.delete();
          exp_tx.push_back(salida);
        end
      end
      3'd3: lcr = dato;
      3'd4: mcr = dato & 8'h1F; // MCR solo tiene 5 bits
      3'd7: scratch = dato; // AMB-01
      default: ; // LSR y MSR son de solo lectura
    endcase
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

  //==================================Chequeos==================================

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
      `uvm_error("CHECK_RBR", $sformatf("RBR: DUT 0x%02h, se esperaba 0x%02h", dato, esperado.data))
  endfunction

    //Registros que solo cambian por el bus: valor exacto
  function void check_reg(string nombre, bit [7:0] dato, bit [7:0] esperado);
    n_comparaciones++;
    if (dato != esperado)
      `uvm_error("CHECK_REG", $sformatf("%s: DUT 0x%02h, se esperaba 0x%02h", nombre, dato, esperado))
  endfunction

  //Cada vez que se lee LSR, determina cuales son los fields seguros de leer
  //DR[0],OE[1],PE[2],FE[3],BI[4],THRE[5],TEMT[6],-[7]
  function void check_lsr(bit [7:0] dato, bit solo_comparar = 0);
    
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

    if (solo_comparar) return; //Debug 1: sin efectos

    //Leer LSR borra el overrun y los errores del primer caracter
    if (!oe_transito || dato[1]) lsr_oe = 0;
    if (rx_q.size() > 0 && rx_q[0].recibido) begin
      rx_q[0].pe = 0;
      rx_q[0].fe = 0;
      rx_q[0].bi = 0;
    end  
  endfunction

  //Interrupción de mayor prioridad habilitada
  function void check_iir(bit [7:0] dato, bit solo_comparar = 0);
    int unsigned k_min, total, nivel, n_min;
    bit oe_transito, err_seguro, err_posible, ok;
    estado_e rls, rda, cti, thre, modem;
    bit [3:0] posibles[$];
    string lista;

    //Nivel de disparo de la FIFO RX
    case (fcr_tl)
      2'b00: nivel = 1;
      2'b01: nivel = 4;
      2'b10: nivel = 8;
      default: nivel = 14;
    endcase

    //Caracteres que el DUT tiene seguro (k_min) y que puede tener (total)
    k_min = 0;
    while (k_min < rx_q.size() && rx_q[k_min].recibido) k_min++;
    total = rx_q.size();

    //RLS: error en el primer carácter del DUT o un overrun
    err_seguro = (k_min >= 1) && (rx_q[0].pe || rx_q[0].fe || rx_q[0].bi);
    err_posible = (total >= 1) && (rx_q[0].pe || rx_q[0].fe || rx_q[0].bi);
    oe_transito = lsr_oe && t_actual <= lsr_oe_t + ventana();
    if (!ier[2]) rls = EST_NO;
    else if (err_seguro || (lsr_oe && !oe_transito)) rls = EST_SI;
    else if (err_posible || oe_transito) rls = EST_DUDA;
    else rls = EST_NO;

    //RDA: la FIFO RX llegó al nivel de disparo
    if (!ier[0]) rda = EST_NO;
    else if (k_min >= nivel) rda = EST_SI;
    else if (total >= nivel) rda = EST_DUDA;
    else rda = EST_NO;

    //Timeout: hay caracteres bajo el nivel de disparo; el tiempo exacto no se modela
    if (!ier[0] || total == 0 || k_min >= nivel) cti = EST_NO;
    else cti = EST_DUDA;

    //THRE: la FIFO TX está vacía y la interrupción no se ha limpiado
    n_min = 0;
    foreach (exp_tx[i]) if (exp_tx[i].compare) n_min++;
    if (!ier[1] || n_min >= 2 || thre_leido) thre = EST_NO;
    else if (exp_tx.size() == 0 && !mcr[4]) thre = EST_SI;
    else thre = EST_DUDA;

    //Módem: algún delta de MSR activo
    if (!ier[3]) modem = EST_NO;
    else if (t_actual <= msr_chg_t + ventana()) modem = EST_DUDA; //cambio muy reciente
    else if (msr_delta != 0) modem = EST_SI;
    else modem = EST_NO;

    //Valores posibles de IIR[3:0], en orden de prioridad.
    //Si una causa seguro está, las de menor prioridad ya no se pueden ver.
    if (rls != EST_NO) posibles.push_back(4'h6);
    if (rls != EST_SI) begin
      if (rda != EST_NO) posibles.push_back(4'h4);
      if (cti != EST_NO) posibles.push_back(4'hC);
      if (rda != EST_SI) begin
        if (thre != EST_NO) posibles.push_back(4'h2);
        if (thre != EST_SI) begin
          if (modem != EST_NO) posibles.push_back(4'h0);
          if (modem != EST_SI) posibles.push_back(4'h1); //ninguna pendiente
        end
      end
    end

    ok = 0;
    foreach (posibles[i]) if (dato[3:0] == posibles[i]) ok = 1;

    n_comparaciones++;
    if (posibles.size() > 1) n_resoluciones++;

    if (!ok || dato[7:4] != 4'hC) begin
      lista = "";
      foreach (posibles[i]) lista = {lista, $sformatf(" %0h", posibles[i])};
      `uvm_error("CHECK_IIR", $sformatf("IIR: DUT 0x%02h, se esperaba 0xC + uno de:%s", dato, lista))
    end

    if (solo_comparar) return; //Debug 1: sin efectos

    //Leer IIR cuando muestra THRE limpia esa interrupción
    if (dato[3:0] == 4'h2) thre_leido = 1;
  endfunction

  //Pines actuales y deltas; en loopback refleja MCR
  function void check_msr(bit [7:0] dato, bit solo_comparar = 0);
    bit [7:0] nuevo, anterior;
    bit reciente;

    //Valor con el último cambio ya visto por el DUT
    if (mcr[4]) nuevo[7:4] = {mcr[3], mcr[2], mcr[0], mcr[1]}; //loopback
    else nuevo[7:4] = msr_pins; //como el RTL, sin complementar
    nuevo[3:0] = msr_delta;

    //Valor si el DUT todavía no vio el último cambio
    anterior[7:4] = mcr[4] ? nuevo[7:4] : msr_pins_ant;
    anterior[3:0] = msr_delta_ant;

    reciente = (t_actual <= msr_chg_t + ventana());

    n_comparaciones++;
    if (reciente) n_resoluciones++;

    if (dato != nuevo && !(reciente && dato == anterior))
      `uvm_error("CHECK_MSR", $sformatf("MSR: DUT 0x%02h, se esperaba 0x%02h", dato, nuevo))

    if (solo_comparar) return;

    //Leer MSR borra los deltas. Si el DUT todavía no veía el cambio, ese delta llega después
    if (reciente && dato == anterior && dato != nuevo) msr_delta = msr_pins ^ msr_pins_ant;
    else msr_delta = 4'h0;
    msr_delta_ant = 4'h0;
  endfunction

  //Verificacion de debug 1 y 2 coinciden con el modelo
  function void check_dbg(wb_item_t item);
    bit [31:0] d;
    int unsigned k_min, n_min, rf, tf;

    d = item.data;

    if (item.addr[4:2] == 3'b010) begin
      //Debug 1: LCR e IER exactos; LSR, IIR y MSR con las reglas de sus registros
      n_comparaciones++;
      if (d[23:16] != lcr)
        `uvm_error("CHECK_DBG", $sformatf("Debug 1, LCR: DUT 0x%02h, se esperaba 0x%02h", d[23:16], lcr))
      if (d[11:8] != ier[3:0])
        `uvm_error("CHECK_DBG", $sformatf("Debug 1, IER: DUT 0x%0h, se esperaba 0x%0h", d[11:8], ier[3:0]))
      check_lsr(d[7:0], 1);
      check_iir({4'hC, d[15:12]}, 1);
      check_msr(d[31:24], 1);
    end
    else if (item.addr[4:2] == 3'b011) begin
      //Debug 2: niveles de las FIFOs, MCR y nivel de disparo
      rf = d[16:12];
      tf = d[7:3];

      k_min = 0;
      while (k_min < rx_q.size() && rx_q[k_min].recibido) k_min++;
      n_min = 0;
      foreach (exp_tx[i]) if (exp_tx[i].compare) n_min++;

      n_comparaciones++;
      if (d[23:22] != fcr_tl)
        `uvm_error("CHECK_DBG", $sformatf("Debug 2, FCR[7:6]: DUT %b, se esperaba %b", d[23:22], fcr_tl))
      if (d[21:17] != mcr[4:0])
        `uvm_error("CHECK_DBG", $sformatf("Debug 2, MCR: DUT 0x%0h, se esperaba 0x%0h", d[21:17], mcr[4:0]))
      //FIFO RX: entre los que el DUT tiene seguro y todos los que puede tener
      if (rf < k_min || rf > rx_q.size())
        `uvm_error("CHECK_DBG", $sformatf("Debug 2, nivel RX: DUT %0d, se esperaba entre %0d y %0d", rf, k_min, rx_q.size()))
      //FIFO TX: el carácter que se está enviando ya no cuenta en la FIFO
      if (tf + 1 < n_min || tf > exp_tx.size())
        `uvm_error("CHECK_DBG", $sformatf("Debug 2, nivel TX: DUT %0d, se esperaba entre %0d y %0d", tf, (n_min > 0) ? n_min - 1 : 0, exp_tx.size()))
    end
  endfunction 

  //Check phase
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (dl == 0 || mcr[4]) return; //Sin transmisión por stx no se espera nada
    foreach (exp_tx[i])
      if (exp_tx[i].compare)
        `uvm_error("CHECK_END", $sformatf("0x%02h se escribió en THR y nunca salió por stx", exp_tx[i].data))
  endfunction

  //Report phase
  function void report_phase(uvm_phase phase);
      real pct;
    pct = (n_comparaciones == 0) ? 0.0 : 100.0 * n_resoluciones / n_comparaciones;
    `uvm_info("SCB", $sformatf("\nResumen del scoreboard\n  comparaciones: %0d\n  resoluciones por lectura: %0d (%0.2f %%)", n_comparaciones, n_resoluciones, pct), UVM_NONE)
  endfunction

endclass
`endif //UART_SCOREBOARD_SV
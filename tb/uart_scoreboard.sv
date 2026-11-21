`ifndef UART_SCOREBOARD_SV
`define UART_SCOREBOARD_SV

// uart_scoreboard.sv

class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)

  //Configuración
  uart_scoreboard_cfg cfg;
  virtual wb_if vif;

  //Constructor
  // Crea las FIFOs de análisis y las FIFOs del modelo
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  //Build phase
  // Obtiene la cfg y la vif, y pone el modelo en valores de reset
  function void build_phase(uvm_phase phase);
  endfunction

  //Run phase
  // Arranca los recolectores en paralelo y el lazo principal
  task run_phase(uvm_phase phase);
  endtask

  //Recolectores: cada transacción se vuelve un evento con su ciclo

  // Mete un evento en la cola; avisa si llega para un ciclo ya procesado (lag corto)
  function void push_evt(uart_evt e);
  endfunction

  // Escrituras y lecturas del monitor Wishbone
  task collect_wb();
  endtask

  // Caracteres que manda el driver serial por srx; se usa para verificar RX
  // porque trae los errores inyectados y baud_dev_pct (plan 10, fila "Datos RX")
  task collect_ser_drv();
  endtask

  // Caracteres que ve el monitor de stx
  task collect_ser_tx();
  endtask

  // Cambios en los pines del módem
  task collect_mod();
  endtask

  // Cambios de int_o
  task collect_intr();
  endtask

  // Cada flanco de rst de la vif se vuelve un evento, igual que en los agentes
  // (plan 10, fila "Estado tras reset")
  task watch_reset();
  endtask

  //Lazo principal

  // En cada ciclo procesa los eventos que ya quedaron atrás del lag
  task main_loop();
  endtask

  // Procesa, en orden, todos los ciclos con eventos hasta el horizonte
  function void process_until(longint unsigned horizon);
  endfunction

  // Procesa los eventos de un ciclo, ordenados por prioridad
  function void process_cycle(longint unsigned c);
  endfunction

  //Despachador

  // Manda cada evento a su función: entradas -> predict, salidas -> check
  function void dispatch(uart_evt e);
  endfunction

  //Modelo de referencia (predict_*)

  // Valores de reset de registros, FIFOs y esperados (F-REG-01)
  function void reset_model();
  endfunction

  // Reset asíncrono: valores de reset y descarta los esperados pendientes (V-RST-01)
  function void predict_reset(bit rst_val, longint unsigned c);
  endfunction

  // Escrituras por Wishbone: LCR, DL, IER, FCR, MCR, THR y scratch (V-REG-03)
  function void predict_write(wb_seq_item t);
  endfunction

  // Valor y máscara esperados de una lectura, con el estado antes de leer
  function uart_rd_exp_t predict_read(wb_seq_item t);
  endfunction

  // Efectos de una lectura: sacar de RBR, limpiar LSR y MSR, THRE por IIR
  function void predict_read_effects(wb_seq_item t);
  endfunction

  // Carácter que entra a la FIFO RX con sus errores (plan 10, fila "Datos RX")
  function void predict_rx_push(ser_seq_item t, longint unsigned c);
  endfunction

  // Resincroniza los tiempos previstos de TX con el carácter visto en stx
  function void predict_tx_obs(ser_seq_item t);
  endfunction

  // Pines del módem: MSR, deltas y su interrupción (plan 10, fila "MSR")
  function void predict_modem(mod_seq_item t);
  endfunction

  // Lo que depende solo del tiempo: TX (THRE, TEMT), timeout y cambios vencidos
  function void advance_time(longint unsigned c);
  endfunction

  //Checker (check_*)

  // Compara una lectura según su dirección: (obs & mask) == (exp & mask)
  function void check_read(wb_seq_item t, uart_rd_exp_t rd_exp);
  endfunction

  // CHK-TX: carácter en stx contra el esperado (plan 10, fila "Datos TX")
  function void check_tx(ser_seq_item t);
  endfunction

  // CHK-MODOUT: cambios de rts y dtr contra MCR (plan 10, fila "Salidas rts/dtr")
  function void check_modout(mod_seq_item t);
  endfunction

  // CHK-INT: cambios de int_o; exacto para causas del bus y del módem,
  // ventana para srx y timeout (plan 10, fila "int_o")
  function void check_int(mod_intr_item t);
  endfunction

  // CHK-END: nada pendiente al final y niveles de FIFOs (plan 10, fila "Niveles de FIFOs")
  function void check_end();
  endfunction

  //Utilidades

  // Cuenta el error y lo reporta con el nombre del chequeo
  function void err(uart_chk_e k, string msg);
  endfunction

  // Ciclos de un bit con el DL actual (16 * DL)
  function longint unsigned bit_cycles();
  endfunction

  // Ciclos de una trama completa con el LCR actual
  function longint unsigned frame_cycles();
  endfunction

  // Retraso del procesamiento: el mayor entre lag_min y lag_frames tramas
  function longint unsigned lag_cycles();
  endfunction

  // El driver publica al terminar la trama, pero el DUT guarda el carácter en
  // el centro del bit de parada: se corrige la estampa
  function longint unsigned rx_push_cycle(ser_seq_item t);
  endfunction

  //Check phase
  // Procesa lo que quedó en la cola y hace las revisiones de cierre
  function void check_phase(uvm_phase phase);
  endfunction

  //Report phase
  // Imprime el resumen por chequeo
  function void report_phase(uvm_phase phase);
  endfunction
endclass
`endif //UART_SCOREBOARD_SV
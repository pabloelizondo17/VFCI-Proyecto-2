// =======================================================
//  Conjunto de clases de configuración
// -------------------------------------------------------
//  Clases de configuración:
//      - uart_env_cfg
//      - uart_dut_cfg
//      -
// =======================================================

`ifndef UART_CFG_SV
`define UART_CFG_SV


// =======================================================
//  Clase de configuración Wishbone (wb_agent_cfg)
// -------------------------------------------------------
//  Lugar de lectura de plusargs:
//   - uart_env_cfg  
// =======================================================
class wb_agent_cfg extends uvm_object;
    `uvm_object_utils(wb_agent_cfg)

    uvm_active_passive_enum is_active = UVM_ACTIVE;
    virtual wb_if           wb_vif;

    int unsigned            delay_min      = 0;
    int unsigned            delay_max      = 10;
    int unsigned            rst_cycles_min = 1;
    int unsigned            rst_cycles_max = 5; 

    // ===== Constructor con la fábrica =====
    function new(string name = "wb_agent_cfg");
        super.new(name); 
    endfunction
endclass : wb_agent_cfg


// =======================================================
//  Clase de configuración Modem (mod_agent_cfg)
// -------------------------------------------------------
//  Lugar de lectura de plusargs:
//   - uart_env_cfg  
// =======================================================
class mod_agent_cfg extends uvm_object;
    `uvm_object_utils(mod_agent_cfg)

    // ===== Handle a la interfaz real ===== 
    virtual mod_if vif;

    // ===== Modo del agente ===== 
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // ===== Constructor con la fábrica =====
    function new(string name = "mod_agent_cfg");
        super.new(name);
    endfunction
endclass: mod_agent_cfg


// =======================================================
//  Clase de configuración Serial (serial_agent_cfg)
// -------------------------------------------------------
//  Lugar de lectura de plusargs:
//   - uart_env_cfg  
// =======================================================
class serial_agent_cfg extends uvm_object;
    `uvm_object_utils(serial_agent_cfg)

    virtual serial_if       vif;
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // ===== Formato de línea ===== 
    bit [15 : 0] dl        = 16'd0;  // Divisor (DL = 0: sin actividad serialial)
    int unsigned data_bits = 8;      // 5, 6, 7 u 8
    int unsigned stop_half = 2;      // Bits de parada
    bit          pe        = 1'b0;   // LCR[3]
    bit          ep        = 1'b0;   // LCR[4]: 1 = par, 0 = impar
    bit          sp        = 1'b0;   // LCR[5]: paridad fija
    bit          bc        = 1'b0;   // LCR[6]: break en TX (stx forzado a 0)

    int unsigned baud_tol = 4;       // Tolerancia del receptor (%)


    // ===== Constructor con la fábrica =====
    function new(string name = "serial_agent_cfg");
        super.new(name);
    endfunction

    // ===== Decodifica LCR y DL a la configuración de línea ===== 
    function void set_line(bit [7:0] lcr, bit [15:0] dl);
        this.dl   = dl;
        data_bits = 5 + lcr[1:0]; // 00->5, 01->6, 10->7, 11->8

        if (lcr[2] == 1'b0) begin
            stop_half = 2;      // 1 bit de parada
        end else if (data_bits == 5) begin
            stop_half = 3;      // 1,5 bits con 5 bits de datos
        end else begin
            stop_half = 4;      // 2 bits en los demás casos
        end    

        pe = lcr[3];
        ep = lcr[4];
        sp = lcr[5];
        bc = lcr[6];
    endfunction

    // ===== Ciclos de reloj por bit nominal (0 si DL = 0) ===== 
    function int unsigned bit_cycles();
        return 16 * dl;
    endfunction

    // ===== Paridad esperada para un dato con el formato dado ===== 
    function bit parity_of(bit [7:0] d, int unsigned nbits, bit ep, bit sp);
        bit [7:0] m = d & ((8'h1 << nbits) - 1); //Solo los bits de datos usados

        if (sp) begin
            return ~ep; //Paridad fija: EPS=0 -> 1, EPS=1 -> 0
        end

        return ep ? ^m : ~^m; //Par : impar
    endfunction
endclass: serial_agent_cfg


// =======================================================
//  Clase de configuración para el DUT
// -------------------------------------------------------
//  Lugar de lectura de plusargs:
//   - uart_env_cfg  
// =======================================================
class uart_dut_cfg extends uvm_object;
    `uvm_object_utils(uart_dut_cfg)

    uart_stim_cfg stim;

    // ===== Knobs modificados por plusargs =====
    int unsigned dl_min = 1, dl_max = 16'hFFFF;

    int unsigned fcr_tl_weights[];         // [00=1,01=4,10=8,11=14] bytes
    int unsigned lcr_bits_char_weights[];  // [00=5,01=6,10=7,11=8] bits
    int unsigned mcr_loopback_weights[];   // [normal,loopback]


    // ===== Registros para configurar el DUT =====
    rand bit [15 : 0] divisor_latch;
    bit      [7 : 0]  dl1_reg, dl2_reg;


    // ===== Fields de IER =====
    rand bit ier_rda, ier_thre, ier_rls, ier_ms;

    // ===== Fields de FCR =====
    rand bit         fcr_rfr, fcr_tfr;
    rand bit [1 : 0] fcr_tl;

    // ===== Fields de MCR =====
    rand bit mcr_dtr, mcr_rts, mcr_out1, mcr_out2, mcr_lb;

    // ===== Fields de LCR =====
    rand bit [1 : 0] lcr_bits;
    rand bit         lcr_sb, lcr_pe, lcr_ep, lcr_sp, lcr_bc;


    // ===== Restricciones para Divisor Latch =====
    constraint c_divisor_latch {
        divisor_latch inside {[dl_min : dl_max]};

        divisor_latch dist {
            [0 : 16'hF]       :/ 35,    // <= rapido
            [16 : 16'hFF]     :/ 30,    // <= medio
            [256 : 16'hFFF]   :/ 30,    // <= medio/lento
            [4096 : 16'hFFFF] :/ 5      // <= lento
        };
    }

    // ===== Restricciones de IER =====
    constraint c_ier {
        // Nota: ier_rda es definido por c_stim_cross
        ier_thre dist {1 := 70,  0 := 30};
        ier_rls  dist {1 := 70,  0 := 30};
        ier_ms   dist {1 := 70,  0 := 30};
    }

    // ===== Restricciones de FCR =====
    constraint c_fcr {
        fcr_rfr dist {1 := 50, 0 := 50}; 
        fcr_tfr dist {1 := 50, 0 := 50};
        fcr_tl dist  {2'b00 := fcr_tl_weights[0], 
                      2'b01 := fcr_tl_weights[1],
                      2'b10 := fcr_tl_weights[2], 
                      2'b11 := fcr_tl_weights[3]};
    }

    // ===== Restricciones de MCR =====
    constraint c_mcr {
        mcr_lb dist {1 := mcr_loopback_weights[1], 
                     0 := mcr_loopback_weights[0]};
    }

    // ===== Restricciones de LCR =====
    constraint c_lcr {
        lcr_bits dist {2'b00 := lcr_bits_char_weights[0], 
                       2'b01 := lcr_bits_char_weights[1],
                       2'b10 := lcr_bits_char_weights[2], 
                       2'b11 := lcr_bits_char_weights[3]};
        lcr_sb dist   {1 := 20, 0 := 80};
        lcr_pe dist   {1 := 80, 0 := 20};
        lcr_ep dist   {1 := 50, 0 := 50}; 
        lcr_sp dist   {1 := 10, 0 := 90};
        lcr_bc dist   {1 := 0,  0 := 100};
    }


    // ===== Variaciones según los estímulos =====
    constraint c_stim_cross {
        if (stim != null) {
            // Polling: sin interrupción de datos disponibles
            if (stim.wb_polling_status) {
                ier_rda == 1'b0;
            } else {
                ier_rda == 1'b1;
            }

            // Errores de paridad inyectados: paridad habilitada + intr
            if (stim.ser_parity_err_pct > 0) {
                lcr_pe  == 1'b1;
                ier_rls == 1'b1;
            }
        }

        // Sin paridad: EP y SP no tienen efecto
        if (!lcr_pe) {
            lcr_ep == 0;
            lcr_sp == 0;
        }
    }


    // ===== Separa Divisor Latch en DL1 y DL2 =====
    function void post_randomize();
        dl2_reg = divisor_latch[15 : 8];
        dl1_reg = divisor_latch[7 : 0];
    endfunction

    // ===== Funciones para obtener registros enteros (concatenados) =====
    function bit [7 : 0] ier_value();
        return {4'b0, ier_ms, ier_rls, ier_thre, ier_rda};
    endfunction

    function bit [7 : 0] fcr_value();
        return {fcr_tl, 3'b0, fcr_tfr, fcr_rfr, 1'b0};
    endfunction

    function bit [7 : 0] mcr_value();
        return {3'b0, mcr_lb, mcr_out2, mcr_out1, mcr_rts, mcr_dtr};
    endfunction

    function bit [7 : 0] lcr_value(bit dlab = 0);
        // Nota: bit de DLAB se configura según el proceso de "uart_main_vseq".
        return {dlab, lcr_bc, lcr_sp, lcr_ep, lcr_pe, lcr_sb, lcr_bits};
    endfunction

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_dut_cfg");
        super.new(name); 

        fcr_tl_weights        = '{25, 25, 25, 25};
        lcr_bits_char_weights = '{25, 25, 25, 25};
        mcr_loopback_weights  = '{90, 10};
    endfunction
endclass : uart_dut_cfg


// =======================================================
//  Clase de configuración para los estímulos
// -------------------------------------------------------
//  Lugar de lectura de plusargs:
//   - uart_env_cfg  
// =======================================================
class uart_stim_cfg extends uvm_object;
    `uvm_object_utils(uart_stim_cfg)

    // ===== Knobs para estímulos por Wishbone =====
    int unsigned wb_n_stim_min        = 30;
    int unsigned wb_n_stim_max        = 150;
    int unsigned wb_status_gap_min    = 5;
    int unsigned wb_status_gap_max    = 15;
    int unsigned wb_polling_min       = 10;
    int unsigned wb_polling_max       = 25;
    int unsigned sw_service_delay_max = 15;
    int unsigned sw_service_delay_min = 0;

    // ===== Parámetros para estímulos por Wishbone =====
    rand int unsigned wb_n_stim;
    rand bit          wb_polling_status;


    // ===== Knobs para estímulos por Serial =====
    int unsigned ser_parity_err_pct_min = 5; // Porcentaje de caracteres con error de paridad
    int unsigned ser_parity_err_pct_max = 5;
    int unsigned ser_frame_err_pct_min  = 5; // Porcentaje de caracteres con el bit de frame en 0
    int unsigned ser_frame_err_pct_max  = 5;
    int unsigned ser_break_pct_min      = 2; // Porcentaje de caracteres que son un break
    int unsigned ser_break_pct_max      = 2;
    int unsigned ser_glitch_pct_min     = 2; // Porcentaje de caracteres que llevan un pulso corto
    int unsigned ser_glitch_pct_max     = 2;

    int unsigned ser_baud_out_pct_min = 10; // Porcentaje de caracteres fuera de tolerancia (por época)
    int unsigned ser_baud_out_pct_max = 10;
    int          ser_baud_dev_min     = 0;  // Magnitud dentro de tolerancia (por carácter)
    int          ser_baud_dev_max     = 2;
    int unsigned ser_baud_out_dev_min = 4;  // Magnitud fuera de tolerancia (por carácter)
    int unsigned ser_baud_out_dev_max = 10;
 
    int unsigned ser_gap_min       = 0;   // Separación entre caracteres RX
    int unsigned ser_gap_max       = 20;
    int unsigned ser_break_len_min = 1;   // Bits extra en 0 después de una trama completa
    int unsigned ser_break_len_max = 20;

    int unsigned ser_n_items_min = 30;  
    int unsigned ser_n_items_max = 150; 

    // ===== Parámetros para estímulos por Serial =====
    rand int unsigned ser_n_items;
    rand int unsigned ser_parity_err_pct;
    rand int unsigned ser_frame_err_pct;
    rand int unsigned ser_break_pct;
    rand int unsigned ser_glitch_pct;
    rand int unsigned ser_baud_out_pct;


    // ===== Knobs para estímulos por Módem =====
    int unsigned modem_toggle_pct_min   = 0;
    int unsigned modem_toggle_pct_max   = 10;
    int unsigned modem_toggle_delay_min = 0;
    int unsigned modem_toggle_delay_max = 1000;
    int unsigned modem_n_items_min      = 30;
    int unsigned modem_n_items_max      = 150;

    // ===== Parámetros para estímulos por Módem =====
    rand int unsigned modem_n_items;
    rand int unsigned modem_toggle_pct;


    // ===== Restricciones para estímulos por Wishbone =====
    constraint c_n_stim {
        wb_n_stim inside {[wb_n_stim_min : wb_n_stim_max]};
    }
    constraint c_polling_status {
        wb_polling_status dist {0 := 80, 1 := 20};
    }


    // ===== Restricciones para estímulos por Serial =====
    constraint c_ser_n_items{
        ser_n_items inside {[ser_n_items_min : ser_n_items_max]};
    }
    constraint c_ser_parity_err_pct{
        ser_parity_err_pct inside {[ser_parity_err_pct_min : ser_parity_err_pct_max]};

        ser_parity_err_pct <= 100;
    }
    constraint c_ser_frame_err_pct{
        ser_frame_err_pct inside {[ser_frame_err_pct_min : ser_frame_err_pct_max]};

        ser_frame_err_pct <= 100;
    }
    constraint c_ser_break_pct{
        ser_break_pct inside {[ser_break_pct_min : ser_break_pct_max]};

        ser_break_pct <= 100;
    }
    constraint c_ser_glitch_pct{
        ser_glitch_pct inside {[ser_glitch_pct_min : ser_glitch_pct_max]};

        ser_glitch_pct <= 100;
    }
    constraint c_ser_baud_out_pct{
        ser_baud_out_pct inside {[ser_baud_out_pct_min : ser_baud_out_pct_max]};

        ser_baud_out_pct <= 100;
    }


    // ===== Restricciones para estímulos por Modem =====
    constraint c_modem_n_items{
        modem_n_items inside {[modem_n_items_min : modem_n_items_max]};
    }
    constraint c_modem_toggle_pct{
        modem_toggle_pct inside {[modem_toggle_pct_min : modem_toggle_pct_max]};
    }


    // ===== Constructor con la fábrica =====
    function new(string name = "uart_stim_cfg");
        super.new(name); 
    endfunction
endclass : uart_stim_cfg


// =======================================================
//  Clase de configuración para el ambiente
// -------------------------------------------------------
//  Lee los plusargs y agrupa:
//      - wb_agent_cfg
//      - mod_agent_cfg
//      - serial_agent_cfg
//      - uart_stim_cfg
//      - uart_scoreboard_cfg
//      - uart_dut_cfg
//      - 
//      - 
// =======================================================
class uart_env_cfg extends uvm_object;
    `uvm_object_utils(uart_env_cfg)

    wb_agent_cfg        wb_cfg;
    mod_agent_cfg       mod_cfg;
    serial_agent_cfg    serial_cfg;
    uart_stim_cfg       stim_cfg;
    uart_scoreboard_cfg scoreboard_cfg;
    uart_dut_cfg        dut_cfg;

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_env_cfg");
        super.new(name);

        wb_cfg         = wb_agent_cfg::type_id::create("wb_cfg");
        mod_cfg        = mod_agent_cfg::type_id::create("mod_cfg");
        serial_cfg     = serial_agent_cfg::type_id::create("serial_cfg");
        stim_cfg       = uart_stim_cfg::type_id::create("stim_cfg");
        scoreboard_cfg = uart_scoreboard_cfg::type_id::create("scoreboard_cfg");
        dut_cfg        = uart_dut_cfg::type_id::create("dut_cfg");
   endfunction

    // ===== Lectura de plusargs =====
    function void parse_plusargs();



    endfunction
endclass : uart_env_cfg

`endif //UART_CFG_SV

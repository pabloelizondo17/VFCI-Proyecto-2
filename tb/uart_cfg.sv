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
//  Clase de configuración para el DUT
// -------------------------------------------------------
//  Lugar de lectura de plusargs:
//   - uart_env_cfg  
// =======================================================
class uart_dut_cfg extends uvm_object;
    `uvm_object_utils(uart_dut_cfg)

    typedef int unsigned w4_t[4];
    typedef int unsigned w2_t[2];

    uart_stim_cfg stim;

    // ===== Knobs modificados por plusargs =====
    int unsigned dl_min = 2, dl_max = 16'hFFFF;

    w4_t fcr_tl_weights        = '{25, 25, 25, 25}; // [00=1,01=4,10=8,11=14] bytes
    w4_t lcr_bits_char_weights = '{25, 25, 25, 25}; // [00=5,01=6,10=7,11=8] bits
    w2_t mcr_loopback_weights  = '{90, 10};         // [normal,loopback]


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
        ier_rda  dist {1 := 100, 0 := 0};
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
            // Polling => Sin interrupción de datos disponibles
            if (stim.polling_status) begin
                ier_rda == 1'b0;
            end else begin                   
                ier_rda == 1'b1;
            end

            if (stim.ser_parity_err_pct > 0) {
                lcr_pe  == 1'b1;
                ier_rls == 1'b1;
            }
        }

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
    int unsigned n_stim_min     = 30;
    int unsigned n_stim_max     = 150
    int unsigned status_gap_min = 5;
    int unsigned status_gap_max = 15;
    int unsigned polling_min    = 10;
    int unsigned polling_max    = 25;


    // ===== Parámetros para estímulos por Wishbone =====
    rand int unsigned n_stim;
    rand bit          polling_status;





    // ===== Knobs para estímulos por Serial =====

    // ===== Parámetros para estímulos por Serial =====

    // ===== Knobs para estímulos por Módem =====

    // ===== Parámetros para estímulos por Módem =====



    // ===== Restricciones para estímulos por Wishbone =====
    constraint c_n_stim {
        n_stim inside {[n_stim_min : n_stim_max]};
    }
    constraint c_polling_status {
        polling_status dist {0 := 70, 1 := 30};
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
//      -
//      -
//      -
// =======================================================
class uart_env_cfg extends uvm_object;

endclass : uart_dut_cfg

`endif //UART_CFG_SV

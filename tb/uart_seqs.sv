// =======================================================
//  Conjunto de secuencias virtuales
// -------------------------------------------------------
//  Proceso de configuración: config_DUT
//
//  Procesos principales:
//      - reset_DUT
//      - config_DUT
//      - traffic_and_drain
// -------------------------------------------------------
//  Secuencia virtual principal:
//      - uart_main_vseq
//
//  Secuencia virtual base:
//      - uart_base_vseq
//
//  Otras secuencias virtuales:
//      - uart_wb_traffic_vseq
//      - uart_serial_traffic_vseq
//      - uart_modem_traffic_vseq
//      - uart_status_vseq
//      - uart_polling_vseq
//      - uart_int_attend_vseq
// =======================================================


`ifndef UART_SEQS_SV
`define UART_SEQS_SV

// =======================================================
//  Secuencia base para herencia
// -------------------------------------------------------
//   - Concentra tareas de uso general (w_reg, r_reg...)
// =======================================================
class uart_base_vseq extends uvm_sequence;
    `uvm_object_utils(uart_base_vseq)
    `uvm_declare_p_sequencer(uart_virtual_seqr)

    uart_reg_block ral;
    uart_env_cfg   env_cfg;
    uart_dut_cfg   dut_cfg;
    uart_stim_cfg  stim_cfg;

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_base_vseq"); 
        super.new(name); 
    endfunction

    // ===== Carga de punteros (pre body) =====
    virtual task pre_body();
        this.ral      = p_sequencer.reg_model;
        this.env_cfg  = p_sequencer.env_cfg;
        this.dut_cfg  = env_cfg.dut_cfg;
        this.stim_cfg = env_cfg.stim_cfg;
    endtask

    // ===== Tarea para escritura de registros =====
    task w_reg(uvm_reg rg, uvm_reg_data_t rg_value, uvm_reg_map rg_map = null);
        uvm_status_e status;

        rg.write(status, rg_value, .path(UVM_FRONTDOOR), .map(rg_map), .parent(this));

        if (status != UVM_IS_OK) begin
            `uvm_error("VSEQ", {"Escritura fallida en el registro", rg.get_name()})
        end
    endtask

    // ===== Tarea para lectura de registros =====
    task r_reg(uvm_reg rg, output uvm_reg_data_t rg_value, input uvm_reg_map rg_map = null);
        uvm_status_e status;

        rg.read(status, rg_value, .path(UVM_FRONTDOOR), .map(rg_map), .parent(this));

        if (status != UVM_IS_OK) begin
            `uvm_error("VSEQ", {"Lectura fallida en el registro", rg.get_name()})
        end
    endtask

    // ===== Proceso de reset del DUT =====
    task reset_DUT();
        wb_item_t wb_rst_item = wb_item_t::type_id::create("wb_rst_item");
        
        start_item(wb_rst_item, -1, p_sequencer.wb_seqr_0);
            if (!wb_rst_item.randomize() with {kind  == WB_RESET; delay == 0;}) begin
                `uvm_fatal("RAND", "No se pudo generar el reset.")
            end
        finish_item(wb_rst_item);

        ral.reset();
    endtask

    // ===== Porcentaje de cambio en el bit (Modem)===== 
    // (0 no cambia y 1 si cambia): Orden (dcd, ri, dsr, cts)
    virtual function bit [3:0] pick_toggles();
        bit [3:0] t;

        for (int i = 0; i < 4; i++) begin
            t[i] = ($urandom_range(99) < stim_cfg.modem_toggle_pct); 
        end   

        return t; 
    endfunction 

    // ... wait_cycles, etc.
endclass : uart_base_vseq


// =======================================================
//  Secuencia para escritura de datos a THR
// =======================================================
class uart_wb_traffic_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_wb_traffic_vseq)

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_wb_traffic_vseq"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
        repeat(stim_cfg.wb_n_stim) begin

            if (!ral.thr.randomize()) begin
                `uvm_fatal("THR", "Aleatorización de THR falló.")
            end

            w_reg(ral.thr, ral.thr.get(), ral.map_dlab0);
        end
    endtask
endclass : uart_wb_traffic_vseq


// =======================================================
//  Secuencia para la generación de tráfico serial
// =======================================================
class uart_serial_traffic_vseq extends uart_base_vseq #();
    `uvm_object_utils(uart_serial_traffic_vseq)

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_serial_traffic_vseq"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
        int unsigned mag;
        int          sign_mult;

        repeat (stim_cfg.ser_n_items) begin
            serial_seq_item ser_item = serial_seq_item::type_id::create("ser_item");

            start_item(ser_item, -1, p_sequencer.serial_seqr_0);
                ser_item.data = $urandom;
                sign_mult     = ($urandom_range(1, 0) == 0) ? -1 : 1;  // Selección aleatoria del signo

                // Primero se determina si el carácter es un break
                ser_item.is_break = ($urandom_range(99) < stim_cfg.ser_break_pct);

                // Los errores de trama y paridad se anulan durante un carácter tipo break
                ser_item.parity_err = !ser_item.is_break && ($urandom_range(99) < stim_cfg.ser_parity_err_pct);
                ser_item.frame_err  = !ser_item.is_break && ($urandom_range(99) < stim_cfg.ser_frame_err_pct);

                ser_item.gap        = $urandom_range(stim_cfg.ser_gap_max, stim_cfg.ser_gap_min);
                ser_item.break_len  = $urandom_range(stim_cfg.ser_break_len_max, stim_cfg.ser_break_len_min);

                if ($urandom_range(99) < stim_cfg.ser_glitch_pct) begin
                    ser_item.glitch = GLITCH_START;
                end else begin
                    ser_item.glitch = GLITCH_NONE;
                end

                if ($urandom_range(99) < stim_cfg.ser_baud_out_pct) begin
                    // Fuera de tolerancia
                    mag = $urandom_range(stim_cfg.ser_baud_out_dev_max, stim_cfg.ser_baud_out_dev_min);
                end else begin
                    // Dentro de tolerancia
                    mag = $urandom_range(stim_cfg.ser_baud_dev_max, stim_cfg.ser_baud_dev_min);
                end

                ser_item.baud_dev_pct = (mag == 0) ? 0 : (sign_mult * int'(mag));
            finish_item(ser_item);
        end
    endtask
endclass : uart_serial_traffic_vseq


// =======================================================
//  Secuencia para señales modem
// =======================================================
class uart_modem_traffic_vseq extends uart_base_vseq #(mod_seq_item);
    `uvm_object_utils(uart_modem_traffic_vseq)

    // ===== Incializa valor del estado de cada línea ===== 
    bit dsr_ultimo = 1'b0;
    bit ri_ultimo  = 1'b0;
    bit cts_ultimo = 1'b0;
    bit dcd_ultimo = 1'b0;

    // ===== Constructor con la fábrica =====
    function new(string name = "mod_sequence"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
        bit [3 : 0] toggle;

        repeat (stim_cfg.modem_n_items) begin
            mod_seq_item req    = mod_seq_item::type_id::create("req");
                         toggle = pick_toggles();
            
            start_item(req, -1, p_sequencer.mod_seqr_0);
                req.cts_pad_i = toggle[0] ? !cts_ultimo : cts_ultimo;
                req.dsr_pad_i = toggle[1] ? !dsr_ultimo : dsr_ultimo;
                req.ri_pad_i  = toggle[2] ? !ri_ultimo  : ri_ultimo;
                req.dcd_pad_i = toggle[3] ? !dcd_ultimo : dcd_ultimo;

                req.delay = $urandom_range(stim_cfg.modem_toggle_delay_max, 
                                           stim_cfg.modem_toggle_delay_min);
            finish_item(req);

            // ===== Registro de lo que mandó  ===== 
            cts_ultimo = req.cts_pad_i;
            dsr_ultimo = req.dsr_pad_i;
            ri_ultimo  = req.ri_pad_i;
            dcd_ultimo = req.dcd_pad_i;
        end
    endtask
endclass : uart_modem_traffic_vseq


// =======================================================
//  Secuencia para sondeo de registros de estado
// =======================================================
class uart_status_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_status_vseq)

    bit stop = 0;

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_status_vseq"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
        uvm_reg_data_t reg_value;

        while (!stop) begin
            wait_cycles($urandom_range(stim_cfg.wb_status_gap_max, stim_cfg.wb_status_gap_min));

            randcase
                // Registro de interes: LSR, MSR, DBG1, DBG2, SR
                // Nota: IIR se lee en otras secuencias
                52: r_reg(ral.lsr, reg_value);
                35: r_reg(ral.msr, reg_value);
                5:  r_reg(ral.dbg1, reg_value);
                5:  r_reg(ral.dbg2, reg_value);
                3:  r_reg(ral.sr, reg_value);
            endcase
        end
    endtask
endclass : uart_status_vseq


// =======================================================
//  Secuencia para polling en RBR
// -------------------------------------------------------
//   - Depende de wb_polling_status en uart_stim_cfg
// =======================================================
class uart_polling_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_polling_vseq)

    bit stop = 0;;

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_polling_vseq"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
        uvm_reg_data_t reg_value;

        while (!stop) begin
            wait_cycles($urandom_range(stim_cfg.wb_polling_max, stim_cfg.wb_polling_min));

            r_reg(ral.rbr, reg_value);
        end
    endtask
endclass : uart_polling_vseq


// =======================================================
//  Secuencia para atender interrupciones
// -------------------------------------------------------
//   - Depende de wb_polling_status en uart_stim_cfg
// =======================================================
class uart_int_attend_vseq extends uart_base_vseq;
endclass : uart_int_attend_vseq


// =======================================================
//  Secuencia virtual principal (uart_main_vseq)
// -------------------------------------------------------
//   - Hereda funciones de: uart_base_vseq
// =======================================================
class uart_main_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_main_vseq)
    
    // ===== Constructor con la fábrica =====
    function new(string name = "uart_main_vseq"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
        uart_wb_traffic_vseq     wb_traffic_seq     = uart_wb_traffic_vseq::type_id::create("wb_traffic");
        uart_serial_traffic_vseq serial_traffic_seq = uart_serial_traffic_vseq::type_id::create("serial_traffic");
        uart_modem_traffic_vseq  modem_traffic_seq  = uart_modem_traffic_vseq::type_id::create("modem_traffic");
        uart_status_vseq         status_seq         = uart_status_vseq::type_id::create("status");
        uart_polling_vseq        polling_seq        = uart_polling_vseq::type_id::create("polling");
        uart_int_attend_vseq     int_attend_seq     = uart_int_attend_vseq::type_id::create("int_attend");

        if(!dut_cfg.randomize()) begin   // <= Aleatoriza la configuración del DUT
            `uvm_fatal("RAND", "No fue posible aleatorizar la configuración del DUT.")
        end

        reset_DUT();
        config_DUT(dut_cfg);

        // ===== Secuencias de tráfico en paralelo =====
        fork
            begin : traffic_and_drain
                fork
                    wb_traffic_seq.start(p_sequencer, this);
                    serial_traffic_seq.start(p_sequencer, this);
                    modem_traffic_seq.start(p_sequencer, this);
                join

                // ===== Esperar fin de tx y rx =====
                wait_tx();
                wait_rx();

                status_seq.stop     = 1;
                polling_seq.stop    = 1;
                int_attend_seq.stop = 1;
            end

            int_attend_seq.start(p_sequencer, this);
            status_seq.start(p_sequencer, this);

            if(stim_cfg.polling_status) begin
                polling_seq.start(p_sequencer, this);
            end
        join
    endtask

    // ===== Proceso de configuración =====
    // ------------------------------------
    //  1. DLAB <= 1
    //  2. Definir LD2
    //  3. Definir LD1
    //  4. DLAB <= 0
    //  5. Definir IER, FCR y MCR
    // ------------------------------------
    task config_DUT(uart_dut_cfg cfg);
        w_reg(ral.lcr, cfg.lcr_value(1));
        
        w_reg(ral.dl2, cfg.dl2_reg, ral.map_dlab1);
        w_reg(ral.dl1, cfg.dl1_reg, ral.map_dlab1);

        w_reg(ral.lcr, cfg.lcr_value(0));
        w_reg(ral.fcr, cfg.fcr_value());
        w_reg(ral.mcr, cfg.mcr_value());
        w_reg(ral.ier, cfg.ier_value());
    endtask
endclass : uart_main_vseq

`endif //UART_SEQS_SV

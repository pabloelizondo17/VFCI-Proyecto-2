// =======================================================
//  Conjunto de secuencias virtuales
// -------------------------------------------------------
//  Proceso de configuración: config_DUT
//
//  Procesos principales:
//      - 
// -------------------------------------------------------
//  Secuencia virtual principal:
//      - uart_main_vseq
//
//  Otras secuencias virtuales:
//      - uart_main_vseq
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

    // ... wait_cycles, etc.
endclass : uart_base_vseq


// =======================================================
//  Secuencia para escritura de datos a THR
// =======================================================
class uart_wb_traffic_vseq extends uart_base_vseq #(wb_item_t);
    `uvm_object_utils(uart_wb_traffic_vseq)

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_wb_traffic_vseq"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
        repeat(stim_cfg.n_stim) begin

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


    endtask
endclass : uart_serial_traffic_vseq


// =======================================================
//  Secuencia para señales modem
// =======================================================


// =======================================================
//  Secuencia para sondeo de registros de estado
// =======================================================
class uart_status_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_status_vseq)

    bit stop;

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_status_vseq"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
        uvm_reg_data_t reg_value;

        while (!stop) begin
            wait_cycles($urandom_range(stim_cfg.status_gap_max, stim_cfg.status_gap_min));

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
//   - Depende de polling_status en uart_stim_cfg
// =======================================================
class uart_polling_vseq extends uart_base_vseq;
    `uvm_object_utils(uart_polling_vseq)

    bit stop;

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_polling_vseq"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
        uvm_reg_data_t reg_value;

        while (!stop) begin
            wait_cycles($urandom_range(stim_cfg.polling_max, stim_cfg.polling_min));

            r_reg(ral.rbr, reg_value);
        end
    endtask
endclass : uart_polling_vseq


// =======================================================
//  Secuencia para atender interrupciones
// =======================================================



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
        uart_wb_traffic_vseq     wb_traffic     = uart_wb_traffic_vseq::type_id::create("wb_traffic");
        uart_serial_traffic_vseq serial_traffic = uart_serial_traffic_vseq::type_id::create("serial_traffic");

        if(!dut_cfg.randomize()) begin   // <= Aleatoriza la configuración del DUT
            `uvm_fatal("RAND", "No fue posible aleatorizar la configuración del DUT.")
        end

        reset_DUT();
        config_DUT(dut_cfg);

        // ===== Secuencias de tráfico en paralelo =====
        fork
            wb_traffic.start(p_sequencer, this);
            serial_traffic.start(p_sequencer, this);


            //wb_int_service();
            //mod_traffic();
        join

        // ===== Esperar fin de tx y rx =====
        wait_tx();
        wait_rx();
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

// =======================================================
//  Ambiente de pruebas (wb_agent)
// -------------------------------------------------------
//  Componentes principales:
//      - wb_driver
//      - wb_monitor
//      - wb_seqr
// -------------------------------------------------------
// Objeto de configuración: uart_env_cfg
// =======================================================

`ifndef UART_ENV_SV
`define UART_ENV_SV

class uart_env extends uvm_env;
    `uvm_component_utils(uart_env)

    // ----- Punteros de los componentes -----
    wb_agent                     wb_agt;
    mod_agent                    mod_agt;
    serial_agent                 serial_agt;
    uart_virtual_seqr            v_sqr;
    uart_scoreboard              scrb;
    uart_coverage                cov;
    uvm_reg_predictor #(wb_item) reg_predictor;

    // ----- Punteros de los objetos -----
    uart_env_cfg                 env_cfg;
    uart_reg_block               reg_model;
    uart_reg_adapter             reg_adapter;
    

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_env", uvm_component parent = null); 
        super.new(name, parent); 
    endfunction

    // ===== Fase "build" de UVM =====
    function void build_phase (uvm_phase phase);
        super.build_phase(phase);

        // ----- Objeto de configuración del ambiente -----
        if (!uvm_config_db#(uart_env_cfg)::get(this, "", "cfg", env_cfg)) begin
            `uvm_fatal("NOCFG", "Ambiente sin objeto de configuración (env_cfg).")
        end


        // ----- Asignación del objeto de configuración de cada componente -----
        uvm_config_db#(wb_agent_cfg)::set(this, "wb_agt*",  "wb_cfg", env_cfg.wb_cfg);
        uvm_config_db#(mod_agent_cfg)::set(this, "mod_agt*", "mod_cfg", env_cfg.mod_cfg);
        uvm_config_db#(serial_agent_cfg)::set(this, "serial_agt*", "serial_cfg", env_cfg.serial_cfg);

        uvm_config_db#(uart_env_cfg)::set(this, "v_sqr", "env_cfg", env_cfg);
        uvm_config_db#(uart_env_cfg)::set(this, "scrb", "env_cfg", env_cfg);
        uvm_config_db#(uart_env_cfg)::set(this, "cov", "env_cfg", env_cfg);


        // ----- Instancia de los componentes -----
        wb_agt         = wb_agent::type_id::create("wb_agt", this);
        mod_agt        = mod_agent::type_id::create("mod_agt", this);
        serial_agt     = serial_agent::type_id::create("serial_agt", this);
        v_sqr          = uart_virtual_seqr::type_id::create("v_sqr", this);
        cov            = uart_coverage::type_id::create("cov", this);
        reg_predictor  = uvm_reg_predictor #(wb_item)::type_id::create("reg_predictor", this);


        // ----- Instancia de los objetos -----
        reg_model   = uart_reg_block::type_id::create("reg_model");
        reg_adapter = uart_reg_adapter::type_id::create("reg_adapter");

        reg_model.build();
        reg_model.reset();
        reg_model.set_test_exclusions();

        reg_adapter.cfg = env_cfg.wb_cfg;
    endfunction

    // ===== Fase "connect" de UVM =====
    function void connect_phase (uvm_phase phase);



    endfunction
endclass : uart_env

`endif //UART_ENV_SV

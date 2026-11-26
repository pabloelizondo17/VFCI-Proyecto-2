// =======================================================
//  Test base (uart_base_test)
// -------------------------------------------------------
//  Ambiente que instancia:
//   - uart_env
// -------------------------------------------------------
// Objeto de configuración: uart_env_cfg
// =======================================================

`ifndef UART_TEST_SV
`define UART_TEST_SV

class uart_base_test extends uvm_test;
    `uvm_component_utils(uart_base_test)

    uart_env     env;
    uart_env_cfg cfg;

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_base_test", uvm_component parent = null); 
        super.new(name, parent); 
    endfunction


    // ===== Fase "build" de UVM =====
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        cfg = uart_env_cfg::type_id::create("cfg");

        // ----- Carga de las interfaces en los agentes desde el config_db-----
        if (!uvm_config_db#(virtual wb_if)::get(this, "", "wb_vif", cfg.wb_cfg.wb_vif)) begin
            `uvm_fatal("NOVIF", "Interfaz Wishbone no está en uvm_config_db.")
        end
        if (!uvm_config_db#(virtual mod_if)::get(this, "", "mod_vif", cfg.mod_cfg.vif)) begin
            `uvm_fatal("NOVIF", "Interfaz Modem no está en uvm_config_db.")
        end
        if (!uvm_config_db#(virtual serial_if)::get(this, "", "serial_vif", cfg.serial_cfg.vif)) begin
            `uvm_fatal("NOVIF", "Interfaz Serial no está en uvm_config_db.")
        end

        cfg.parse_plusargs();

        uvm_config_db#(uart_env_cfg)::set(this, "env", "cfg", cfg);
        env = uart_env::type_id::create("env", this);

        //uvm_top.set_timeout(cfg.stim_cfg.timeout_us * 1us, 0);
    endfunction


    // ===== Fase "end of elaboration" de UVM =====
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        uvm_top.print_topology();
        cfg.print_knobs();
    endfunction


    // ===== Fase "run" de UVM =====
    task run_phase(uvm_phase phase);


    endtask

    // ===== Fase "report" de UVM =====
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

    endfunction
endclass : uart_base_test

`endif //UART_TEST_SV

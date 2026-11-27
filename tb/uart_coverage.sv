`ifndef UART_COVERAGE_SV
`define UART_COVERAGE_SV

// =======================================================
//  Recolector de cobertura (uart_coverage)
// -------------------------------------------------------
//  Recibe los items que publica el scoreboard (modelo de
//  referencia) y muestrea el covergroup que corresponde
//  según el tipo de item.
// =======================================================

class uart_coverage extends uvm_subscriber #(uart_cov_item);
    `uvm_component_utils(uart_coverage)

    // ===== Configuración =====
    uart_env_cfg env_cfg;

    // ===== Covergroups =====

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_coverage", uvm_component parent = null);
        super.new(name, parent);
        // Creación de los covergroups
    endfunction

    // ===== Fase "build" de UVM =====
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(uart_env_cfg)::get(this, "", "env_cfg", env_cfg)) begin
            `uvm_fatal("NOCFG", "Cobertura sin objeto de configuración del ambiente (env_cfg).")
        end
    endfunction

    // ===== Item del modelo: muestrea según el tipo =====
    function void write(uart_cov_item t);
        case (t.kind)
            EV_WB:       ;
            EV_LINE_CFG: ;
            EV_CHAR:     ;
            EV_RX_ERR:   ;
            EV_FIFO:     ;
            EV_INT:      ;
            EV_MODEM:    ;
            EV_TRAFICO:  ;
            EV_RST:      ;
        endcase
    endfunction

    // ===== Cobertura total =====
    function real total();
        return 0.0;
    endfunction

    // ===== Fase "report" de UVM =====
    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("\nCobertura funcional de esta corrida: %6.2f %%", total()), UVM_NONE)
    endfunction
endclass : uart_coverage

`endif //UART_COVERAGE_SV
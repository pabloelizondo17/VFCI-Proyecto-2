// =======================================================
//  Secuenciador Virtual (uart_virtual_seqr)
// -------------------------------------------------------
//  Coordina los secuenciadores:
//      - wb_seqr
//      - mod_seqr
//      - serial_seqr
// -------------------------------------------------------
//  Secuencia virtual correspondiente:
//      - uart_main_vseq
// =======================================================

`ifndef UART_VIRTUAL_SEQR_SV
`define UART_VIRTUAL_SEQR_SV

class uart_virtual_seqr extends uvm_sequencer #(uvm_sequence_item);
    `uvm_component_utils(uart_virtual_seqr)

    // ===== Punteros a los secuenciadores de cada agente =====
    wb_seqr     wb_seqr_0;
    mod_seqr    mod_seqr_0;
    serial_seqr serial_seqr_0;

    // ===== RAL y configuración =====
    uart_reg_block reg_model;
    uart_env_cfg   env_cfg;

    // ===== Puertos de análisis para interrupciones =====
    uvm_tlm_analysis_fifo #(mod_intr_item) intr_fifo;

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_virtual_seqr", uvm_component parent = null); 
        super.new(name, parent); 
    endfunction

    // ===== Fase "build" de UVM =====
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(uart_env_cfg)::get(this, "", "env_cfg", env_cfg)) begin
            `uvm_fatal("NOCFG", "Secuenciador virtual sin objeto de configuración (env_cfg).")
        end

        intr_fifo = new("intr_fifo", this);
    endfunction
endclass : uart_virtual_seqr

`endif //UART_VIRTUAL_SEQR_SV

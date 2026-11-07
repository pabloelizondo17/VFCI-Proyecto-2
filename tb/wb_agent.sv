// =======================================================
//  Agente Wishbone (wb_agent)
// -------------------------------------------------------
//      - wb_driver
//      - wb_monitor
//      - wb_seqr
// -------------------------------------------------------
// Objeto de configuración: wb_agent_cfg
// Item de secuencia: wb_item
// Secuencia: wb_seq
// =======================================================

`ifndef WB_AGENT_SV
`define WB_AGENT_SV

// =======================================================
// Secuenciador Wishbone (wb_seqr)
// -------------------------------------------------------
//  - Item wb_item definido como wb_item_t
// =======================================================
uvm_sequencer #(wb_item_t) wb_seqr;



// =======================================================
// Driver Wishbone (wb_driver)
// =======================================================
class wb_driver extends uvm_driver #(wb_item_t);
    `uvm_component_utils(wb_driver)
    wb_agent_cfg  cfg;
    virtual wb_if wb_vif;

    // ===== Constructor con la fábrica =====
    function new(string name = "wb_driver", uvm_component parent = null); 
        super.new(name, parent); 
    endfunction

    // ===== Fase "build" de UVM =====
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(wb_agent_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("NOCFG", "wb_driver sin wb_agent_cfg")
        end

        wb_vif = cfg.wb_vif;
    endfunction

    // ===== Fase "run" de UVM =====
    task run_phase(uvm_phase phase);
        bus_idle();
        apply_reset(5);

        forever begin
            seq_item_port.get_next_item(req);
            repeat (req.delay) @(wb_vif.wb_driver_cb);

            case (req.kind)
                WB_BUS:   drive_bus(req);
                WB_RESET: apply_reset(req.rst_cycles);

                default: ;
            endcase

            seq_item_port.item_done();
        end
    endtask

    // ===== Estado en reposo del bus =====
    task bus_idle();
        wb_vif.stb <= 1'b0;
        wb_vif.cyc <= 1'b0;
    endtask

    // ===== Aplica reset al bus =====
    task apply_reset(int unsigned rst_times);
        @(wb_vif.wb_driver_cb);

        bus_idle();
        wb_vif.wb_driver_cb.rst <= 1'b1;

        repeat (rst_times) @(wb_vif.wb_driver_cb);
        wb_vif.wb_driver_cb.rst <= 1'b0;

        repeat (2) @(wb_vif.wb_driver_cb);
    endtask

    // ===== Proceso principal del driver =====
    task drive_bus(wb_item wb_item);
        int unsigned guardia = 0;
        @(wb_vif.wb_driver_cb);

        wb_vif.wb_driver_cb.cyc        <= 1'b1;
        wb_vif.wb_driver_cb.stb        <= 1'b1;
        wb_vif.wb_driver_cb.we         <= wb_item.we;
        wb_vif.wb_driver_cb.sel        <= wb_item.sel;
        wb_vif.wb_driver_cb.addr       <= wb_item.addr;
        wb_vif.wb_driver_cb.data_m2dut <= wb_item.we ? wb_item.data : '0;

        do begin
            @(wb_vif.wb_driver_cb); 
            if (++guardia > 1000) begin
                `uvm_fatal("WB_DRV", "El DUT no respondió con ack en 1000 ciclos.")
            end
        end while(wb_vif.wb_driver_cb.ack !== 1'b1);

        if (!wb_item.we) wb_item.data = wb_vif.wb_driver_cb.data_dut2m;

        bus_idle();
    endtask
endclass : wb_driver



// =======================================================
// Monitor Wishbone (wb_monitor)
// =======================================================
class wb_monitor extends uvm_monitor;


endclass : wb_monitor



// =======================================================
// Agente Wishbone (wb_agent)
// =======================================================
class wb_agent extends uvm_agent;


endclass : wb_agent

`endif //WB_AGENT_SV

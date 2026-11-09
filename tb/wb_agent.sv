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

    // ===== Constructor con la fábrica =====
    function new(string name = "wb_driver", uvm_component parent = null); 
        super.new(name, parent); 
    endfunction

    virtual wb_if wb_vif;
    wb_agent_cfg  cfg;

    // ===== Fase "build" de UVM =====
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(wb_agent_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("NOCFG", "Driver Wishbone sin wb_agent_cfg")
        end

        wb_vif = cfg.wb_vif;
    endfunction

    // ===== Fase "run" de UVM =====
    task run_phase(uvm_phase phase);
        bus_idle();
        apply_reset(5);

        super.build_phase(phase);

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
    task drive_bus(wb_item_t item);
        int unsigned guardia = 0;
        @(wb_vif.wb_driver_cb);

        wb_vif.wb_driver_cb.cyc        <= 1'b1;
        wb_vif.wb_driver_cb.stb        <= 1'b1;
        wb_vif.wb_driver_cb.we         <= item.we;
        wb_vif.wb_driver_cb.sel        <= item.sel;
        wb_vif.wb_driver_cb.addr       <= item.addr;
        wb_vif.wb_driver_cb.data_m2dut <= item.we ? item.data : '0;

        do begin
            @(wb_vif.wb_driver_cb); 
            if (++guardia > 1000) begin
                `uvm_fatal("WB_DRV", "El DUT no respondió con ack en 1000 ciclos.")
            end
        end while(wb_vif.wb_driver_cb.ack !== 1'b1);

        if (!item.we) item.data = wb_vif.wb_driver_cb.data_dut2m;

        bus_idle();
    endtask
endclass : wb_driver



// =======================================================
// Monitor Wishbone (wb_monitor)
// =======================================================
class wb_monitor extends uvm_monitor;
    `uvm_component_utils(wb_monitor)

    // ===== Constructor con la fábrica =====
    function new(string name = "wb_monitor", uvm_component parent = null); 
        super.new(name, parent); 
    endfunction
 
    virtual wb_if                  wb_vif;
    uvm_analysis_port #(wb_item_t) wb_mon_ap
    wb_agent_cfg                   cfg;

    // ===== Fase "build" de UVM =====
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        wb_mon_ap = new("wb_mon_ap", this);

        if (!uvm_config_db#(wb_agent_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("NOCFG", "Monitor Wishbone sin wb_agent_cfg")
        end

        wb_vif = cfg.wb_vif;
    endfunction

    // ===== Fase "run" de UVM =====
    task run_phase(uvm_phase phase);
        logic prev_rst = 1'bx;

        forever begin
            @(wb_vif.wb_monitor_cb);

            // ===== Se registra un reset =====
            if (wb_vif.wb_monitor_cb.rst !== prev_rst) begin
                wb_item item = wb_item::type_id::create("rst_item");

                item.kind  = WB_RESET;
                item.data  = wb_vif.wb_monitor_cb.rst;
                item.stamp = wb_vif.wb_monitor_cb.clk_counter;
                prev_rst   = wb_vif.wb_monitor_cb.rst;

                wb_mon_ap.write(item);
            end

            // ===== Se registra una transferencia =====
            if(wb_vif.wb_monitor_cb.cyc &&
               wb_vif.wb_monitor_cb.stb &&
               wb_vif.wb_monitor_cb.ack) begin
                wb_item item = wb_item::type_id::create("trans_item");

                item.kind  = WB_BUS;
                item.we    = wb_vif.wb_monitor_cb.we;
                item.data  = wb_vif.wb_monitor_cb.we ? 
                             wb_vif.wb_monitor_cb.data_m2dut : 
                             wb_vif.wb_monitor_cb.data_dut2m;
                item.addr  = wb_vif.wb_monitor_cb.addr;
                item.stamp = wb_vif.wb_monitor_cb.clk_counter;

                wb_mon_ap.write(item);
            end
        end
    endtask
endclass : wb_monitor



// =======================================================
// Agente Wishbone (wb_agent)
// =======================================================
class wb_agent extends uvm_agent;
    `uvm_component_utils(wb_agent)

    // ===== Constructor con la fábrica =====
    function new(string name = "wb_agent", uvm_component parent); 
        super.new(name, parent); 
    endfunction

    wb_driver                      wb_driver_0;
    wb_monitor                     wb_monitor_0;
    wb_seqr                        wb_seqr_0;
    uvm_analysis_port #(wb_item_t) wb_agent_ap;
    wb_agent_cfg                   cfg;

    // ===== Fase "build" de UVM =====
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(wb_agent_cfg)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("NOCFG", "Agente Wishbone sin wb_agent_cfg.")
        end

        wb_agent_ap  = new("wb_agent_ap", this);
        wb_monitor_0 = wb_monitor::type_id::create("wb_monitor_0", this);

        if(cfg.is_active == UVM_ACTIVE) begin
            wb_driver_0  = wb_driver::type_id::create("wb_driver_0", this);
            wb_seqr_0    = uvm_sequencer #(wb_item_t)::type_id::create("wb_seqr_0", this);
        end
    endfunction

    // ===== Fase "connect" de UVM =====
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if(cfg.is_active == UVM_ACTIVE) begin
            wb_driver_0.seq_item_port.connect(wb_seqr_0.seq_item_export);
        end

        wb_monitor_0.wb_mon_ap.connect(this.wb_agent_ap);
    endfunction
endclass : wb_agent

`endif //WB_AGENT_SV

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

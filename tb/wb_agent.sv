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

// =======================================================
// Secuenciador Wishbone (wb_seqr)
// =======================================================
uvm_sequencer #(wb_item) wb_seqr;



// =======================================================
// Secuencia Wishbone (wb_seq)
// =======================================================
class wb_seq extends uvm_sequence #(wb_item);


endclass : wb_seq



// =======================================================
// Driver Wishbone (wb_driver)
// =======================================================
class wb_driver extends uvm_driver #(wb_item);


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

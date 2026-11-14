// =======================================================
//  Clase de configuración Wishbone (wb_agent_cfg)
// -------------------------------------------------------
// Objeto de configuración: wb_agent_cfg
// Utilizado por: 
//                 - Driver
//                 - Monitor 
//                 - Agente Wishbone      
//                 - Secuencias Wishbone
// =======================================================


// =======================================================
//  Clase de configuración Wishbone (wb_agent_cfg)
// -------------------------------------------------------
// Lugar de lectura de plusargs:
//  - uart_env_cfg  
// =======================================================

`ifndef WB_AGENT_CFG_SV
`define WB_AGENT_CFG_SV

class wb_agent_cfg extends uvm_object;
    `uvm_object_utils(wb_agent_cfg)

    uvm_active_passive_enum is_active = UVM_ACTIVE;
    virtual wb_if           wb_vif;

    int unsigned            delay_min      = 0;
    int unsigned            delay_max      = 10;
    int unsigned            rst_cycles_min = 1;
    int unsigned            rst_cycles_max = 5; 

    // ===== Constructor con la fábrica =====
    function new(string name = "wb_agent_cfg");
        super.new(name); 
    endfunction

endclass : wb_agent_cfg

`endif //WB_AGENT_CFG_SV

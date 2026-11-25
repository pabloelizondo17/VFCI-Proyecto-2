// =======================================================
// Ítem Wishbone
// -------------------------------------------------------
// Item de secuencia: wb_item
// -------------------------------------------------------
// Objeto de configuración: wb_agent_cfg
// =======================================================


// =======================================================
// Ítem Wishbone (wb_item)
// =======================================================

`ifndef WB_ITEM_SV
`define WB_ITEM_SV

typedef enum {WB_BUS, WB_RESET} wb_item_kind;

class wb_item extends uvm_sequence_item;
    // ===== Parámetros propios para los objetos =====
    rand wb_item_kind          kind;
    rand bit                   we;
    rand bit          [3 : 0]  sel;
    rand bit          [4 : 0]  addr;
    rand bit          [31 : 0] data;
    rand int unsigned          delay;
    rand int unsigned          rst_cycles;
    longint unsigned           stamp;   // Borde en que ocurrió

    // ===== Límites para la aleatorización =====
    int unsigned delay_min      = 0;
    int unsigned delay_max      = 10;
    int unsigned rst_cycles_min = 1;
    int unsigned rst_cycles_max = 5; 

    // ===== Restricciones =====
    constraint c_kind {
        soft kind == WB_BUS;
    }
    constraint c_rst_cycles {
        (kind == WB_BUS)   -> rst_cycles == 0;
        (kind == WB_RESET) -> rst_cycles inside {[rst_cycles_min : rst_cycles_max]};
    }
    constraint c_delay {
        delay inside {[delay_min : delay_max]};
    }

    // ===== Registro de item en la fábrica =====
    `uvm_object_utils_begin(wb_item)
        `uvm_field_enum(wb_item_kind, kind, UVM_ALL_ON)
        `uvm_field_int(we,                  UVM_ALL_ON)
        `uvm_field_int(sel,                 UVM_ALL_ON)
        `uvm_field_int(addr,                UVM_ALL_ON)
        `uvm_field_int(data,                UVM_ALL_ON)
        `uvm_field_int(delay,               UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(delay_min,           UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(delay_max,           UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(rst_cycles,          UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(rst_cycles_min,      UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(rst_cycles_max,      UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(stamp,               UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_object_utils_end

    // ===== Constructor con la fábrica =====
    function new(string name = "wb_item"); 
        super.new(name); 
    endfunction

endclass : wb_item

`endif // WB_ITEM_SV

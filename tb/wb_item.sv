// =======================================================
// Ítem Wishbone
// -------------------------------------------------------
// Item de secuencia: wb_item
//   - Parámetro data_W (32 u 8 bits) 
//   - Parámetro addr_W (5 o 3 bits)
// =======================================================


// =======================================================
// Ítem Wishbone (wb_item)
// =======================================================

`ifndef WB_ITEM_SV
`define WB_ITEM_SV

typedef enum {WB_BUS, WB_RESET} wb_item_kind;

class wb_item #(int data_W = `WB_DATA_W, int addr_W = `WB_ADDR_W) extends uvm_sequence_item;

    // ===== Define el tipo con parámetros =====
    typedef wb_item #(data_W, addr_W) this_wb_item;

    rand wb_item_kind                  kind;
    rand bit                           we;
    rand              [3 : 0]          sel;
    rand              [(addr_W-1) : 0] addr;
    rand              [(data_W-1) : 0] data;
    rand int unsigned                  delay;
    rand int unsigned                  rst_cycles;   // Duración del reset (kind = WB_RESET)
    longint unsigned                   stamp;        // Borde en que ocurrió (lo llena el monitor)

    // ===== Restricciones =====
    constraint c_kind{
        soft kind == WB_BUS;
    }
    constraint c_rst_cycles{
        (kind == WB_BUS)   -> rst_cycles == 0;
        (kind == WB_RESET) -> soft rst_cycles inside {[1 : 5]};
    }
    constraint c_delay{
        soft delay inside{[0 : 10]};
    }

    // ===== Registro de item en la fábrica =====
    `uvm_object_param_utils_begin(this_wb_item)
        `uvm_field_enum(wb_item_kind, kind, UVM_ALL_ON)
        `uvm_field_int(we,                  UVM_ALL_ON)
        `uvm_field_int(sel,                 UVM_ALL_ON)
        `uvm_field_int(addr,                UVM_ALL_ON)
        `uvm_field_int(data,                UVM_ALL_ON)
        `uvm_field_int(delay,               UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(rst_cycles,          UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int(stamp,               UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_object_utils_end

    // ===== Constructor con la fábrica =====
    function new(string name = "wb_item"); 
        super.new(name); 
    endfunction

endclass : wb_item

`endif // WB_ITEM_SV

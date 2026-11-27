`ifndef UART_COV_ITEM_SV
`define UART_COV_ITEM_SV

// =======================================================
//  Item de cobertura (uart_cov_item)
// -------------------------------------------------------
//  Lo crea el scoreboard cuando ocurre algo que se cubre,
//  con los datos de la transacción y el estado del modelo
//  en ese momento.
// =======================================================

// ===== Qué ocurrió =====
typedef enum {
    EV_WB,          // -> cg_regs
    EV_LINE_CFG,    // -> cg_line_cfg
    EV_CHAR,        // -> cg_line_cfg, cg_modem
    EV_RX_ERR,      // -> cg_err
    EV_FIFO,        // -> cg_fifo
    EV_INT,         // -> cg_int
    EV_MODEM,       // -> cg_modem
    EV_TRAFICO,     // -> cg_trafico
    EV_RST          // -> cg_rst
} uart_ev_kind_e;

class uart_cov_item extends uvm_object;
    `uvm_object_utils(uart_cov_item)

    uart_ev_kind_e kind;

    // ===== cg_regs =====

    // ===== cg_line_cfg =====

    // ===== cg_fifo =====

    // ===== cg_int =====

    // ===== cg_err =====

    // ===== cg_modem =====

    // ===== cg_trafico =====

    // ===== cg_rst =====

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_cov_item");
        super.new(name);
    endfunction
endclass : uart_cov_item

`endif //UART_COV_ITEM_SV
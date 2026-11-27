// =======================================================
//  Paquete del ambiente, interfaces y aserciones
// -------------------------------------------------------
//  Orden de includes: de acuerdo con las dependencias
// =======================================================

`ifndef UART_PKG_SV
`define UART_PKG_SV

`timescale 1ns/1ps

// =======================================================
//  Interfaces y Aserciones
// =======================================================
`include "wb_if.sv"
`include "mod_if.sv"
`include "ser_if.sv"
// `include "uart_sva.sv"


// =======================================================
//  Paquetes UVM y todas las clases el ambiente
// =======================================================
package uart_pkg;
    // ----- Paquetes UVM -----
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ----- Configuraciones -----
    `include "uart_cfg.sv"

    // ----- Sequence items -----
    `include "wb_item.sv"
    `include "mod_seq_item.sv"
    `include "ser_seq_item.sv"

    // ----- Agentes -----
    `include "wb_agent.sv"
    `include "mod_agent.sv"
    `include "ser_agent.sv"

    // ----- Infraestructura RAL -----
    `include "uart_ral.sv"

    // -----Scoreboard, cobertura y secuenciador virtual -----
    `include "uart_scoreboard.sv"
    //`include "uart_cov.sv"
    `include "uart_virtual_seqr.sv"

    // ----- Secuencias, ambiente y test -----
    `include "uart_seqs.sv"
    `include "uart_env.sv"
    `include "uart_test.sv"
endpackage : uart_pkg

`endif //UART_PKG_SV

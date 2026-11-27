// =======================================================
//  Testbench
// -------------------------------------------------------
//  DUT: UART 16550 | OpenCores
// -------------------------------------------------------
//  Test base: uart_base_test
// =======================================================
`timescale 1ns/1ps

`include "uart_pkg.sv"


// =======================================================
//  Módulo top Testbench
// =======================================================
module top_tb;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import uart_pkg::*;


    // ----- Reloj de 50 MHz -----
    logic clk = 1'b0;
    always #10 clk = ~clk;


    // ----- Punteros de las interfaces -----
    wb_if     wb  (.clk(clk));
    serial_if ser (.clk(clk), .rst(wb.rst));
    mod_if    mod (.clk(clk), .rst(wb.rst));

    // ===== Conexiones DUT =====
    uart_top dut(
        .wb_clk_i  (clk),

        // ----- Señales Wishbone ----- 
        .wb_rst_i  (wb.rst),
        .wb_adr_i  (wb.addr),
        .wb_dat_i  (wb.data_m2dut), // ambiente -> DUT
        .wb_dat_o  (wb.data_dut2m), // DUT -> ambiente
        .wb_we_i   (wb.we),
        .wb_stb_i  (wb.stb),
        .wb_cyc_i  (wb.cyc),
        .wb_ack_o  (wb.ack),
        .wb_sel_i  (wb.sel),
        
        // ----- Señales Seriales ----- 
        .stx_pad_o (ser.stx_pad_o),
        .srx_pad_i (ser.srx_pad_i),

        // ----- Señales Modem ----- 
        .rts_pad_o (mod.rts_pad_o),
        .cts_pad_i (mod.cts_pad_i),
        .dtr_pad_o (mod.dtr_pad_o),
        .dsr_pad_i (mod.dsr_pad_i),
        .ri_pad_i  (mod.ri_pad_i),
        .dcd_pad_i (mod.dcd_pad_i),
        .int_o     (mod.int_o)

        // ----- Puerto opcional ----- 
        `ifdef UART_HAS_BAUDRATE_OUTPUT
            , .baud_o  (ser.baud_o)
        `endif
    );

    // ===== Enlace de aserciones =====
    // pendiente...

    // ===== Inicio y paso de interfaces por config_db =====
    initial begin
        uvm_config_db#(virtual wb_if)::set(null, "uvm_test_top", "wb_vif", wb);
        uvm_config_db#(virtual serial_if)::set(null, "uvm_test_top", "serial_vif", ser);
        uvm_config_db#(virtual mod_if)::set(null, "uvm_test_top", "mod_vif", mod);

        run_test("uart_base_test");
    end
endmodule : top_tb

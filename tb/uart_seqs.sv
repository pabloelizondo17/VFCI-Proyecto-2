// =======================================================
//  Conjunto de secuencias virtuales
// -------------------------------------------------------
//  Proceso de configuración: config_DUT
//
//  Procesos principales:
//      - 
// -------------------------------------------------------
//  Secuencia virtual principal:
//      - uart_main_vseq
//
//  Otras secuencias virtuales:
//      - uart_main_vseq
// =======================================================

`ifndef UART_SEQS_SV
`define UART_SEQS_SV
// =======================================================
// Secuencia para escritura de datos a THR
// =======================================================


// =======================================================
// Secuencia para polling a RBR
// =======================================================


// =======================================================
// Secuencia para atender interrupciones
// =======================================================


// =======================================================
// Secuencia para la generación de tráfico serial
// =======================================================


// =======================================================
// Secuencia para señales modem
// =======================================================



// =======================================================
// Secuencia virtual principal (uart_main_vseq)
// =======================================================
class uart_main_vseq extends uvm_sequence;
    `uvm_object_utils(uart_main_vseq)
    `uvm_declare_p_sequencer(uart_virtual_seqr)
    
    // ===== Constructor con la fábrica =====
    function new(string name = "uart_main_vseq"); 
        super.new(name); 
    endfunction

    // ===== Body de la secuencia =====
    task body();
            uart_dut_cfg dut_cfg = p_sequencer.env_cfg.dut_cfg;

            if(!dut_cfg.randomize()) begin   // <= Aleatoriza la configuración del DUT
                `uvm_fatal("RAND", "No fue posible aleatorizar la configuración del DUT.")
            end

            reset_DUT();
            config_DUT(dut_cfg);

            // ===== Procesos de tráfico en paralelo =====
            fork
                wb_traffic();
                wb_int_service();
                serial_traffic();
                mod_traffic();
            join

            // ===== Esperar fin de tx y rx =====
            wait_tx();
            wait_rx();
    endtask

    // ===== Proceso de reset del DUT =====
    task reset_DUT();

    endtask

    // ===== Proceso de configuración =====
    task config_DUT(uart_dut_cfg dut_cfg);


    endtask
endclass : uart_main_vseq

`endif //UART_SEQS_SV

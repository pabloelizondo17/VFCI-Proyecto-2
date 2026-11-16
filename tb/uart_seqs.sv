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

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_main_vseq"); 
        super.new(name); 
    endfunction

    // ===== Secuenciador que ejecuta la secuencia =====
    `uvm_declare_p_sequencer(uart_virtual_seqr);

    // ===== Body de la secuencia =====
    task body();
        int unsigned ep_index = 0;  // <= Contador de episodios

        repeat (env_cfg.stim.episodes) begin

            if(ep == null) begin        // <= Reutiliza el mismo objeto para aplicar randc
                ep      = spi_dut_cfg::type_id::create("ep");
                ep.stim = cfg.stim;
            end

            if(!ep.randomize()) begin   // <= Aleatoriza la configuración del DUT
                `uvm_fatal("RAND", "No fue posible aleatorizar el episodio (EP: %0d).", ep_index)
            end

            config_DUT(ep);

            // ===== Procesos de tráfico en paralelo =====
            fork
                wb_traffic();
                wb_int_service();
                serial_traffic();
                mod_traffic();
            join

            wait_tx();
            wait_rx();

            ep_index++;
        end
    endtask

endclass : uart_main_vseq

`endif //UART_SEQS_SV

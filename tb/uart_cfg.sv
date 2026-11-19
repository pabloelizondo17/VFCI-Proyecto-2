// =======================================================
//  Conjunto de clases de configuración
// -------------------------------------------------------
//  Clases de configuración:
//      - uart_env_cfg
//      - uart_dut_cfg
//      -
// =======================================================

`ifndef UART_CFG_SV
`define UART_CFG_SV


// =======================================================
//  Clase de configuración para el DUT
// =======================================================
class uart_dut_cfg extends uvm_object;
    `uvm_object_utils(uart_dut_cfg)

    typedef int unsigned w4_t[4];
    typedef int unsigned w2_t[2];

    uart_stim_cfg stim;

    // ===== Knobs modificados por plusargs =====
    int unsigned dl_min = 2, dl_max = 16'hFFFF;

    w4_t fcr_tl_weights        = '{25, 25, 25, 25}; // [00=1,01=4,10=8,11=14] bytes
    w4_t lcr_bits_char_weights = '{25, 25, 25, 25}; // [00=5,01=6,10=7,11=8] bits
    w2_t mcr_loopback_weights  = '{70, 30};         // [normal,loopback]


    // ===== Registros para configurar el DUT =====
    rand bit [15 : 0] divisor_latch;
    bit      [7 : 0]  dl1_reg, dl2_reg;
    rand bit [7 : 0]  ier_reg;
    rand bit [7 : 0]  fcr_reg;
    rand bit [7 : 0]  mcr_reg;
    rand bit [7 : 0]  lcr_reg;


    // ===== Fields de IER =====
    rand bit ier_rda, ier_thre, ier_rls, ier_ms;

    // ===== Fields de FCR =====
    rand bit         fcr_rfr, fcr_tfr;
    rand bit [1 : 0] fcr_tl;

    // ===== Fields de MCR =====
    rand bit mcr_dtr, mcr_rts, mcr_out1, mcr_out2, mcr_lb;

    // ===== Fields de LCR =====
    rand bit [1 : 0] lcr_bits;
    rand bit         lcr_sb, lcr_pe, lcr_ep, lcr_sp, lcr_bc, lcr_dl;


    // ===== Restricciones para Divisor Latch =====
    constraint c_divisor_latch {
        soft divisor_latch >= 1;

        divisor_latch dist{
            [1 : 16'hF]       :/ 30,    // <= rapido
            [16 : 16'hFF]     :/ 30,    // <= medio
            [256 : 16'hFFF]   :/ 30,    // <= medio/lento
            [4096 : 16'hFFFF] :/ 10     // <= lento
        };

        dl2_reg == divisor_latch[15 : 8];
        dl1_reg == divisor_latch[7 : 0];
    }






    

    // ===== Separa Divisor Latch en DL1 y DL2 =====
    function void post_randomize();
        dl2_reg = divisor_latch[15 : 8];
        dl1_reg = divisor_latch[7 : 0];
    endfunction

    // ===== Funciones para obtener registros enteros (concatenados) =====
    function bit [7 : 0] ier_value();

    endfunction

    function bit [7 : 0] fcr_value();

    endfunction

    function bit [7 : 0] mcr_value();

    endfunction

    function bit [7 : 0] lcr_value(bit dlab = 0);

    endfunction

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_dut_cfg");
        super.new(name); 
    endfunction
endclass : uart_dut_cfg



// =======================================================
//  Clase de configuración para el ambiente
// -------------------------------------------------------
//  Lee los plusargs y agrupa:
//      -
//      -
//      -
// =======================================================
class uart_env_cfg extends uvm_object;

endclass : uart_dut_cfg

`endif //UART_CFG_SV

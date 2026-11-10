// =======================================================
// Interfaz Wishbone
// -------------------------------------------------------
// Item de secuencia: wb_item
//   - Parámetro data_W (32 u 8 bits) 
//   - Parámetro addr_W (5 o 3 bits)
// =======================================================


// =======================================================
// Interfaz Wishbone
// =======================================================

`ifndef WB_IF_SV
`define WB_IF_SV

interface wb_if #(int data_W = `WB_DATA_W, int addr_W = `WB_ADDR_W)(input logic clk);
    logic                  rst = 1'b0;
    logic                  we  = 1'b0;
    logic                  stb = 1'b0;
    logic                  cyc = 1'b0;
    logic                  ack;
    logic [3 : 0]          sel = 4'b0;

    logic [(addr_W-1) : 0] addr       = '0;  // ambiente -> DUT
    logic [(data_W-1) : 0] data_m2dut = '0;  // ambiente -> DUT
    logic [(data_W-1) : 0] data_dut2m;       // DUT -> ambiente

    longint unsigned clk_counter       = 0;
    always @(posedge clk) clk_counter <= clk_counter + 1;


    // ===== Clocking block para el driver wishbone =====
    clocking wb_driver_cb @(posedge clk);
        default input #1step output #1;
        output rst, we, stb, cyc, sel, addr, data_m2dut;
        input ack, data_dut2m, clk_counter;
    endclocking

    // ===== Clocking block para el monitor wishbone =====
    clocking wb_monitor_cb @(posedge clk);
        default input #1step;
        input rst, we, stb, cyc, ack, sel, addr, 
              data_m2dut, data_dut2m, clk_counter;
    endclocking

    // ===== Modport para el driver wishbone =====
    modport wb_driver_mp(
        clocking wb_driver_cb,
        input clk
    );

    // ===== Modport para el monitor wishbone =====
    modport wb_monitor_mp(
        clocking wb_monitor_cb,
        input clk
    );

    // ===== Modport para el DUT =====
    modport wb_dut_mp(
        input clk, rst, we, stb, cyc, sel, addr, data_m2dut
        output ack, data_dut2m
    );

endinterface : wb_if

`endif // WB_IF_SV

class uart_scoreboard_cfg extends uvm_object;
    `uvm_object_utils(uart_scoreboard_cfg)

    //Interfaz del bus: de aqui se saca rst y clk_counter
    virtual wb_if vif;

    //Desviacion maxima de baudios (%) para comparar un caracter RX
    int unsigned baud_tol = 4;

    //Constructor
    function new(string name = "uart_scoreboard_cfg");
        super.new(name);
    endfunction
endclass : uart_scoreboard_cfg
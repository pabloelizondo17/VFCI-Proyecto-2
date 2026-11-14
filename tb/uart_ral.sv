// =======================================================
//  Infraestructura RAL
// -------------------------------------------------------
// Modelo RAL (registros | dirección | modo (W y/o R)):
//      - RBR | 0 | R
//      - THR | 0 | W
//      - IER | 1 | RW
//      - IIR | 2 | R
//      - FCR | 2 | W
//      - LCR | 3 | RW
//      - MCR | 4 | W
//      - LSR | 5 | R
//      - MSR | 6 | R
//      - SR  | 7 | RW
//
//      - DL1 | 0 | RW
//      - DL2 | 1 | RW
//
//      - DBG1 | 8  | R
//      - DBG2 | 12 | R
// -------------------------------------------------------
// Objeto de configuración: uart_reg_block_cfg
// =======================================================


`ifndef UART_RAL_SV
`define UART_RAL_SV

// =======================================================
// Modelo RAL
// =======================================================

// ===== Registro RBR ====================================
class uart_rbr_reg extends uvm_reg;
    `uvm_object_utils(uart_rbr_reg)

    rand uvm_reg_field rx;

    // ===== Constructor con la fábrica =====
    function new(string name = "rbr"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        rx = uvm_reg_field::type_id::create("rx");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        rx.configure(this, 8, 0, "RO", 1, 8'b0, 0, 0, 0);
    endfunction
endclass : uart_rbr_reg


// ===== Registro THR ====================================
class uart_thr_reg extends uvm_reg;
    `uvm_object_utils(uart_thr_reg)

    rand uvm_reg_field tx;

    // ===== Constructor con la fábrica =====
    function new(string name = "thr"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        tx = uvm_reg_field::type_id::create("tx");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        tx.configure(this, 8, 0, "WO", 0, 8'b0, 0, 1, 0);
    endfunction
endclass : uart_thr_reg


// ===== Registro IER ====================================
class uart_ier_reg extends uvm_reg;
    `uvm_object_utils(uart_ier_reg)

    rand uvm_reg_field rda, thre, rls, ms;

    // ===== Constructor con la fábrica =====
    function new(string name = "ier"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        rda  = uvm_reg_field::type_id::create("rda");
        thre = uvm_reg_field::type_id::create("thre");
        rls  = uvm_reg_field::type_id::create("rls");
        ms   = uvm_reg_field::type_id::create("ms");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        rda .configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
        thre.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 0);
        rls .configure(this, 1, 2, "RW", 0, 1'b0, 1, 1, 0);
        ms  .configure(this, 1, 3, "RW", 0, 1'b0, 1, 1, 0);
    endfunction
endclass : uart_ier_reg


// ===== Registro IIR ====================================
class uart_iir_reg extends uvm_reg;
    `uvm_object_utils(uart_iir_reg)

    rand uvm_reg_field ip, ii, fifoen;

    // ===== Constructor con la fábrica =====
    function new(string name = "iir"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        ip     = uvm_reg_field::type_id::create("ip");
        ii     = uvm_reg_field::type_id::create("ii");
        fifoen = uvm_reg_field::type_id::create("fifoen");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        ip    .configure(this, 1, 0, "RO", 1, 1'b1,   1, 0, 0);
        ii    .configure(this, 3, 1, "RO", 1, 3'b000, 1, 0, 0);
        fifoen.configure(this, 2, 6, "RO", 0, 2'b11,  1, 0, 0);
    endfunction
endclass : uart_iir_reg


// ===== Registro FCR ====================================
class uart_fcr_reg extends uvm_reg;
    `uvm_object_utils(uart_fcr_reg)

    rand uvm_reg_field rfr, tfr, tl;

    // ===== Constructor con la fábrica =====
    function new(string name = "fcr"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        rfr = uvm_reg_field::type_id::create("rfr");
        tfr = uvm_reg_field::type_id::create("tfr");
        tl  = uvm_reg_field::type_id::create("tl");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        rfr.configure(this, 1, 1, "WO", 0, 1'b0,  1, 1, 0);
        tfr.configure(this, 1, 2, "WO", 0, 1'b0,  1, 1, 0);
        tl .configure(this, 2, 6, "WO", 0, 2'b11, 1, 1, 0);
    endfunction
endclass : uart_fcr_reg


// ===== Registro LCR ====================================
class uart_lcr_reg extends uvm_reg;
    `uvm_object_utils(uart_lcr_reg)

    rand uvm_reg_field bits, sb, pe, ep, sp, bc, dl;

    // ===== Constructor con la fábrica =====
    function new(string name = "lcr"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        bits = uvm_reg_field::type_id::create("bits");
        sb   = uvm_reg_field::type_id::create("sb");
        pe   = uvm_reg_field::type_id::create("pe");
        ep   = uvm_reg_field::type_id::create("ep");
        sp   = uvm_reg_field::type_id::create("sp");
        bc   = uvm_reg_field::type_id::create("bc");
        dl   = uvm_reg_field::type_id::create("dl");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        bits.configure(this, 2, 0, "RW", 0, 2'b11, 1, 1, 0);
        sb  .configure(this, 1, 2, "RW", 0, 1'b0,  1, 1, 0);
        pe  .configure(this, 1, 3, "RW", 0, 1'b0,  1, 1, 0);
        ep  .configure(this, 1, 4, "RW", 0, 1'b0,  1, 1, 0);
        sp  .configure(this, 1, 5, "RW", 0, 1'b0,  1, 1, 0);
        bc  .configure(this, 1, 6, "RW", 0, 1'b0,  1, 1, 0);
        dl  .configure(this, 1, 7, "RW", 0, 1'b0,  1, 1, 0); // <= DLAB
    endfunction
endclass : uart_lcr_reg


// ===== Registro MCR ====================================
class uart_mcr_reg extends uvm_reg;
    `uvm_object_utils(uart_mcr_reg)

    rand uvm_reg_field dtr, rts, out1, out2, lb;

    // ===== Constructor con la fábrica =====
    function new(string name = "mcr"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        dtr  = uvm_reg_field::type_id::create("dtr");
        rts  = uvm_reg_field::type_id::create("rts");
        out1 = uvm_reg_field::type_id::create("out1");
        out2 = uvm_reg_field::type_id::create("out2");
        lb   = uvm_reg_field::type_id::create("lb");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        dtr .configure(this, 1, 0, "WO", 0, 1'b0,  1, 1, 0);
        rts .configure(this, 1, 1, "WO", 0, 1'b0,  1, 1, 0);
        out1.configure(this, 1, 2, "WO", 0, 1'b0,  1, 1, 0);
        out2.configure(this, 1, 3, "WO", 0, 1'b0,  1, 1, 0);
        lb  .configure(this, 1, 4, "WO", 0, 1'b0,  1, 1, 0);
    endfunction
endclass : uart_mcr_reg


// ===== Registro LSR ====================================
class uart_lsr_reg extends uvm_reg;
    `uvm_object_utils(uart_lsr_reg)

    rand uvm_reg_field dr, oe, pe, fe, bi, tfe, te, ei;

    // ===== Constructor con la fábrica =====
    function new(string name = "lsr"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        dr  = uvm_reg_field::type_id::create("dr");
        oe  = uvm_reg_field::type_id::create("oe");
        pe  = uvm_reg_field::type_id::create("pe");
        fe  = uvm_reg_field::type_id::create("fe");
        bi  = uvm_reg_field::type_id::create("bi");
        tfe = uvm_reg_field::type_id::create("tfe");
        te  = uvm_reg_field::type_id::create("te");
        ei  = uvm_reg_field::type_id::create("ei");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        dr  .configure(this, 1, 0, "RO", 1, 1'b0,  1, 0, 0);
        oe  .configure(this, 1, 1, "RO", 1, 1'b0,  1, 0, 0);
        pe  .configure(this, 1, 2, "RO", 1, 1'b0,  1, 0, 0);
        fe  .configure(this, 1, 3, "RO", 1, 1'b0,  1, 0, 0);
        bi  .configure(this, 1, 4, "RO", 1, 1'b0,  1, 0, 0);
        tfe .configure(this, 1, 5, "RO", 1, 1'b1,  1, 0, 0);
        te  .configure(this, 1, 6, "RO", 1, 1'b1,  1, 0, 0);
        ei  .configure(this, 1, 7, "RO", 1, 1'b0,  1, 0, 0);
    endfunction
endclass : uart_lsr_reg


// ===== Registro MSR ====================================
class uart_msr_reg extends uvm_reg;
    `uvm_object_utils(uart_msr_reg)

    rand uvm_reg_field dcts, ddsr, teri, ddcd, ccts, cdsr, cri, cdcd;

    // ===== Constructor con la fábrica =====
    function new(string name = "msr"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        dcts = uvm_reg_field::type_id::create("dcts");
        ddsr = uvm_reg_field::type_id::create("ddsr");
        teri = uvm_reg_field::type_id::create("teri");
        ddcd = uvm_reg_field::type_id::create("ddcd");
        ccts = uvm_reg_field::type_id::create("ccts");
        cdsr = uvm_reg_field::type_id::create("cdsr");
        cri  = uvm_reg_field::type_id::create("cri");
        cdcd = uvm_reg_field::type_id::create("cdcd");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        dcts.configure(this, 1, 0, "RO", 1, 1'b0,  1, 0, 0);
        ddsr.configure(this, 1, 1, "RO", 1, 1'b0,  1, 0, 0);
        teri.configure(this, 1, 2, "RO", 1, 1'b0,  1, 0, 0);
        ddcd.configure(this, 1, 3, "RO", 1, 1'b0,  1, 0, 0);
        ccts.configure(this, 1, 4, "RO", 1, 1'b0,  0, 0, 0);
        cdsr.configure(this, 1, 5, "RO", 1, 1'b0,  0, 0, 0);
        cri .configure(this, 1, 6, "RO", 1, 1'b0,  0, 0, 0);
        cdcd.configure(this, 1, 7, "RO", 1, 1'b0,  0, 0, 0);
    endfunction
endclass : uart_msr_reg


// ===== Registro SR =====================================
class uart_sr_reg extends uvm_reg;
    `uvm_object_utils(uart_sr_reg)

    rand uvm_reg_field scratch;

    // ===== Constructor con la fábrica =====
    function new(string name = "sr"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        scratch = uvm_reg_field::type_id::create("scratch");
    
        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        scratch.configure(this, 8, 0, "RW", 0, 8'b0, 1, 1, 0);
    endfunction
endclass : uart_sr_reg


// ===== Registro DL1 ====================================
class uart_dl1_reg extends uvm_reg;
    `uvm_object_utils(uart_dl1_reg)

    rand uvm_reg_field dl1;

    // ===== Constructor con la fábrica =====
    function new(string name = "dl1"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        dl1 = uvm_reg_field::type_id::create("dl1");
    
        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        dl1.configure(this, 8, 0, "RW", 0, 8'b0, 1, 1, 0);
    endfunction
endclass : uart_dl1_reg

// ===== Registro DL2 ====================================
class uart_dl2_reg extends uvm_reg;
    `uvm_object_utils(uart_dl2_reg)

    rand uvm_reg_field dl2;

    // ===== Constructor con la fábrica =====
    function new(string name = "dl2"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 8, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        dl2 = uvm_reg_field::type_id::create("dl2");
    
        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        dl2.configure(this, 8, 0, "RW", 0, 8'b0, 1, 1, 0);
    endfunction
endclass : uart_dl2_reg


// ===== Registro DBG1 ===================================
class uart_dbg1_reg extends uvm_reg;
    `uvm_object_utils(uart_dbg1_reg)

    rand uvm_reg_field lsr_v, ier_v, iir_v, lcr_v, msr_v;

    // ===== Constructor con la fábrica =====
    function new(string name = "dbg1"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 32, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        lsr_v = uvm_reg_field::type_id::create("lsr_v");
        ier_v = uvm_reg_field::type_id::create("ier_v");
        iir_v = uvm_reg_field::type_id::create("iir_v");
        lcr_v = uvm_reg_field::type_id::create("lcr_v");
        msr_v = uvm_reg_field::type_id::create("msr_v");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        lsr_v.configure(this, 8, 0,  "RO", 1, 8'h60, 1, 0, 0);
        ier_v.configure(this, 4, 8,  "RO", 1, 4'h00, 1, 0, 0);
        iir_v.configure(this, 4, 12, "RO", 1, 4'h01, 1, 0, 0);
        lcr_v.configure(this, 8, 16, "RO", 1, 8'h03, 1, 0, 0);
        msr_v.configure(this, 8, 24, "RO", 1, 8'h00, 1, 0, 0);
    endfunction
endclass : uart_dbg1_reg


// ===== Registro DBG2 ===================================
class uart_dbg2_reg extends uvm_reg;    // <= PENDIENTE DE REVISAR
    `uvm_object_utils(uart_dbg2_reg)

    rand uvm_reg_field tstate, tf_count, rstate, rf_count, mcr_v, fcr_v;

    // ===== Constructor con la fábrica =====
    function new(string name = "dbg2"); 
        //(nombre, total_bits, cobertura)
        super.new(name, 32, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        tstate   = uvm_reg_field::type_id::create("tstate");
        tf_count = uvm_reg_field::type_id::create("tf_count");
        rstate   = uvm_reg_field::type_id::create("rstate");
        rf_count = uvm_reg_field::type_id::create("rf_count");
        mcr_v    = uvm_reg_field::type_id::create("mcr_v");
        fcr_v    = uvm_reg_field::type_id::create("fcr_v");

        //(padre, tamaño, pos. de lsb, acceso, volatil, 
        // valor rst, rst conocido, rand? y se accede solo)
        tstate  .configure(this, 3, 0,  "RO", 1, 3'h00, 1, 0, 0);
        tf_count.configure(this, 5, 3,  "RO", 1, 5'h00, 1, 0, 0);
        rstate  .configure(this, 4, 8,  "RO", 1, 4'h00, 1, 0, 0);
        rf_count.configure(this, 5, 12, "RO", 1, 5'h00, 1, 0, 0);
        mcr_v   .configure(this, 2, 17, "RO", 1, 2'h00, 1, 0, 0);
        fcr_v   .configure(this, 5, 19, "RO", 1, 5'h11, 1, 0, 0);
    endfunction
endclass : uart_dbg2_reg


// ===== Bloque de registros =============================
class uart_reg_block extends uvm_reg_block;
    `uvm_object_utils(uart_reg_block)

    uvm_reg_map map_dlab0;
    uvm_reg_map map_dlab1;

    rand uart_rbr_reg  rbr;
    rand uart_thr_reg  thr;
    rand uart_ier_reg  ier;
    rand uart_iir_reg  iir;
    rand uart_fcr_reg  fcr;
    rand uart_lcr_reg  lcr;
    rand uart_mcr_reg  mcr;
    rand uart_lsr_reg  lsr;
    rand uart_msr_reg  msr;
    rand uart_sr_reg   sr;
    rand uart_dl1_reg  dl1;
    rand uart_dl2_reg  dl2;
    rand uart_dbg1_reg dbg1;
    rand uart_dbg2_reg dbg2;

    // ===== Constructor con la fábrica =====
    function new(string name = "uart_reg_block"); 
        super.new(name, UVM_NO_COVERAGE); 
    endfunction

    virtual function void build();
        rbr  = uart_rbr_reg::type_id::create("rbr");
        thr  = uart_thr_reg::type_id::create("thr");
        ier  = uart_ier_reg::type_id::create("ier");
        iir  = uart_iir_reg::type_id::create("iir");
        fcr  = uart_fcr_reg::type_id::create("fcr");
        lcr  = uart_lcr_reg::type_id::create("lcr");
        mcr  = uart_mcr_reg::type_id::create("mcr");
        lsr  = uart_lsr_reg::type_id::create("lsr");
        msr  = uart_msr_reg::type_id::create("msr");
        sr   = uart_sr_reg::type_id::create("sr");
        dl1  = uart_dl1_reg::type_id::create("dl1");
        dl2  = uart_dl2_reg::type_id::create("dl2");
        dbg1 = uart_dbg1_reg::type_id::create("dbg1");
        dbg2 = uart_dbg2_reg::type_id::create("dbg2");

        rbr.configure(this); rbr.build();
        thr.configure(this); thr.build();
        ier.configure(this); ier.build();
        iir.configure(this); iir.build();
        fcr.configure(this); fcr.build();
        lcr.configure(this); lcr.build();
        mcr.configure(this); mcr.build();
        lsr.configure(this); lsr.build();
        msr.configure(this); msr.build();
        sr.configure(this); sr.build();
        dl1.configure(this); dl1.build();
        dl2.configure(this); dl2.build();
        dbg1.configure(this); dbg1.build();
        dbg2.configure(this); dbg2.build();

        // ===== Mapa 1: map_dlab0 (RBR, THR, IER, IIR,
        //       FCR, LCR, MCR, LSR, MSR, SR, DBG1, DBG2) =====
        //            (name, base_addr, n_bytes, endian, byte_addressing = 1)
        map_dlab0 = create_map("map_dlab0", 'h0, 4, UVM_LITTLE_ENDIAN, 1);

        map_dlab0.add_reg(rbr, 'h0, "RO");
        map_dlab0.add_reg(thr, 'h0, "WO");
        map_dlab0.add_reg(ier, 'h1, "RW");
        map_dlab0.add_reg(iir, 'h2, "RO");
        map_dlab0.add_reg(fcr, 'h2, "WO");
        map_dlab0.add_reg(lcr, 'h3, "RW");
        map_dlab0.add_reg(mcr, 'h4, "WO");
        map_dlab0.add_reg(lsr, 'h5, "RO");
        map_dlab0.add_reg(msr, 'h6, "RO");
        map_dlab0.add_reg(sr,  'h7, "RW");
        map_dlab0.add_reg(dbg1,'h8, "RO");
        map_dlab0.add_reg(dbg2,'hC, "RO");


        // ===== Mapa 2: map_dlab1 (DL1, DL2, IIR, FCR, 
        //       LCR, MCR, LSR, MSR, SR, DBG1, DBG2) =====
        map_dlab1 = create_map("map_dlab1", 'h0, 4, UVM_LITTLE_ENDIAN, 1);

        map_dlab1.add_reg(dl1, 'h0, "RW");
        map_dlab1.add_reg(dl2, 'h1, "RW");
        map_dlab1.add_reg(iir, 'h2, "RO");
        map_dlab1.add_reg(fcr, 'h2, "WO");
        map_dlab1.add_reg(lcr, 'h3, "RW");
        map_dlab1.add_reg(mcr, 'h4, "WO");
        map_dlab1.add_reg(lsr, 'h5, "RO");
        map_dlab1.add_reg(msr, 'h6, "RO");
        map_dlab1.add_reg(sr,  'h7, "RW");
        map_dlab1.add_reg(dbg1,'h8, "RO");
        map_dlab1.add_reg(dbg2,'hC, "RO");

        default_map = map_dlab0;

        lock_model();
    endfunction
endclass : uart_reg_block


// =======================================================
// Adaptador RAL
//  -reg2bus: traduce operaciones del registro al bus
//  -bus2reg: traduce operaciones del bus al registro
// -------------------------------------------------------
// Objeto de configuración: wb_agent_cfg
// =======================================================
class uart_reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(uart_reg_adapter)

    // ===== Constructor con la fábrica =====
    function new(string name = "spi_reg_adapter");
        super.new(name);

        supports_byte_enable = 0;
        provides_responses   = 0;
    endfunction

    //wb_agent_cfg  cfg;

    // ===== Escritura del modelo al bus =====
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        wb_item_t item = wb_item_t::type_id::create("item");

        int unsigned lane      = rw.addr[1 : 0];
        bit          full_word = (rw.n_bits == 32);

        item.kind       = WB_BUS;
        item.we         = (rw.kind == UVM_WRITE);
        item.addr       = rw.addr;
        item.data       = (rw.kind == UVM_WRITE) ? rw.data : '0;
        item.sel  = full_word ? 4'hF : (4'b0001 << lane);

        item.rst_cycles.randomize();   // (kind = WB_BUS -> rst_cycles = 0)
        item.delay.randomize();

        return item;
    endfunction

    // ===== Escritura del bus al modelo =====
    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        wb_item_t item;

        // ===== Verificación de seguridad =====
        if (!$cast(item, bus_item)) begin
            `uvm_fatal("ADAPTER", "bus2reg recibió un ítem que no es de tipo wb_item")
            return;
        end

        rw.kind   = item.we ? UVM_WRITE : UVM_READ;
        rw.addr   = item.addr;
        rw.data   = item.data;
        rw.status = UVM_IS_OK;
    endfunction
endclass : uart_reg_adapter

`endif //UART_RAL_SV

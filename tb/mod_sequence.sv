`ifndef MOD_SEQUENCE_SV
`define MOD_SEQUENCE_SV

class mod_trafico extends uvm_sequence #(mod_seq_item);
  `uvm_object_utils(mod_trafico)

  //Configuración
  mod_agent_cfg mod_cfg;

  //Valores que randomizan una vez por época
  int unsigned n_items;
  int unsigned toggle_porc;

  //Incializa valor del estado de cada línea 
  bit dsr_ultimo = 1'b0;
  bit ri_ultimo = 1'b0;
  bit cts_ultimo = 1'b0;
  bit dcd_ultimo = 1'b0;

  //Constructor
  function new(string name = "mod_sequence"); 
    super.new(name); 
  endfunction

  //Porcentaje de cambio en el bit (0 no cambia y 1 si cambia): Orden (dcd, ri, dsr, cts)
  virtual function bit [3:0] pick_toggles();
    bit [3:0] t; 
    for (int i = 0; i < 4; i++) begin
      t[i] = ($urandom_range(99) < toggle_porc); 
    end   
    return t; 
  endfunction 
  
  task body();

   bit [3:0] toggle; 

   //Obtiene configuración 
   if (!uvm_config_db#(mod_agent_cfg)::get(m_sequencer, "", "cfg", mod_cfg))
    `uvm_fatal("NO_CFG", "Secuencia del modem sin mod_cfg")
    
    //Sortea valores de época
    n_items    = $urandom_range(mod_cfg.n_items_max,    mod_cfg.n_items_min);
    toggle_porc = $urandom_range(mod_cfg.toggle_pct_max, mod_cfg.toggle_pct_min);
    `uvm_info("mod_trafico", $sformatf("Epoca de modem: n_items=%0d toggle_porc=%0d",n_items, toggle_porc), UVM_MEDIUM)

    repeat (n_items) begin
     toggle = pick_toggles();

     req = mod_seq_item::type_id::create("req");
     start_item(req);

     req.cts_pad_i = toggle[0] ? !cts_ultimo : cts_ultimo;
     req.dsr_pad_i = toggle[1] ? !dsr_ultimo : dsr_ultimo;
     req.ri_pad_i  = toggle[2] ? !ri_ultimo  : ri_ultimo;
     req.dcd_pad_i = toggle[3] ? !dcd_ultimo : dcd_ultimo;
     req.delay     = $urandom_range(mod_cfg.toggle_delay_max, mod_cfg.toggle_delay_min);
     finish_item(req);

     //Registro de lo que mandó 
     cts_ultimo = req.cts_pad_i;
     dsr_ultimo = req.dsr_pad_i;
     ri_ultimo  = req.ri_pad_i;
     dcd_ultimo = req.dcd_pad_i;

    end
  endtask 


endclass: mod_trafico

`endif //MOD_SEQUENCE_SV
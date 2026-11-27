# =======================================================
#  Makefile del ambiente UVM
# =======================================================

# ----- Simulador -----
SIM       = vcs

# ----- Carpetas -----
RTL_DIR   = src
AMB_DIR   = tb
SIM_DIR   = sim

# ----- Archivos -----
TOP       = top

//Wildcard devuelve todos los archivos de src que terminen en .v
RTL_FILES = $(filter-out $(RTL_DIR)/uart_defines.v $(SRC_DIR)/timescale.v, \$(wildcard $(SRC_DIR)/*.v))

TB_FILES  = $(AMB_DIR)/uart_pkg.sv \
            $(AMB_DIR)/top.sv

# ----- Opciones de compilación -----
COMP_OPTS = -full64 \
            -sverilog \
            -ntb_opts uvm-1.2 \
            -timescale=1ns/1ps \
            -debug_access+all \
            +incdir+$(SRC_DIR) \
            +incdir+$(TB_DIR) \
            -Mdir=$(SIM_DIR)/csrc

# ----- Compilar -----
compile:
	mkdir -p $(SIM_DIR)
	$(SIM) $(COMP_OPTS) $(RTL_FILES) $(TB_FILES) \
	    -top $(TOP) -o $(SIM_DIR)/simv -l $(SIM_DIR)/comp.log
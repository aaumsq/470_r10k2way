# make          <- runs simv (after compiling simv if needed)
# make simv     <- compile simv if needed (but do not run)
# make syn      <- runs syn_simv (after synthesizing if needed then 
#                                 compiling synsimv if needed)
# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be 
# similar to the information in those scripts but that seems hard to avoid.
#

VCS = SW_VCS=2015.09 vcs -sverilog +vc -Mupdate -line -full64 +lint=TFIPC-L
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

.PHONY: all
all:    run_all_ut

.PHONY: syn
syn:	
	./syn_test

##### 
# Modify starting here
#####

BASE = sys_defs.vh
SYNTH_DIR = ./synth
PIPE_TESTBENCH = testbench/testbench.v $(MEM_UNIT_TESTBENCH) testbench/print.c
PIPE_SIMFILES = verilog/pipeline.v $(ROB_SIMFILES) $(RS_SIMFILES) $(MULT_SIMFILES) $(ALU_SIMFILES) \
                $(REG_SIMFILES) $(HAZ_SIMFILES) $(MT_SIMFILES) $(FL_SIMFILES) $(CDB_SIMFILES)  \
                $(FUS_SIMFILES) $(FUBI_SIMFILES) $(MEM_SIMFILES) $(IF_SIMFILES) $(IB_SIMFILES) \
                $(BS_SIMFILES) $(AT_SIMFILES) $(PF_SIMFILES) $(APF_SIMFILES) $(BRANCH_SIMFILES) \
                $(CC_SIMFILES) $(MEMFU_SIMFILES) 
                #$(IC_SIMFILES) $(DC_SIMFILES) $(DE_SIMFILES) $(BP_SIMFILES) $(SQ_SIMFILES) $(MA_SIMFILES)
                
PIPE_MODULE = $(IF_SYNFILES) $(BP_SYNFILES) $(BS_SYNFILES) $(ROB_SYNFILES) $(RS_SYNFILES) $(MULT_SYNFILES) \
              $(ALU_SYNFILES) $(HAZ_SYNFILES) $(MT_SYNFILES) $(AT_SYNFILES) $(FL_SYNFILES) $(CDB_SYNFILES) \
              $(FUS_SYNFILES) $(IB_SYNFILES) $(FUBI_SYNFILES)  $(FD_SYNFILES) $(PF_SYNFILES) $(APF_SYNFILES) \
              $(MA_SYNFILES) $(BRANCH_SYNFILES) $(SQ_SYNFILES)  $(MEMFU_SYNFILES)
              #$(DE_SYNFILES) $(REG_SYNFILES) $(CC_SYNFILES) $(IC_SYNFILES) $(DC_SYNFILES)

PIPE_SYNFILES = $(SYNTH_DIR)/pipeline.vg

MEM_UNIT_TESTBENCH = testbench/mem.v
MEM_SIMFILES = 
MEM_SYNFILES = 

CC_UNIT_TESTBENCH =
CC_SIMFILES = verilog/CacheCtrl.v verilog/DMEM/dcache.v verilog/IMEM/icache.v
CC_SYNFILES = $(SYNTH_DIR)/CacheCtrl.vg

MEMFU_UNIT_TESTBENCH =
MEMFU_SIMFILES = verilog/DMEM/dmemFU.v verilog/DMEM/SQ.v verilog/DMEM/memAlu.v
MEMFU_SYNFILES = $(SYNTH_DIR)/dmemFU.vg

IC_UNIT_TESTBENCH =
IC_SIMFILES = verilog/IMEM/icache.v
IC_SYNFILES = $(SYNTH_DIR)/icache.vg

DC_UNIT_TESTBENCH =
DC_SIMFILES = verilog/DMEM/dcache.v
DC_SYNFILES = $(SYNTH_DIR)/dcache.vg

IF_UNIT_TESTBENCH = 
IF_SIMFILES = verilog/IMEM/if_stage.v verilog/IMEM/BP.v verilog/IMEM/FetchDecoder.v
IF_SYNFILES = $(SYNTH_DIR)/if_stage.vg

BP_UNIT_TESTBENCH = 
BP_SIMFILES = verilog/IMEM/BP.v
BP_SYNFILES = $(SYNTH_DIR)/BP.vg

BS_UNIT_TESTBENCH = 
BS_SIMFILES = verilog/BranchStack.v
BS_SYNFILES = $(SYNTH_DIR)/branchStack.vg

ROB_UNIT_TESTBENCH = #testbench/ROBUnitTest.v testbench/ROBPrintSim.c
ROB_SIMFILES = verilog/ROB.v
ROB_SYNFILES = $(SYNTH_DIR)/ROB.vg

RS_UNIT_TESTBENCH = #testbench/RSUnitTest.v testbench/RSPrintSim.c
RS_SIMFILES = verilog/RS.v
RS_SYNFILES = $(SYNTH_DIR)/RS.vg

MULT_UNIT_TESTBENCH = #testbench/mult_test.v
MULT_SIMFILES = verilog/FU/pipe_mult_fu.v
MULT_SYNFILES = $(SYNTH_DIR)/pipe_mult_fu.vg 

ALU_UNIT_TESTBENCH = #testbench/ALUUnitTest.v
ALU_SIMFILES = verilog/FU/alu_fu.v verilog/decoder.v
ALU_SYNFILES = $(SYNTH_DIR)/alu_fu.vg $(SYNTH_DIR)/decoder.vg

BRANCH_UNIT_TESTBENCH = 
BRANCH_SIMFILES = verilog/FU/branch_fu.v
BRANCH_SYNFILES = $(SYNTH_DIR)/branch_fu.vg

MA_UNIT_TESTBENCH = 
MA_SIMFILES = verilog/DMEM/memAlu.v
MA_SYNFILES = $(SYNTH_DIR)/memAlu.vg

REG_UNIT_TESTBENCH = #testbench/regfileUnitTest.v
REG_SIMFILES = verilog/regfile.v
REG_SYNFILES = $(SYNTH_DIR)/regfile.vg

HAZ_UNIT_TESTBENCH = 
HAZ_SIMFILES = verilog/if_id_hazard.v
HAZ_SYNFILES = $(SYNTH_DIR)/if_id_hazard.vg

MT_UNIT_TESTBENCH = #testbench/MTUnitTest.v testbench/MTPrintSim.c
MT_SIMFILES = verilog/MapTable.v
MT_SYNFILES = $(SYNTH_DIR)/MapTable.vg

AT_UNIT_TESTBENCH = 
AT_SIMFILES = verilog/ArchTable.v
AT_SYNFILES = $(SYNTH_DIR)/ArchTable.vg

FL_UNIT_TESTBENCH = #testbench/FLUnitTest.v testbench/FLPrintSim.c
FL_SIMFILES = verilog/FreeList.v
FL_SYNFILES = $(SYNTH_DIR)/FreeList.vg

DE_UNIT_TESTBENCH = 
DE_SIMFILES = verilog/decoder.v
DE_SYNFILES = $(SYNTH_DIR)/decoder.vg

CDB_UNIT_TESTBENCH = #testbench/CDBUnitTest.v testbench/CDBPrintSim.c
CDB_SIMFILES = verilog/CDB.v
CDB_SYNFILES = $(SYNTH_DIR)/CDB.vg

FUS_UNIT_TESTBENCH = #testbench/FUSUnitTest.v
FUS_SIMFILES = verilog/FU/FUS.v
FUS_SYNFILES = $(SYNTH_DIR)/FUS.vg

IB_UNIT_TESTBENCH = #testbench/InstrBufferUnitTest.v testbench/InstrBufferPrintSim.c
IB_SIMFILES = verilog/InstrBuffer.v
IB_SYNFILES = $(SYNTH_DIR)/InstrBuffer.vg

FUBI_UNIT_TESTBENCH = #testbench/FUBIUnitTest.v testbench/FUBIPrintSim.c
FUBI_SIMFILES = verilog/FU/FUBi.v
FUBI_SYNFILES = $(SYNTH_DIR)/FUBi.vg

SQ_UNIT_TESTBENCH = #testbench/SQUnitTest.v testbench/SQPrintSim.c
SQ_SIMFILES = verilog/DMEM/SQ.v
SQ_SYNFILES = $(SYNTH_DIR)/SQ.vg

FD_UNIT_TESTBENCH = 
FD_SIMFILES = verilog/IMEM/FetchDecoder.v
FD_SYNFILES = $(SYNTH_DIR)/FetchDecoder.vg

PF_UNIT_TESTBENCH = 
PF_SIMFILES = verilog/IMEM/Prefetcher.v
PF_SYNFILES = $(SYNTH_DIR)/Prefetcher.vg

APF_UNIT_TESTBENCH = 
APF_SIMFILES = verilog/IMEM/AdvPrefetcher.v
APF_SYNFILES = $(SYNTH_DIR)/AdvPrefetcher.vg

# Passed through to .tcl scripts:
export BASE

export CLOCK_NET_NAME = clk
export RESET_NET_NAME = reset
export CLOCK_PERIOD = 13

# TODO: You will want to make this more aggresive

#Synthesis Unit Test Build
synth/pipeline.vg:   $(PIPE_SIMFILES) synth/pipeline.tcl Makefile
	cd synth && dc_shell-t -f ./pipeline.tcl | tee pipeline_synth.out 

synth/ROB.vg:        $(ROB_SIMFILES) synth/ROB.tcl
	cd synth && dc_shell-t -f ./ROB.tcl | tee rob_synth.out 
 
synth/RS.vg:        $(RS_SIMFILES) synth/RS.tcl
	cd synth && dc_shell-t -f ./RS.tcl | tee rs_synth.out 

synth/pipe_mult_fu.vg:	$(MULT_SIMFILES) synth/mult.tcl
	cd synth && dc_shell-t -f ./mult.tcl | tee mult_synth.out 

synth/alu_fu.vg:        $(ALU_SIMFILES) synth/alu.tcl
	cd synth && dc_shell-t -f ./alu.tcl | tee alu_synth_fu.out 

synth/branch_fu.vg:        $(BRANCH_SIMFILES) synth/branch.tcl
	cd synth && dc_shell-t -f ./branch.tcl | tee branch_fu_synth.out 

synth/memAlu.vg:        $(MA_SIMFILES) synth/memAlu.tcl
	cd synth && dc_shell-t -f ./memAlu.tcl | tee memAlu_synth.out 

synth/decoder.vg:      $(DECODER_SIMFILES) synth/decoder.tcl
	cd synth && dc_shell-t -f ./decoder.tcl | tee decoder_synth.out 

synth/regfile.vg:        $(REG_SIMFILES) synth/regfile.tcl
	cd synth && dc_shell-t -f ./regfile.tcl | tee regfile_synth.out 

synth/if_id_hazard.vg:      $(HAZ_SIMFILES) synth/if_id_hazard.tcl
	cd synth && dc_shell-t -f ./if_id_hazard.tcl | tee haz_synth.out 

synth/CDB.vg:      $(CDB_SIMFILES) synth/CDB.tcl
	cd synth && dc_shell-t -f ./CDB.tcl | tee CDB_synth.out 

synth/FUS.vg:      $(FUS_SIMFILES) synth/FUS.tcl
	cd synth && dc_shell-t -f ./FUS.tcl | tee FUS_synth.out 

synth/FUBi.vg:      $(FUBI_SIMFILES) synth/FUBI.tcl
	cd synth && dc_shell-t -f ./FUBI.tcl | tee FUBI_synth.out

synth/InstrBuffer.vg:      $(IB_SIMFILES) synth/InstrBuffer.tcl
	cd synth && dc_shell-t -f ./InstrBuffer.tcl | tee InstrBuffer_synth.out 
	
synth/ArchTable.vg:      $(AT_SIMFILES) synth/ArchTable.tcl
	cd synth && dc_shell-t -f ./ArchTable.tcl | tee ArchTable_synth.out
	
synth/BP.vg:      $(BP_SIMFILES) synth/BP.tcl
	cd synth && dc_shell-t -f ./BP.tcl | tee BP_synth.out
	
synth/branchStack.vg:      $(BS_SIMFILES) synth/BranchStack.tcl
	cd synth && dc_shell-t -f ./BranchStack.tcl | tee BranchStack_synth.out
	
synth/CacheCtrl.vg:      $(CC_SIMFILES) synth/CacheCtrl.tcl Makefile
	cd synth && dc_shell-t -f ./CacheCtrl.tcl | tee CacheCtrl_synth.out
	
synth/icache.vg:      $(IC_SIMFILES) synth/icache.tcl Makefile
	cd synth && dc_shell-t -f ./icache.tcl | tee icache_synth.out
	
synth/dcache.vg:      $(DC_SIMFILES) synth/dcache.tcl Makefile
	cd synth && dc_shell-t -f ./dcache.tcl | tee dcache_synth.out

synth/FreeList.vg:      $(FL_SIMFILES) synth/FreeList.tcl
	cd synth && dc_shell-t -f ./FreeList.tcl | tee FreeList_synth.out

synth/MapTable.vg:      $(MT_SIMFILES) synth/MapTable.tcl
	cd synth && dc_shell-t -f ./MapTable.tcl | tee MapTable_synth.out

synth/if_stage.vg:      $(IF_SIMFILES) synth/if_stage.tcl
	cd synth && dc_shell-t -f ./if_stage.tcl | tee if_synth.out

synth/FetchDecoder.vg:      $(FD_SIMFILES) synth/FetchDecoder.tcl
	cd synth && dc_shell-t -f ./FetchDecoder.tcl | tee FetchDecoder_synth.out

synth/Prefetcher.vg:      $(PF_SIMFILES) synth/prefetcher.tcl
	cd synth && dc_shell-t -f ./prefetcher.tcl | tee prefetcher_synth.out
	
synth/AdvPrefetcher.vg:      $(PF_SIMFILES) synth/advprefetcher.tcl
	cd synth && dc_shell-t -f ./advprefetcher.tcl | tee advprefetcher_synth.out

synth/SQ.vg:      $(SQ_SIMFILES) synth/SQ.tcl
	cd synth && dc_shell-t -f ./SQ.tcl | tee SQ_synth.out

synth/dmemFU.vg:      $(MEMFU_SIMFILES) synth/dmemFU.tcl
	cd synth && dc_shell-t -f ./dmemFU.tcl | tee dmemFU_synth.out

simv:	$(BASE) $(PIPE_SIMFILES) $(PIPE_TESTBENCH) Makefile
	$(VCS) $(BASE) $(PIPE_TESTBENCH) $(PIPE_SIMFILES) -o pipeline_simv
	
#Unit Test Build
build_pipeline:	$(BASE) $(PIPE_SIMFILES) $(PIPE_TESTBENCH) Makefile
	$(VCS) $(BASE) $(PIPE_TESTBENCH) $(PIPE_SIMFILES) -o pipeline_simv

.PHONY: run_pipeline
run_pipeline: build_pipeline Makefile
	./pipeline_simv | tee pipeline_program.out

dve_pipeline:	$(BASE) $(PIPE_SIMFILES) $(PIPE_TESTBENCH) Makefile
	$(VCS) +memcbk $(PIPE_TESTBENCH) $(PIPE_SIMFILES) -o dve -R -gui
	
#dve_syn:	$(SYNFILES) $(TESTBENCH)
#	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) +define+SYNTH_TEST -o syn_simv -R -gui

.PHONY: run_all_ut
run_all_ut: 
	./runUnitTests
	
build_rob_ut:	$(BASE) $(HAZ_SIMFILES) $(ROB_SIMFILES) $(ROB_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(ROB_UNIT_TESTBENCH) $(HAZ_SIMFILES) $(ROB_SIMFILES) -o rob_simv

.PHONY: run_rob_ut
run_rob_ut: build_rob_ut Makefile
	./rob_simv | tee rob_program.out

build_rs_ut:	$(BASE) $(RS_SIMFILES) $(RS_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(RS_UNIT_TESTBENCH) $(RS_SIMFILES) -o rs_simv

.PHONY: run_rs_ut
run_rs_ut: build_rs_ut Makefile
	./rs_simv | tee rs_program.out

build_mt_ut:	$(BASE) $(MT_SIMFILES) $(MT_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(MT_UNIT_TESTBENCH) $(MT_SIMFILES) -o mt_simv

.PHONY: run_mt_ut
run_mt_ut: build_mt_ut Makefile
	./mt_simv | tee mt_program.out

build_fl_ut:	$(BASE) $(FL_SIMFILES) $(FL_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(FL_UNIT_TESTBENCH) $(FL_SIMFILES) -o fl_simv

.PHONY: run_fl_ut
run_fl_ut: build_fl_ut Makefile
	./fl_simv | tee fl_program.out

build_mult_ut:	$(BASE) $(MULT_SIMFILES) $(MULT_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(MULT_UNIT_TESTBENCH) $(MULT_SIMFILES) -o mult_simv

.PHONY: run_mult_ut
run_mult_ut: build_mult_ut Makefile
	./mult_simv | tee mult_program.out

build_alu_ut:	$(BASE) $(ALU_SIMFILES) $(ALU_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(ALU_UNIT_TESTBENCH) $(ALU_SIMFILES) -o alu_simv

.PHONY: run_alu_ut
run_alu_ut: build_alu_ut Makefile
	./alu_simv | tee alu_program.out

build_memAlu_ut:	$(BASE) $(MA_SIMFILES) $(MA_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(MA_UNIT_TESTBENCH) $(MA_SIMFILES) -o memAlu_simv

.PHONY: run_memAlu_ut
run_memAlu_ut: build_memAlu_ut Makefile
	./memAlu_simv | tee memAlu_program.out

build_decoder_ut:	$(BASE) $(DE_SIMFILES) $(DE_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(DE_UNIT_TESTBENCH) $(DE_SIMFILES) -o decoder_simv

.PHONY: run_decoder_ut
run_decoder_ut: build_decoder_ut Makefile
	./decoder_simv | tee decoder_program.out

build_regfile_ut:	$(BASE) $(REG_SIMFILES) $(REG_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(REG_UNIT_TESTBENCH) $(REG_SIMFILES) -o reg_simv

.PHONY: run_regfile_ut
run_regfile_ut: build_regfile_ut Makefile
	./reg_simv | tee reg_program.out

build_CDB_ut:	$(BASE) $(CDB_SIMFILES) $(CDB_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(CDB_UNIT_TESTBENCH) $(CDB_SIMFILES) -o CDB_simv

.PHONY: run_CDB_ut
run_CDB_ut: build_CDB_ut Makefile
	./CDB_simv | tee CDB_program.out

build_FUS_ut:	$(BASE) $(FUS_SIMFILES) $(FUS_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(FUS_UNIT_TESTBENCH) $(FUS_SIMFILES) -o FUS_simv

.PHONY: run_FUS_ut
run_FUS_ut: build_FUS_ut Makefile
	./FUS_simv | tee FUS_program.out
	
build_FUBI_ut:	$(BASE) $(FUBI_SIMFILES) $(FUBI_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(FUBI_UNIT_TESTBENCH) $(FUBI_SIMFILES) -o FUBI_simv

.PHONY: run_FUBI_ut
run_FUBI_ut: build_FUBI_ut Makefile
	./FUBI_simv | tee FUBI_program.out

build_InstrBuffer_ut:	$(BASE) $(IB_SIMFILES) $(IB_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(IB_UNIT_TESTBENCH) $(IB_SIMFILES) -o InstrBuffer_simv

.PHONY: run_InstrBuffer_ut
run_InstrBuffer_ut: build_InstrBuffer_ut Makefile
	./InstrBuffer_simv | tee InstrBuffer_program.out

build_ArchTable_ut:	$(BASE) $(AT_SIMFILES) $(AT_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(AT_UNIT_TESTBENCH) $(AT_SIMFILES) -o ArchTable_simv

.PHONY: run_ArchTable_ut
run_ArchTable_ut: build_ArchTable_ut Makefile
	./ArchTable_simv | tee ArchTable_program.out
	
build_BP_ut:	$(BASE) $(BP_SIMFILES) $(BP_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(BP_UNIT_TESTBENCH) $(BP_SIMFILES) -o BP_simv

.PHONY: run_BP_ut
run_BP_ut: build_BP_ut Makefile
	./BP_simv | tee BP_program.out
	
build_BranchStack_ut:	$(BASE) $(BS_SIMFILES) $(BS_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(BS_UNIT_TESTBENCH) $(BS_SIMFILES) -o BranchStack_simv

.PHONY: run_BranchStack_ut
run_BranchStack_ut: build_BranchStack_ut Makefile
	./BranchStack_simv | tee BranchStack_program.out

build_CacheCtrl_ut:	$(BASE) $(CC_SIMFILES) $(CC_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(CC_UNIT_TESTBENCH) $(CC_SIMFILES) -o CacheCtrl_simv

.PHONY: run_CacheCtrl_ut
run_CacheCtrl_ut: build_CacheCtrl_ut Makefile
	./CacheCtrl_simv | tee CacheCtrl_program.out
	
build_icache_ut:	$(BASE) $(IC_SIMFILES) $(IC_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(IC_UNIT_TESTBENCH) $(IC_SIMFILES) -o icache_simv

.PHONY: run_icache_ut
run_icache_ut: build_icache_ut Makefile
	./icache_simv | tee icache_program.out
	
build_dcache_ut:	$(BASE) $(DC_SIMFILES) $(DC_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(DC_UNIT_TESTBENCH) $(DC_SIMFILES) -o dcache_simv

.PHONY: run_dcache_ut
run_dcache_ut: build_dcache_ut Makefile
	./dcache_simv | tee dcache_program.out
	
build_Prefetcher_ut:	$(BASE) $(PF_SIMFILES) $(PF_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(PF_UNIT_TESTBENCH) $(PF_SIMFILES) -o Prefetcher_simv

.PHONY: run_Prefetcher_ut
run_Prefetcher_ut: build_Prefetcher_ut Makefile
	./Prefetcher_simv | tee Prefetcher_program.out
	
build_branch_ut:	$(BASE) $(BRANCH_SIMFILES) $(BRANCH_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(BRANCH_UNIT_TESTBENCH) $(BRANCH_SIMFILES) -o branch_simv

.PHONY: run_branch_ut
run_branch_ut: build_branch_ut Makefile
	./branch_simv | tee branch_program.out

build_SQ_ut:	$(BASE) $(SQ_SIMFILES) $(SQ_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(SQ_UNIT_TESTBENCH) $(SQ_SIMFILES) -o SQ_simv

.PHONY: run_SQ_ut
run_SQ_ut: build_SQ_ut Makefile
	./SQ_simv | tee SQ_program.out
	
build_hazard_ut:	$(BASE) $(HAZ_SIMFILES) $(HAZ_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(HAZ_UNIT_TESTBENCH) $(HAZ_SIMFILES) -o hazard_simv

.PHONY: run_hazard_ut
run_hazard_ut: build_hazard_ut Makefile
	./hazard_simv | tee hazard_program.out
	
build_if_ut:	$(BASE) $(IF_SIMFILES) $(IF_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(IF_UNIT_TESTBENCH) $(IF_SIMFILES) -o if_simv

.PHONY: run_if_ut
run_if_ut: build_if_ut Makefile
	./if_simv | tee if_program.out
	
build_fd_ut:	$(BASE) $(FD_SIMFILES) $(FD_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(FD_UNIT_TESTBENCH) $(FD_SIMFILES) -o fd_simv

.PHONY: run_fd_ut
run_fd_ut: build_fd_ut Makefile
	./fd_simv | tee fd_program.out

build_dmemFU_ut:	$(BASE) $(MEMFU_SIMFILES) $(MEMFU_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(MEMFU_UNIT_TESTBENCH) $(MEMFU_SIMFILES) -o dmemFU_simv

.PHONY: run_dmemFU_ut
run_dmemFU_ut: build_dmemFU_ut Makefile
	./dmemFU_simv | tee dmemFU_program.out


#####
# Should be no need to modify after here
#####

#dve:	$(SIMFILES) $(TESTBENCH) 
#	$(VCS) +memcbk $(TESTBENCH) $(SIMFILES) -o dve -R -gui
	
#dve_syn:	$(SYNFILES) $(TESTBENCH)
#	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) +define+SYNTH_TEST -o syn_simv -R -gui

#simv:	$(SIMFILES) $(TESTBENCH)
#	$(VCS) $(TESTBENCH) $(SIMFILES)	-o simv
rob_syn_simv:	$(BASE) $(HAZ_SYNFILES) $(ROB_SYNFILES) $(ROB_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(ROB_UNIT_TESTBENCH) $(HAZ_SYNFILES) $(ROB_SYNFILES) $(LIB) +define+SYNTH_TEST -o rob_syn_simv

.PHONY: rob_syn
rob_syn:	rob_syn_simv Makefile
	./rob_syn_simv | tee rob_syn_program.out

rs_syn_simv:	$(BASE) $(RS_SYNFILES) $(RS_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(RS_UNIT_TESTBENCH) $(RS_SYNFILES) $(LIB) +define+SYNTH_TEST -o rs_syn_simv

.PHONY: rs_syn
rs_syn:	rs_syn_simv Makefile
	./rs_syn_simv | tee rs_syn_program.out

mult_syn_simv:	$(BASE) $(MULT_SYNFILES) $(MULT_UNIT_TESTBENCH)
	$(VCS) $(BASE) $(MULT_UNIT_TESTBENCH) $(MULT_SYNFILES) $(LIB) +define+SYNTH_TEST -o mult_syn_simv

.PHONY: mult_syn
mult_syn:	mult_syn_simv Makefile
	./mult_syn_simv | tee mult_syn_program.out

alu_syn_simv:	$(BASE) $(ALU_SYNFILES) $(ALU_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(ALU_UNIT_TESTBENCH) $(ALU_SYNFILES) $(LIB) +define+SYNTH_TEST -o alu_syn_simv

.PHONY: alu_syn
alu_syn:	alu_syn_simv Makefile
	./alu_syn_simv | tee alu_syn_program.out

branch_syn_simv:	$(BASE) $(BRANCH_SYNFILES) $(BRANCH_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(BRANCH_UNIT_TESTBENCH) $(BRANCH_SYNFILES) $(LIB) +define+SYNTH_TEST -o branch_syn_simv

.PHONY: branch_syn
branch_syn:	branch_syn_simv Makefile
	./branch_syn_simv | tee branch_syn_program.out

ma_syn_simv:	$(BASE) $(MA_SYNFILES) $(MA_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(MA_UNIT_TESTBENCH) $(MA_SYNFILES) $(LIB) +define+SYNTH_TEST -o ma_syn_simv

.PHONY: ma_syn
ma_syn:	ma_syn_simv Makefile
	./ma_syn_simv | tee ma_syn_program.out

de_syn_simv:	$(BASE) $(DE_SYNFILES) $(DE_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(DE_UNIT_TESTBENCH) $(DE_SYNFILES) $(LIB) +define+SYNTH_TEST -o de_syn_simv

.PHONY: de_syn
de_syn:	de_syn_simv Makefile
	./de_syn_simv | tee de_syn_program.out

reg_syn_simv:	$(BASE) $(REG_SYNFILES) $(REG_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(REG_UNIT_TESTBENCH) $(REG_SYNFILES) $(LIB) +define+SYNTH_TEST -o reg_syn_simv

.PHONY: reg_syn
reg_syn:	reg_syn_simv Makefile
	./reg_syn_simv | tee reg_syn_program.out

cdb_syn_simv:	$(BASE) $(CDB_SYNFILES) $(CDB_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(CDB_UNIT_TESTBENCH) $(CDB_SYNFILES) $(LIB) +define+SYNTH_TEST -o cdb_syn_simv

.PHONY: cdb_syn
cdb_syn:	cdb_syn_simv Makefile
	./cdb_syn_simv | tee cdb_syn_program.out

fus_syn_simv:	$(BASE) $(FUS_SYNFILES) $(FUS_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(FUS_UNIT_TESTBENCH) $(FUS_SYNFILES) $(LIB) +define+SYNTH_TEST -o fus_syn_simv

.PHONY: fus_syn
fus_syn:	fus_syn_simv Makefile
	./fus_syn_simv | tee fus_syn_program.out
	
fubi_syn_simv:	$(BASE) $(FUBI_SYNFILES) $(FUBI_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(FUBI_UNIT_TESTBENCH) $(FUBI_SYNFILES) $(LIB) +define+SYNTH_TEST -o fubi_syn_simv

.PHONY: fubi_syn
fubi_syn:	fubi_syn_simv Makefile
	./fubi_syn_simv | tee fubi_syn_program.out

ib_syn_simv:	$(BASE) $(IB_SYNFILES) $(IB_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(IB_UNIT_TESTBENCH) $(IB_SYNFILES) $(LIB) +define+SYNTH_TEST -o ib_syn_simv

.PHONY: ib_syn
ib_syn:	ib_syn_simv Makefile
	./ib_syn_simv | tee ib_syn_program.out
	
at_syn_simv:	$(BASE) $(AT_SYNFILES) $(AT_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(AT_UNIT_TESTBENCH) $(AT_SYNFILES) $(LIB) +define+SYNTH_TEST -o at_syn_simv

.PHONY: at_syn
at_syn:	at_syn_simv Makefile
	./at_syn_simv | tee at_syn_program.out
	
bp_syn_simv:	$(BASE) $(BP_SYNFILES) $(BP_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(BP_UNIT_TESTBENCH) $(BP_SYNFILES) $(LIB) +define+SYNTH_TEST -o bp_syn_simv

.PHONY: bp_syn
bp_syn:	bp_syn_simv Makefile
	./bp_syn_simv | tee bp_syn_program.out
	
bs_syn_simv:	$(BASE) $(BS_SYNFILES) $(BS_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(BS_UNIT_TESTBENCH) $(BS_SYNFILES) $(LIB) +define+SYNTH_TEST -o bs_syn_simv

.PHONY: bs_syn
bs_syn:	bs_syn_simv Makefile
	./bs_syn_simv | tee bs_syn_program.out

mt_syn_simv:	$(BASE) $(MT_SYNFILES) $(MT_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(MT_UNIT_TESTBENCH) $(MT_SYNFILES) $(LIB) +define+SYNTH_TEST -o mt_syn_simv

.PHONY: mt_syn
mt_syn:	mt_syn_simv Makefile
	./mt_syn_simv | tee mt_syn_program.out
	
fl_syn_simv:	$(BASE) $(FL_SYNFILES) $(FL_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(FL_UNIT_TESTBENCH) $(FL_SYNFILES) $(LIB) +define+SYNTH_TEST -o fl_syn_simv

.PHONY: fl_syn
fl_syn:	fl_syn_simv Makefile
	./fl_syn_simv | tee fl_syn_program.out

fd_syn_simv:	$(BASE) $(FD_SYNFILES) $(FD_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(FD_UNIT_TESTBENCH) $(FD_SYNFILES) $(LIB) +define+SYNTH_TEST -o fd_syn_simv

.PHONY: fd_syn
fd_syn:	fd_syn_simv Makefile
	./fd_syn_simv | tee fd_syn_program.out
	
ic_syn_simv:	$(BASE) $(IC_SYNFILES) $(IC_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(IC_UNIT_TESTBENCH) $(IC_SYNFILES) $(LIB) +define+SYNTH_TEST -o ic_syn_simv

.PHONY: ic_syn
ic_syn:	ic_syn_simv Makefile
	./ic_syn_simv | tee ic_syn_program.out
	
haz_syn_simv:	$(BASE) $(HAZ_SYNFILES) $(HAZ_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(HAZ_UNIT_TESTBENCH) $(HAZ_SYNFILES) $(LIB) +define+SYNTH_TEST -o haz_syn_simv

.PHONY: haz_syn
haz_syn:	haz_syn_simv Makefile
	./haz_syn_simv | tee haz_syn_program.out

if_syn_simv:	$(BASE) $(IF_SYNFILES) $(IF_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(IF_UNIT_TESTBENCH) $(IF_SYNFILES) $(LIB) +define+SYNTH_TEST -o if_syn_simv

.PHONY: if_syn
if_syn:	if_syn_simv Makefile
	./if_syn_simv | tee if_syn_program.out

pf_syn_simv:	$(BASE) $(PF_SYNFILES) Makefile
	$(VCS) $(BASE) $(PF_SYNFILES) $(LIB) +define+SYNTH_TEST -o pf_syn_simv

.PHONY: pf_syn
pf_syn:	pf_syn_simv Makefile
	./pf_syn_simv | tee pf_syn_program.out
	
dc_syn_simv:	$(BASE) $(DC_SYNFILES) Makefile
	$(VCS) $(BASE) $(DC_SYNFILES) $(LIB) +define+SYNTH_TEST -o dc_syn_simv

.PHONY: dc_syn
dc_syn:	dc_syn_simv Makefile
	./dc_syn_simv | tee dc_syn_program.out
	
cc_syn_simv:	$(BASE) $(CC_SYNFILES) Makefile
	$(VCS) $(BASE) $(CC_SYNFILES) $(LIB) +define+SYNTH_TEST -o cc_syn_simv

.PHONY: cc_syn
cc_syn:	cc_syn_simv Makefile
	./cc_syn_simv | tee cc_syn_program.out
	
sq_syn_simv:	$(BASE) $(SQ_SYNFILES) $(SQ_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(SQ_UNIT_TESTBENCH) $(SQ_SYNFILES) $(LIB) +define+SYNTH_TEST -o sq_syn_simv

.PHONY: sq_syn
sq_syn:	sq_syn_simv Makefile
	./sq_syn_simv | tee sq_syn_program.out

dmemFU_syn_simv:	$(BASE) $(MEMFU_SYNFILES) $(MEMFU_UNIT_TESTBENCH) Makefile
	$(VCS) $(BASE) $(MEMFU_UNIT_TESTBENCH) $(MEMFU_SYNFILES) $(LIB) +define+SYNTH_TEST -o dmemFU_syn_simv

.PHONY: dmemFU_syn
dmemFU_syn:	dmemFU_syn_simv Makefile
	./dmemFU_syn_simv | tee dmemFU_syn_program.out

pipeline_syn_simv:	$(BASE) $(PIPE_SYNFILES) $(PIPE_MODULE) $(PIPE_TESTBENCH) Makefile
	$(VCS) $(BASE) $(PIPE_TESTBENCH) $(PIPE_SYNFILES) $(PIPE_MODULE) $(LIB) +define+SYNTH_TEST -o pipeline_syn_simv

.PHONY: pipeline_syn
pipeline_syn:  pipeline_syn_simv Makefile
		./pipeline_syn_simv | tee pipeline_syn_program.out

syn_simv:	$(BASE) $(PIPE_SYNFILES) $(PIPE_MODULE) $(PIPE_TESTBENCH) Makefile
	./syn_all.sh
	$(VCS) $(BASE) $(PIPE_TESTBENCH) $(PIPE_SYNFILES) $(PIPE_MODULE) $(LIB) +define+SYNTH_TEST -o pipeline_syn_simv
	
  
.PHONY: clean
clean:
	rm -rvf *_simv *.daidir csrc vcs.key \
	  *_syn_simv *_syn_simv.daidir *.out \
		  dve *.vpd *.vcd *.dump ucli.key \
	  simv vc_hdrs.h *.at *.mem
	
.PHONY: nuke
nuke:	clean
	rm -rvf synth/*.vg synth/*.rep synth/*.db synth/*.chk synth/*.log *.out DVEfiles/ synth/*.ddc synth/*.res *_svsim.sv synth/*.svf *.vdb synth/*.out synth/*.sv
	./cleanbaseline

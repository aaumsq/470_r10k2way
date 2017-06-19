#ifndef PRINT_H_
#define PRINT_H_
#include "Utility.h"

char* futos[] = {"alu", "mult", "ldst", "br"};
//RS Printing
void print_RSHeader(){
  printf("index\tinstruction\tFU\ttag\ttagA\ttagB\tbmask\tsq_index\tcanLoadIssue\n");
}

void print_RSEntry(int index, int instruction, int fuType, int tag, int tagA, int tagB,
    int aReady, int bReady, int bmask, int sq_index, int canLoadIssue){
  printf("%d\t", index);
  printf("%x\t", instruction);
  printf("%s\t", futos[fuType]);
  printf("%d\t", tag);
  printf(aReady?"%d+\t":"%d\t", tagA);
  printf(bReady?"%d+\t":"%d\t", tagB);
  printf("%d\t", bmask);
  printf("%d\t\t", sq_index);
  printf("%d\n", canLoadIssue);
}

void print_RSOutputs(int slots, int nIssue){
  printf("%d slots available, %d issued:\n", slots, nIssue);
}

void print_fu_en(int fu_en0, int fu_en1, int fu_en2, int fu_en3, 
         int fu_en4, int fu_en5, int fu_en6){
  printf("fu_en: ldst: %d %d, mult: %d %d, alu: %d %d, br: %d\n",   
            fu_en0, fu_en1, fu_en2, fu_en3, 
            fu_en4, fu_en5, fu_en6);
}

//ROB Printing

void print_ROBHeader(int head, int tail, int rob_availableSlots, int prev_nRetired,
    int rob_prev_retireTag0, int rob_prev_retireTag1, int rob_prev_retireTagOld0, int rob_prev_retireTagOld1){
  printf("head: %d, tail: %d, rob_availableSlots: %d, prev_nRetired: %d, ", head, tail, 
      rob_availableSlots, prev_nRetired);
  printf("\nprev_retireTag: {%d, %d}, prev_retireTagOld: {%d, %d}\n",
      rob_prev_retireTag0, rob_prev_retireTag1, rob_prev_retireTagOld0, rob_prev_retireTagOld1);
  printf("\tcomplete\ttag\ttagOld\n");
}

void print_ROBEntry(int idx, int complete, int tag, int tagOld){
  printf("%d\t%d\t\t%d\t%d\n", idx, complete, tag, tagOld);
}

// Instruction buffer printing
void print_IBHeader(int head, int tail, int numIns_buffer, int ib_nIsnBuffer, int ib_nAvai,
  int instruction0, int fd_control_uncond0, int fd_control_cond0,int pred_NPC0,
  int not_taken_NPC0, int bp_pred_taken0, int ib_valid0,
  int instruction1, int fd_control_uncond1, int fd_control_cond1,int pred_NPC1,
  int not_taken_NPC1, int bp_pred_taken1, int ib_valid1) {
  printf("head: %d, tail: %d, ib_nIsnBuffer: %d, numIns_buffer: %d, ib_nAvai: %d, ", head, tail, ib_nIsnBuffer, numIns_buffer, ib_nAvai);
  printf("ib_valid: {%d, %d}\n",ib_valid0, ib_valid1);
    printf("instruction fd_control_uncond fd_control_cond pred_NPC not_taken_NPC bp_pred_taken\n");
  if(ib_valid0 || ib_valid1){
    printf("ib_data: \n");
  }
  if(ib_valid0){
    print_IBEntry(instruction0, fd_control_uncond0, fd_control_cond0, pred_NPC0, not_taken_NPC0, bp_pred_taken0);
  }
  if(ib_valid1){
    print_IBEntry(instruction1, fd_control_uncond1, fd_control_cond1, pred_NPC1, not_taken_NPC1, bp_pred_taken1);
    }
    if(numIns_buffer > 0){
      printf("buffer entries: \n");
  }
}

void print_IBEntry(int instruction, int fd_control_uncond, int fd_control_cond, int pred_NPC, int not_taken_NPC, int bp_pred_taken){
  printf("%x\t%d\t\t%d\t\t%d\t%d\t\t%d\n", instruction, fd_control_uncond, fd_control_cond, pred_NPC, not_taken_NPC, bp_pred_taken);
}

// SQ Printing
void print_SQHeader(int sq_trueHead, int sq_tail, int sq_empty, int slotsOpen, int sq_nAvailable, int sq_mem_data, int sq_mem_en, int sq_mem_addr,  
  int sq_index0, int sq_index1, int sq_index_empty, int sq_ea_ptr, int sq_ea_empty, int sq_ld_match, int sq_ld_data0, int sq_ld_data1, int retireHead){
  printf("sq_trueHead: %d, sq_tail: %d, sq_empty: %d, slotsOpen: %d, sq_nAvailable: %d, sq_mem_data: %d, sq_mem_en: %d, sq_mem_addr: %d, sq_index_empty: %d, sq_ea_ptr: %d, sq_ea_empty: %d, sq_ld_match: %d, retireHead: %d",
    sq_trueHead, sq_tail, sq_empty, slotsOpen, sq_nAvailable, sq_mem_data, sq_mem_en,
    sq_mem_addr, sq_index_empty, sq_ea_ptr, sq_ea_empty, sq_ld_match, retireHead);
  printf("\nsq_index: {%d, %d}, sq_ld_data: {%d, %d}\n",
    sq_index0, sq_index1, sq_ld_data0, sq_ld_data1);
  printf("\taddr\tdata\tretired\tea_calcd\n");
}

void print_SQEntry(int idx, int addr, int data, int retired, int ea_calcd){
  printf("%d\t%d\t%d\t%d\t%d\n", idx, addr, data, retired, ea_calcd);
}

#endif

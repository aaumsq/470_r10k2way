#include <stdint.h>
#include <stdlib.h>
#include "Utility.h"


//Input file
static FILE* file = NULL;
//Inputs to simulation and testbench
//static uint32_t if_id_instructions_IN[2];
//static uint64_t if_id_NPC_IN[2];
static int rs_availableSlots_IN;
static int fl_availableRegs_IN;
static int ib_nIsnBuffer_IN;
static int fl_freeRegs_IN[2];
static int mt_dispatchTagOld_IN[2];
static int cdb_rd_IN[2];
static int cdb_rd_en_IN[2];
static int br_fub_pred_wrong_IN;
static int bs_recov_rob_tail_IN;
//Simulation state
static int head, tail;
static ROBEntry_t buffer[32];
//Simulation outputs
static int rob_availableSlots, prev_nRetired, rob_prev_retireTag[2], rob_prev_retireTagOld[2];

static void init_sim(){
  int i;
  head = 0;
  tail = 31;
  rob_availableSlots = 32;
  prev_nRetired = 0;
  rob_prev_retireTag[0] = 0;
  rob_prev_retireTag[1] = 0;
  rob_prev_retireTagOld[0] = 0;
  rob_prev_retireTagOld[1] = 0;
  for(i = 0; i < 32; i++){
    buffer[i].valid = 0;
  }
}

void init_filetest(char* filename){
  init_sim();
  file = fopen(filename, "r");
}

int readLine(){
  char c;
  int nRead, i;

  if(removeSOLComment(file) == EOF){
    return 1;
  }
  
  ib_nIsnBuffer_IN = readBoundedInt(file, 2);
  
  /*
  readInstructions(file, &if_id_instructions_IN, &if_id_NPC_IN);
  */
  rs_availableSlots_IN = readBoundedInt(file, 16);
  fl_availableRegs_IN = readBoundedInt(file, 32);
  readBoundedPair(file, fl_freeRegs_IN, 63);
  readBoundedPair(file, mt_dispatchTagOld_IN, 63);
  readBoundedPair(file, cdb_rd_IN, 63);
  readBoundedPair(file, cdb_rd_en_IN, 1);
  br_fub_pred_wrong_IN = readBoundedInt(file, 1);
  bs_recov_rob_tail_IN = readBoundedInt(file, 31);

  //end of line is a comment
  while((c = getc(file)) != '\n');
  
  return 0;
}


/*static int nextRandPC;*/
void init_randomtest(int seed){
  /*nextRandPC = 4;*/
  init_sim();
  srand(seed);
}

void getRandomValues(){
  int i, j, r = rand() % 100, cdb_n, cdb_choices[32], cdb_nchoices, last_cdb_choice, cdb_choice;
  int isFree[64];
  /* gives 2 a higher chance of happening than 1 or 0 because we are taking the min of three of these*/
  ib_nIsnBuffer_IN = (r > 50)? 2 : (r > 25? 1 : 0);
  r = rand() % 100;
  rs_availableSlots_IN = (r > 50)? 2 : (r > 25? 1 : 0);   
  
  for(i = 0; i < 64; i++){
    isFree[i] = 1;
  }
  for(i = 0; i < 32; i++){
    if(buffer[i].valid){
      isFree[buffer[i].tag] = 0;
    }    
  }
  
  r = rand() % 100;                    
  fl_availableRegs_IN = (r > 50)? 2 : (r > 25? 1 : 0);
  for(i = 0; i < fl_availableRegs_IN; i++){
    while(!isFree[fl_freeRegs_IN[i] = rand() % 64]);
    isFree[fl_freeRegs_IN[i]] = 0;
  }
  
  for(i = 0; i < 2; i++){
    mt_dispatchTagOld_IN[i] = rand() % 64;
  }
  
  cdb_n = rand() % 2;
  cdb_nchoices = 0;
  for(i = 0; i < 32; i++){
    if(buffer[i].valid && !buffer[i].complete){
      cdb_choices[cdb_nchoices++] = buffer[i].tag;
    }
  }
  last_cdb_choice = -1;
  for(i = 0; i < cdb_n && i < cdb_nchoices; i++){
    cdb_rd_en_IN[i] = 1;
    while((cdb_choice = rand() % cdb_nchoices) == last_cdb_choice);
    cdb_rd_IN[i] = cdb_choices[last_cdb_choice = cdb_choice];
  }
  for(; i < 2; i++){
    cdb_rd_en_IN[i] = 0;
  }
}


int get_ib_nIsnBuffer(){
  return ib_nIsnBuffer_IN;
}

/*
uint32_t get_if_id_instructions(int idx){
  assert(idx >= 0 && idx < ib_nIsnBuffer_IN);
  return if_id_instructions_IN[idx];
}

uint64_t get_if_id_NPC(int idx){
  assert(idx == 0 || idx == 1);
  return if_id_NPC_IN[idx];
}*/

int get_rs_availableSlots(){
  return rs_availableSlots_IN;
}

int get_fl_availableRegs(){
  return fl_availableRegs_IN;
}

int get_br_fub_pred_wrong(){
  return br_fub_pred_wrong_IN;
}

int get_bs_recov_rob_tail(){
  return bs_recov_rob_tail_IN;
}

int get_fl_freeRegs(int idx){
  assert(idx >= 0 && idx < 2);
  return fl_freeRegs_IN[idx];
}

int get_mt_dispatchTagOld(int idx){
  assert(idx == 0 || idx == 1); 
  return mt_dispatchTagOld_IN[idx];
}

int get_cdb_rd(int idx){
  assert(idx == 0 || idx == 1);
  return cdb_rd_IN[idx];
}

int get_cdb_rd_en(int idx){
  assert(idx == 0 || idx == 1); 
  return cdb_rd_en_IN[idx];
}


void updateSim(){
  int nDispatched, i, j, idx;
  //Retire stage
  //IMPORTANT!!! ALL THESE retire variables are actually for the previous cycle!
  //we retired them in the previous cycle, and it is updated at this posedge!
  //that's why we call them prev_nRetired, rob_prev_retireTag, etc.
  prev_nRetired = (buffer[head].complete && buffer[head].valid)? 
        ((buffer[(head+1) % 32].complete && buffer[(head+1) % 32].valid)? 2 : 1) : 0;
  for(i = 0; i < 2; i++){
    idx = (head+i) % 32;
    if(prev_nRetired >= i+1){
      buffer[idx].valid = 0;
    }
    rob_prev_retireTag[i] = buffer[idx].tag;
    rob_prev_retireTagOld[i] = buffer[idx].tagOld;
  }
  head = (head + prev_nRetired) % 32;
  //Complete stage
  for(i = 0; i < 32; i++){
    for(j = 0; j < 2; j++){
      if(cdb_rd_en_IN[j] && cdb_rd_IN[j] == buffer[i].tag){
        buffer[i].complete = 1;
      }
    }
  }
  
  //Dispatch stage
  nDispatched = br_fub_pred_wrong_IN ? 0 :
          min(2, 
          min(ib_nIsnBuffer_IN,
          min(rs_availableSlots_IN, 
          min(fl_availableRegs_IN, 
          rob_availableSlots + prev_nRetired))));
  //printf("nDispatched: %d\n", nDispatched);
  for(i = 0; i < nDispatched; i++){
    idx = (tail+i+1) % 32;
    buffer[idx].valid = 1;
    buffer[idx].complete = 0;
    /*buffer[idx].instruction = if_id_instructions_IN[i];
    buffer[idx].nextPC = if_id_NPC_IN[i];*/
    buffer[idx].tag = fl_freeRegs_IN[i];
    buffer[idx].tagOld = mt_dispatchTagOld_IN[i];
  }

  if(br_fub_pred_wrong_IN ) {
    tail = bs_recov_rob_tail_IN;
    //invalidate mispredicted stuff
    i = (tail + 1) % 32;
    while(i != head) {
      buffer[i].valid = 0;
      i = (i+1)%32;
    }
  } else {
    tail = (tail + nDispatched) % 32;
  }

  rob_availableSlots = 0;
  for(i = 0; i < 32; i++){
    rob_availableSlots += (buffer[i].valid? 0 : 1); // if valid, not available
  }
}

int checkROBState(int headV, int tailV, int rob_availableSlotsV, int prev_nRetiredV, 
  int rob_prev_retireTagV0, int rob_prev_retireTagV1, int rob_prev_retireTagOldV0, int rob_prev_retireTagOldV1){
  /*printf("C: head: %d, tail: %d, rob_availableSlots: %d, prev_nRetired: %d, ", head, tail, 
      rob_availableSlots, prev_nRetired);
  printf("retire tags: {%d, %d}, retire old tags: {%d, %d}\n",
      rob_prev_retireTag[0], rob_prev_retireTag[1], rob_prev_retireTagOld[0], rob_prev_retireTagOld[1]);
  printf("V: head: %d, tail: %d, rob_availableSlots: %d, prev_nRetired: %d, ", headV, tailV, 
      rob_availableSlotsV, prev_nRetiredV);
  printf("retire tags: {%d, %d}, retire old tags: {%d, %d}\n",
      rob_prev_retireTagV0, rob_prev_retireTagV1, rob_prev_retireTagOldV0, rob_prev_retireTagOldV1);*/
  if(headV != head){
    printf("head incorrect\n");
    return 0;
  } else if (tailV != tail){
    printf("tail incorrect\n");
    return 0;
  } else if (rob_availableSlotsV != rob_availableSlots){
    printf("available slots incorrect\n");
    return 0;
  } else if (prev_nRetiredV != prev_nRetired){
    printf("prev_nRetired incorrect\n");
    return 0;
  } else if (prev_nRetired >= 1){
    if(rob_prev_retireTagV0 != rob_prev_retireTag[0]){
      printf("retire tag 0 incorrect\n");
      return 0;
    } else if (rob_prev_retireTagOldV0 != rob_prev_retireTagOld[0]){
      printf("retire tag old 0 incorrect\n");
      return 0;
    } 
    if(prev_nRetired >= 2){
      if(rob_prev_retireTagV1 != rob_prev_retireTag[1]){
        printf("retire tag 1 incorrect\n");
        return 0;
      } else if (rob_prev_retireTagOldV1 != rob_prev_retireTagOld[1]){
        printf("retire tag old 1 incorrect\n");
        return 0;
      } 
    }
  }
  //printf("correct\n");
  return 1;
}

int checkROBEntry(int index, int completeV, int tagV, int tagOldV){
  return ((buffer[index].complete == completeV)
      /*&& (buffer[index].instruction == instructionV)
      && (buffer[index].nextPC == nextPCV)*/
      && (buffer[index].tag == tagV)
      && (buffer[index].tagOld == tagOldV)) ? 1 : 0;
}  

void printSimROB(){
  int i;
  print_ROBHeader(head, tail, rob_availableSlots, prev_nRetired, 
        rob_prev_retireTag[0], rob_prev_retireTag[1], rob_prev_retireTagOld[0], rob_prev_retireTagOld[1]);
  for(i = 0; i < 32; i++){
    print_ROBEntry(i, buffer[i].complete, buffer[i].tag, buffer[i].tagOld);
  }
}





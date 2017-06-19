#include <stdint.h>
#include <stdlib.h>
#include "Utility.h"


//Input file
static FILE* file = NULL;
//Inputs to simulation and testbench
// From InstrBuffer
static int ib_store_en;
// From RS
static int st_en;
static int ld_en;
static int fus_SQIndex[2];
// From ROB
static int rob_nRetireStores;    
// From alu
static int alu_data[2];
static int alu_addr[2];
// From LD fu
static int ld_addr[2];
//inputs from branch functional unit
static int br_pred_wrong;
static int bs_recov_sq_tail;
static int bs_recov_sq_empty;
static int dcachectrl_st_request_sent;

//Simulation state
static SQEntry_t queue[8];
static int slotsOpen;
static int retireHead;
static int ea_calcd[8];
static int shifted_ea_calcd[8];

//Simulation Output
// To InstrBuffer
static int sq_nAvailable;
// To D$
static int sq_mem_data;
static int sq_mem_en;
static int sq_mem_addr;
// To RS
static int sq_tail;
static int sq_empty;
static int sq_index[2];
static int sq_index_empty;
static int sq_ea_ptr;
static int sq_ea_empty;
static int sq_trueHead;

static int sq_ld_match;
static int sq_ld_data[2];

static void init_sim(){
  int i;
  sq_trueHead = 0;
  sq_tail = 0;
  sq_empty = 1;
  retireHead = 0;
  sq_ea_empty = 1;
  for(i = 0; i < 32; i++){
    ea_calcd[i] = 0;
    queue[i].retired = 0;
  }

  sq_nAvailable = 2;
  slotsOpen = 8;
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
  
  ib_store_en = readBoundedInt(file, 3);
  st_en = readBoundedInt(file, 3);
  ld_en = readBoundedInt(file, 3);
  readBoundedPair(file, fus_SQIndex, 7);
  rob_nRetireStores = readBoundedInt(file, 2);
  readBoundedPair(file, alu_data, 2147483647);
  readBoundedPair(file, alu_addr, 4095);
  readBoundedPair(file, ld_addr, 4095);
  br_pred_wrong = readBoundedInt(file, 1);
  bs_recov_sq_tail = readBoundedInt(file, 7);
  bs_recov_sq_empty = readBoundedInt(file, 1);
  dcachectrl_st_request_sent = readBoundedInt(file, 15);

  //end of line is a comment
  while((c = getc(file)) != '\n');
  
  return 0;
}



int get_ib_store_en(){
  return ib_store_en;
}

int get_st_en(){
  return st_en;
}

int get_rob_nRetireStores(){
  return rob_nRetireStores;
}

int get_alu_addr(int idx){
  assert(idx == 0 || idx == 1); 
  return alu_addr[idx];
}

int get_fus_SQIndex(int idx){
  assert(idx == 0 || idx == 1); 
  return fus_SQIndex[idx];
}

int get_alu_data(int idx){
  assert(idx == 0 || idx == 1); 
  return alu_data[idx];
}

int get_ld_en(){
  return ld_en;
}

int get_ld_addr(int idx){
  assert(idx == 0 || idx == 1); 
  return ld_addr[idx];
}

int get_br_pred_wrong(){
  return br_pred_wrong;
}

int get_bs_recov_sq_tail(){
  return bs_recov_sq_tail;
}

int get_bs_recov_sq_empty(){
  return bs_recov_sq_empty;
}

int get_dcachectrl_st_request_sent(){
  return dcachectrl_st_request_sent;
}


void updateSim(){
  // Store Dispatch
  sq_index[0] = sq_tail;
  sq_index[1] = sq_tail;
  if (br_pred_wrong) {
    sq_tail = bs_recov_sq_tail;
  } else if (ib_store_en == 1) {
    if(slotsOpen != 8){
      sq_tail = (sq_tail + 1)%8;
    }  
    sq_index[0] = sq_tail;
    slotsOpen--;
  } else if (ib_store_en == 2) {
    if(slotsOpen != 8){
      sq_tail = (sq_tail + 1)%8;
    }  
    sq_index[1] = sq_tail;
    slotsOpen--;
  } else if (ib_store_en == 3) {
    if(slotsOpen != 8) {
      sq_tail = (sq_tail + 2)%8;
    } else { 
      sq_tail = (sq_tail + 1)%8;
    }
    sq_index[0] = (sq_tail - 1)%8;
    sq_index[1] = sq_tail;
    slotsOpen -= 2;
  }
  
  // Execute
  // Store
  if (st_en == 1) {
    queue[fus_SQIndex[0]].data = alu_data[0];
    queue[fus_SQIndex[0]].addr = alu_addr[0];
    ea_calcd[fus_SQIndex[0]] = 1;
  }
  else if (st_en == 2) {
    queue[fus_SQIndex[1]].data = alu_data[1];
    queue[fus_SQIndex[1]].addr = alu_addr[1];
    ea_calcd[fus_SQIndex[1]] = 1;
  }
  else if (st_en == 3) {
    queue[fus_SQIndex[0]].data = alu_data[0];
    queue[fus_SQIndex[0]].addr = alu_addr[0];
    ea_calcd[fus_SQIndex[0]] = 1;
    queue[fus_SQIndex[1]].data = alu_data[1];
    queue[fus_SQIndex[1]].addr = alu_addr[1];
    ea_calcd[fus_SQIndex[1]] = 1;
  }

  // Load
  int i;
  int j;
  sq_ld_match = 0;
  sq_ld_data[0] = 0;
  sq_ld_data[1] = 0;
  if (fus_SQIndex[0]-sq_trueHead < 0) {
    fus_SQIndex[0] += 8;
  }
  if (fus_SQIndex[1]-sq_trueHead < 0) {
    fus_SQIndex[1] += 8;
  }
  if (ld_en%2 == 1) {
    for (j = 0; j < 8; j++) {
      if (j <= fus_SQIndex[0]-sq_trueHead && queue[(sq_trueHead + j)%8].addr == ld_addr[0]) {
        sq_ld_match += 1;
        sq_ld_data[0] = queue[(sq_trueHead + j)%8].data;
      }
    }
  }
  if (ld_en/2 == 1) {
    for (j = 0; j < 8; j++) {
      //printf("limit value: %d\n", (fus_SQIndex[1]-sq_trueHead)%8);
      if (j <= fus_SQIndex[1]-sq_trueHead && queue[(sq_trueHead + j)%8].addr == ld_addr[1]) {
        sq_ld_match += 2;
        sq_ld_data[1] = queue[(sq_trueHead + j)%8].data;
      }
    }
  }


  // Retire
  if (rob_nRetireStores == 1) {
    queue[retireHead].retired = 1;
    if(retireHead == sq_tail)
      retireHead = sq_tail;
    else 
      retireHead = (retireHead + rob_nRetireStores)%8;
  }
  else if (rob_nRetireStores == 2) {
    queue[retireHead].retired = 1;
    queue[(retireHead + 1)%8].retired = 1;
    if((retireHead == sq_tail) || ((retireHead + 1) == sq_tail))
      retireHead = sq_tail;
    else 
      retireHead = (retireHead + rob_nRetireStores)%8;
  }
  

  sq_mem_addr = 0;
  sq_mem_data = 0;
  sq_mem_en = 0;
  
  if (queue[sq_trueHead].retired) {
    sq_mem_en = 1;
    sq_mem_addr = queue[sq_trueHead].addr;
    sq_mem_data = queue[sq_trueHead].data;
    if (dcachectrl_st_request_sent) {
      queue[sq_trueHead].retired = 0;
      sq_trueHead = (sq_trueHead + 1)%8;
      slotsOpen += 1;
    }
  }

  // Effective Address
  if (ib_store_en%2 == 1) {
    queue[sq_index[0]].retired = 0;
    queue[sq_index[0]].addr = 0;
    queue[sq_index[0]].data = 0;
    ea_calcd[sq_index[0]] = 0;
  }
  if (ib_store_en/2 == 1) {
    queue[sq_index[1]].retired = 0;
    queue[sq_index[1]].addr = 0;
    queue[sq_index[1]].data = 0;
    ea_calcd[sq_index[1]] = 0;
  }

  for(i = 0; i < 8; i++) {
    shifted_ea_calcd[i] = ea_calcd[(sq_trueHead + i)%8];
  }
  sq_ea_ptr = sq_trueHead;
  sq_ea_empty = 1;
  for(i = 0; i < 8; i++) {
    if(shifted_ea_calcd[i]) {
      sq_ea_empty = 0;
      sq_ea_ptr = (sq_trueHead + i)%8;
    }
    else {
      break;
    }
  }

  // Slot Available
  sq_nAvailable = (slotsOpen >= 2)? 2 : slotsOpen;
  sq_empty = (slotsOpen == 8);
}

int checkSQState(int sq_trueHeadV, int sq_tailV, int sq_emptyV, int slotsOpenV, int sq_nAvailableV, int sq_mem_dataV, int sq_mem_enV, int sq_mem_addrV,  
  int sq_indexV0, int sq_indexV1, int sq_index_emptyV, int sq_ea_ptrV, int sq_ea_emptyV, int sq_ld_matchV, int sq_ld_dataV0, int sq_ld_dataV1, int retireHeadV){
  if (slotsOpenV != slotsOpen){
    printf("slotsOpen incorrect\n");
    return 0;
  } else if (sq_nAvailableV != sq_nAvailable){
    printf("sq_nAvailable incorrect\n");
    return 0;
  } else if (sq_mem_dataV != sq_mem_data){
    printf("sq_mem_data incorrect\n");
    return 0;
  } else if (sq_mem_enV != sq_mem_en){
    printf("sq_mem_en incorrect\n");
    return 0;
  } else if (sq_mem_addrV != sq_mem_addr){
    printf("sq_mem_addr incorrect\n");
    return 0;
  } else if (sq_tailV != sq_tail){
    printf("sq_tail incorrect\n");
    return 0;
  } else if (sq_emptyV != sq_empty){
    printf("sq_empty incorrect\n");
    return 0;
  } else if (sq_ea_ptrV != sq_ea_ptr){
    printf("sq_ea_ptr incorrect\n");
    return 0;
  } else if (sq_trueHeadV != sq_trueHead){
    printf("sq_trueHead incorrect\n");
    return 0;
  } else if (retireHeadV != retireHead){
    printf("retireHead incorrect\n");
    return 0;
  } else if(ib_store_en%2 == 1 && sq_indexV0 != sq_index[0]){
    printf("load position 0 incorrect\n");
    return 0;
  } else if(ib_store_en/2 == 1 && sq_indexV1 != sq_index[1]){
    printf("load position 1 incorrect\n");
    return 0;
  } else if (sq_index_emptyV != sq_index_empty){
    printf("sq_index_empty incorrect\n");
    return 0;
  } else if (sq_ea_emptyV != sq_ea_empty){
    printf("sq_ea_empty incorrect\n");
    return 0;
  } else if (sq_ld_matchV != sq_ld_match){
    printf("sq_ld_match incorrect\n");
    return 0;
  } else if ( sq_ld_dataV0 !=  sq_ld_data[0]){
    printf(" sq_ld_data position 0 incorrect\n");
    return 0;
  } else if ( sq_ld_dataV1 !=  sq_ld_data[1]){
    printf(" sq_ld_data position 1 incorrect\n");
    return 0;
  }
  //printf("correct\n");
  return 1;
}

int checkSQEntry(int index, int addrV, int dataV, int retiredV) {
  return ((queue[index].addr == addrV)
      && (queue[index].data == dataV)
      && (queue[index].retired == retiredV));
}  

void printSimSQ(){
  int i;
  print_SQHeader(sq_trueHead, sq_tail, sq_empty, slotsOpen, sq_nAvailable, sq_mem_data, sq_mem_en, sq_mem_addr, 
    sq_index[0], sq_index[1], sq_index_empty, sq_ea_ptr, sq_ea_empty, sq_ld_match, sq_ld_data[0], sq_ld_data[1], retireHead);
  for(i = 0; i < 8; i++) {
    print_SQEntry(i, queue[i].addr, queue[i].data, queue[i].retired, ea_calcd[i]);
  }
}





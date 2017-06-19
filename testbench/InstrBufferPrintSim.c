#include <stdint.h>
#include <stdlib.h>
#include "Utility.h"

//Input file
static FILE* file = NULL;
//Inputs to simulation and testbench
static int br_fub_pred_wrong;
static int haz_nDispatched;
static int bs_nEntries;
static int bp_pred_taken[2];
static int bp_pred_NPC[2];
static int bp_not_taken_NPC[2];
static int if_inst_in[2];
static int if_valid_in[2];
FD_t fd_control[2];
//Simulation state
static int head, tail;
static IBEntry_t buffer[8];
static int numIns_buffer; //available slots in buffer
//Simulation outputs
static IBEntry_t ib_data[2];
static int ib_valid[2], ib_nIsnBuffer; //nIsnBuffer only goes till 2
static int ib_nAvai;

static void init_sim(){
  int i;
  head = 0;
  tail = 0;
  numIns_buffer = 0;
  ib_valid[0] = 0;
  ib_valid[1] = 0;
  ib_nIsnBuffer = 0;
  ib_nAvai = 2;
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
  
  br_fub_pred_wrong = readBoundedInt(file, 1);
  haz_nDispatched = readBoundedInt(file, 2);
  bs_nEntries = readBoundedInt(file, 4);
  readBoundedPair(file, bp_pred_taken, 1);
  readBoundedPair(file, bp_pred_NPC, 2147483647);
  readBoundedPair(file, bp_not_taken_NPC, 2147483647);
  readBoundedPair(file, if_inst_in, 2147483647);
  readBoundedPair(file, if_valid_in, 1);

  fd_control[0].uncond_branch = readBoundedInt(file, 1);
  fd_control[0].cond_branch = readBoundedInt(file, 1);
  fd_control[1].uncond_branch = readBoundedInt(file, 1);
  fd_control[1].cond_branch = readBoundedInt(file, 1);

  //end of line is a comment
  while((c = getc(file)) != '\n');
  
  return 0;
}


/*static int nextRandPC;
void init_randomtest(int seed){
  //nextRandPC = 4;
  init_sim();
  srand(seed);
}


void getRandomValues(){
  int i, j, r = rand() % 100, cdb_n, cdb_choices[32], cdb_nchoices, last_cdb_choice, cdb_choice;
  int isFree[64];
  // gives 2 a higher chance of happening than 1 or 0 because we are taking the min of three of these
  if_id_nIsnBuffer_IN = (r > 50)? 2 : (r > 25? 1 : 0);
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
*/


int get_br_fub_pred_wrong(){
  return br_fub_pred_wrong;
}

int get_haz_nDispatched(){
  return haz_nDispatched;
}

int get_bs_nEntries(){
  return bs_nEntries;
}

int get_bp_pred_taken(int idx){
  assert(idx == 0 || idx == 1);
  return bp_pred_taken[idx];
}

int get_bp_pred_NPC(int idx){
  assert(idx == 0 || idx == 1); 
  return bp_pred_NPC[idx];
}

int get_bp_not_taken_NPC(int idx){
  assert(idx == 0 || idx == 1);
  return bp_not_taken_NPC[idx];
}

int get_if_inst_in(int idx){
  assert(idx == 0 || idx == 1); 
  return if_inst_in[idx];
}

int get_if_valid_in(int idx){
  assert(idx == 0 || idx == 1); 
  return if_valid_in[idx];
}


int get_fd_control_uncond(int idx){
  assert(idx == 0 || idx == 1); 
  return fd_control[idx].uncond_branch;
}

int get_fd_control_cond(int idx){
  assert(idx == 0 || idx == 1); 
  return fd_control[idx].cond_branch;
}

void updateSim(){
  int nIsnBuffer_corner;

  //dispatch (empty buffer)
  if(haz_nDispatched == 2) {
    head = (head + 2)%8;
    numIns_buffer -= 2;
  } else if (haz_nDispatched == 1) {
    head = (head + 1)%8;
    numIns_buffer -= 1;
  }

  //fetch (fill buffer)
  if (if_valid_in[1]) {
    buffer[tail].instruction = if_inst_in[0];
    buffer[tail].fd_control.uncond_branch = fd_control[0].uncond_branch;
    buffer[tail].fd_control.cond_branch = fd_control[0].cond_branch;
    buffer[tail].pred_NPC = bp_pred_NPC[0];
    buffer[tail].not_taken_NPC = bp_not_taken_NPC[0];
    buffer[tail].bp_pred_taken = bp_pred_taken[0];

    buffer[(tail+1)%8].instruction = if_inst_in[1];
    buffer[(tail+1)%8].fd_control.uncond_branch = fd_control[1].uncond_branch;
    buffer[(tail+1)%8].fd_control.cond_branch = fd_control[1].cond_branch;
    buffer[(tail+1)%8].pred_NPC = bp_pred_NPC[1];
    buffer[(tail+1)%8].not_taken_NPC = bp_not_taken_NPC[1];
    buffer[(tail+1)%8].bp_pred_taken = bp_pred_taken[1];

    tail = (tail + 2)%8;
    numIns_buffer += 2;
  } else if (if_valid_in[0]) {
    buffer[tail].instruction = if_inst_in[0];
    buffer[tail].fd_control.uncond_branch = fd_control[0].uncond_branch;
    buffer[tail].fd_control.cond_branch = fd_control[0].cond_branch;
    buffer[tail].pred_NPC = bp_pred_NPC[0];
    buffer[tail].not_taken_NPC = bp_not_taken_NPC[0];
    buffer[tail].bp_pred_taken = bp_pred_taken[0];
    tail = (tail + 1)%8;
    numIns_buffer += 1;
  }


  if(buffer[head].fd_control.uncond_branch || buffer[head].fd_control.cond_branch) {
    if(bs_nEntries > 0)
      nIsnBuffer_corner = 1;
    else 
      nIsnBuffer_corner = 0;
  }
  else if (buffer[(head+1)%8].fd_control.uncond_branch || buffer[(head+1)%8].fd_control.cond_branch) {
    if(bs_nEntries > 0)
      nIsnBuffer_corner = 2;
    else 
      nIsnBuffer_corner = 1;
  } else {
    nIsnBuffer_corner = 2;
  }

  if(numIns_buffer >= 2) {
    ib_nIsnBuffer = nIsnBuffer_corner;
  } else {
    ib_nIsnBuffer = ((unsigned)(nIsnBuffer_corner) > (unsigned)(numIns_buffer)) ? numIns_buffer : nIsnBuffer_corner;
  }

  if (numIns_buffer == 8) {
    ib_nAvai = 0;
  } else if (numIns_buffer == 7) {
    ib_nAvai = 1;
  } else {
    ib_nAvai = 2;
  }



  //update output entry
  if(ib_nIsnBuffer == 2) {
    if(buffer[head].fd_control.uncond_branch | buffer[head].fd_control.cond_branch) {
      ib_data[0] = buffer[head];
      ib_valid[0] = 1;
      ib_valid[1] = 0;
    } else {
      ib_data[0] = buffer[head];
      ib_valid[0] = 1;
      ib_data[1] = buffer[(head+1)%8];
      ib_valid[1] = 1;
    }

  } else if (ib_nIsnBuffer == 1) {
    ib_data[0] = buffer[head];
    ib_valid[0] = 1;
    ib_valid[1] = 0;
  } else {
    ib_valid[0] = 0;
    ib_valid[1] = 0;
  }

  if(br_fub_pred_wrong) {
    init_sim();
    return;
  }

}

int checkIBState(int headV, int tailV, int numIns_bufferV, int ib_nIsnBufferV,
  int ib_fetch_instV0, int ib_fetch_instV1, int ib_validV0, int ib_validV1, int ib_nAvaiV){

  if(headV != head){
    printf("head incorrect\n");
    return 0;
  } else if (tailV != tail){
    printf("tail incorrect\n");
    return 0;
  } else if (numIns_bufferV != numIns_buffer){
    printf("number of entries inside buffer incorrect\n");
    return 0;
  } else if (ib_nIsnBufferV != ib_nIsnBuffer){
    printf("ib_nIsnBuffer (0-2) incorrect\n");
    return 0;
  } else if (ib_nAvaiV != ib_nAvai){
    printf("ib_nAvai (0-2) incorrect\n");
    return 0;
  } else if (ib_validV0 != ib_valid[0]){
    printf("ib_valid 0 incorrect\n");
    return 0;
  } else if (ib_validV1 != ib_valid[1]){
    printf("ib_valid 1 incorrect\n");
    return 0;
  }
  else if (ib_validV0) {
    if(ib_fetch_instV0 != ib_data[0].instruction){
      printf("fetch instruction output 0 incorrect\n");
      return 0;
    }
  }
  else if (ib_validV1) {
    if(ib_fetch_instV1 != ib_data[1].instruction){
      printf("fetch instruction output 1 incorrect\n");
      return 0;
    }
  }
  //printf("correct\n");
  return 1;
}

int checkIBEntry(int index, int instructionV, int fd_control_uncondV, int fd_control_condV, int pred_NPCV, int not_taken_NPCV, int bp_pred_takenV){
  return ((buffer[index].instruction == instructionV)
      && (buffer[index].fd_control.uncond_branch == fd_control_uncondV)
      && (buffer[index].fd_control.cond_branch   == fd_control_condV)
      && (buffer[index].pred_NPC == pred_NPCV)
      && (buffer[index].not_taken_NPC == not_taken_NPCV)
      && (buffer[index].bp_pred_taken == bp_pred_takenV)) ? 1 : 0;
}

void printSimIB(){
  int i;
  print_IBHeader(head, tail, numIns_buffer, ib_nIsnBuffer, ib_nAvai,
    ib_data[0].instruction, ib_data[0].fd_control.uncond_branch,
    ib_data[0].fd_control.cond_branch, ib_data[0].pred_NPC,
    ib_data[0].not_taken_NPC, ib_data[0].bp_pred_taken, ib_valid[0],
    ib_data[1].instruction, ib_data[1].fd_control.uncond_branch,
    ib_data[1].fd_control.cond_branch, ib_data[1].pred_NPC,
    ib_data[1].not_taken_NPC, ib_data[1].bp_pred_taken, ib_valid[1]);
  for(i = 0; i < 8; i++){
    print_IBEntry(buffer[i].instruction, buffer[i].fd_control.uncond_branch, 
      buffer[i].fd_control.cond_branch, buffer[i].pred_NPC, buffer[i].not_taken_NPC,
      buffer[i].bp_pred_taken);
  }
}

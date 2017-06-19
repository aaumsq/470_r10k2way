#include "Utility.h"

static FILE* file;

static int head, tail, array[32], fl_freeRegs[2], fl_availableRegs;
static int prevRetired;

void init_sim(){
  int i;
  for(i = 0; i < 32; i++){
    array[i] = i + 32;
  }
  head = 0;
  tail = 31;
  fl_availableRegs = 32;
  prevRetired = 0;
}

void init_filetest(char* filename){
  file = fopen(filename, "r");
  init_sim();
}

static int ext_nDispatched_IN, rob_retireTagOld_IN[2], rob_nRetired_IN;

int readLine(){
  char c;
  if(removeSOLComment(file) == EOF){
    printf("RETURNING 1\n");
    return 1;
  }
  ext_nDispatched_IN = readBoundedInt(file, 2);
  prevRetired = rob_nRetired_IN;
  rob_nRetired_IN = readBoundedInt(file, 2);
  readBoundedPair(file, &rob_retireTagOld_IN, 63);
  //end of line is a comment
  while((c = getc(file)) != '\n');
  return 0;
}

int get_ext_nDispatched(){
  return ext_nDispatched_IN;
}

int get_rob_retireTagOld(int idx){
  assert(idx == 0 || idx == 1);
  return rob_retireTagOld_IN[idx];
}

int get_rob_nRetired(){
  return rob_nRetired_IN;
}

void updateSim(){
  int i, ndispatched;
  ndispatched = min(ext_nDispatched_IN, fl_availableRegs);
  fl_availableRegs += prevRetired - ndispatched;
  for(i = 0; i < ndispatched; i++){
    fl_freeRegs[i] = array[(head+i)&31];
  }
  head = (head + ndispatched) & 31;
  for(i = 0; i < rob_nRetired_IN; i++){
    array[(tail+i+1)&31] = rob_retireTagOld_IN[i];
  }
  tail = (tail + rob_nRetired_IN) & 31;
  printf("head: %d, tail: %d\n", head, tail);
}

int checkFLOutputs(int fl_availableRegsV, int ndispatched, int fl_freeRegs0, int fl_freeRegs1){
  return (fl_availableRegs == fl_availableRegsV) &&
      ((ndispatched == 0) || (fl_freeRegs[0] == fl_freeRegs0)) &&
      ((ndispatched <= 1) || (fl_freeRegs[1] == fl_freeRegs1)) ? 1 : 0;
}

void printSimFL(){
  int i;
    printf("head: %d, fl_availableRegs: %d\n", head, fl_availableRegs);
    printf("Regs In Freelist: ");
    for(i = head; i < head + fl_availableRegs; i++){
      printf("%d ", array[i&31]);
    }
    printf("\nDispatched Freelist Regs: ");
    for(i = 0; i < fl_availableRegs && i < 2; i++){
      printf("%d ", fl_freeRegs[i]);
    }
    printf("\n-------------------------------------------------\n");
}

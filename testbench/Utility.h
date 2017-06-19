#ifndef UTILITY_H_   /* Include guard */
#define UTILITY_H_

#include "print.c"
#include <stdio.h>
#include <stdint.h>
#include "DirectC.h"

#ifndef NDEBUG
#define assert(cond) assert__(cond, __FILE__, __LINE__)
#else
#define assert(cond)
#endif


typedef struct ROBEntry ROBEntry_t;
typedef struct RSEntry RSEntry_t;
typedef struct IBEntry IBEntry_t;
typedef struct SQEntry SQEntry_t;
typedef struct FD FD_t;

struct ROBEntry {
  int valid;
  int complete;
  int tag;
  int tagOld;
};

struct RSEntry {
    int valid;
    uint64_t nextPC;
    int instruction;
    int fuType;
//    DE_control_t    control; //hard to simulate and not very useful
    int tag;
    int tagA;
    int tagB; 
    int tagAReady;
    int tagBReady;
};

struct FD {
  int cond_branch;
  int uncond_branch;
};

struct IBEntry {
  int instruction;
  FD_t fd_control;
  int pred_NPC;
  int not_taken_NPC;
  int bp_pred_taken;
};

struct SQEntry {
  int addr;
  int data;
  int retired;
};


void assert__(int cond, char* file, int line){
  if(!cond){
    printf("ASSERTION FAILED: %s:%d\n", file, line);
    exit(1);
  }
}

int min(int a, int b){
  return a < b? a : b;
}

int removeSOLComment(FILE* file){
  int c;
  while((c = getc(file)) == '#'){
    while((c = getc(file)) != '\n');
  }
  if(c == EOF){
  printf("EOF FOUND\n");
    return c;
  }
  ungetc(c, file);
  return c;
}

int readBoundedInt(FILE* file, long long max){
  int val, nRead;
  nRead = fscanf(file, "%u", &val);
  assert(nRead == 1);
  assert(val >= 0 && val <= max);
  return val;
}

void readBoundedPair(FILE* file, int* pair, int max){
  int i, nRead;
  for(i = 0; i < 2; i++){
    nRead = fscanf(file, "%u", pair+i);
    assert(nRead == 1);
    assert(pair[i] >= 0 && pair[i] <= max);
  }
}

void readInstructions(FILE* file, int* if_id_instructions_IN, int* if_id_NPC_IN){
  int i, nRead;
  for(i = 0; i < 2; i++){
    nRead = fscanf(file, "%u", if_id_instructions_IN+i);
    assert(nRead == 1);
    nRead = fscanf(file, "%llu", if_id_NPC_IN+i);
    assert(nRead == 1);
  }
}


#endif // UTILITY_H_

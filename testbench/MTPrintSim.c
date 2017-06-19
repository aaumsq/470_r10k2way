#include "Utility.h"

void printMapEntries(int index0, int reg0, int ready0, int reg8, int ready8, int reg16, int ready16, int reg24, int ready24){
  printf("%d: %d%s\t\t", index0, reg0, ready0? "+" : "");
  printf("%d: %d%s\t\t", index0+8, reg8, ready8? "+" : "");
  printf("%d: %d%s\t\t", index0+16, reg16, ready16? "+" : "");
  printf("%d: %d%s\n", index0+24, reg24, ready24? "+" : "");
}

static int map[32];

static int mt_tagA[2], mt_tagB[2], mt_dispatchTagOld[2], mt_ready[32], mt_aReady[2], mt_bReady[2];

static FILE* file;
static int de_destidx_IN[2], de_regAidx_IN[2], de_regBidx_IN[2], 
      ext_nDispatched_IN, cdb_rd_IN[2], cdb_rd_en_IN[2], fl_freeRegs_IN[2];

void init_sim(){
  int i;
  ext_nDispatched_IN = 0;
  cdb_rd_en_IN[0] = 0;
  cdb_rd_en_IN[1] = 0;
  for(i = 0; i < 32; i++){
    map[i] = i;
    mt_ready[i] = 1;
  }
}


static int nextFree;
void init_randomtest(int seed){
  srand(seed);
  init_sim();
  nextFree = 32;
}
      
void init_filetest(char* filename){
  file = fopen(filename, "r");
  init_sim();
}

void getRandomValues(){
  int i;
  ext_nDispatched_IN = rand() % 2;
  for(i = 0; i < 2; i++){
    de_destidx_IN[i] = rand() % 32;
    de_regAidx_IN[i] = rand() % 32;
    de_regBidx_IN[i] = rand() % 32;
    fl_freeRegs_IN[i] = nextFree+i; 
    cdb_rd_en_IN[i] = rand() % 2;
    cdb_rd_IN[i] = rand() % 64;
  }
  nextFree = (nextFree + ext_nDispatched_IN) % 64;
}

int readLine(){
  char c;
  if(removeSOLComment(file) == EOF){
    return 1;
  }
  ext_nDispatched_IN = readBoundedInt(file, 2);
  readBoundedPair(file, &de_destidx_IN, 31);
  readBoundedPair(file, &de_regAidx_IN, 31);
  readBoundedPair(file, &de_regBidx_IN, 31);
  readBoundedPair(file, &fl_freeRegs_IN, 63);
  readBoundedPair(file, &cdb_rd_en_IN, 1);
  readBoundedPair(file, &cdb_rd_IN, 63);
  //end of line is a comment
  while((c = getc(file)) != '\n');
  
  return 0;
}

int get_de_destidx(int idx){
  assert(idx == 0 || idx == 1);
  return de_destidx_IN[idx];
}

int get_de_regAidx(int idx){
  assert(idx == 0 || idx == 1);
  return de_regAidx_IN[idx];
}

int get_de_regBidx(int idx){
  assert(idx == 0 || idx == 1);
  return de_regBidx_IN[idx];
}

int get_ext_nDispatched(){
  return ext_nDispatched_IN;
}

int get_fl_freeRegs(int idx){
  assert(idx >= 0 && idx < 2);
  return fl_freeRegs_IN[idx];
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
  int i, j;
    //complete
  for(i = 0; i < 31; i++){
    for(j = 0; j < 2; j++){
      if(cdb_rd_en_IN[j] && cdb_rd_IN[j] == map[i]){
        mt_ready[i] = 1;
      }
    }
  }
    //dispatch
  for(i = 0; i < 2; i++){
    mt_dispatchTagOld[i] = map[de_destidx_IN[i]];
  }
  for(i = 0; i < ext_nDispatched_IN; i++){
    if(de_destidx_IN[i] != 31){
      map[de_destidx_IN[i]] = fl_freeRegs_IN[i];
      mt_ready[de_destidx_IN[i]] = 0;
    }
  }
  
    //combinational
  for(i = 0; i < 2; i++){
    mt_aReady[i] = mt_ready[de_regAidx_IN[i]];
    mt_bReady[i] = mt_ready[de_regBidx_IN[i]];
    mt_tagA[i] = map[de_regAidx_IN[i]];
    mt_tagB[i] = map[de_regBidx_IN[i]];
  }
}

int checkMapEntry(int arch, int phys, int ready){
  return (map[arch] == phys) && (mt_ready[arch] == ready)? 1: 0;
}

int checkOutputs(int mt_tagA0, int mt_tagA1, int mt_tagB0, int mt_tagB1, 
          int aReady0, int aReady1, int bReady0, int bReady1,
          int mt_dispatchTagOld0,  int mt_dispatchTagOld1){
  return ((aReady0 == mt_aReady[0]) && (aReady1 == mt_aReady[1]) &&
      (bReady0 == mt_bReady[0]) && (bReady1 == mt_bReady[1]) &&
      (mt_tagA0 == mt_tagA[0]) && (mt_tagB0 == mt_tagB[0]) &&
      (mt_tagA1 == mt_tagA[1]) && (mt_tagB1 == mt_tagB[1]) &&
      (mt_dispatchTagOld0 == mt_dispatchTagOld[0]) && 
      (mt_dispatchTagOld1 == mt_dispatchTagOld[1])) ? 1 : 0;  
}

void printSimMT(){
  int i;
  for(i = 0; i < 8; i++){
      printMapEntries(i, map[i], mt_ready[i], 
                         map[i+8], mt_ready[i+8], 
                         map[i+16], mt_ready[i+16], 
                         map[i+24], mt_ready[i+24]);
    }
    printf("mt_tagA[0]=%d%s, mt_tagB[0]=%d%s, mt_dispatchTagOld[0]=%d, mt_tagA[1]=%d%s, mt_tagB[1]=%d%s, mt_dispatchTagOld[1]=%d\n"
             , mt_tagA[0], mt_aReady[0]? "+" : "", mt_tagB[0], mt_bReady[0]? "+" : "", mt_dispatchTagOld[0]
             , mt_tagA[1], mt_aReady[1]? "+" : "", mt_tagB[1], mt_bReady[1]? "+" : "", mt_dispatchTagOld[1]);
  printf("-------------------------------------------------\n");
}

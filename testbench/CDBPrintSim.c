#include "Utility.h"

  // CDB Inputs
static int fub_valid;
static int fub_tagDest[8];
static int fub_result[8];         

//Simulation outputs
static int cdb_rd[2];
static int cdb_rd_en[2];
static int cdb_stall;
static int cdb_reg_value[2];

void init_sim(){
  int j;
  fub_valid = 0;
  for (j = 0; j < 8; ++j) {
    fub_tagDest[j] = j;
    fub_result[j] = j;
  }
  cdb_rd[0] = 0;
  cdb_rd[1] = 0;
  cdb_rd_en[0] = 0;
  cdb_rd_en[1] = 0;
  cdb_stall = 255;
  cdb_reg_value[0] = 0;
  cdb_reg_value[1] = 0;
}

void init_comptest(){
  ++fub_valid;
}

int get_fub_valid(){
  return fub_valid;
}

int get_fub_tagDest(int idx){
  assert(idx >= 0 && idx < 8);
  return fub_tagDest[idx];
}

int get_fub_result(int idx){
  assert(idx >= 0 && idx < 8);
  return fub_result[idx];
}

int checkCDB(int cdb_rd0V, int cdb_rd1V, 
  int cdb_rd_en0V, int cdb_rd_en1V, int cdb_stallV, int cdb_reg0V, int cdb_reg1V){
  if (cdb_rd_en0V != cdb_rd_en[0] ||
    cdb_rd_en1V != cdb_rd_en[1] ||
    cdb_stallV != cdb_stall) {
    printf("---------------------------------------------------------------------------------------\n");
    printf("FAILED: Incorrect control bit output\n");
    printf("cdb_rd_en[0]: %d, cdb_rd_en[1] %d, cdb_stall: %d\n",
      cdb_rd_en[0], cdb_rd_en[1], cdb_stall);
    printf("Correct values:\n");
    printf("cdb_rd_en[0]: %d, cdb_rd_en[1] %d, cdb_stall: %d\n",
      cdb_rd_en0V, cdb_rd_en1V, cdb_stallV);
    printf("---------------------------------------------------------------------------------------\n");
    return 0;
  }
  else if ((cdb_rd_en[0] && cdb_rd0V != cdb_rd[0]) ||
    (cdb_rd_en[1] && cdb_rd1V != cdb_rd[1])) {
    printf("---------------------------------------------------------------------------------------\n");
    printf("FAILED: Incorrect cdb_rd output\n");
    printf("---------------------------------------------------------------------------------------\n");
    return 0;
  }
  return 1;
}

void updateSim(){
  init_comptest();
  cdb_stall = 255;
  cdb_rd_en[0] = 0;
  cdb_rd_en[1] = 0;

  unsigned int valid_bits = fub_valid;

  int i;
  for (i = 0; i < 8; i++) {
    if (valid_bits & 1 == 1) {
      if (cdb_rd_en[0]) {
        cdb_rd_en[1] = 1;
        cdb_rd[1] = fub_tagDest[i];
        cdb_stall -= (1 << i);
        cdb_reg_value[1] = fub_result[i];
        return;
      }
      else if (valid_bits == 1) {
        cdb_rd_en[0] = 1;
        cdb_rd[0] = fub_tagDest[i];
        cdb_stall -= (1 << i);
        cdb_reg_value[0] = fub_result[i];
        return;
      }
      cdb_rd_en[0] = 1;
      cdb_rd[0] = fub_tagDest[i];
      cdb_stall -= (1 << i);
      cdb_reg_value[0] = fub_result[i];
    }
    valid_bits = valid_bits >> 1;
  }
}

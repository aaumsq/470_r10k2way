#include "Utility.h"

static FILE* file = NULL;
static int ext_nDispatched_IN, de_instruction_IN[2], if_id_NPC_IN[2], 
      fl_freeRegs_IN[2], mt_tagA_IN[2], mt_tagB_IN[2], mt_aReady_IN[2], mt_bReady_IN[2],
      de_fuType_IN[2], fub_busy_IN[8], cdb_rd_en_IN[2], cdb_rd_IN[2];
static RSEntry_t entries[16];
static int rs_availableSlots;
static int rs_nIssue, rs_issuePtr[2], regA_val[2], regB_val[2], rs_tagDest[2], rs_fu_en[8];

static void init_sim(){
  int i;
  for(i = 0; i < 16; i++){
    entries[i].valid = 0;
  }
  rs_availableSlots = 16;
  for(i = 0; i < 8; i++){
    rs_fu_en[i] = 0;
  }
  rs_nIssue = 0;
  for(i = 0; i < 2; i++){
    rs_issuePtr[i] = 0;
    regA_val[i] = 0;
    regB_val[i] = 0;
    rs_tagDest[i] = 0;
  }
}

void init_filetest(char* filename){
  init_sim();
  ext_nDispatched_IN = 0;
  de_instruction_IN[0] = 0;
  de_instruction_IN[1] = 1;
  if_id_NPC_IN[0] = 4;
  if_id_NPC_IN[1] = 8;
  file = fopen(filename, "r");
}

int readLine(){
  char c;
  int i;

  if(removeSOLComment(file) == EOF){
    return 1;
  }
  
  de_instruction_IN[0] += 2;
  de_instruction_IN[1] += 2;
  if_id_NPC_IN[0] += 4*ext_nDispatched_IN;
  if_id_NPC_IN[1] += 4*ext_nDispatched_IN;
  
  ext_nDispatched_IN = readBoundedInt(file, 2);
  
  
  readBoundedPair(file, fl_freeRegs_IN, 63);
  readBoundedPair(file, mt_tagA_IN, 63);
  readBoundedPair(file, mt_tagB_IN, 63);
  readBoundedPair(file, mt_aReady_IN, 1);
  readBoundedPair(file, mt_bReady_IN, 1);
  
  readBoundedPair(file, de_fuType_IN, 3);
  
  for(i = 0; i < 8; i++){
    fub_busy_IN[i] = readBoundedInt(file, 1);
  }
  
  readBoundedPair(file, cdb_rd_en_IN, 1);
  readBoundedPair(file, cdb_rd_IN, 63);

  //end of line is a comment
  while((c = getc(file)) != '\n');
  
  return 0;
}

static int cdbSelective;
void init_randomtest(int seed, int cdbSelective_){
  init_sim();
  srand(seed);
  ext_nDispatched_IN = 0;
  de_instruction_IN[0] = 0;
  de_instruction_IN[1] = 1;
  if_id_NPC_IN[0] = 4;
  if_id_NPC_IN[1] = 8;
  cdbSelective = cdbSelective_;
}

void getRandomValues(){
  int i, j, r, isFree[64], last_cdb_choice, cdb_choice, cdb_n, cdb_choices[32], cdb_nchoices, foundA, foundB;
  de_instruction_IN[0] += 2;
  de_instruction_IN[1] += 2;
  if_id_NPC_IN[0] += 4*ext_nDispatched_IN;
  if_id_NPC_IN[1] += 4*ext_nDispatched_IN;
  
  ext_nDispatched_IN = rand() % 2;
  
  for(i = 0; i < 64; i++){
    isFree[i] = 1;
  }
  for(i = 0; i < 16; i++){
    if(entries[i].valid){
      isFree[entries[i].tag] = 0;
    }    
  }
  for(i = 0; i < ext_nDispatched_IN; i++){
    while(!isFree[fl_freeRegs_IN[i] = rand() % 64]);
    isFree[fl_freeRegs_IN[i]] = 0;
  }
  
  for(i = 0; i < 2; i++){
    mt_tagA_IN[i] = rand() % 64;
    mt_tagB_IN[i] = rand() % 64;
    mt_aReady_IN[i] = rand() % 2;
    mt_bReady_IN[i] = rand() % 2;  
  }
  
  for(i = 0; i < 2; i++){
    de_fuType_IN[i] = rand() % 4;
  }
  
  for(i = 0; i < 8; i++){
    fub_busy_IN[i] = rand() % 2;
  }  
  
  if(cdbSelective){
    cdb_nchoices = 0;
    for(i = 0; i < 16; i++){
      if(!entries[i].valid){
        continue;
      }
      foundA = 0;
      foundB = 0;
      for(j = 0; j < cdb_nchoices; j++){
        if(entries[i].tagA == cdb_choices[j]){
          foundA = 1;
        }
        if(entries[i].tagB == cdb_choices[j] && entries[i].tagA != entries[i].tagB){
          foundB = 1;
        }
      }
      if(!foundA && !entries[i].tagAReady){
        cdb_choices[cdb_nchoices++] = entries[i].tagA;
      }
      if(!foundB && !entries[i].tagBReady){
        cdb_choices[cdb_nchoices++] = entries[i].tagB;
      }
    }
    printf("choices: ");
    for(i = 0; i < cdb_nchoices; i++){
      printf("%d ", cdb_choices[i]);
    }
    printf("\n");
    last_cdb_choice = -1;
    cdb_n = min(rand()%2, cdb_nchoices);
    for(i = 0; i < cdb_n && i < cdb_nchoices; i++){
      cdb_rd_en_IN[i] = 1;
      while((cdb_choice = rand() % cdb_nchoices) == last_cdb_choice);
      cdb_rd_IN[i] = cdb_choices[last_cdb_choice = cdb_choice];
      printf("%d chosen\n", cdb_choice);
    }
    for(; i < 2; i++){
      cdb_rd_en_IN[i] = 0;
    }
    printf("cdb_n: %d\n", cdb_n);
    for(i = 0; i < cdb_n; i++){
      printf("\tcdb[%d]: %d\n", i, cdb_rd_IN[i]);
    }
  } else {
    last_cdb_choice = -1;
    cdb_n = rand() % 2;
    for(i = 0; i < cdb_n; i++){
      cdb_rd_en_IN[i] = 1;
      while((cdb_rd_IN[i] = rand() % 64) == last_cdb_choice);
    }
    for(; i < 2; i++){
      cdb_rd_en_IN[i] = 0;
    }
  }
}

int get_ext_nDispatched(){
  return ext_nDispatched_IN;
}

int get_de_instruction(int idx){
  assert(idx >= 0 && idx < 2);
  return de_instruction_IN[idx];
}

int get_de_fuType(int idx){
  assert(idx >= 0 && idx < 2);
  return de_fuType_IN[idx];  
}

int get_if_id_NPC(int idx){
  assert(idx >= 0 && idx < 2);
  return if_id_NPC_IN[idx];  
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

int get_fuBusy(int idx){
  assert(idx >= 0 && idx < 8);
  return fub_busy_IN[idx];
}

int get_mt_tagA(int idx){
  assert(idx == 0 || idx == 1); 
  return mt_tagA_IN[idx];
}

int get_mt_tagB(int idx){
  assert(idx == 0 || idx == 1); 
  return mt_tagB_IN[idx];
}

int get_mt_aReady(int idx){
  assert(idx == 0 || idx == 1); 
  return mt_aReady_IN[idx];
}

int get_mt_bReady(int idx){
  assert(idx == 0 || idx == 1); 
  return mt_bReady_IN[idx];
}

void updateSim(){
  int i, j, nDispatched;
    //Complete
  for(i = 0; i < 2; i++){
    for(j = 0; j < 16; j++){
      if(cdb_rd_en_IN[i]){
        if(entries[j].tagA == cdb_rd_IN[i]){
          entries[j].tagAReady = 1;
        }
        if(entries[j].tagB == cdb_rd_IN[i]){
          entries[j].tagBReady = 1;
        }
      }
    }
  }
  
    //Issue
      //Combinational selection logic
  for(i = 0; i < 8; i++){
    rs_fu_en[i] = 0;
  }
  rs_nIssue = 0;
  for(i = 0; (i < 16) && (rs_nIssue < 2); i++){
    int aReady, bReady;
    aReady = entries[i].tagAReady;
    bReady = entries[i].tagBReady;
    for(j = 0; j < 2; j++){
      if(cdb_rd_en_IN[j]){
        aReady = aReady || (cdb_rd_IN[j] == entries[i].tagA);
        bReady = bReady || (cdb_rd_IN[j] == entries[i].tagB);
      }
    }
    if(entries[i].valid && aReady && bReady && (rs_nIssue == 0 || rs_issuePtr[0] != i)){
      switch(entries[i].fuType){
        case 0: //alu (6, 7)
          for(j = 6; j < 8; j++){
            if(!fub_busy_IN[j] && !rs_fu_en[j]){
              rs_issuePtr[rs_nIssue] = i;
              rs_fu_en[j] = rs_nIssue + 1;
              rs_nIssue++;
              break;
            }
          }
          break;
        case 1: //mult (4, 5)
          for(j = 4; j < 6; j++){
            if(!fub_busy_IN[j] && !rs_fu_en[j]){
              rs_issuePtr[rs_nIssue] = i;
              rs_fu_en[j] = rs_nIssue + 1;
              rs_nIssue++;
              break;
            }
          }          
          break;
        case 2: //ldst (1, 2, 3)
          for(j = 1; j < 4; j++){
            if(!fub_busy_IN[j] && !rs_fu_en[j]){
              rs_issuePtr[rs_nIssue] = i;
              rs_fu_en[j] = rs_nIssue + 1;
              rs_nIssue++;
              break;
            }
          }
          break;
        case 3: //br (0)
          for(j = 0; j < 1; j++){
            if(!fub_busy_IN[j] && !rs_fu_en[j]){
              rs_issuePtr[rs_nIssue] = i;
              rs_fu_en[j] = rs_nIssue + 1;
              rs_nIssue++;
              break;
            }
          }
          break;
        default:
          assert(0);
      }
    }
  }
      //Sequential state updating logic
  for(i = 0; i < rs_nIssue; i++){
    regA_val[i] = entries[rs_issuePtr[i]].tagA;
    regB_val[i] = entries[rs_issuePtr[i]].tagB;
    rs_tagDest[i] = entries[rs_issuePtr[i]].tag;
    entries[rs_issuePtr[i]].valid = 0;
  }
  
    //Dispatch
  nDispatched = min(ext_nDispatched_IN, rs_availableSlots);
  for(i = 0; i < nDispatched; i ++){
    for(j = 0; j < 16; j++){
      if(!entries[j].valid && ((j != rs_issuePtr[0]) || (rs_nIssue < 1)) 
                && ((j != rs_issuePtr[1]) || (rs_nIssue < 2))){
        entries[j].valid = 1;
        entries[j].nextPC = if_id_NPC_IN[i];
        entries[j].instruction = de_instruction_IN[i];
        entries[j].fuType = de_fuType_IN[i];
        entries[j].tag = fl_freeRegs_IN[i];
        entries[j].tagA = mt_tagA_IN[i];
        entries[j].tagB = mt_tagB_IN[i];
        entries[j].tagAReady = mt_aReady_IN[i];
        entries[j].tagBReady = mt_bReady_IN[i];
        break;
      }
    }
  }
  
    //General state
  rs_availableSlots = 16;
  for(i = 0; i < 16; i++){
    if(entries[i].valid){
      rs_availableSlots--;
    }
  }
}


int checkRSState(int rs_availableSlotsV){
  return rs_availableSlots == rs_availableSlotsV;
}

int checkRSEntry(int index, int valid, int tag, int tagA, int tagB, 
            int tagAReady, int tagBReady, int fuType){
  if(!valid){
    return !entries[index].valid? 1:0;
  }
  return ((entries[index].tag == tag) &&
      (entries[index].tagA == tagA) && 
      (entries[index].tagB == tagB) &&
      (entries[index].tagAReady == tagAReady) &&
      (entries[index].tagBReady == tagBReady) &&
      (entries[index].fuType == fuType)) ? 1:0;
}

int checkRSOutputs(int rs_nIssueV, int rs_issuePtr0V, int rs_issuePtr1V,
        int regA_val0V, int regA_val1V, int regB_val0V, int regB_val1V, 
        int rs_tagDest0V, int rs_tagDest1V){
  if(rs_nIssue != rs_nIssueV){
    printf("incorrect nIssed\n");
    return 0;
  }
  if(rs_nIssue >= 1 && (rs_issuePtr[0] != rs_issuePtr0V)){
    printf("incorrect issuePtr[0]\n");
    return 0;
  }
  if(rs_nIssue >= 2 && (rs_issuePtr[1] != rs_issuePtr1V)){
    printf("incorrect issuePtr[1]\n");
    return 0;
  }
  if(rs_nIssue >= 1 && (regA_val[0] != regA_val0V)){
    printf("incorrect regA[issuePtr[0]]\n");
    return 0;
  }
  if(rs_nIssue >= 2 && (regA_val[1] != regA_val1V)){
    printf("incorrect regA[issuePtr[1]]\n");
    return 0;
  }
  if(rs_nIssue >= 1 && (regB_val[0] != regB_val0V)){
    printf("incorrect regB[issuePtr[0]=%d] (%d != %d)\n", 
        rs_issuePtr0V, regB_val[0], regB_val0V);
    return 0;
  }
  if(rs_nIssue >= 2 && (regB_val[1] != regB_val1V)){
    printf("incorrect regB[issuePtr[1]]\n");
    return 0;
  }
  if(rs_nIssue >= 1 && (rs_tagDest[0] != rs_tagDest0V)){
    printf("incorrect tag[issuePtr[0]]\n");
    return 0;
  }
  if(rs_nIssue >= 2 && (rs_tagDest[1] != rs_tagDest1V)){\
    printf("incorrect tag[issuePtr[1]]\n");
    return 0;
  }
  return 1;
}

int checkFU_EN(int f0, int f1, int f2, int f3, int f4, int f5, int f6, int f7){
  return (f0 == rs_fu_en[0])
    && (f1 == rs_fu_en[1])
    && (f2 == rs_fu_en[2])
    && (f3 == rs_fu_en[3])
    && (f4 == rs_fu_en[4])
    && (f5 == rs_fu_en[5])
    && (f6 == rs_fu_en[6])
    && (f7 == rs_fu_en[7]);
}

void printSimRS(){
  int i;
  print_RSHeader();
    for(i = 0; i < 16; i++){
        if(entries[i].valid){
          print_RSEntry(i, entries[i].instruction, entries[i].fuType, entries[i].tag, 
                      entries[i].tagA, entries[i].tagB, 
                      entries[i].tagAReady, entries[i].tagBReady);
        }
    }
    print_RSOutputs(rs_availableSlots, rs_nIssue);
    for(i = 0; i < rs_nIssue; i++){
      print_RSEntry(rs_issuePtr[i], entries[rs_issuePtr[i]].instruction, 
                    entries[rs_issuePtr[i]].fuType, entries[rs_issuePtr[i]].tag, 
                    entries[rs_issuePtr[i]].tagA, entries[rs_issuePtr[i]].tagB, 
                    entries[rs_issuePtr[i]].tagAReady, entries[rs_issuePtr[i]].tagBReady);
    }
  print_fu_en(rs_fu_en[0], rs_fu_en[1], rs_fu_en[2], rs_fu_en[3], rs_fu_en[4], 
                rs_fu_en[5], rs_fu_en[6], rs_fu_en[7]);
  printf("busy: br: %d, ldst: %d %d %d, mult: %d %d, alu: %d %d\n", 
            fub_busy_IN[0], fub_busy_IN[1], fub_busy_IN[2], fub_busy_IN[3],
            fub_busy_IN[4], fub_busy_IN[5], fub_busy_IN[6], fub_busy_IN[7]);
  printf("-------------------------------------------------\n");
}






#include "Utility.h"

static FILE* file;
static int fu_result, fu_done, fu_tagDest, cdb_stall, br_fub_done, pred_wrong, bs_ptr, fu_bmask;

void init_filetest(char* filename){
  file = fopen(filename, "r");
  assert(file);  
}

int readline(){
  char c;
  int i;

  
  if(removeSOLComment(file) == EOF){
    return 1;
  }
  
  fu_result = readBoundedInt(file, 2147483647);
  fu_done = readBoundedInt(file, 1);
  fu_tagDest = readBoundedInt(file, 31);
  cdb_stall = readBoundedInt(file, 1);

  pred_wrong = readBoundedInt(file, 1);
  br_fub_done = readBoundedInt(file, 1);
  bs_ptr = readBoundedInt(file, 3);
  
  fu_bmask = readBoundedInt(file, 15);
  
  //end of line is a comment
  while((c = getc(file)) != '\n');
  
  return 0;
}

int get_fu_result(){
  return fu_result;
}

int get_fu_done(){
  return fu_done;
}

int get_fu_tagDest(){
  return fu_tagDest;
}

int get_cdb_stall(){
  return cdb_stall;
}

int get_pred_wrong(){
  return pred_wrong;
}

int get_br_fub_done(){
  return br_fub_done;
}

int get_bs_ptr(){
  return bs_ptr;
}

int get_fu_bmask(){
  return fu_bmask;
}

void print_fub(int valid0, int tag0, int bmask0, int valid1, int tag1, int bmask1){
  printf("buffer: ");
  if(valid0){
    printf("%d [%d], ", tag0, bmask0);
  } else {
    printf("x, ");
  }
  if(valid1){
    printf("%d [%d], \n", tag1, bmask1);
  } else {
    printf("x, \n");
  }
}



#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/times.h>
#define EXPLAIN "\
  This program can generate the test bench for your program. The input number\n\
  and the vector number are depend on the size of integer in your computer. For\n\
  example, a 16-bit CPU system would have a maximum number 65535.\n\
  The syntax is as follows:\n\n\
  SYNOPSIS\n\
	bench_gen [options: -in_no, -vec_no, -comp_file, -o, -x_rate_max]\n\n\
  OPTIONS\n\
	-in_no _N_U_M\n\
		Define the input number as _N_U_M.\n\n\
	-vec_no _N_U_M\n\
		Define the vector number as _N_U_M.\n\n\
	-comp_file _F_I_L_E\n\
		Define the compatible set in _F_I_L_E file\n\n\
	-o _F_I_L_E\n\
		Define the ouptput file name as _F_I_L_E. The default out file\n\
		is \"bench_gen.vec\".\n\n\
	-x_rate_max _F_L_O_A_T\n\
		Define the maximum don't care rate (0 ~ <1) as _F_L_O_A_T in each\n\
		test vector. The default FLOAT is 0.5\n\n\
  EXAMPLE\n\n\
  	./bench_gen -in_no 10 -vec_no 20 -comp_file comp_file.comp -x_rate_max 0.7 -o test.vec\n"
	
		

char **comp_array;
unsigned int input_no, vector_no;

int comp_absi(a, b)
int *a, *b;
{
  return (abs(*b) - abs(*a));
}

main(argc, argv)
int argc;
char **argv;
{
  unsigned int index;
  unsigned int mask, k;
  register int i, j, vec, x_no_max;
  int *comp_tmp;
  char *str, *head, *tail, sign, *vector;
  float x_rate_max;
  FILE *fout, *fin;

  srand(time(NULL));

  if (argc == 1) {
    printf(EXPLAIN);
    exit(0);
  }
  
  fin = fout = NULL;
  x_rate_max = 0.5;

  for (i = 1; i < argc;) {
    if (argv[i][0] == '-')  {
      str = argv[i++];
      switch(str[1]) {
	case 'i':
	  if (!strcmp(str, "-in_no")) {
	    if (i == argc) {
	      printf("input number is empty\n");
	      exit(0);
	    }
	    input_no = atoi(argv[i++]);
	  }
	  else {
	    printf("Unknown option: %s\n", str);
	    printf(EXPLAIN);
	    exit(0);
	  }
	  break;
	case 'v':
	  if (!strcmp(str, "-vec_no")) {
	    if (i == argc) {
	      printf("vector number is empty\n");
	      exit(0);
	    }
	    vector_no = atoi(argv[i++]);
	  }
	  else {
	    printf("Unknown option: %s\n", str);
	    printf(EXPLAIN);
	    exit(0);
	  }
	  break;
	case 'c':
	  if (!strcmp(str, "-comp_file")) {
	    if (i == argc) {
	      printf("Compatible file is empty.\n");
	      exit(0);
	    }
	    if (fin) {
	      printf("Duplicate compatible file. Please merge them.\n");
	      exit(0);
	    }
	    fin = fopen(argv[i++], "r");	    
	  }
	  else {
	    printf("Unknown option: %s\n", str);
	    printf(EXPLAIN);
	    exit(0);
	  }
	  break;

	case 'o':
	  if (!strcmp(str, "-o")) {
	    if (i == argc) {
	      printf("Output file is empty\n");
	      exit(0);
	    }
	    fout = fopen(argv[i++], "w");
	  }
	  else {
	    printf("Unknown option: %s\n", str);
	    printf(EXPLAIN);
	    exit(0);
	  }
	  break;
	
	case 'h':
	  if (strcmp(str, "-help")) printf("Unknown option: %s\n", str);
	  printf(EXPLAIN);
	  exit(0);
	  break;
	
	case 'x':
	  if (!strcmp(str, "-x_rate_max")) {
	    if (i == argc) {
	      printf("Unknown rate is empty\n");
	      exit(0);
	    }
	    tail = head = argv[i++];
	    while (*tail) {
	      if (((*tail >= '0') && (*tail <= '9')) || (*tail == '.') || (*tail = 'e') || (*tail == '-')) tail++;
	      else {
	        printf("Unknown unknown rate!\n");
		exit(0);
	      }
	    }
	    x_rate_max = atof(head);
	  }
	  else {
	    printf("Unknown option: %s\n", str);
	    printf(EXPLAIN);
	    exit(0);
	  }
	  break;
	
	default:
	  printf("Unknown option: %s\n", str);
	  printf(EXPLAIN);
	  exit(0);
      }
    }
    else {
      printf("Option is empty for %s\n", argv[i]);
      exit(0);
    }
  }

  comp_array = (char **) calloc(input_no, sizeof(char *));
  comp_tmp = (int *) calloc(input_no + 1, sizeof(int));

  for (i = input_no - 1; i; i--) {
    comp_array[i] = (char *) calloc(j = i, sizeof(char));
    while (j) comp_array[i][--j] = 0;
  }

  str = (char *) calloc(j = input_no << 3, sizeof (char));

  i = 0;
  if (fin) {
    while (fgets(str, j, fin)) {
      tail = head = str;
      i++;
      while (*tail) {
	if (((*tail >= '0') && (*tail <= '9')) || (*tail == ' ') || (*tail == '\t') || (*tail == '-') || (*tail == '\n')) tail++;
	else {
	  printf("Illegal compatible file description in line %d\n", i);
	  exit(0);
	}
      }
      index = 0;
      while (*head) {
	vec = comp_tmp[index++] = atoi(head);
	while ((*head != ' ') && (*head != '\t')) head++;
	while ((*head == ' ') || (*head == '\t') || (*head == '\n')) head++;
      }
      qsort((int *) comp_tmp, index, sizeof(int), comp_absi);
      for (argc = 0; argc < index; argc++) {
	for (mask = argc + 1; mask < index; mask++) {
	  if ((comp_tmp[argc] ^ comp_tmp[mask]) < 0) sign = -1;
	  else sign = 1;
	  comp_array[abs(comp_tmp[argc]) - 1][abs(comp_tmp[mask]) - 1] = sign;
        }
      }
    }
  }

  if (fout == NULL) fout = fopen("bench_gen.vec", "w");

  fprintf(fout, "INPUT_NO\t%d\n", input_no);
  fprintf(fout, "VECTOR_NO\t%d\n", vector_no);
  fprintf(fout, "VECTORS\n");

  i = input_no;
  while (i) {
    i--;
    comp_tmp[i] = i;
  }

  index = vector_no;
  x_no_max = input_no * x_rate_max;
  vector = (char *) calloc(input_no + 1, sizeof(char));
  vector[input_no] = 0;
  while (index) {
    index--;
    i = input_no;
    while (i) {
      sign = rand() % 4;
      mask = (1 << ((rand() % 7) + 4)) - 1;
      vec = (rand() & (mask << sign)) >> sign ;
      while (vec && i) {
	--i;
	if (vec & 1) vector[i] = '1';
	else vector[i] = '0';
	vec >>= 1;
      }
    }
    j = rand() % x_no_max;

    // assign don't care
    mask = input_no;
    while (j) {
      i = rand() % mask;
      vector[comp_tmp[i]] = '-';
      mask--;
      k = comp_tmp[mask];
      comp_tmp[mask] = comp_tmp[i];
      comp_tmp[i] = k;
      j--;
    }
    check_comp(vector);
    fprintf(fout, "%s\n", vector);
  }
}

check_comp(vec)
char *vec;
{
  int i, j, i2, j2, k, x;
  char sign;

  for (k = i = input_no - 1; i; i--) {
    i2 = k - i;
    if (vec[i2] == '-') continue;
    for (j = i; j;) {
      j--;
      j2 = k - j;
      if (vec[j2] == '-') continue;
      if (sign = comp_array[i][j]) {
	switch (vec[i2] ^ vec[j2]) {
	  case 1:
	    if (sign == -1) sign = 0;
	    break;
	  case 0:
	    if (sign == 1) sign = 0;
	    break;
	}
	if (sign) {
	  switch (rand() & 15) {
	    case 15:
	      vec[i2] = '-';
	      break;
	    case 0:
	    case 1:
	    case 2:
	    case 4:
	    case 8:
	      vec[j2] = '-';
	      break;
	    default:
	      vec[j2] ^= 1;
	      break;
	  }
	}
      }
      if (vec[i2] == '-') break;
    }
  }
}

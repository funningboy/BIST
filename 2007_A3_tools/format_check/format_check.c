#include <stdio.h>
#define EXPLAIN "\
  This program is only checking the correctness of your LFSR struct file's format\n\
  The syntax is as follows:\n\
	format_check -vec_file [test set file] -str_file [your LFSR struct file]\n"

typedef struct LINE_Struct {
  char *str;
  int index;
} Line_Struct;


comp_str(a, b)
Line_Struct *a, *b;
{
  int i;
  if (!(i = strcmp((*a).str, (*b).str))) i = (*a).index - (*b).index;
  return(i);
}

comp_int(a, b)
unsigned *a, *b;
{
  return(*b - *a);
}

main(argc, argv)
int argc;
char **argv;
{

  register int input_no;
  int total_size, LFSR_no;
  register unsigned int *Poly, *Poly_size, error, warning, index;
  register char *Seed;
  register int *input_seq;
  register int i, *tmpi;
  int Poly_index, Seed_index;
  unsigned int fsize, line_count;
  char *str, *head, *tail, *next_head, *fname, *Poly_Seed_check;
  Line_Struct *Line, *Poly_Line, *Seed_Line;
  char ch1, ch2, ch_tmp;
  FILE *fin, *fout;


  error = 0;
  if (argc == 1) {
    printf(EXPLAIN);
    exit(0);
  }
  
  fin = fout = NULL;
  for (i = 1; i < argc; i++) {
    if (argv[i][0] == '-')  {
      str = argv[i++];
      if (i == argc) fname = NULL;
      else fname = argv[i];
      switch(str[1]) {
	case 'v':
	  if (!strcmp(str, "-vec_file")) fin = fopen(fname, "r");
	  else {
	    printf("Unknown option: %s\n", str);
	    printf(EXPLAIN);
	    exit(0);
	  }
	  break;
	case 's':
	  if (!strcmp(str, "-str_file")) fout = fopen(fname, "r");
	  else {
	    printf("Unknown option: %s\n", str);
	    printf(EXPLAIN);
	    exit(0);
	  }
	  break;
	case 'h':
	  if (!strcmp(str, "-help")) {
	    printf(EXPLAIN);
	    exit(0);
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

  if (fin == NULL) printf("Test vector file is empty\n");
  else if (fout == NULL) printf("Your LFSR structure file is empty\n");

  if (!((int)fin & (int)fout)) {
    printf(EXPLAIN);
    exit(0);
  }

  fseek(fout, 0, SEEK_END);
  fsize = ftell(fout);
  rewind(fout);

  str = (char *) calloc(fsize + 1, sizeof(char));

  while (fgets(str, 1024, fin)) {
    head = str;
    while ((*head == ' ') || (*head == '\t')) head++;
    if ((*head == 13) || (*head == 10)) continue;
    tail = head + 1;
    while ((*tail != ' ') && (*tail != '\t') && (*tail != 13) && (*tail != 10)) tail++;
    *(tail++) = 0;
    if (!strcmp(head, "INPUT_NO")) {
      input_no = atoi(tail);
      break;
    }
  }
  fclose(fin);

  next_head = head = tail = str;
  line_count = 0;
  while (fgets(tail, fsize, fout)) {
    tail += strlen(tail);
    line_count++;
  }

  Line = (Line_Struct *) calloc(line_count, sizeof(Line_Struct));
  fname = (char *) calloc(16, sizeof(char));

  i = 0;
  Line[0].str = Line[1].str = Line[line_count - 1].str = NULL;
  Poly_index = 2; Seed_index = line_count - 2;
  printf("Checking output format...\n");
  total_size = LFSR_no = 0;
  do {
    i++;
    head = next_head;
    while ((*head == ' ') || (*head == '\t')) head++;
    tail = head + 1;
    
    while ((*tail != 13) && (*tail != 10)) tail++;
    if (*tail == 13) {
      *tail = 0;
      tail += 2;
    }
    else *(tail++) = 0;
    next_head = tail;

    tail = head + 1;
    while ((*tail != ' ') && (*tail != '\t') && (*tail)) tail++;
    ch1 = *tail;
    *tail = 0;

    switch (head[0]) {
      case 'P':
      case 'S':
        if (!(total_size && LFSR_no)) {
          if (!(total_size | LFSR_no)) printf("  Fatal error: Please assign TOTAL_SIZE and LFSR_NO before POLY and SEED delarations!\n");
          else if (!total_size) printf("  Fatal error: Please assign TOTAL_SIZE before POLY and SEED delarations!\n");
	  else if (!LFSR_no) printf(" Fatal error: Please assign LFSR_NO before POLY and SEED delarations!\n");
	  exit(0);
	}

        if (head[0] == 'P') {
	  sprintf(fname, "POLY_");
	  tmpi = &Poly_index;
	  ch2 = 1;
	}
	else {
	  sprintf(fname, "SEED_");
	  tmpi = &Seed_index;
	  ch2 = -1;
	}
	*tail = ch1;
	ch1 = head[5];
	head[5] = 0;
	if (strcmp(fname, head)) {
	  printf("  Error %d: Line %d, unknown keyword %s...\n", ++error, i, head);
	  break;
	}
	else {
	  Line[*tmpi].str = head;
	  head[5] = ch1;
	  tail = head = head + 5;
	  while ((*tail != ' ') && (*tail != '\t') && (*tail)) {
	    if ((*tail > '9') || (*tail < '0')) {
	      fname[4] = 0;
	      while ((*tail != ' ') && (*tail != '\t')) tail++;
	      *tail = 0;
	      printf("  Error %d: Line %d, illegal %s identification %s!\n", ++error, i, fname, head);
	      tail = NULL;
	      break;
	    }
	    tail++;
	  }
	  if (!tail) break;
	  if (*tail == 0) {
	    printf("  Error %d: Line %d, null description for %s\n", ++error, i, Line[*tmpi].str);
	    break;
	  }
	  ch1 = *tail;
	  *tail = 0;
	  index = atoi(head);
	  *tail = ch1;
	  if ((index > LFSR_no) || (index < 1)) {
	    fname[4] = 0;
	    printf("  Error %d: Line %d, %s's index out of range!\n", ++error, i, fname);
	    break;
	  }
	  Line[*tmpi].index = i;
	  *tmpi = *tmpi + ch2;
	}
	break;

      case 'T':
      case 'L':
        if (head[0] == 'T') {
	  sprintf(fname, "TOTAL_SIZE");
	  tmpi = &total_size;
	  index = 0;
	}
	else {
	  sprintf(fname, "LFSR_NO");
	  tmpi = &LFSR_no;
	  index = 1;
	}
	if (strcmp(head, fname))
	  printf("  Error %d: Line %d, unknown keyword %s...\n", ++error, i, head);
	else {
	  *(tail++) = ch1;
	  while ((*tail == ' ') || (*tail == '\t')) tail++;
	  if (*tail == 0) {
	    printf("  Error %d: Line %d, missing assign %s\n", ++error, i, fname);
	    break;
	  }
	  else {
	    if ((*tail <='9') && (*tail >= '0')) {
	      *tmpi = atoi(tail);
	      while ((*tail <='9') && (*tail >= '0')) tail++;
	      while ((*tail == ' ') || (*tail == '\t')) tail++;
	      if (*tail) {
		printf("  Error %d: Line %d, could not understand this description!\n", ++error, i);
		break;
	      }
	    }
	    else {
	      printf("  Error %d: Line %d, could not understand this description!\n", ++error, i);
	      break;
	    }
	  }
	}
	if (Line[index].str) printf("  Error %d: Line %d, duplicate assigning %s\n", ++error, i, fname);
	else {
	  Line[index].str = head;
	  Line[index].index = i;
	}
	break;

      case 'I':
	if (!strcmp(head, "INPUT_SEQ")) {
	  *(tail++) = ch1;
	  Line[line_count - 1].str = head;
	  for (index = total_size; index; index--) {
	    while ((*tail == ' ') || (*tail == '\t')) tail++;
	    while (((*tail >= '0') && (*tail <= '9')) || (*tail == ',') || (*tail == '-')) {
	      if ((*tail == ',') || (*tail == '-')) {
	        tail++;
		while (*tail == ' ') tail++;
	      }
	      else tail++;
	    }
	    if ((*tail != ' ') && (*tail != '\t') && (*tail != 0)) break;
	  }
	  if (index) {
	    printf("  Error %d: Line %d, could not understand this description\n", ++error, i);
	    break;
	  }
	}
	else printf("  Error %d: Line %d, unknown keyword %s...\n", ++error, i, head);
	break;

      default:
        printf("  Error %d: Line %d, unknown keyword %s...\n", ++error, i, head);
	break;
	
    }
    
  } while(i < line_count);

  if (!Line[line_count - 1].str) printf("  Error %d: No INPUT_SEQ assignment!\n", ++error);
/*
  tail += strlen(tail) - 1;
  while ((*tail == 13) || (*tail == 10)) *(tail--) = 0;
*/

  if (error) {
    printf("\nTotal %d error(s)!\n", error);
    exit(0);
  }
  printf("...Format checking succeed!\n");

  printf("Checking LFSR struct!...\n");
  qsort((Line_Struct *) (Poly_Line = Line + 2),  (Poly_index = Seed_index - 1), sizeof(Line_Struct), comp_str);
  qsort((Line_Struct *) (Seed_Line = Line + Seed_index + 1), (fsize = line_count - Seed_index - 2), sizeof(Line_Struct), comp_str);
  Seed_index = fsize;

  warning = 0;
  Poly = (unsigned int *) calloc(total_size, sizeof(unsigned int));
  Poly_Seed_check = (char *) calloc(LFSR_no + 1, sizeof(char));
  Poly_size = (unsigned int *) calloc(input_no + 1, sizeof(unsigned int));
  for (i = LFSR_no; i; i--) {
    Poly_Seed_check[i] = 0;
    Poly_size[i] = 0;
  }

  fsize = 0;
  Poly_Line--;
  Seed_Line--;
  for (i = 1; i <= Poly_index; i++) {
    head = Poly_Line[i].str;
    head[4] = 0;
    if (!strcmp(head, "POLY")) {
      head += 5;
      index = atoi(head);

      if (Poly_Seed_check[index] & 1) printf("  Warning %d: Line %d, POLY_%d line has been assigned previously\n", ++warning, Poly_Line[i].index, index);
      else {
	Poly_Seed_check[fsize = index] |= 1;
	while ((*head != ' ') && (*head != '\t')) head++;
	while ((*head == ' ') || (*head == '\t')) head++;
	index = 0;
	while (*head) {
	  Poly[index++] = atoi(head);
	  while ((*head != ' ') && (*head != '\t') && *head) head++;
	  while ((*head == ' ') || (*head == '\t')) head++;
	}
	qsort((unsigned int *) Poly, index, sizeof(unsigned int), comp_int);
	Poly_size[fsize] = Poly[0];
	if (Poly[index - 1] != 0) {
	  printf("  Warning %d: Line %d, illegal LFSR structure\n", ++warning, Poly_Line[i].index);
	  printf("The last %d bit(s) of this LFSR would be fix or unknown value.\n", Poly[index - 2] - Poly[index - 1]);
	}
	index--;
	while (index) {
	  if (Poly[index] == Poly[index - 1]) printf("  Warning %d: Line %d, duplicated exponent %d\n", ++warning, Poly_Line[i].index, Poly[index]);
          index--;
	}
      }
    }
  }

  for (i = LFSR_no, fsize = 0; i; i--) fsize += Poly_size[i];
  
  for (i = 1; i <= Seed_index; i++) {
    head = Seed_Line[i].str;
    head[4] = 0;
    if (!strcmp(head, "SEED")) {
      head += 5;
      index = atoi(head);

      if (Poly_Seed_check[index] & 2) printf("  Warning %d: Line %d, SEED_%d has been assigned previously\n", ++warning, Seed_Line[i].index, index);
      else {
	Poly_Seed_check[index] |= 2;
	while ((*head != ' ') && (*head != '\t')) head++;
	while ((*head == ' ') || (*head == '\t')) head++;
	if (strlen(head) != Poly_size[index]) printf("  Warning %d: Line %d, unmatch size of seed with its LFSR\n", ++warning, Seed_Line[i].index);
	while (*head) {
	  if ((*head != '0') && (*head != '1')) printf("  Error %d: Line %d, the seed is not a binary code!\n", ++error, Seed_Line[i].index);
	  head++;
	}
      }
    }
  }

  for (i = LFSR_no; i; i--) {
    switch (Poly_Seed_check[i]) {
      case 2:
	printf("  Warning %d: Miss assinging Poly_%d\n", ++warning, i);
	break;
      case 0:
        printf("  Warning %d: Miss assinging Poly_%d\n", ++warning, i);
      case 1:
	printf("  Warning %d: Miss assigning Seed_%d\n", ++warning, i);
	break;
    }
  }
  if (fsize != total_size) printf("  Warning %d: Unmatch TOTAL_SIZE (= %d) and the sum of LFSRs (= %d)!\n", ++warning, total_size, fsize);

  printf("...Checking LFSRs' structure complete!\n");
  printf("Checking INPUT_SEQ...\n");
  for (i = input_no; i; i--) Poly_size[i] = 0;

  head = Line[line_count - 1].str + 9;
  while ((*head == '\t') || (*head == '\t')) head++;

  line_count--;
  while (*head) {
    index = abs(atoi(head));
    if (index > input_no) printf("  Error %d: Illegal input identification: %d\n", ++error, index);
    else if (Poly_size[index]) printf("  Warning %d: Both output %d and %d are connecting to input %d!\n", ++warning, Poly_size[index], total_size, index);
    else if (index) Poly_size[index] = total_size;
    while ((*head != ' ') && (*head != '\t') && (*head != ',') && *head) head++;
    if (*head != ',') {
      while ((*head == ' ') || (*head == '\t')) head++;
      total_size--;
    }
    else {
      if (!index) printf("  Warning %d: Line %d, Confused INPUT_SEQ description: ... 0%s\n", ++warning, line_count, head);
      head++;
    }
  }

  if (total_size) {
    printf("  Warning %d, Line %d, insufficient connection description for output(s):", ++warning, line_count);
    while (total_size) printf(" %d", total_size--);
    printf("\n");
  }
  while (input_no) {
    if (!Poly_size[input_no]) printf("  Warning %d: Floating input %d\n", ++warning, input_no);
    input_no--;
  }
  printf("...INPUT_SEQ checking complete!\n");

  if (error | warning) {
    printf("\n");
    if (error) printf("Total %d error(s)!\n", error);
    if (warning) printf("Total %d warning!\n", warning);
  }
  else printf("\nNo error or warning found!\n");
}
  

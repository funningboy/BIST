
use strict;
use tCAD::BISTtb;
use Data::Dumper;
use Bit::Vector;


sub get_usage {
  print STDOUT '

#=============================================#
# Pattern Generation for Logic BIST 
# author : sean chen
# mail : funningboy@gmail.com
# license: FBS
# publish: 2011/02/20 v1
# project reference : https://docs.google.com/viewer?a=v&pid=sites&srcid=ZGVmYXVsdGRvbWFpbnxmdW5uaW5nYm95fGd4OmI0MTU5NTQzNzU0YzEyYw  
#=============================================#

<USAGE>

-vec           [vector/input file]
-min_partition [partition number]
-min_loop      [loop number]

</USAGE>

ex: perl main.pl -vec test.vec \
                 -min_partition 30 \
                 -min_loop 100 \
';
die "\n";
}

if(!@ARGV){ get_usage(); }

# loop 1
my $min_lv1   = 30;
my $min_lv2   = 1000;
my $cur_lv1   = 0;
my $cur_lv2   = 0;
my $root_path = ();

while(@ARGV){
  $_ = shift @ARGV;

    if( /-vec/           ){ $root_path = shift @ARGV; }
 elsif( /-min_partition/ ){ $min_lv1   = shift @ARGV; }
 elsif( /-min_loop/      ){ $min_lv2   = shift @ARGV; }
 else { get_usage(); }
}

my $bist_ptr = tCAD::BISTtb->new();
   $bist_ptr->run_BIST_table_gen($root_path);
   $bist_ptr->run_BIST_table_opt();
   $bist_ptr->run_BIST_input_sort();

   while($cur_lv1 <= $min_lv1){
   $bist_ptr->run_BIST_input_merge();
   $bist_ptr->run_BIST_input_merge_cut();

   $bist_ptr->run_BIST_input_LFSR_best_assign();
   $bist_ptr->run_BIST_input_LFSR_map();

   $bist_ptr->run_BIST_vector_LFSR_exp();
   $bist_ptr->run_BIST_vector_LFSR_gen();

#loop 2
   while($cur_lv2 <= $min_lv2){ 
   $bist_ptr->run_BIST_vector_test_table_gen();
   $bist_ptr->run_BIST_vector_test_table_map();

   $bist_ptr->run_BIST_vector_cycle_table_gen();
   $bist_ptr->run_BIST_vector_cycle_table_check();

   $bist_ptr->free_lv2();
   $cur_lv2++;
   }

  $cur_lv2 =0;
  $bist_ptr->free_lv1();
  print 'lv1::'.$cur_lv1."\n";
  $cur_lv1++; 
   
 }
   $bist_ptr->run_BIST_vector_cycle_table_report();

#! /usr/bin/perl

package tCAD::BISTtb;
use tCAD::LFSRtb;
use Data::Dumper;
use Bit::Vector;
use POSIX;
use strict;

sub new {
     my $class = shift;
     my $self  = {
                  input_no         => '0',
                  vector_no        => '0',        
                  max_run_test     => '10000',
                  vector_list      => {}, 
                  sort_list        => {},
                  table_list       => {},
                  merge_list       => {},
                  cur_list         => {},
                  cycle_list       => {},
                  result_list      => [],
                  lfsr_list   => { 
                                   max_exp     => '0', 
                                   min_exp     => '3', # x^3 + x^2 + 1
                                   max_div_num => '5',
                                   min_div_num => '1',
                                   max_indx    => '0',
                                   list        => {},
                                 },          
              };
     bless $self, $class;
     return $self;
}

# read table 
sub run_BIST_table_gen {
    my ($self,$path) = (@_);

    open (INPUT,"$path") || die "open $path error\n";
    my $i =0;

    while(<INPUT>){
     chomp;

         if( /INPUT_NO\s+(\w+)/ ){ $self->{input_no}  = $1; }
      elsif( /VECTOR_NO\s+(\w+)/){ $self->{vector_no} = $1; }
      elsif( /VECTORS/ ){}
      else{   
           @{$self->{table_list}->{org_list}->[$i++]} = split('',$_);
          }
    }
    close(INPUT);
}

# find the merge list @ input based
sub run_BIST_table_opt {
    my ($self) = (@_);

    for(my $i=0; $i<$self->{input_no}; $i++){ # lv1
        my ($ia,$jb,$inv_jb);

      for(my $j=$i+1; $j<$self->{input_no}; $j++){ # lv2
          my $pass = 0;
          my $pos  = 0;
          my $neg  = 0;

       if( !defined($self->{merge_list}->{merge}->{$i})     ||
           !defined($self->{merge_list}->{merge}->{'-'.$i}) ){

       for(my $deep =0; $deep<$self->{vector_no}; $deep++ ){
              $ia = $self->{table_list}->{org_list}->[$deep]->[$i];
              $jb = $self->{table_list}->{org_list}->[$deep]->[$j];
              $inv_jb = ( $jb eq '0' )? 1 :
                        ( $jb eq '1' )? 0 : '-';

           if( $jb     eq $ia && $pos==0 ||
               $inv_jb eq $ia && $neg==0 ||
               $jb     eq '-'            ||
               $ia     eq '-'            )
           { 
               $neg = ( $jb     eq $ia && $ia ne '-' )? 1 : $neg;  
               $pos = ( $inv_jb eq $ia && $ia ne '-' )? 1 : $pos; 
               $pass++; 
          }
       }

           if($pass == $self->{vector_no} ){
               my $new_j = ( $pos==0 )? $j : '-'.$j; 
               $self->{merge_list}->{merge}->{$new_j} = $i;
               push (@{$self->{merge_list}->{org_list}->{$i}},$new_j); 
           }       
     }

   } # lv2
  } # /lv1

$self->{merge_list}->{merge} = {};

}

sub run_BIST_input_sort {
    my ($self) = (@_);

    for(my $i=0; $i<$self->{input_no}; $i++){
      for(my $deep =0; $deep<$self->{vector_no}; $deep++ ){
          if( $self->{table_list}->{org_list}->[$deep]->[$i] eq '-' ){ 
              $self->{sort_list}->{org_list}->{$i}++;
           }
       }
    }
}

sub run_BIST_input_merge {
    my ($self) = (@_);

    my $merge_list = $self->{merge_list}->{org_list} || die;
   
    # check merge is ok    
    my @merge_keys = keys %{$merge_list}; 
    my $tmp_select = {};

    for(my $i=0; $i<=$#merge_keys; $i++){
        my $select = int(rand($#merge_keys+1));

        while( defined($tmp_select->{$select}) ){
           $select = int(rand($#merge_keys+1));
        }
        $tmp_select->{$select} =1;

        my $key        = $merge_keys[$select];
        my $value_list = $merge_list->{$key};

        foreach my $value (@{$value_list}){
        
        my $ivalue = $value;
                my $ikey   = $key;
                   $ivalue =~ s/\-//g;
                   $ikey   =~ s/\-//g; 
        if( !defined($self->{merge_list}->{merge}->{$ikey})   &&
            !defined($self->{merge_list}->{merge}->{$ivalue}) ){
                    push (@{$self->{merge_list}->{new_list}->{$key}},$value); 
                     $self->{merge_list}->{merge}->{$ivalue} = 1;
                     $self->{merge_list}->{merge}->{$ikey}   = 1;
        }
      }
   }
$self->{merge_list}->{merge} = {};
}


sub run_BIST_input_merge_cut {
    my ($self) = (@_);

    my $merge_new_list = $self->{merge_list}->{new_list} || die "";
    my $org_sort_list  = $self->{sort_list}->{org_list}  || die "";
 
      %{$self->{sort_list}->{new_list}} = %{$org_sort_list};
    my $tmp_merge_list = {};

    foreach my $merge ( keys %{$merge_new_list} ){
            my @list = @{$merge_new_list->{$merge}};
            push (@list,$merge);

            my $tmp_list = [];

          foreach my $inx (@list){
                  my $inv = ( $inx =~ /\-/ )? 1 : 0;
                     $inx=~ s/\-//g;
                  push (@{$tmp_list}, { inv  => $inv,
                                        port => $inx,
                                        num  => $org_sort_list->{$inx},});
                } 

          my @new_list = sort { $a->{num} <=> $a->{num} } @{$tmp_list};

          my $top_port = $new_list[$#new_list]->{port};

          # remain best
          if( $new_list[$#new_list]->{inv} == 1 ){
              my $port = $new_list[$#new_list]->{port}; 
              my $num  = $self->{sort_list}->{new_list}->{$port};

              delete $self->{sort_list}->{new_list}->{$port};
                     $self->{sort_list}->{new_list}->{'-'.$port} = $num;
                     $top_port = '-'.$port;
          }  
          # cut worst 
          for(my $i=0; $i<$#new_list; $i++){ 
              my $port = $new_list[$i]->{port};
              delete $self->{sort_list}->{new_list}->{$port};
                 $port = ( $new_list[$i]->{inv} == 1 )? '-'.$port : $port;
                    push (@{$tmp_merge_list->{$top_port}},$port);
          }
      }

#update merge_new_list
%{$self->{merge_list}->{new_list}} = %{$tmp_merge_list};
}

# @ set LFSR number 
sub run_BIST_input_LFSR_best_assign {
    my ($self) = (@_);

    my $sort_new_list = $self->{sort_list}->{new_list} || die "";

    my @list = keys %{$sort_new_list};
    $self->{lfsr_list}->{max_exp} = $#list +1;

    my $max_exp     = $self->{lfsr_list}->{max_exp};
    my $min_exp     = $self->{lfsr_list}->{min_exp};
 
                      $self->{lfsr_list}->{list} = {};

    my $offset   = $self->{lfsr_list}->{max_div_num} - $self->{lfsr_list}->{min_div_num};
    if( $offset < 0 ){ die "" }

    my $cur_div_num = int(rand($offset)) + $self->{lfsr_list}->{min_div_num};

    #@ only 1 partition
    if( $cur_div_num == 1 ){
        $self->{lfsr_list}->{list}->{0} = $max_exp;
    }else { 
           my $tot_exp =0;
       while( $tot_exp < $max_exp ){
              $self->{lfsr_list}->{list} = {};
              $tot_exp =0;
          for(my $i=0; $i<$cur_div_num; $i++){
              my $offset  = $max_exp - $min_exp;
              my $tmp_exp = int(rand($offset)) + $min_exp;
                 $tot_exp += $tmp_exp;
                 $self->{lfsr_list}->{list}->{$i} = $tmp_exp;
            }
      }
   }

}

# @ rand assign LFSR input 2 table input
sub run_BIST_input_LFSR_map {
    my ($self) = (@_);

    my $lfsr_list     = $self->{lfsr_list}->{list} || die "";
    my $new_sort_list = $self->{sort_list}->{new_list} || die "";
    my $new_merge_list= $self->{merge_list}->{new_list} || die "";
   
    my @lfsr_keys   = keys %{$lfsr_list};
    my $select_list = {};

    foreach my $key ( keys %{$new_sort_list} ){
            my $pass = -1;
           while( $pass ==-1 ){

            my $lfsr_id   = int(rand($#lfsr_keys+1));
            my $lfsr_num  = $lfsr_list->{$lfsr_id};
            my $lfsr_port = int(rand($lfsr_num)); 
  
            if( !defined($select_list->{$lfsr_id}->{$lfsr_port}) ){
                 push ( @{$self->{assign_list}->{$lfsr_id}} , { input_port => $key,
                                                                lfsr_port  => $lfsr_port, } );

                 if( defined$new_merge_list->{$key} ){
                     foreach my $key2 (@{$new_merge_list->{$key}}){
                     push ( @{$self->{assign_list}->{$lfsr_id}} , { input_port => $key2,
                                                                    lfsr_port  => $lfsr_port, } );
                     }
                 }

                 $select_list->{$lfsr_id}->{$lfsr_port} = 1;
                 $pass =0;
             }
          }
    }
}

sub run_BIST_vector_LFSR_exp {
    my ($self) = (@_);

    my $lfsr_list     = $self->{lfsr_list}->{list} || die "";
   
    foreach my $lfsr (keys %{$lfsr_list}){
      my $exp_num   = $lfsr_list->{$lfsr}-1;
      my $bound_num = POSIX::pow(2,$exp_num); 
      my $inx       = 0;
 
      for(my $i=0; $i<$bound_num; $i++){
          my $vector  = Bit::Vector->new_Dec($exp_num,$i);
          my $bit_str = $vector->to_Bin();
             $bit_str = '1'.$bit_str.'1'; 
   
         $self->{vector_list}->{$lfsr}->{vector}->{$bit_str} = undef;
         $self->{vector_list}->{$lfsr}->{size}->{$bit_str}   = $exp_num;
      }
   }
}

sub run_BIST_vector_LFSR_gen {
    my ($self) = (@_);

    my $vector_list = $self->{vector_list} || die "";

    foreach my $lfsr (keys %{$vector_list}){
            my $inx        = 0;

      foreach my $vector (keys %{$vector_list->{$lfsr}->{vector}}){

         my $LFSR_ptr = tCAD::LFSRtb->new();
            $LFSR_ptr->run_LFSR_vector_decoder($vector);
            $LFSR_ptr->run_LFSR_vector_table_gen();
  
         my $lfsr_table = $LFSR_ptr->get_LFSR_table_list();
         my $uniq_list  = {};
         my $pass       = 0;

            # check unique vector list
            foreach my $indx (@{$lfsr_table}){
                    my $vector = join('',@{$indx});
                    if( defined($uniq_list->{$vector}) ){ $pass=-1; last; }
                       $uniq_list->{$vector} = 1;
            }              

            if($pass==-1){
               delete $self->{vector_list}->{$lfsr}->{vector}->{$vector};
               delete $self->{vector_list}->{$lfsr}->{size}->{$vector};
            } else {
                      $self->{vector_list}->{$lfsr}->{vector}->{$vector} = $lfsr_table;
                      $self->{vector_list}->{$lfsr}->{indx}->{$inx++}    = $vector; 
            } 
            $LFSR_ptr->free();
      }
                      $self->{vector_list}->{$lfsr}->{max} = $inx;
   }
} 


sub run_BIST_vector_test_table_gen {
    my ($self) = (@_);

    my $vector_list = $self->{vector_list} || die "";
    my $tmp_list    = {};

    foreach my $lfsr (keys %{$self->{vector_list}}){
            my $max = $self->{vector_list}->{$lfsr}->{max};
            my $inx = int(rand($max));

            my $vector = $self->{vector_list}->{$lfsr}->{indx}->{$inx};
            my $table  = $self->{vector_list}->{$lfsr}->{vector}->{$vector};
            my $size   = $self->{vector_list}->{$lfsr}->{size}->{$vector};

            $self->{cur_list}->{$lfsr} = { vector => $vector,
                                           table  => $table,
                                           size   => $size,
                                         };

            $tmp_list->{$#$table} = $lfsr;
    }

   # aline the table 
   my @keys_list = sort { $a<=>$b } keys %{$tmp_list};

   for(my $i=0; $i<$#keys_list; $i++){

       my $min_lfsr  = $tmp_list->{$keys_list[$i]};
       my $max_lfsr  = $tmp_list->{$keys_list[$#keys_list]};

       my $min       = $keys_list[$i];
       my $max       = $keys_list[$#keys_list]; 

       my $min_table = $self->{cur_list}->{$min_lfsr}->{table};
       my $inx       = 0;
       my $tmp_table = [];

       for(my $j=$min; $j<$max; $j++){
           my @tt = @{$min_table->[$inx]};
           push (@{$tmp_table},\@tt); 
           $inx = ($inx == $#$min_table)? 0 : $inx+1; 
       }  

      @{$self->{cur_list}->{$min_lfsr}->{table}} = (@{$min_table},@{$tmp_table});  
   }
}

sub run_BIST_vector_test_table_map {
    my ($self) = (@_);

    my $assign_list = $self->{assign_list} || die;    
    my $cur_list    = $self->{cur_list}    || die;

    my $t_input_table = [];
    foreach my $assign (keys %{$assign_list}){
            my $table_list = $cur_list->{$assign}->{table};
            my $indx       = 0;

            foreach my $table (@{$table_list}){
              foreach my $key (@{$assign_list->{$assign}}){
                      my $lfsr_port  = $key->{lfsr_port};
                      my $input_port = $key->{input_port};
                      my $bit        = $table->[$lfsr_port];

                      if( $input_port =~ /\-/ ){
                          $bit = ( $table->[$lfsr_port] eq '0' )? 1 : 0;
                          $input_port =~ s/\-//g;
                       }
                      $t_input_table->[$indx]->[$input_port] = $bit;
               }
              $indx++;   
            } 
    } 
  @{$self->{table_list}->{test_list}} = @{$t_input_table};
}


sub run_BIST_vector_cycle_table_gen {
    my ($self) = (@_);

    my $table_list  = $self->{table_list}->{org_list}  || die;
    my $test_list   = $self->{table_list}->{test_list} || die;

    for(my $table=0; $table<=$#$table_list; $table++){
       for(my $test=0; $test<=$#$test_list; $test++){

           if( $#{$table_list->[$table]} != $#{$test_list->[$test]} ){ last; }
               my $pass =0;
           for(my $i=0; $i<=$#{$table_list->[$table]}; $i++){
                  if( $table_list->[$table]->[$i] eq '-'                       ||
                      $table_list->[$table]->[$i] eq $test_list->[$test]->[$i] ){
                      $pass++;
                  }
           }
           if($pass == $#{$table_list->[$table]}+1){
              push (@{$self->{cycle_list}->{$test}},{ id     => $table,
                                                      vector => join('',@{$test_list->[$test]}),});
           }
       }
    }

} 


sub run_BIST_vector_cycle_table_check {
    my ($self) = (@_);

    my $cycle_list  = $self->{cycle_list}   || die;
    my $assign_list = $self->{assign_list}  || die;
    my $cur_list    = $self->{cur_list}     || die;   
    
    my $hit_list    = {};
    my $hit_time    = 0;
    my $hit_cycle   = 0;
    my @lfsr_list   = keys %{$cur_list};

    foreach my $cycle (sort {$a<=>$b} keys %{$cycle_list}){
        foreach my $list (@{$cycle_list->{$cycle}}){
                if( !defined($hit_list->{$list->{id}}) ){
                     $hit_cycle = $cycle;
                     $hit_time++;
                     my $result = '@cycle'."\t".$cycle."\t".'@hit pattern'."\t".$list->{id}."\t".'@vector'."\t".$list->{vector};
                     push ( @{$hit_list->{result}}, $result); 
                     $hit_list->{$list->{id}} = 1;
                }
        }
    }

   my $size = 0;
   foreach my $assign (keys %{$cur_list}){
           my $table = $cur_list->{$assign}->{table}->[0];
              $cur_list->{$assign}->{table} = [];
              $cur_list->{$assign}->{table}->[0] = $table; 
              $size += $cur_list->{$assign}->{size};
   }
     
   push (@{$self->{result_list}} ,{ hit_cycle   => $hit_cycle,
                                    hit_time    => $hit_time,
                                    size        => $size,
                                    assign_list => $assign_list,
                                    cur_list    => $cur_list,
                                    hit_list    => $hit_list->{result},});
}

sub run_BIST_vector_cycle_table_report {
    my ($self) = (@_);
  
    my $result_list = $self->{result_list} || die;

    my @sort_list = reverse sort { $a->{hit_time}  <=> $b->{hit_time} } @{$result_list};
    for(my $i=1; $i<=$#sort_list; $i++){
        if( $sort_list[$i]->{hit_time} != $sort_list[0]->{hit_time} ){
            delete $sort_list[$i];
        }
    }

    my @sort_list = sort { $a->{hit_cycle} <=> $b->{hit_cycle} } @sort_list;     
    for(my $i=1; $i<=$#sort_list; $i++){
        if( $sort_list[$i]->{hit_cycle} != $sort_list[0]->{hit_cycle} ){
            delete $sort_list[$i];
        }
    }
   
    my @sort_list = sort { $a->{size} <=> $b->{size} } @sort_list;     
    for(my $i=1; $i<=$#sort_list; $i++){
        if( $sort_list[$i]->{size} != $sort_list[0]->{size} ){
            delete $sort_list[$i];
        }
    }
              
   print 'Total_Size '."\t".$sort_list[0]->{size}."\n";

   foreach my $assign (keys %{$sort_list[0]->{cur_list}}){
   print 'POLY_'.$assign.' '."\t".$sort_list[0]->{cur_list}->{$assign}->{vector}."\n";
   print 'SEED_'.$assign.' '."\t".join('',@{$sort_list[0]->{cur_list}->{$assign}->{table}->[0]})."\n";           

   foreach my $port (keys %{$sort_list[0]->{assign_list}}){
     foreach my $list (@{$sort_list[0]->{assign_list}->{$port}}){
   print 'POLY_'.$port.'[p]->INPUT[p] '."\t".$list->{lfsr_port}.'->'.$list->{input_port}."\n";
    }
   }
  }

  print "HIT_CYCLE\n";
  foreach my $hit (@{$sort_list[0]->{hit_list}}){
  print $hit."\n";
  }

  print "HIT_COVERAGE\t".$sort_list[0]->{hit_time}.'/'.$self->{vector_no}."\n";
}


sub free_lv1 {
    my ($self) = (@_);

       $self->{vector_list}            = {};
       $self->{sort_list}->{new_list}  = {};
       $self->{merge_list}->{new_list} = {};
       $self->{lfsr_list}->{list}      = {};
       $self->{assign_list}            = {}; 
       $self->{cur_list}               = {};
       $self->{cycle_list}             = {};
}

sub free_lv2 {
    my ($self) = (@_);

       $self->{cur_list}               = {};
       $self->{cycle_list}             = {};
}

1;

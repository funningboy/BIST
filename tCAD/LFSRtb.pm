#! /usr/bin/perl

package tCAD::LFSRtb;
use Data::Dumper;
use POSIX;
use strict;

sub new {
     my $class = shift;
     my $self  = {
                   decoder_list => [],
                   decoder_deep => '0',
                   default_list => [],
                   vector_list  => [],
                   table_list   => [],
                   remain_list  => [],
               };
     bless $self, $class;
     return $self;
}


sub is_LFSR_0_at_top_vector {
    my ($self) = (@_);
       if( $self->{vector_list}->[0]==0 ){ return 0; }
return -1; 
}

sub get_LFSR_table_list {
    my ($self) = (@_);
return $self->{table_list};
}


#===========================
# $decoder = (1,1,0,1) => 1*x^3 + 1*x^2 + 0*x^1 + 1*x^0 = x^3 + x^2 + x^1
# '^' = power of ex x^3 = x power of 3
#===========================
sub run_LFSR_vector_decoder {
    my ($self,$decoder) = (@_); 

    @{$self->{decoder_list}} = split('',$decoder); 

    if( $#{$self->{decoder_list}} <2 ){  die "" }
        $self->{decoder_deep} = $#{$self->{decoder_list}};

    my $i;
    for($i=0; $i<=$#{$self->{decoder_list}}; $i++){

       push (@{$self->{default_list}},0);
       ( $i == $#{$self->{decoder_list}}-1 )? push (@{$self->{vector_list}},1) : push (@{$self->{vector_list}},0) ;

#       ( $self->{decoder_list}->[$i] == 1 )? $self->{decoder_deep}++ : 0;
    }
}

sub run_LFSR_vector_table_gen {
    my ($self) = (@_);

    my $decoder_list = $self->{decoder_list} || die;
    my $bound_num    = POSIX::pow(2,$self->{decoder_deep})-1; 

    for(my $i=0; $i<$bound_num; $i++){
        $self->{remain_list} = [];
   
        my $div_list = ( $self->is_LFSR_0_at_top_vector() ==0 )? $self->{default_list} : $self->{decoder_list};
        
        for(my $j=0; $j<=$#{$self->{vector_list}}; $j++){
            my $bit = $div_list->[$j] ^ $self->{vector_list}->[$j];
            push (@{$self->{remain_list}},$bit); 
        }
       
            shift @{$self->{remain_list}};          
            push (@{$self->{table_list}}, $self->{remain_list});

            @{$self->{vector_list}} = @{$self->{remain_list}};
            push (@{$self->{vector_list}},0);
   }
}

sub free {
    my ($self) = (@_);
        $self->{decoder_list} = [];
        $self->{default_list} = [];
        $self->{vector_list}  = [];
        $self->{table_list}   = [];
        $self->{remain_list}  = [];

}




1;

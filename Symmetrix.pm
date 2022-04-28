package Symmetrix;
# michael.s.denney@gmail.com
# Rpt provides methods for common needed functions such as:
# Preparing email body with html formating from array of arrays
# Sending email
# Writing CSV file from array of arrays
use common::sense;
use Carp;
use Common;
use Data::Dumper;
use Env;

use vars qw($VERSION);
use subs qw(sym_cmd determine_connect);
$VERSION = '0.01';
##  HISTORY
###################################################################
sub new{
###################################################################
    my ($class_name) = shift;
    my $self = {};
    $self->{sid}=shift||undef;
    $self->{api}  = 'symcli';
    $self->{SYMCLI_CONNECT} = undef;
    $self->{model_family} = undef;
    bless ($self, $class_name) if defined $self;
    $self->{_created} = 1;
    return $self;
}
###################################################################
sub sid{
###################################################################
   my $self = shift;
   if (@_) { $self->{sid} = shift }
   return $self->{sid};
}
###################################################################
sub SYMCLI_CONNECT{
###################################################################
   my $self = shift;
   if (@_) { $self->{SYMCLI_CONNECT} = shift; }
   unless ( $self->{SYMCLI_CONNECT}){
       $self->{SYMCLI_CONNECT}=$self->determine_connect;
   }
   return $self->{SYMCLI_CONNECT};
}
###################################################################
sub verbose{
###################################################################
   my $self = shift;
   if (@_) { $self->{verbose} = shift }
   return $self->{verbose};
}
###################################################################
sub parse_symdev_show{
###################################################################
   my $self   = shift;
   my $stdout = shift;
   my $family = shift;
   return undef unless ($stdout);
   my %dev_info;
   my $meta;
   my $dev_config_add;
   $dev_info{FAMILY}=$family;
   foreach (@$stdout){
      $dev_info{SYMM}=$1 if (/Symmetrix ID\s+:\s+(\S+)/);
      $dev_info{DEV_NAME}=$1 if (/^\s+Device Symmetrix Name\s+:\s+(\S+)/);
      $dev_info{MEGABYTES}=$1 if (/MegaBytes\s+:\s+(\S+)/);
      $dev_info{DEV_STATUS}=$1 if (/Device Status\s+:\s+(\S.+)/);
      $dev_info{DEV_CONFIG}=$1 if (/Device Configuration\s+:\s+(\S.+)/);
      if (($dev_info{DEV_CONFIG}) and (!/:/) and (! $dev_config_add)){
          $dev_info{DEV_CONFIG}.=$1 if (/^\s+(\S.+\))/);
          $dev_config_add=1;
      }
      push @{$dev_info{FA}},$1 if (/^\s+FA\s+(\S+)\s+/);
      $dev_info{MEGABYTES}=$1 if (/MegaBytes\s+:\s+(\S+)/);
      $dev_info{THIN_POOL}=$1 if (/Bound Thin Pool Name\s+:\s+(\S+)/);
      $meta=1 if (/Meta Device Members/);
      if ($meta){
         if (/\s+([a-fA-f0-9]{4})\s+\d+/){
             $dev_info{METAHEAD}=$1 unless($dev_info{METAHEAD});
             push @{$dev_info{META_MEMBERS}},$1; 
         }
      }
      undef $meta if (/}/);
      $dev_info{DEV_WWN}=$1 if (/Device WWN\s+:\s+(\S+)/);
      $dev_info{SRDF_SERIAL}=$1 if (/Remote Symmetrix ID\s+:\s+(\S+)/);
      $dev_info{SRDF_DEV}=$1 if (/Remote Device Symmetrix Name\s+:\s+(\S+)/);
      $dev_info{RDFG}=$1 if (/RDF \(RA\) Group Number\s+:\s+(\S+)/);
      $dev_info{RDF_STATE}=$1 if (/RDF Pair State\s+.+:\s+(\S+)/);

      $dev_info{BCV_DEV}=$1 if (/BCV Device Symmetrix Name\s+:\s+(\S+)/);
      $dev_info{BCV_DEV_STATUS}=$1 if (/BCV Device Status\s+:\s+(\S.+)/);
      $dev_info{BCV_PAIR_STATE}=$1 if (/State of Pair \( STD ====> BCV \)\s+:\s+(\S+)/);
      $dev_info{BCV_STD_GRP}=$1 if (/Standard \(STD\) Device Group Name\s+:\s+(\S+)/);
      $dev_info{BCV_ASC_GRP}=$1 if (/BCV Device Associated Group Name\s+:\s+(\S+)/);
      $dev_info{BCV_CG_GRP}=$1 if (/BCV Device Associated CG Name\s+:\s+(\S+)/);
      $dev_info{SCSI_STATUS}=$1 if (/SCSI-3 Persistent Reserve:\s+(\S+)/);
      
   }
   #print "meta=>$meta\n";
   $dev_info{DEV_CONFIG}=~s/\s+/ /g if $dev_info{DEV_CONFIG};
   $dev_info{DEV_STATUS}=~s/\s+/ /g if $dev_info{DEV_STATUS};
   $dev_info{BCV_DEV_STATUS}=~s/\s+/ /g if $dev_info{BCV_DEV_STATUS};
   return \%dev_info;
}
###################################################################
sub get_access{
###################################################################
   my $self = shift;
   my $dev=shift ;
   return undef unless ($dev);
   my @wwns;
   my $type='symmaskdb';
   $type='symaccess' if ($self->model_family =~ /VMAX/i);
   my $cmd="$type -sid $self->{sid} list assignment -dev $dev";
   my ($stdout,$stderr,$rc)=$self->sym_cmd($cmd);
   if ($rc != 0){
      if ($self->{verbose}){print "symdev ERR->$_\n" foreach (@$stderr);}
      push @wwns,$_ foreach (@$stderr);
   }
   foreach (@$stdout){
      print "$_ \n" if $self->{verbose};
      push @wwns,$1 if (/([a-fA-F0-9]+)\s+FIBRE/);
   }
   return \@wwns;
}
###################################################################
sub show_vmax_view{
###################################################################
   my $self = shift;
   my $view=shift ;
   return undef unless ($view);
   unless ($self->{show_vmax_view}{$view}){
      $self->{show_vmax_view}{$view}=$self->get_vmax_view($view);
   }
   return($self->{show_vmax_view}{$view});
}
###################################################################
sub get_vmax_view{
###################################################################
   my $self = shift;
   my $view=shift ;
   return undef unless ($view);
   my %view;
   my $cmd="symaccess -sid $self->{sid} show view $view";
   my ($stdout,$stderr,$rc)=$self->sym_cmd($cmd);
      if ($rc != 0){
         if ($self->{verbose}){print "symaccess ERR->$_\n" foreach (@$stderr);}
         return undef;
      }
      foreach (@$stdout){
         print "$_ \n" if $self->{verbose};
         $view{VIEW_INIT_GRP}=$1 if (/Initiator Group Name\s+:\s+(\S+)/);
         $view{VIEW_PORT_GRP}=$1 if (/Port Group Name\s+:\s+(\S+)/);
         $view{VIEW_STOR_GRP}=$1 if (/Storage Group Name\s+:\s+(\S+)/);
      }
      return (\%view);
}
###################################################################
sub determine_vmax_view{
###################################################################
   my $self = shift;
   my $group=shift ;
   return undef unless ($group);
   unless ($self->{determine_vmax_view}{$group}){
      $self->{determine_vmax_view}{$group}=$self->get_determine_vmax_view($group);
   }
   return($self->{determine_vmax_view}{$group});
}
###################################################################
sub get_determine_vmax_view{
###################################################################
   my $self = shift;
   my $group=shift ;
   return undef unless ($group);
   my @views;
   my $cmd="symaccess -sid $self->{sid} show $group -type storage";
   my ($stdout,$stderr,$rc)=$self->sym_cmd($cmd);
      if ($rc != 0){
         if ($self->{verbose}){print "symaccess ERR->$_\n" foreach (@$stderr);}
         push @views,$_ foreach (@$stderr);
      }
      my $the_line;
      foreach (@$stdout){
         print "$_ \n" if $self->{verbose};
         if (/^\s+\{/){
            $the_line=1;
            next;
         }
         last if (/^\s+\}/);
         push @views,$1  if ((/^\s+(\S+)/)and ($the_line));
      }#foreach @$stdout
   return \@views;
}
###################################################################
sub vmax_sg_from_dev{
###################################################################
   my $self = shift;
   my $dev = shift;
   return undef unless ($dev);
   my @stor_grp;
   my $cmd="symaccess -sid $self->{sid} list -type storage -dev $dev";
   my ($stdout,$stderr,$rc)=$self->sym_cmd($cmd);
   if ($rc != 0){
      if ($self->{verbose}){print "symaccess ERR->$_\n" foreach (@$stderr);}
      push @stor_grp,$_ foreach (@$stderr);
   }
   my $the_line;
   foreach (@$stdout){
      print "$_ \n" if $self->{verbose};
      if (/^-----------/){
         $the_line=1 ;
         next;
      }
      push @stor_grp,$1  if ((/^(\S+)/)and ($the_line));
   }
   return \@stor_grp;
}
###################################################################
sub dev_info{
###################################################################
   my $self = shift;
   if (@_) {
       #$self->{dev_info} = shift ;
       my $dev=shift ;
       my $cmd="symdev -sid $self->{sid} show $dev";
       my ($stdout,$stderr,$rc)=$self->sym_cmd($cmd);
       if ($rc != 0){
          #print "symdev ERR->$_\n" foreach (@$stderr);
          return undef,$stderr;
       }
       foreach (@$stdout){
          print "$_\n" if $self->{verbose};
       }
       $self->{dev_info}=$self->parse_symdev_show($stdout,$self->model_family);
   }
   return $self->{dev_info};
}
###################################################################
sub determine_connect{
###################################################################
   my $self = shift;
   return undef if $self->{SYMCLI_CONNECT};
   my $bad_sym_file="/apps/srt/etc/bad_sym_cli";
   open FH,"$bad_sym_file";
   my @bad_syms=(<FH>);
   close FH;
   chomp @bad_syms;
   my %bad_syms;
   $bad_syms{lc $_}=1 foreach (@bad_syms);

   #$self->verbose(1);
   #print "determine_connect\n" if $self->{verbose};;
   my $cmd="/usr/local/bin/sym_chooser $self->{sid}";
   #print "$cmd\n";exit;
   my ($stdout,$stderr,$rc)=$self->sym_cmd($cmd);
   if ($rc != 0){
      if ($self->verbose){
          print "sym_chooser ERR->$_\n" foreach (@$stderr);
      }
      return undef;
   }
   reverse (@$stdout);
   foreach (@$stdout){
      $self->{SYMCLI_CONNECT}=$1 if (/SYMCLI_CONNECT=(.+)/);
      $self->{SYMCLI_CONNECT}=$1 if (/^\d+\s+(\S+)/);
      if ($bad_syms{lc $self->{SYMCLI_CONNECT}}){
         print "Bad symm detected ".$self->{SYMCLI_CONNECT}."\n" if $self->verbose;
         undef $self->{SYMCLI_CONNECT};
         next;
      }
      return $self->{SYMCLI_CONNECT} if $self->model_family;
   }
   #print "SYMCLI_CONNECT NOT FOUND\n";
   return undef; #if we got here, means we didnt  
                 #find a good symcli_connect
}
###################################################################
sub model_family{
###################################################################
   my $self = shift;
   if (@_) { $self->{model_family} = shift; }
   unless ($self->{model_family}){
      my $cmd="symcfg -sid $self->{sid} list";
      my ($stdout,$stderr,$rc)=$self->sym_cmd($cmd);
      if ($rc != 0){
         if ($self->verbose){
            print "model_family ERR->$_\n" foreach (@$stderr);
         }
         return undef;
      }
      foreach (@$stdout){
         print "$_\n" if $self->{verbose};
         if (/^\s+\d+\s+Local\s+(\S+)/){
            $self->{model_family}=$1;
            $self->{model_family}='DMX' unless ($self->{model_family}=~/VMAX/i);
            $self->{model_family}='VMAX' if ($self->{model_family}=~/VMAX/i);
            return $self->{model_family};
            
         }#if
      }#foreach
   }#unless
   return $self->{model_family};
}
##########################################################
sub list_logins{
##########################################################
    my $self = shift;
    unless ($self->{list_logins}){
       my $cmd="symmask -sid $self->{sid} list logins";
       #$self->{list_logins}=$self->sym_cmd($cmd);
        my ($stdout,$stderr,$rc)=$self->sym_cmd($cmd);
        if ($rc != 0){
           if ($self->verbose){
              print "list_logins ERR->$_\n" foreach (@$stderr);
           }
           return undef;
        }
        $self->{list_logins}=$stdout;
    }
    return $self->{list_logins};
}
##########################################################
sub sym_cmd{
##########################################################
   my $self=shift;
   my $cmd=shift;
   $cmd="export PATH=$PATH:/usr/symcli/bin;$cmd";
   $cmd="export SYMCLI_CONNECT=$self->{SYMCLI_CONNECT};export PATH=$PATH:/usr/symcli/bin;$cmd" if ($self->{SYMCLI_CONNECT});
   my $err_dir='/var/tmp';
   $err_dir='/dev/shm' if ($^O =~ /linux/i);
   my $err_file="$err_dir/err.$$";
   $cmd.=" 2>$err_file";
   print "INFO sym_cmd->$cmd\n" if $self->{verbose};
   my @stdout=qx($cmd);
   my $rc=$?;
   chomp @stdout;
   my @stderr;
   if (-s $err_file) { #if the error file has messages
      open ERR,"$err_file";
      @stderr=(<ERR>);
      close ERR;
      chomp @stderr;
      @stderr=grep /\S/,@stderr;
      #print "$_\n" foreach (@stderr);
   }
   unlink ($err_file);
   return (\@stdout,\@stderr,$rc);
}
;

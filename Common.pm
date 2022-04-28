package Common;
# michael.s.denney@gmail.com
# Common:: provides methods for common needed functions  
#                 -say() use instead of print
#                 -logit() print status messages of script
#                 -read_config() read a conf file into a hash
#                 -convert_std_date_to_epoch()
#                 -date routines
#                 -prepare directories for logging
#                 -__die__ signal trap
#                 -dos2unix
use strict;
use POSIX;
use Exporter;
use Time::Local;
use File::Basename;
use File::Find;
use File::Copy;
use FindBin;
use Net::DNS;

use vars qw($VERSION @EXPORT @ISA %mon2num %num2mon %wday2num $base_dir $basename $shortname $log_dir $rpt_log $delete_days $rpt_log $log_off);
use subs qw (say logit read_config convert_std_date_to_epoch delete_file delete_old_logs free_drive_letter commify curr_date_time run_cmd get_fqdn);

@ISA = qw(Exporter);
@EXPORT = qw(
say
logit
read_config
convert_std_date_to_epoch
curr_time
curr_date_time
delete_old_logs
load_manage_exclusions
check_exclude
free_drive_letter
commify
dos2unix
run_cmd
get_fqdn
);
$VERSION = '0.39';
#HISTORY
#       0.02 added support for multiple hosts files to get_hosts by reading nas.conf file
#       0.03 basename and base_dir now use FindBin
#       0.05 get_hosts moved to Nas::Connect
#       0.07 added delete_old_logs
#       0.09 Touch ups to first section to determine true script path and script name
#       0.11 Added load_manage_exclusions and check_exclude
#       0.13 read_config now skips any line that does not contain =
#       0.15 This change was aborted=> $log_dir is no longer created auto, 
#       0.17 Added use File::Copy
#       0.21 load_manage_exclusions now ignores the 4th field not having a recognized date(or perm name)
#       0.23 Added free_drive_letter
#       0.25 Added remote node ability to free_drive_letter
#       0.27 Added commify
#       0.29 Added dos2unix
#       0.30 Added curr_date_time 
#       0.31 conversions to linux
#       0.32 Conversion to object orientation for logit
#       0.33 UPdates to read_config
#       0.35 curr_date_time added to Exporter
#       0.37 added run_cmd
#       0.38 get_fqdn
#       0.39 $log_off
$log_off=1;
###################################################################
sub new{
###################################################################
    my ($class_name)=@_;
    my $self = {};
    bless ($self,$class_name) if defined $self;
    #$self->(_created)=1;
    return $self;
}
###################################################################
sub log_name{
   my $self=shift;
   if (@_) {
      $self->{log_name} = shift;
      #$rpt_log=$self->{log_name};
      $Common::rpt_log=$self->{log_name};
   }
   return $self->{log_name};
}
###################################################################
##    Log and program VARS for Nas
###################################################################
our $basename=$FindBin::Script;
our $base_dir=$FindBin::Bin;   ##Get base dir, but this returns Driver letter:format
#say "base_dir=>$base_dir basename => $basename"; 
my ($drive,$path)=split /:/,$base_dir;  ## We need UNC format! So, split drive and path.
#if ($path) {
    #$path=~s/\//\\/g;              #change the path slashes to backslash for windows
    #my @netout=`net use`;          #get the drive letter to UNC mappings
    #my $unc;
    #chomp @netout;
    ##say "basename $basename";
    ##say "basedir $base_dir";
    ##say "drive=>$drive Path=>$path";
    #foreach (@netout) {
	    ##say $_;
         #if ( /^OK\s+$drive:\s+(\S+)(\s.+$|$)/ ) {   #get the UNC from the "net use" output
              #$base_dir=$1;
	      #say "In if base_dir =>$base_dir";
              #$base_dir.=$path;
         #}    
    #}
#}
#say "base_dir =>$base_dir";
#say "basename =>$basename";
our $shortname=$basename;
$shortname=~s/\..*//g; ##remove .pl or any .extension
#$base_dir=~s/\//\\/g;              #change the path slashes to backslash for windows
#our $rpt_log="$base_dir/$shortname.log"; 
###################################################################
##    Trap DIE to print to log also
###################################################################
$SIG{__DIE__} =  \&die_handler;
sub die_handler{
   logit(@_);
   exit 1;
}
###################################################################
sub say {
###################################################################
## Use instead of print to auto add /n
   return 2 unless @_;
   print "@_\n";
}
###################################################################
sub logit{
###################################################################
## Use to print status to running log file throughout the script
   return undef unless (@_);
   my ($lwday,$lmon,$lmday,$lhour,$lmin,$lsec,$lyear,$ltz)= split(/ /,strftime "%a %b %d %H %M %S %Y %Z",localtime());
   #say "$lwday,$lmon,$lmday,$lhour,$lmin,$lsec,$lyear,$ltz"; exit;
   #my $now_string = "$lmon $lmday $lhour:$lmin:$lsec $ltz $lyear";
   my $now_string = "$lhour:$lmin:$lsec";
   say "@_";

   my $rpt_log=$Common::rpt_log if ($Common::rpt_log);
   $rpt_log="$shortname.log" unless ($Common::rpt_log);

   return if ($log_off);
   open (LOGIT,">>$rpt_log") or die "Unable to open $rpt_log $!";
   print LOGIT "$now_string : @_\n";
   close LOGIT;
}
###################################################################
   sub read_config {          # parse file with "var=value" format
###################################################################
     my ($file) = @_;
     my %hash = ();           # left side of = will be key
          open(FH, $file) or die "Common::Connect sub read_config() - Can't open $file: $! ".caller;
          while (<FH>) {
               chomp;
               next if /^\s*$/;# ignore blank lines
               next if /^#/;   # ignore comments
               s/#.*//;        # remove trailing comments
               s/^\s*//;       # remove leading space
               s/\s*$//;       # remove trailing space
               #$hash{$1}=$2 if (/(\S*)\s*=\s*(.*)/);
               if (/(\S*)\s*=\s*(.*)/){
                  my $key=$1;
                  my $val=$2;
                  $val =~ s/'//g;
                  $hash{$key}=$val;
               }
	       #say "Key =>$1 Value=>$hash{$2}";
	       #say "Key=>$1<=END";
	       #say "Value=>$2<=END";
          }
          close FH;
     #while ( (my $k,my $v) = each %hash) { print "$k => $v\n"; }
   return (%hash);              # return this to the caller
   }
###################################################################
sub convert_std_date_to_epoch{
###################################################################
##This sub takes a standard unix style date and returns epoch value
##Example standard date format: Sat May 14 15:10:50 EDT 2011
   #say "My date=>$_[0]";
   my @tmparray=split(/ +/,scalar $_[0]);
   #say "tmparray size=>".scalar @tmparray;
   die "Nas:: sub convert_std_date_to_epoch : Date not standard unix style 5 fields" unless ( scalar @tmparray == 6 );
   my $e_mon=$tmparray[1];
   if (isalpha $e_mon ) {   ##if mon is number already , no need to convert with hash
      $e_mon=$mon2num{$tmparray[1]};
   }
   $e_mon--;
   my $e_day=$tmparray[2];
   my $indate=$tmparray[3];
   my $e_year=$tmparray[5];
   my ($e_hour,$e_min,$e_sec)=split(/:/,$indate);
   my $epoc_time = timelocal($e_sec,$e_min,$e_hour,$e_day,$e_mon,$e_year); 
   #say "Epoch -> $epoc_time";
   return($epoc_time);
}
###################################################################
##   Time /Date stuff
###################################################################
#print strftime qq{
#a: Day of Week    (short, text) %a
#A: Day of Week     (long, text) %A
#b: Monthname      (short, text) %b
#B: Monthname       (long, text) %B
#c: Full datetime (number, long) %c
#d: Day                 (number) %d
#H: Hour (24 hour)      (number) %H
#I: Hour (12 hour)      (number) %I
#j: Day of year         (number) %j
#m: Month               (number) %m
#M: Minutes             (number) %M
#p: am/pm/empty           (text) %p 
#S: Seconds             (number) %S
#U: Week of Year        (number) %U
#w: Day of week         (number) %w
#W: Week of Year        (number) %W
#x: date                (number) %x
#X: time                (number) %X
#y: year         (short, number) %y
#Y: year          (long, number) %Y
#Z: timezone              (text) %Z
#},
#localtime;
###################################################################
sub delete_file{
###################################################################
#This sub is designed to only be called from the File::Find sub which passed
#the days to delete from delete_old_logs sub

    my $curr_epoch=time;
    #say "curr epoch $curr_epoch";
    my $threshold_delete_seconds=$Common::delete_days*24*60*60;
    #say "threshold_seconds = $threshold_delete_seconds";
    my $epoch_threshold=$curr_epoch-$threshold_delete_seconds;
    #say "threshold = $epoch_threshold";
   if (-f $File::Find::name ) {
	   #say "$File::Find::name" if ( (stat($File::Find::name))[9] < $epoch_threshold);
	   unlink "$File::Find::name" if ( (stat($File::Find::name))[9] < $epoch_threshold);
       }
}
###################################################################
sub delete_old_logs{
###################################################################
    $Common::delete_days=shift or die "delete_days required $!";
    my $directory=shift or die "directory reqiured $!";
    logit "Deleting files older then $Common::delete_days from $directory" unless $log_off;
    find(\&delete_file,$directory);
    undef $Common::delete_days;
}
###################################################################
sub curr_time{
###################################################################
    my ($wday,$mon,$mday,$hour,$min,$sec,$year,$t1,$t2,$t3)=split(/ /,strftime "%a %b %d %H %M %S %Y %Z",localtime()); 
    my $tz=$t1.$t2.$t3;
    $tz =~ s/([a-z]|\s)//g;
    return($hour.":".$min.":".$sec.$tz);
}
###################################################################
sub curr_date_time{
###################################################################
    my ($wday,$mon,$mday,$hour,$min,$sec,$year,$t1,$t2,$t3)=split(/ /,strftime "%a %b %d %H %M %S %Y %Z",localtime()); 
    #my $tz=$t1.$t2.$t3;
    #say "$wday,$mon,$mday,$hour,$min,$sec,$year,$t1,$t2,$t3";
    #$tz =~ s/([a-z]|\s)//g;
    #say "inside curr_date_time";
    return("$wday $mon $mday $hour".":".$min.":"."$sec $t1 $year");
}
###################################################################
#my ($wday,$mon,$mday,$hour,$min,$sec,$year,$t1,$t2,$t3)=split(/ /,strftime "%a %b %d %H %M %S %Y %Z",localtime()); 
#my $tz=$t1.$t2.$t3;
#$tz =~ s/([a-z]|\s)//g;
#print ($wday,$mon,$mday,$hour,$min,$sec,$year,$tz);
### %mon2num needed for Epoc conversion
our %mon2num = qw(
   Jan 1  Feb 2  Mar 3  Apr 4  May 5  Jun 6
   Jul 7  Aug 8  Sep 9  Oct 10 Nov 11 Dec 12
);
our %num2mon = qw(
   1 Jan 2 Feb 3 Mar 4 Apr 5 May 6 Jun 
   7 Jul 8 Aug 9 Sep 10 Oct 11 Nov 12 Dec 
);
our %wday2num = qw(Sun 0  Mon 1  Tue 2  Wed 3  Thu 4  Fri 5 Sat 6);
#Given a time $etime in all seconds, below converts to $hours:$minutes:$secounds
#my $seconds=(($etime%3600)%60);
#my $minutes=((($etime-$seconds)%3600)/60);
#my $hours=(($etime-$seconds-($minutes*60))/3600);
#print ($hours:$inutes:$seconds);
###############################################################################
sub check_exclude{
###############################################################################
##example exlusion date: 2011/5/2
##Return 0 if no exclusions
   my $host_check=shift;
   my $fs_check=shift;
   my @exclusions=@{$_[0]} or die "exclusions array of array required $!";
   #say "Host check -> $host_check FS check -> $fs_check";
   foreach my $aref (@exclusions){
	   #say "EXL_HOST -> @$aref[0] EXL_FS -> @$aref[1]";
      if (((lc $host_check eq lc @$aref[0])||(@$aref[0] eq "")) &&
            ((lc $fs_check eq lc @$aref[1])||(@$aref[1] eq ""))) {
	    #say "EXCLUDE $host_check $fs_check ";
         return(@$aref[2],@$aref[3]);
      }
   }
}
###################################################################
sub load_manage_exclusions{
###################################################################
	##This sub takes a file name as input and returns an array of arrays
	##
	##This sub will load exclusions from a file.
	##The file being loaded should have lines with 4 fields, each field seperated by comma
	##The 4 fields will be: Celerra,FS/datamover,Reason,Exclusion Expiration
	##The sub will return an array to be used, later in the main script to determine if items
	##should be excluded from a report.
	##This sub will remove expired lines from the input file
    my $repl_rpt_exclusion=shift or die "file name required $!";
    my @exclusions; #array of arrays that gets returned to the caller

    my $curr_epoch=time;
    my $expire_flag;
    my @newfile;
    open(EXCLUDES,$repl_rpt_exclusion) or die "Can't open $repl_rpt_exclusion $! \n";
    while( <EXCLUDES> ) { 
       if (/#.*/) {push @newfile,$_;next;}    # write comments to new file, not to array
       if (/^(\s)*$/) {push @newfile,$_;next;}  # write blank lines to new file, not to array
       my @inline=split /,/; #Split normal lines from file delimited by ,
       chomp @inline;
       my ($E_year,$E_mon,$E_day)=split("/",$inline[3]) if $inline[3]; #pull out and split 4th field, should be expiration date
       #say "E_year = $E_year" if $E_year;
       if ((lc $E_year eq "perm") || (! $inline[3])) {
	   $E_year=2037;
	   $E_mon=12;
	   $E_day=30;
       }
       if ($E_year =~ /\D+/) {
	   #say "Text detected -> $E_year";
	   push (@newfile,$_); #The 4th field text of the exclusion rule is not recognized, 
	                       #suppose to be "perm" or a date in format yyyy/mm/dd
			       #since we don't recognize it, we add it to @newfile
			       #so the line does not get erased and we do not
			       #add this rule to be excluded
            next;
       }
       my $testdate="ANY $E_mon $E_day 1:00:00 EDT $E_year";
       #say "sending to convert_std_data_to_epoch => ANY $E_mon $E_day 1:00:00 EDT $E_year";
       my $curr_rule_epoch=convert_std_date_to_epoch($testdate);
       #print "RULE Epoch -> $curr_rule_epoch\n";
       if ($curr_epoch > $curr_rule_epoch) {#this line removes expirations if true
          $expire_flag=1;
       } else { push (@newfile,$_);}
       push @exclusions,[@inline];   #@exclusions will be used later in script to test Celerra/Hostnames for excl
    }
    #print (@newfile);
    close EXCLUDES;
    if ($expire_flag) {
       logit "Expired exclusion rule, creating new exclusion file" unless $log_off;
       copy("$base_dir\\previous_repl_rpt_exclusion.txt",$log_dir) or say "$base_dir\\previous_repl_rpt_exclusion.txt File cannot be copied.";
       copy($repl_rpt_exclusion,"$base_dir\\previous_repl_rpt_exclusion.txt") or die "File cannot be copied.";
       open(EXCLUDES,">$repl_rpt_exclusion");
       print EXCLUDES (@newfile);
       close EXCLUDES;
     }

=cut
     foreach my $aref (@exclusions) {  
       print "REASON -> @$aref[2]\n";
       foreach (@$aref) {
          print "$_ ";
       }
       print "\n";
    }
=cut
    return(\@exclusions);
} #end load_manage_exclusions
###################################################################
sub commify {
###################################################################
   my $input = shift;
   $input = reverse $input;
   $input =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   return reverse $input;
}
###################################################################
sub free_drive_letter{
###################################################################
## This sub determines a free Windows drive letter that can be used for mounting
## If node,user,pass are passed to this sub, the drive letter will be determined 
#  on remote node specified.
	my $node=shift;
	my $user=shift;
	my $pass=shift;
	my $start_letter='C';
	my %mounted_drives;
	my $cmd='wmic logicaldisk get deviceid';
	if ($pass) {
	   $cmd="wmic /user:$user /password:$pass /node:$node logicaldisk get deviceid";
        }
	say $cmd;
	my @stdout=qx/$cmd/;
	shift @stdout;
	foreach (@stdout) {
	      print $_;
	      $_=~s/\W//g; ##remove all the non-white space including : from mounted drive letters
	      say "cooked=>$_";
	      $mounted_drives{$_}='null' if (/^[A-Z]$/);
        }
	print "mounted_drives hash="; print "$_ " foreach (keys %mounted_drives);print "END\n";
	return 0 unless (%mounted_drives);
	foreach ($start_letter .. 'Z'){
		return "$_:" unless $mounted_drives{$_};
        }
	return 0; #return false if unable to find free drive letter
}
###################################################################
sub dos2unix{
###################################################################
#This sub preps a text file for use on Unix/Linux when the file was produced on Windows.
#This script will take all carriage return-line feed combinations and replace with just line feed
    my $text_file=shift  or die "dos2unix : file name required for text_file";
    my $write_file=$text_file.'dos2unix';
    open (TF,"<$text_file") or die "dos2unix : Unable to open $text_file";
    open (WTF,">$write_file") or die "dos2unix : Unable to open $write_file";
    #my @text_file=<TF>;
    while (<TF>) {
	s/\r\n$/\n/g ;
        print WTF $_;
    }
    close TF;
    close WTF;
    move($write_file,$text_file);
    return 0;
}
##########################################################
sub run_cmd{
##########################################################
   my $cmd=" @_";
   my $err_file="/dev/shm/err.$$";
   $cmd.=" 2>$err_file";
   logit "INFO run_cmd->$cmd" unless $log_off;
   my @stdout=qx($cmd);
   my $rc=$?;
   chomp @stdout;
   my @stderr;
   if (-s $err_file) { #if the error file has messages
      open ERR,"$err_file";
      @stderr=(<ERR>);
      close ERR;
      chomp @stderr;
      #print "$_\n" foreach (@stderr);
   }
   unlink ($err_file);
   return (\@stdout,\@stderr,$rc);
}
###################################################################
sub get_fqdn{
###################################################################
   my $search_host=shift or return undef;
   my $res   = Net::DNS::Resolver->new;
   my $query = $res->search($search_host);
   my $result;
   if ($query) {
      foreach my $rr ($query->answer) {
          #say $_;
          next unless $rr->type eq "A";
          $result.=$rr->name;
      }
  } else {
      warn "fqdn query failed: ", $res->errorstring, "\n";
      return $res->errorstring;
  }
  return $result;
}
1;

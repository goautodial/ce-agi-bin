#!/usr/bin/perl


$filter_stats = 1;
$script = 'festival-tts.pl';

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year = ($year + 1900);
$mon++;
if ($mon < 10) {$mon = "0$mon";}
if ($mday < 10) {$mday = "0$mday";}
if ($hour < 10) {$hour = "0$hour";}
if ($min < 10) {$min = "0$min";}
if ($sec < 10) {$sec = "0$sec";}

$now_date_epoch = time();
$now_date = "$year-$mon-$mday $hour:$min:$sec";
$SQLdate = "$year-$mon-$mday $hour:$min:$sec";

# default path to astguiclient configuration file:
$PATHconf =		'/etc/astguiclient.conf';

open(conf, "$PATHconf") || die "can't open $PATHconf: $!\n";
@conf = <conf>;
close(conf);
$i=0;
foreach(@conf)
	{
	$line = $conf[$i];
	$line =~ s/ |>|\n|\r|\t|\#.*|;.*//gi;
	if ( ($line =~ /^PATHhome/) && ($CLIhome < 1) )
		{$PATHhome = $line;   $PATHhome =~ s/.*=//gi;}
	if ( ($line =~ /^PATHlogs/) && ($CLIlogs < 1) )
		{$PATHlogs = $line;   $PATHlogs =~ s/.*=//gi;}
	if ( ($line =~ /^PATHagi/) && ($CLIagi < 1) )
		{$PATHagi = $line;   $PATHagi =~ s/.*=//gi;}
	if ( ($line =~ /^PATHweb/) && ($CLIweb < 1) )
		{$PATHweb = $line;   $PATHweb =~ s/.*=//gi;}
	if ( ($line =~ /^PATHsounds/) && ($CLIsounds < 1) )
		{$PATHsounds = $line;   $PATHsounds =~ s/.*=//gi;}
	if ( ($line =~ /^PATHmonitor/) && ($CLImonitor < 1) )
		{$PATHmonitor = $line;   $PATHmonitor =~ s/.*=//gi;}
	if ( ($line =~ /^VARserver_ip/) && ($CLIserver_ip < 1) )
		{$VARserver_ip = $line;   $VARserver_ip =~ s/.*=//gi;}
	if ( ($line =~ /^VARDB_server/) && ($CLIDB_server < 1) )
		{$VARDB_server = $line;   $VARDB_server =~ s/.*=//gi;}
	if ( ($line =~ /^VARDB_database/) && ($CLIDB_database < 1) )
		{$VARDB_database = $line;   $VARDB_database =~ s/.*=//gi;}
	if ( ($line =~ /^VARDB_user/) && ($CLIDB_user < 1) )
		{$VARDB_user = $line;   $VARDB_user =~ s/.*=//gi;}
	if ( ($line =~ /^VARDB_pass/) && ($CLIDB_pass < 1) )
		{$VARDB_pass = $line;   $VARDB_pass =~ s/.*=//gi;}
	if ( ($line =~ /^VARDB_port/) && ($CLIDB_port < 1) )
		{$VARDB_port = $line;   $VARDB_port =~ s/.*=//gi;}
	$i++;
	}

if (!$VARDB_port) {$VARDB_port='3306';}
if (!$AGILOGfile) {$AGILOGfile = "$PATHlogs/agiout.$year-$mon-$mday";}

use DBI;
use Asterisk::AGI;
use File::Basename;
use Digest::MD5 qw(md5_hex);

$AGI = new Asterisk::AGI;


$dbhA = DBI->connect("DBI:mysql:$VARDB_database:$VARDB_server:$VARDB_port", "$VARDB_user", "$VARDB_pass")
    or die "Couldn't connect to database: " . DBI->errstr;

### Grab Server values from the database
$stmtA = "SELECT agi_output FROM servers where server_ip = '$VARserver_ip';";
$sthA = $dbhA->prepare($stmtA) or die "preparing: ",$dbhA->errstr;
$sthA->execute or die "executing: $stmtA ", $dbhA->errstr;
$sthArows=$sthA->rows;
$rec_count=0;
while ($sthArows > $rec_count)
	{
	$AGILOG = '0';
	 @aryA = $sthA->fetchrow_array;
		$DBagi_output =			"$aryA[0]";
		if ($DBagi_output =~ /STDERR/)	{$AGILOG = '1';}
		if ($DBagi_output =~ /FILE/)	{$AGILOG = '2';}
		if ($DBagi_output =~ /BOTH/)	{$AGILOG = '3';}
	 $rec_count++;
	}
$sthA->finish();


### begin parsing run-time options ###
if (length($ARGV[0])>1)
{
	if ($AGILOG) {$agi_string = "Perl Environment Dump:";   &agi_output;}
	$i=0;
	while ($#ARGV >= $i)
	{
	$args = "$args $ARGV[$i]";
	if ($AGILOG) {$agi_string = "$i|$ARGV[$i]";   &agi_output;}
	$i++;
	}

	if ($args =~ /--help/i)
	{
	print "allowed run time options:\n  [-q] = quiet\n  [-t] = test\n  [-debug] = verbose debug messages\n\n";
	}
	else
	{
		if ($args =~ /-V/i)
		{
		$V=1;
		}
		if ($args =~ /-debug/i)
		{
		$DG=1;
		}
		if ($args =~ /-dbAVS/i)
		{
		$DGA=1;
		}
		if ($args =~ /-q/i)
		{
		$q=1;
		$Q=1;
		}
		if ($args =~ /-t/i)
		{
		$TEST=1;
		$T=1;
		}
	}
}


$|=1;
while(<STDIN>) 
{
	chomp;
	last unless length($_);
	if ($AGILOG)
	{
		if (/^agi_(\w+)\:\s+(.*)$/)
		{
			$AGI{$1} = $2;
		}
	}

	if (/^agi_uniqueid\:\s+(.*)$/)		{$unique_id = $1; $uniqueid = $unique_id;}
	if (/^agi_priority\:\s+(.*)$/)		{$priority = $1;}
	if (/^agi_channel\:\s+(.*)$/)		{$channel = $1;}
	if (/^agi_extension\:\s+(.*)$/)		{$extension = $1;}
	if (/^agi_type\:\s+(.*)$/)		{$type = $1;}
	if (/^agi_callerid\:\s+(.*)$/)		{$callerid = $1;   $calleridnum = $callerid;}
	if (/^agi_calleridname\:\s+(.*)$/)	{$calleridname = $1;}
}

if ( (length($callerid)>20) && ($callerid =~ /\"\S\S\S\S\S\S\S\S\S\S\S\S\S\S\S\S\S\S/) )
  {
   $callerid =~ s/^\"//gi;
   $callerid =~ s/\".*$//gi;
  }
if ( (
(length($calleridname)>5) && ( (!$callerid) or ($callerid =~ /unknown|private|00000000/i) or ($callerid =~ /5551212/) )
) or ( (length($calleridname)>17) && ($calleridname =~ /\d\d\d\d\d\d\d\d\d\d\d\d\d\d\d\d\d\d\d/) ) )
  {
   $callerid = $calleridname;
  }


if ($AGILOG) {$agi_string = "AGI Environment Dump:";   &agi_output;}

foreach $i (sort keys %AGI) 
{
	if ($AGILOG) {$agi_string = " -- $i = $AGI{$i}";   &agi_output;}
}

if ($AGILOG) {$agi_string = "AGI Variables: |$unique_id|$channel|$extension|$type|$callerid|BUS: $business_hours|";   &agi_output;}

$callerid =~ s/\"//gi;


if ($filter_stats > 0)
	{
	### find out if phone number exists in the vicidial_list table
	$stmtA = "SELECT first_name,last_name,phone_number FROM vicidial_list where phone_number = '$callerid';";
	$sthA = $dbhA->prepare($stmtA) or die "preparing: ",$dbhA->errstr;
	$sthA->execute or die "executing: $stmtA ", $dbhA->errstr;
	$sthArows=$sthA->rows;
	if ($sthArows > 0)
		{
		@aryA = $sthA->fetchrow_array;
		$fname =	"$aryA[0]";
		$lname =	"$aryA[1]";
		$phone = 	"$aryA[2]";

		}
	$sthA->finish();



if ($fname == ''){$fname = 'firstname';}
if ($lname == ''){$lname = 'lastname';}
if ($phone == ''){$phone = 'phone';}

my %input = $AGI->ReadParse();
#my ($text)=@ARGV;

my ($text)=($phone);
my $hash = md5_hex($text);
my $sounddir = "/var/lib/asterisk/sounds/tts";
my $wavefile = "$sounddir/"."tts-$hash.wav";
my $t2wp= "/usr/bin/";

unless (-f $wavefile) {
open(fileOUT, ">$sounddir"."/say-text-$hash.txt");
print fileOUT "$text";
close(fileOUT);
my $execf=$t2wp."text2wave -F 8000 -o $wavefile $sounddir/say-text-$hash.txt > /dev/null";
system($execf);
unlink($sounddir."/say-text-$hash.txt");
}
$AGI->stream_file('tts/'.basename($wavefile,".wav"));

unlink($wavefile);

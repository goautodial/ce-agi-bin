#!/usr/bin/perl

# default path to astguiclient configuration file:
$PATHconf =             '/etc/astguiclient.conf';

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


use DBI;
use Asterisk::AGI;
use File::Basename;
use Digest::MD5 qw(md5_hex);

$AGI = new Asterisk::AGI;

#my %input = $AGI->ReadParse();

### begin parsing run-time options ###


        $callerid = $ARGV[0];
        $callerid =~ s/['\$','\#','\@','\~','\!','\&','\*','\(','\)','\[','\]','\;','\.','\,','\:','\?','\^',' ', '\`','\\','\/']/ /g;
	#$callerid =~ s/.{10}\K.*//s; 
	
substr($callerid, 11) = "";
	$calleridname = $ARGV[1];
       $calleridnum = $ARGV[2];

$dbhA = DBI->connect("DBI:mysql:$VARDB_database:$VARDB_server:$VARDB_port", "$VARDB_user", "$VARDB_pass")
    or die "Couldn't connect to database: " . DBI->errstr;

### find out if phone number exists in the vicidial_list table
	$stmtA = "SELECT first_name,last_name,phone_number FROM vicidial_list where phone_number = $callerid;";
	$sthA = $dbhA->prepare($stmtA) or die "preparing: ",$dbhA->errstr;
	$sthA->execute or die "executing: $stmtA ", $dbhA->errstr;
	$sthArows=$sthA->rows;
	if ($sthArows > 0)
		{
		@aryA = $sthA->fetchrow_array;
		$firstname   = "$aryA[0]";
		$lastname   = "$aryA[1]";
		$phonenumber = "$aryA[2]";
		}
	$sthA->finish();

	
	$stmtA = "SELECT tts_text FROM vicidial_tts_prompts where tts_id='FestivalTTS';";
	$sthA = $dbhA->prepare($stmtA) or die "preparing: ",$dbhA->errstr;
	$sthA->execute or die "executing: $stmtA ", $dbhA->errstr;
	$sthArows=$sthA->rows;
	if ($sthArows > 0)
		{
		@aryA = $sthA->fetchrow_array;
		$TTS_text =	$aryA[0];
		### BEGIN replace variables with record values 
		$TTS_text =~ s/--A--first_name--B--/$firstname/gi;
		$TTS_text =~ s/--A--last_name--B--/$lastname/gi;
		$TTS_text =~ s/--A--phone_number--B--/$phonenumber/gi;	
		}
	$sthA->finish();
	$dbhA->disconnect();
	
	
#my %input = $AGI->ReadParse();
#my ($text)=@ARGV;


#$callerid='99999999';


$TTS_text =~ s/[^,\.\<\>\'\/\=\_\-\: 0-9a-zA-Z]//gi;




#print STDERR $TTS_text;

my $message = $TTS_text;


my %input = $AGI->ReadParse();


my $hash = md5_hex($message);
my $sounddir = "/var/lib/asterisk/sounds";
my $wavefile = "$sounddir/"."tts-$hash.wav";
my $t2wp= "/usr/bin/";

unless (-f $wavefile) {
open(fileOUT, ">$sounddir"."/say-text-$hash.txt");
print fileOUT "$message";
close(fileOUT);
my $execf=$t2wp."text2wave -F 8000 -o $wavefile $sounddir/say-text-$hash.txt > /dev/null";
system($execf);
unlink($sounddir."/say-text-$hash.txt");
}
$AGI->stream_file(basename($wavefile,".wav"));

unlink($wavefile);



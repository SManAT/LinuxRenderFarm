#!/usr/bin/env perl
#RenderFarm for Blender
use Getopt::Long;
use Net::Ping;
use File::Basename;

use warnings;
use diagnostics;
#Test pod2text Filename, podchecker Filename
use Pod::Usage;
#ceil und floor
use POSIX;
use Config::IniFiles;
#absoluter Pfad des Scripts
use Cwd qw(abs_path);


#Config File
tie my %ini, 'Config::IniFiles', (-file => "./config.ini");
my %Config = %{$ini{"RenderFarm"}};
my $clientPath=$Config{CLIENT_PATH};
my $renderDir=$Config{RENDER_PATH};
my $scpBack=$Config{SCPFILE};
#Path at my local Host
my $collect=$Config{COLLECT_PATH};
my $user=$Config{USER};
my $passwd=$Config{PASSWD};
chomp($hostname = `hostname -s`);

# setup my defaults
my $start = 0;
my $stop = 0;
my $file = '';
my $chunks=$Config{DEFAULT_CHUNKS};
my $cfg = 'hosts.cfg';
my $tempfile='screen_tmp';

my $logDir='log';
my $tmpDir=$Config{TMP_PATH};
my $log_file="$clientPath"."$logDir/blender_log";
my $filename = basename(__FILE__);
my $abspath = dirname(abs_path(__FILE__));


GetOptions(
    'file|f=s'=> \$file,
    'start|s=i'=> \$start,
    'stop|e=i'=> \$stop,
    'chunks|c=i'=>\$chunks,
    'help|?'  => \$help,
);
pod2usage(1) if $help;

my $frame_index=$start;


# Main Programm --------------------------------------
#legt die Befehle für den Screen Befehl an
sub create_WorkCmds{
  #aktuelle Chunk Anzahl
  my $chunks=shift;
  my $end_frame = $frame_index+$chunks;

  #mit type Casting
  if(($end_frame+0) > ($stop+0)){ 
    $end_frame = $stop;
    $frame_index=$end_frame;
  }
  open(my $fh,">$tmpDir"."$tempfile");
  my $movie_file="movie_";

  #Set up the command to run 
  print $fh "command=\"blender -b $clientPath"."$file -x 1 -o $clientPath"."$renderDir"."$movie_file -F MOVIE -s $frame_index -e $end_frame -a\""."\n";

  #Start logging and prepare for time calculations
  print $fh "echo \"Blend Log For $file ($log_file)\" >> $log_file"."\n";
  print $fh "f_start_date=\"\$(date)\""."\n";
  print $fh "start_date=\"\$(date +%s)\""."\n";
  print $fh "echo \"Blend Source File: $file\" >> $log_file"."\n";
  print $fh "echo \"Blend Render (Dest) File: $clientPath"."$renderDir"."$movie_file\" >> $log_file"."\n";
  print $fh "echo \"Command: \$command\" >> $log_file"."\n";
  print $fh "echo \"Started:  \$f_start_date\" >> $log_file"."\n";

  #Start Rendering nur wenn es was zum Rendern gibt
  if(($frame_index+0) < ($end_frame+0)){ 
    print $fh "\$command"."\n";
  }

  #Index weiterschalten
  $frame_index=$end_frame+1;


  print $fh "f_end_date=\"\$(date)\""."\n";
  print $fh "end_date=\"\$(date +%s)\""."\n";
  print $fh "echo \"Finished: \$f_end_date\" >> $log_file"."\n";

  #Calculate the render time for log/display
  print $fh "difference=\$((\$end_date - \$start_date))"."\n";
  print $fh "hours=\$((\$difference / 3600))"."\n";
  print $fh "difference=\$((\$difference % 3600))"."\n";
  print $fh "minutes=\$((\$difference / 60))"."\n";
  print $fh "seconds=\$((\$difference % 60))"."\n";
  print $fh "render_time=\"\$hours hours, \$minutes minutes, \$seconds seconds.\""."\n";
  print $fh "echo \"Total Render Time: \$render_time\" >> $log_file"."\n";

  #Print log file to screen
  print $fh "cat $log_file"."\n";
  #print $fh "EOF";

  close $fh;
}

#Expect File zum zurückkopieren
sub create_scpBack{
  open(my $fh,">$tmpDir"."$scpBack");
  print $fh "#!/usr/bin/expect"."\n";
  print $fh "spawn scp  -r $clientPath"."$renderDir $user\@$hostname:$abspath/"."$collect"."\n";

  print $fh "set pass \"$passwd\""."\n";

  print $fh "expect {"."\n";
  print $fh "  password: {"."\n";
  print $fh "    send \"\$pass\\r\";"."\n";
  print $fh "    exp_continue;"."\n";
  print $fh "  }"."\n";
  print $fh "}"."\n";

  close $fh;
}


create_scpBack();

#gibt es die Datei?
if (! -e $cfg){
  print "Datei $cfg nicht gefunden!\nexit\n";
  exit (0);
}

open(DAT,"<$cfg") || die "File not found!\n";
while(<DAT>)
{
  #letztes Zeichen = Leerzeichen entfernen
  chomp($_);
  #falsche Zeilen, meist Leerzeilen ignorieren
  if(length($_)>2){ push(@hosts,$_); }
}
close(DAT);


#gibt es die Datei?
if (! -e $file){
  print "Datei $file nicht gefunden!\nexit\n";
  exit (0);
}

#Chunks berechnen, also Frames pro Client
my $array_size=@hosts;
my $frame_range=$stop-$start+1;
if($frame_range/$array_size<$chunks){
  $chunks=ceil($frame_range/$array_size);
}

for (@hosts)
{
  print("\n\n".$_."----------------------------------\n");
  print("Check for Software\n");
  $cmdline="apt-get install -y blender screen expect";
  $cmd = "ssh root@".$_." \"$cmdline\"";
  system($cmd);

  #Alte Daten löschen
  print("Lösche alte Daten\n");
  $cmdline="rm -r $clientPath";
  $cmd = "ssh root@".$_." \"$cmdline\"";
  system($cmd);

  #kopiere auf die Hosts
  print("Kopiere neue Daten\n");

  $cmd="scp -r . root@".$_.":$clientPath";
  system($cmd);
  #Befehle an Screen erstellen
  create_WorkCmds($chunks);
  #Kopieren
  $cmd="scp $tmpDir"."$tempfile root@".$_.":$clientPath"."$tmpDir";
#print($cmd."\n");
  system($cmd);

  print("Starte Rendering in Screen Session\n");
  #Befehle am Client ausführen
  #Verzeichnisstruktur anlegen
  #Screen starten und Befehle senden
  #Datei an screen senden   
  # screen -d -m start in detached mode
  # screen -R verwende zuletzt angelegte Session

  $cmdline="cd $clientPath;mkdir -p $renderDir;mkdir -p $logDir;touch $log_file;screen -d -m -S blender;screen -S blender -R -X readbuf $clientPath"."$tmpDir"."$tempfile;screen -R -S blender -X paste .";
  $cmd = "ssh root@".$_." \"$cmdline\"";
print($cmdline."\n");
  system($cmd);
  system("sleep 1");
}


__END__

#Achtung auf Syntax; erste Spalte, nach head Leerzeile, unformatiert mit 1 Space
 am Zeilenebginn
=encoding utf-8

=head1 NAME

$filename -t edv2 -start 1 -stop 100 -file Wald.blend

=head1 SYNOPSIS

 Render in einem Raum das Blender File, und teilt die Frames auf die Clients auf
 Alle Daten liegen im Ordner ./data.
 Alle Hostnamen der PC in der Datei hosts.cfg


 Optionen:
   --start, -s .... Start Frame
   --stop, -e  .... Stop Frame
   --file, -f  .... Blender File
   --chunks, -c .... Wie viele Frames maximal pro Client


=head1 DESCRIPTION

  RenderFarm

=cut

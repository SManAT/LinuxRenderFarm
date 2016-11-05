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
my $tmpDir=$Config{TMP_PATH};
my $scpBack=$Config{SCPFILE};
my $collectPath=$Config{COLLECT_PATH};



my $filename = basename(__FILE__);
my $cfg='hosts.cfg';
# Main Programm --------------------------------------

#Sammelpfad anlegen
system("mkdir -p $clientPath"."$collectPath");

open(DAT,"<$cfg") || die "File not found!\n";
while(<DAT>)
{
  #letztes Zeichen = Leerzeichen entfernen
  chomp($_);
  #falsche Zeilen, meist Leerzeilen ignorieren
  if(length($_)>2){ push(@hosts,$_); }
}
close(DAT);


for (@hosts)
{
  print("\n\n".$_."----------------------------------\n");
  #Copy Back
  $cmdline="expect $clientPath"."$tmpDir"."$scpBack";
  $cmd = "ssh root@".$_." \"$cmdline\"";
#print($cmd."\n");
  system($cmd);
  system("sleep 1");

  #Alte Daten am Client löschen
  print("Lösche Renderdaten am Client ...\n");
  $cmdline="rm -r $clientPath";
  $cmd = "ssh root@".$_." \"$cmdline\"";
  system($cmd);
}

__END__

#Achtung auf Syntax; erste Spalte, nach head Leerzeile, unformatiert mit 1 Space
 am Zeilenebginn
=encoding utf-8

=head1 NAME

$filename 

=head1 SYNOPSIS

 Kopiert die fertig gerenderten Dateien zurück


=head1 DESCRIPTION

  RenderFarm

=cut

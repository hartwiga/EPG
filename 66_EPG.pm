#################################################################
# $Id: 66_EPG.pm 15699 2019-11-03 21:17:50Z HomeAuto_User $
#
# Github - FHEM Home Automation System
# https://github.com/fhem/EPG
#
# 2019 - HomeAuto_User & elektron-bbs
#
#################################################################
# Varianten der Informationen:
# *.gz      -> ohne & mit Dateiendung nach unpack
# *.xml     -> ohne unpack
# *.xml.gz  -> mit Dateiendung xml nach unpack
# *.xz      -> ohne Dateiendung nach unpack
#################################################################

package main;

use strict;
use warnings;

use HttpUtils;					# https://wiki.fhem.de/wiki/HttpUtils
use utf8;
use Data::Dumper;

my $missingModulEPG = "";
eval "use XML::Simple;1" or $missingModulEPG .= "XML::Simple (cpanm XML::Simple)";

my @channel_available;
my %progamm;
my $HTML = {};

#####################
sub EPG_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}                 = "EPG_Define";
	$hash->{SetFn}                 = "EPG_Set";
	$hash->{GetFn}                 = "EPG_Get";
	$hash->{AttrFn}                = "EPG_Attr";
	$hash->{NotifyFn}              = "EPG_Notify";
  $hash->{FW_detailFn}           = "EPG_FW_Detail";
	$hash->{FW_deviceOverview}     = 1;
	$hash->{FW_addDetailToSummary} = 1;                # displays html in fhemweb room-view
	$hash->{AttrList}              =	"Ch_select Ch_sort DownloadFile DownloadURL Variant:Rytec,TvProfil_XMLTV,WebGrab+Plus,XMLTV.se,teXXas_RSS View_Subtitle:no,yes disable";
												             #$readingFnAttributes;
}

#####################
sub EPG_Define($$) {
	my ($hash, $def) = @_;
	my @arg = split("[ \t][ \t]*", $def);
	my $name = $arg[0];									## Definitionsname
	my $typ = $hash->{TYPE};						## Modulname
	my $filelogName = "FileLog_$name";
	my ($autocreateFilelog, $autocreateHash, $autocreateName, $autocreateDeviceRoom, $autocreateWeblinkRoom) = ('%L' . $name . '-%Y-%m.log', undef, 'autocreate', $typ, $typ);
	my ($cmd, $ret);

	return "Usage: define <name> $name"  if(@arg != 2);
	
	if ($init_done) {
		if (!defined(AttrVal($autocreateName, "disable", undef)) && !exists($defs{$filelogName})) {
			### create FileLog ###
			$autocreateFilelog = AttrVal($autocreateName, "filelog", undef) if (defined AttrVal($autocreateName, "filelog", undef));
			$autocreateFilelog =~ s/%NAME/$name/g;
			$cmd = "$filelogName FileLog $autocreateFilelog $name";
			Log3 $filelogName, 2, "$name: define $cmd";
			$ret = CommandDefine(undef, $cmd);
			if($ret) {
				Log3 $filelogName, 2, "$name: ERROR: $ret";
			} else {
				### Attributes ###
				CommandAttr($hash,"$filelogName room $autocreateDeviceRoom");
				CommandAttr($hash,"$filelogName logtype text");
				CommandAttr($hash,"$name room $autocreateDeviceRoom");
			}
		}

		### Attributes ###
		CommandAttr($hash,"$name room $typ") if (!defined AttrVal($name, "room", undef));				# set room, if only undef --> new def
	}
	
	### default value´s ###
	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash, "state" , "Defined");
	readingsEndUpdate($hash, 0);
	return undef;
}

#####################
sub EPG_Set($$$@) {
	my ( $hash, $name, @a ) = @_;
	my $setList = "";
	my $cmd = $a[0];

	return "no set value specified" if(int(@a) < 1);

	if ($cmd ne "?") {
		return "development";
	}

	return $setList if ( $a[0] eq "?");
	return "Unknown argument $cmd, choose one of $setList" if (not grep /$cmd/, $setList);
	return undef;
}

#####################
sub EPG_Get($$$@) {
	my ( $hash, $name, $cmd, @a ) = @_;
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my $Ch_sort = AttrVal($name, "Ch_sort", undef);
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);
	my $DownloadURL = AttrVal($name, "DownloadURL", undef);
	my $EPG_file_name = InternalVal($name, "EPG_file_name", "");
	my $TimeNow = FmtDateTime(time());
	my $Variant = AttrVal($name, "Variant", undef);
	my $cmd2 = $a[0];
	my $getlist = "loadFile:noArg ";

	my @Ch_select_array = split(",",$Ch_select) if ($Ch_select);
	my @Ch_sort_array = split(",",$Ch_sort) if ($Ch_sort);

	if ($Variant) {
		$getlist.= "available_channels:noArg " if (InternalVal($name, "EPG_file_age", undef) && InternalVal($name, "EPG_file_age", undef) ne "unknown or no file found");
	}

	my $ch_id;
	my $obj;
	my $state;
	my $xml;

	if ($cmd ne "?") {
		return "ERROR: no Attribute DownloadURL or DownloadFile defined - Please check!" if (!$DownloadURL || !$DownloadFile);
		return "ERROR: you need ".$missingModulEPG."package to use this command!" if ($missingModulEPG ne "");
		return "ERROR: You need the directory ./FHEM/EPG to download!" if (! -d "FHEM/EPG");
	}

	if ($cmd eq "loadFile") {
		EPG_PerformHttpRequest($hash);
		Log3 $name, 4, "$name: Get | $cmd successful";
		return undef;
	}

	if ($cmd eq "available_channels") {
		return "ERROR: no EPG_file_name" if ($EPG_file_name eq "");
		Log3 $name, 4, "$name: Get | $cmd read file $EPG_file_name with variant $Variant" if ($Variant);

		$HTML = {};
		@channel_available = ();
		%progamm = ();
		my $cnt = 0;

		if (-e "/opt/fhem/FHEM/EPG/$EPG_file_name") {
			open (FileCheck,"</opt/fhem/FHEM/EPG/$EPG_file_name");
				while (<FileCheck>) {
					# <tv generator-info-name="Rytec" generator-info-url="http://forums.openpli.org">
					$hash->{EPG_file_format} = "Rytec" if ($_ =~ /.*generator-info-name="Rytec".*/);
					# <tv source-data-url="http://api.tvprofil.net/" source-info-name="TvProfil API v1.7 - XMLTV" source-info-url="https://tvprofil.com">
					$hash->{EPG_file_format} = "TvProfil_XMLTV" if ($_ =~ /.*source-info-name="TvProfil.*/);
					# <tv generator-info-name="WebGrab+Plus/w MDB &amp; REX Postprocess -- version V2.1.5 -- Jan van Straaten" generator-info-url="http://www.webgrabplus.com">
					$hash->{EPG_file_format} = "WebGrab+Plus" if ($_ =~ /.*generator-info-name="WebGrab+Plus.*/);
					#XMLTV.se       <tv generator-info-name="Vind 2.52.12" generator-info-url="https://xmltv.se">
					$hash->{EPG_file_format} = "XMLTV.se" if ($_ =~ /.*generator-info-url="https:\/\/xmltv.se.*/);
					#teXXas via RSS  <channel><title>teXXas - 
					$hash->{EPG_file_format} = "teXXas_RSS" if ($_ =~ /.*<channel><title>teXXas -.*<link>http:\/\/www.texxas.de\/tv\/programm.*/);

					if ($Variant eq "Rytec" || $Variant eq "TvProfil_XMLTV" || $Variant eq "WebGrab+Plus" || $Variant eq "XMLTV.se") {
						$cnt++;
						$ch_id = $1 if ($_ =~ /<channel id="(.*)">/);
						if ($_ =~ /<display-name lang=".*">(.*)<.*/) {
							Log3 $name, 5, "$name: Get | $cmd id: $ch_id -> display_name: ".$1;
							$progamm{$ch_id}{name} = $1;
							push(@channel_available,$1);
						}					
					} elsif ($Variant eq "teXXas_RSS") {
						$cnt++;
						$hash->{EPG_data_time} = "now" if ($_ =~ /<link>http:\/\/www.texxas.de\/tv\/programm\/jetzt\//);
						$hash->{EPG_data_time} = "20:15" if ($_ =~ /<link>http:\/\/www.texxas.de\/tv\/programm\/heute\/2015\//);
						my @RRS = split("<item>", $_);
						my $remove = shift @RRS;
						for (@RRS) {
							push(@channel_available,$1) if ($_ =~ /<dc:subject>(.*)<\/dc:subject>/);
						}
					}
				}
			close FileCheck;
			
			if ($cnt == 0) {
				readingsSingleUpdate($hash, "state", "unknown methode! need development!", 1);
				return "";
			}

			@channel_available = sort @channel_available;
			#Log3 $name, 3, Dumper\@channel_available;
			$state = "available channels loaded";
			$hash->{EPG_data} = "ready to read";

			CommandAttr($hash,"$name Variant $hash->{EPG_file_format}") if ($hash->{EPG_file_format});		# setzt Variante von EPG_File
			FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "location.reload('true')", "");		            # reload Webseite
			readingsSingleUpdate($hash, "state", $state, 1);
		} else {
			$state = "ERROR: $Variant Canceled";
			Log3 $name, 3, "$name: $cmd | error, file $EPG_file_name no found at ./opt/fhem/FHEM/EPG";
			return "ERROR: no file found!";
		}
		return undef;
	}

	if ($Variant eq "Rytec" || $Variant eq "TvProfil_XMLTV" || $Variant eq "WebGrab+Plus" || $Variant eq "XMLTV.se") {
		if (AttrVal($name, "Ch_select", undef) && scalar(@channel_available) > 0 && AttrVal($name, "Ch_select", undef) ne "") {
			$getlist.= "loadEPG_now:noArg ";               # now
			$getlist.= "loadEPG_Prime:noArg ";             # Primetime
			$getlist.= "loadEPG_today:noArg ";             # today all

			my $TimeNowMod = $TimeNow;
			$TimeNowMod =~ s/-|:|\s//g;

			# every hour list #
			my $loadEPG_list = "";
			for my $d (substr($TimeNowMod,8, 2) +1 .. 23) {
				$loadEPG_list.= substr($TimeNowMod,0, 8)."_".sprintf("%02s",$d)."00,";
			}

			if ($loadEPG_list =~ /,$/) {
				$loadEPG_list = substr($loadEPG_list,0, -1);
				$getlist.= "loadEPG:".$loadEPG_list." " ;
			}
		}
		
		if ($cmd =~ /^loadEPG/) {
			$HTML = {};                # reset hash for HTML
			my $start = "";            # TV time start
			my $end = "";              # TV time end
			my $ch_found = 0;          # counter to verification ch
			my $data_found;            # counter to verification data
			my $ch_name = "";          # TV channel display-name
			my $ch_name_old = "";      # TV channel display-name before
			my $ch_id = "";            # TV channel channel id
			my $title = "";            # TV title
			my $subtitle = "";         # TV subtitle
			my $desc = "";             # TV desc
			my $today_start = "";      # today time start
			my $today_end = "";        # today time end
			my $hour_diff_read = "";   # hour diff from file

			Log3 $name, 4, "$name: $cmd from file $EPG_file_name";
			#Log3 $name, 3, "$name: Get | $TimeNow";

			my $off_h = 0;
			my @local = (localtime(time+$off_h*60*60));
			my @gmt = (gmtime(time+$off_h*60*60));
			my $TimeLocaL_GMT_Diff = $gmt[2]-$local[2] + ($gmt[5] <=> $local[5] || $gmt[7] <=> $local[7])*24;
			if ($TimeLocaL_GMT_Diff < 0) {
				$TimeLocaL_GMT_Diff = abs($TimeLocaL_GMT_Diff);
				$TimeLocaL_GMT_Diff = "+".sprintf("%02s", abs($TimeLocaL_GMT_Diff))."00";
			} else {
				$TimeLocaL_GMT_Diff = sprintf("-%02s", $TimeLocaL_GMT_Diff) ."00";
			}

			Log3 $name, 4, "$name: $cmd localtime     ".localtime(time+$off_h*60*60);
			Log3 $name, 4, "$name: $cmd gmtime        ".gmtime(time+$off_h*60*60);
			Log3 $name, 4, "$name: $cmd diff (GMT-LT) " . $TimeLocaL_GMT_Diff;

			$TimeNow =~ s/-|:|\s//g;
			$TimeNow.= " $TimeLocaL_GMT_Diff";                       # loadEPG_now   20191016150432 +0200

			if ($cmd eq "loadEPG_Prime") {
				if (substr($TimeNow,8, 2) > 20) {                      # loadEPG_Prime 20191016201510 +0200	morgen wenn Prime derzeit läuft
					my @time = split(/-\s:/,FmtDateTime(time()));
					$TimeNow = FmtDateTime(time() - ($time[5] + $time[4] * 60 + $time[3] * 3600) + 86400);
					$TimeNow =~ s/-|:|\s//g;
					$TimeNow.= " +0200";
					substr($TimeNow, 8) = "201510 $TimeLocaL_GMT_Diff";
				} else {                                               # loadEPG_Prime 20191016201510 +0200	heute
					substr($TimeNow, 8) = "201510 $TimeLocaL_GMT_Diff";
				}
			}

			if ($cmd eq "loadEPG_today") {                           # Beginn und Ende von heute bestimmen
				$today_start = substr($TimeNow,0,8)."000000 $TimeLocaL_GMT_Diff";
				$today_end = substr($TimeNow,0,8)."235959 $TimeLocaL_GMT_Diff";
			}

			if ($cmd eq "loadEPG" && $cmd2 =~ /^[0-9]*_[0-9]*$/) {   # loadEPG 20191016_200010 +0200 stündlich ab jetzt
				$cmd2 =~ s/_//g;
				$cmd2.= "10 $TimeLocaL_GMT_Diff";
				$TimeNow = $cmd2;
			}

			Log3 $name, 4, "$name: $cmd | TimeNow          -> $TimeNow";

			if (-e "/opt/fhem/FHEM/EPG/$EPG_file_name") {
				open (FileCheck,"</opt/fhem/FHEM/EPG/$EPG_file_name");
					while (<FileCheck>) {
						if ($_ =~ /<programme start="(.*\s+(.*))" stop="(.*)" channel="(.*)"/) {      # find start | end | channel
							my $search = $progamm{$4}->{name};
							if (grep /$search($|,)/, $Ch_select) {                                       # find in attributes channel
								($start, $hour_diff_read, $end, $ch_id, $ch_name) = ($1, $2, $3, $4, $progamm{$4}->{name});
								if ($TimeLocaL_GMT_Diff ne $hour_diff_read) {
									#Log3 $name, 4, "$name: $cmd | Time must be recalculated! local=$TimeLocaL_GMT_Diff read=$2";
									my $hour_diff = substr($TimeLocaL_GMT_Diff,0,1).substr($TimeLocaL_GMT_Diff,2,1);
									#Log3 $name, 4, "$name: $cmd | hour_diff_result $hour_diff";

									my @start_new = split("",$start);
									my @end_new = split("",$end);
									#Log3 $name, 4, "$name: $cmd | ".'sec | min | hour | mday | month | year';
									#Log3 $name, 4, "$name: $cmd | $start_new[12]$start_new[13]  | $start_new[10]$start_new[11]  |  $start_new[8]$start_new[9]  | $start_new[6]$start_new[7]   | $start_new[4]$start_new[5]    | $start_new[0]$start_new[1]$start_new[2]$start_new[3]";
									#Log3 $name, 4, "$name: $cmd | $end_new[12]$end_new[13]  | $end_new[10]$end_new[11]  |  $end_new[8]$end_new[9]  | $end_new[6]$end_new[7]   | $end_new[4]$end_new[5]    | $end_new[0]$end_new[1]$end_new[2]$end_new[3]";
									#Log3 $name, 4, "$name: $cmd | UTC start        -> ".fhemTimeLocal(($start_new[12].$start_new[13]), ($start_new[10].$start_new[11]), ($start_new[8].$start_new[9]), ($start_new[6].$start_new[7]), (($start_new[4].$start_new[5])*1-1), (($start_new[0].$start_new[1].$start_new[2].$start_new[3])*1-1900));
									#Log3 $name, 4, "$name: $cmd | UTC end          -> ".fhemTimeLocal(($end_new[12].$end_new[13]), ($end_new[10].$end_new[11]), ($end_new[8].$end_new[9]), ($end_new[6].$end_new[7]), (($end_new[4].$end_new[5])*1-1), (($end_new[0].$end_new[1].$end_new[2].$end_new[3])*1-1900));
									#Log3 $name, 4, "$name: $cmd | start            -> $start";             # 20191023211500 +0000
									#Log3 $name, 4, "$name: $cmd | end              -> $end";               # 20191023223000 +0000

									if (index($hour_diff,"-")) {
										$start = fhemTimeLocal(($start_new[12].$start_new[13]), ($start_new[10].$start_new[11]), ($start_new[8].$start_new[9]), ($start_new[6].$start_new[7]), (($start_new[4].$start_new[5])*1-1), (($start_new[0].$start_new[1].$start_new[2].$start_new[3])*1-1900)) + (60*60*abs(substr($TimeLocaL_GMT_Diff,2,1)));
										$end = fhemTimeLocal(($end_new[12].$end_new[13]), ($end_new[10].$end_new[11]), ($end_new[8].$end_new[9]), ($end_new[6].$end_new[7]), (($end_new[4].$end_new[5])*1-1), (($end_new[0].$end_new[1].$start_new[2].$start_new[3])*1-1900)) + (60*60*abs(substr($TimeLocaL_GMT_Diff,2,1)));
									} else {
										$start = fhemTimeLocal(($start_new[12].$start_new[13]), ($start_new[10].$start_new[11]), ($start_new[8].$start_new[9]), ($start_new[6].$start_new[7]), (($start_new[4].$start_new[5])*1-1), (($start_new[0].$start_new[1].$start_new[2].$start_new[3])*1-1900)) - (60*60*abs(substr($TimeLocaL_GMT_Diff,2,1)));
										$end = fhemTimeLocal(($end_new[12].$end_new[13]), ($end_new[10].$end_new[11]), ($end_new[8].$end_new[9]), ($end_new[6].$end_new[7]), (($end_new[4].$end_new[5])*1-1), (($end_new[0].$end_new[1].$start_new[2].$start_new[3])*1-1900)) - (60*60*abs(substr($TimeLocaL_GMT_Diff,2,1)));
									}

									#Log3 $name, 4, "$name: $cmd | UTC start new    -> $start";
									#Log3 $name, 4, "$name: $cmd | UTC end new      -> $end";

									$start = FmtDateTime($start);
									$end = FmtDateTime($end);
									$start =~ s/-|:|\s//g;
									$end =~ s/-|:|\s//g;
									$start.= " $TimeLocaL_GMT_Diff";
									$end.= " $TimeLocaL_GMT_Diff";

									#Log3 $name, 4, "$name: $cmd | start new        -> $start";
									#Log3 $name, 4, "$name: $cmd | end new          -> $end";
								}

								if ($cmd ne "loadEPG_today") {
									$ch_found++ if ($TimeNow gt $start && $TimeNow lt $end);                           # Zeitpunktsuche, normal
								} else {
									$ch_found++ if ($today_end gt $start && $today_start lt $end);                     # Zeitpunktsuche, kompletter Tag
								}
							}
						}
						$title = $2 if ($_ =~ /<title lang="(.*)">(.*)<\/title>/ && $ch_found != 0);             # title
						$subtitle = $2 if ($_ =~ /<sub-title lang="(.*)">(.*)<\/sub-title>/ && $ch_found != 0);  # subtitle
						$desc = $2 if ($_ =~ /<desc lang="(.*)">(.*)<\/desc>/ && $ch_found != 0);                # desc

						if ($_ =~ /<\/programme>/ && $ch_found != 0) {   ## find end channel
							$data_found = -1 if ($ch_name_old ne $ch_name);                                        # Reset bei Kanalwechsel
							$data_found++;
							Log3 $name, 4, "#################################################";
							Log3 $name, 4, "$name: $cmd | ch_name          -> $ch_name";
							Log3 $name, 4, "$name: $cmd | ch_name_old      -> $ch_name_old";
							Log3 $name, 4, "$name: $cmd | EPG information  -> $data_found";
							Log3 $name, 4, "$name: $cmd | title            -> $title";
							Log3 $name, 4, "$name: $cmd | subtitle         -> $subtitle";
							Log3 $name, 4, "$name: $cmd | desc             -> $desc.\n";

							$HTML->{$ch_name}{ch_name} = $ch_name;
							$HTML->{$ch_name}{ch_id} = $ch_id;

							if ($Ch_select && $Ch_sort && (grep /$ch_name/, $Ch_select)) {
								foreach my $i (0 .. $#Ch_select_array) {
									if ($Ch_select_array[$i] eq $ch_name) {
										my $value_new = 999;
										$value_new = $Ch_sort_array[$i] if ($Ch_sort_array[$i] != 0);
										$HTML->{$Ch_select_array[$i]}{ch_wish} = $value_new;
										Log3 $name, 4, "$name: $cmd old numbre of ".$Ch_select_array[$i]." set to ".$value_new;
									}
								}
							} else {
								$HTML->{$ch_name}{ch_wish} = 999;
							}

							$HTML->{$ch_name}{EPG}[$data_found]{start} = $start;
							$HTML->{$ch_name}{EPG}[$data_found]{end} = $end;
							$HTML->{$ch_name}{EPG}[$data_found]{hour_diff} = $hour_diff_read;
							$HTML->{$ch_name}{EPG}[$data_found]{title} = $title;
							$HTML->{$ch_name}{EPG}[$data_found]{subtitle} = $subtitle;
							$HTML->{$ch_name}{EPG}[$data_found]{desc} = $desc;

							$ch_found = 0;
							$ch_name_old = $ch_name;
							$ch_name = "";
							$desc = "";
							$hour_diff_read = "";
							$subtitle = "";
							$title = "";
						}
					}
				close FileCheck;

				$hash->{EPG_data} = "all channel information loaded" if ($data_found != -1);
				$hash->{EPG_data} = "no channel information available!" if ($data_found == -1);
			} else {
				readingsSingleUpdate($hash, "state", "ERROR: loaded Information Canceled. file not found!", 1);
				Log3 $name, 3, "$name: $cmd | error, file $EPG_file_name no found at ./opt/fhem/FHEM/EPG";
				return "ERROR: no file found!";
			}
		}
	}
	
	if ($Variant eq "teXXas_RSS" ) {
		$getlist.= "loadEPG_now:noArg " if ($hash->{EPG_data_time} && $hash->{EPG_data_time} eq "now");
		$getlist.= "loadEPG_Prime:noArg " if ($hash->{EPG_data_time} && $hash->{EPG_data_time} eq "20:15");

		if ($cmd ne "?") {
			if (-e "/opt/fhem/FHEM/EPG/$EPG_file_name") {
				open (FileCheck,"</opt/fhem/FHEM/EPG/$EPG_file_name");
					my $string = "";
					while (<FileCheck>) {
						#chomp($_);
						$string .= $_;
					}
				close FileCheck;
				utf8::encode($string);
				#Log3 $name, 4, $string;
				my @RRS = split("<item>", $string);
				my $remove = shift @RRS;

				for (@RRS) {
					my $ch_found = 0;
					my $ch_name;
					my $desc = "";
					my $end;
					my $start;
					my $time;

					if($_ =~ /<dc:subject>(.*)<\/dc:subject>/) {
						Log3 $name, 5, "$name: $cmd | look for    -> ".$1." selection in $Ch_select" if ($Ch_select);
						my $search = $1;
						if (index($search,"+") >= 0) {
							substr($search,index($search,"+"),1,'\+');
						}

						if ( ($Ch_select) && (grep /$search($|,)/, $Ch_select) ) {
							Log3 $name, 5, "$name: $cmd |             -> $1 found";
							$ch_name = $1;
							$ch_found++;						
						} else {
							Log3 $name, 5, "$name: $cmd |             -> not $1 found";
						}
					}

					if($_ =~ /:\s(.*)<\/title>/ && $ch_found != 0) {
						Log3 $name, 4, "$name: $cmd | channel     -> ".$ch_name;
						Log3 $name, 4, "$name: $cmd | title       -> ".$1 ;
						$HTML->{$ch_name}{EPG}[0]{title} = $1;

						### need check
						if ($Ch_select && $Ch_sort && (grep /$ch_name/, $Ch_select)) {
							foreach my $i (0 .. $#Ch_select_array) {
								if ($Ch_select_array[$i] eq $ch_name) {
									my $value_new = 999;
									$value_new = $Ch_sort_array[$i] if ($Ch_sort_array[$i] != 0);
									$HTML->{$Ch_select_array[$i]}{ch_wish} = $value_new;
									Log3 $name, 4, "$name: $cmd | ch numbre   -> set to ".$value_new;
								}
							}
						} else {
							$HTML->{$ch_name}{ch_wish} = 999;
						}
						### need check attribut
						$HTML->{$ch_name}{ch_name} = $ch_name;						
					}

					if($_ =~ /<!\[CDATA\[(.*)?((.*)?\d{2}\.\d{2}\.\d{4}\s(\d{2}:\d{2})\s+-\s+(\d{2}:\d{2}))(<br>)?(.*)]]/ && $ch_found != 0) {
						Log3 $name, 4, "$name: $cmd | time        -> ".$2;    # 02.11.2019 13:35 - 14:30
						$time = $2;
						Log3 $name, 4, "$name: $cmd | start       -> ".$4;
						$start = substr($2,6,4).substr($2,3,2).substr($2,0,2).substr($4,0,2).substr($4,3,2) . "";
						Log3 $name, 4, "$name: $cmd | start mod   -> ".$start;
						Log3 $name, 4, "$name: $cmd | end         -> ".$5;
						$end = substr($2,6,4).substr($2,3,2).substr($2,0,2).substr($5,0,2).substr($5,3,2) . "";						
						Log3 $name, 4, "$name: $cmd | end mod     -> ".$end;
						$desc = $7;
						Log3 $name, 4, "$name: $cmd | description -> ".$7;
						Log3 $name, 4, "#################################################";

						$HTML->{$ch_name}{EPG}[0]{start} = $start;
						$HTML->{$ch_name}{EPG}[0]{end} = $end;
						$HTML->{$ch_name}{EPG}[0]{desc} = $desc;
					}
				}

				#Log3 $name, 4, Dumper\%{$HTML};

			} else {
				readingsSingleUpdate($hash, "state", "ERROR: loaded Information Canceled. file not found!", 1);
				Log3 $name, 3, "$name: $cmd | error, file $EPG_file_name no found at ./opt/fhem/FHEM/EPG";
				return "ERROR: no file found!";
			}
		}
	}

	if ($cmd =~ /^loadEPG/) {
		FW_directNotify("FILTER=(room=)?$name", "#FHEMWEB:WEB", "location.reload('true')", "") if (scalar keys %{$HTML});
		
		readingsSingleUpdate($hash, "state", $cmd . " accomplished", 1);
		return undef;	
	}
	
	return "Unknown argument $cmd, choose one of $getlist";
}

#####################
sub EPG_Attr() {
	my ($cmd, $name, $attrName, $attrValue) = @_;
	my $hash = $defs{$name};
	my $typ = $hash->{TYPE};
	my $Variant = AttrVal($name, "Variant", undef);

	if ($cmd eq "set") {
		if ($attrName eq "disable") {
			if ($attrValue == 1) {
			}
			
			if ($attrValue == 0) {
			}
		}

		if ($attrName eq "DownloadURL") {
			return "Your website entry must end with /\n\nexample: $attrValue/" if ($attrValue !~ /.*\/$/);
			return "Your input must begin with http:// or https://" if ($attrValue !~ /^htt(p|ps):\/\//);
		}
		
		if($attrName eq "Variant") {
			if ($Variant && ($attrValue ne $Variant) || not $Variant) {
				delete $hash->{EPG_data} if ($hash->{EPG_data});
				delete $hash->{EPG_file_age} if ($hash->{EPG_file_age});
				delete $hash->{EPG_file_format} if ($hash->{EPG_file_format});
				delete $hash->{EPG_file_name} if ($hash->{EPG_file_name});
				
				@channel_available = ();
				%progamm = ();
				$HTML = {};

				FW_directNotify("FILTER=(room=)?$name", "#FHEMWEB:WEB", "location.reload('true')", "");
				return undef;
			}
		}
	}
}

#####################
sub EPG_FW_Detail($@) {
	my ($FW_wname, $name, $room, $pageHash) = @_;
	my $hash = $defs{$name};
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my $View_Subtitle = "";
	my $cnt = 0;
	my $ret = "";

	Log3 $name, 5, "$name: FW_Detail is running";
	Log3 $name, 5, "$name: FW_Detail - channel_available: ".scalar(@channel_available);

	if ($Ch_select) {
		my @Channels_value = split(",", $Ch_select);
		$cnt = scalar(@Channels_value);
	}

	if (scalar(@channel_available) > 0) {
		if ($FW_detail) {
			### Control panel ###
			$ret .= "<div class='makeTable wide'><span>Control panel</span>
							<table class='block wide' id='EPG_InfoMenue' nm='$hash->{NAME}' class='block wide'>
							<tr class='even'>";

			$ret .= "<td><a href='#button1' id='button1'>list of all available channels</a></td>";
			$ret .= "<td> readed channels:". scalar(@channel_available) ."</td>";
			$ret .= "<td> selected channels: ". $cnt ."</td>";
			$ret .= "</tr></table></div>";
		}

		### Javascript ###
		$ret .= '
			<script>

			$( "#button1" ).click(function(e) {
				e.preventDefault();
				FW_cmd(FW_root+\'?cmd={EPG_FW_Channels("'.$name.'")}&XHR=1"'.$FW_CSRF.'"\', function(data){EPG_ListWindow(data)});
			});

			function EPG_ListWindow(txt) {
				var div = $("<div id=\"EPG_ListWindow\">");
				$(div).html(txt);
				$("body").append(div);
				var oldPos = $("body").scrollTop();

				$(div).dialog({
					dialogClass:"no-close", modal:true, width:"auto", closeOnEscape:true, 
					maxHeight:$(window).height()*0.95,
					title: "'.$name.' Channel Overview",
					buttons: [
						{text:"select all", click:function(){
							$("#EPG_ListWindow table td input:checkbox").prop(\'checked\', true);
						}},
						{text:"deselect all", click:function(){
							$("#EPG_ListWindow table td input:checkbox").prop(\'checked\', false);
						}},
						{text:"save", click:function(){
							var Channel = [];
							var Channel_id = [];
							var desired_channel = [];
							$("#EPG_ListWindow input:checkbox:checked").each(function() {
								Channel.push($(this).attr(\'name\'));
								Channel_id.push($(this).attr(\'id\'));
							})

							$("#EPG_ListWindow td input:text").each(function() {
								var n = Channel_id.indexOf($(this).attr(\'id\'));
								if (n != -1) {
									var m = $(this).val();
									if (!m) {
										m = 0;
									}
									/* desired_channel.push($(this).val()); */
									desired_channel.push(m);
								}
							})

							var Channel = encodeURIComponent(Channel); /* need to view + | Javascript must encode + */

							FW_cmd(FW_root+ \'?XHR=1"'.$FW_CSRF.'"&cmd={EPG_FW_Attr_Channels("'.$name.'","\'+Channel+\'","\'+desired_channel+\'")}\');
							$(this).dialog("close");
							$(div).remove();
							location.reload();
						}},
						{text:"close", click:function(){
							$(this).dialog("close");
							$(div).remove();
						}}]
				});
			}

			/* checkBox Werte von Checkboxen Wochentage */
			function Checkbox(id) {
				var checkBox = document.getElementById(id);
				if (checkBox.checked) {
					checkBox.value = 1;
				} else {
					checkBox.value = 0;
				}
			}

		</script>';

		### HTML ###
		
		$ret .= "<div id=\"table\"><center>- no EPG Data -</center></div>" if not (scalar keys %{$HTML});

		if (scalar keys %{$HTML}) {
			my $start = "";
			my $end = "";
			my $title = "";
			my $subtitle = "";
			my $desc = "";
			my $cnt_infos = 0;

			$View_Subtitle = "<th>Beschreibung</th>" if (AttrVal($name, "View_Subtitle", "no") eq "yes");
			$ret .= "<div id=\"table\"><table class=\"block wide\">";
			$ret .= "<tr class=\"even\" style=\"text-decoration:underline; text-align:left;\"><th>Sender</th><th>Start</th><th>Ende</th><th>Sendung</th>$View_Subtitle</tr>";

			#Log3 $name, 3, Dumper\%{$HTML};	
			my @positioned = sort { $HTML->{$a}{ch_wish} <=> $HTML->{$b}{ch_wish} or lc ($HTML->{$a}{ch_name}) cmp lc ($HTML->{$b}{ch_name}) } keys %$HTML;

			#foreach my $ch (sort keys %{$HTML}) {

			foreach my $ch (@positioned) {
				## Kanäle ##
				#Log3 $name, 3, "$name: ch                -> $ch (".$HTML->{$ch}{ch_wish}.")";
				foreach my $value (@{$HTML->{$ch}{EPG}}) {
					## EPG ##
					#Log3 $name, 3, "$name: value             -> $value";
					foreach my $d (keys %{$value}) {
						## einzelne Werte ##
						#Log3 $name, 3, "$name: description       -> $d";
						#Log3 $name, 3, "$name: description value -> $value->{$d}";
						$start = substr($value->{$d},8,2).":".substr($value->{$d},10,2) if ($d eq "start");
						$end = substr($value->{$d},8,2).":".substr($value->{$d},10,2) if ($d eq "end");
						$title = $value->{$d} if ($d eq "title");
						$desc = $value->{$d} if ($d eq "desc");
						$subtitle = $value->{$d} if ($d eq "subtitle");
					}
					$cnt_infos++;
					## Darstellung als Link wenn Sendungsbeschreibung ##
					$ret .= sprintf("<tr class=\"%s\">", ($cnt_infos & 1)?"odd":"even");
					$View_Subtitle = "<td>$subtitle</td>" if (AttrVal($name, "View_Subtitle", "no") eq "yes");

					if ($desc ne "") {
						#$desc =~ s/"/&quot;/g if (grep /"/, $desc);  # "
						#$desc =~ s/'/\\'/g if (grep /'/, $desc);     # '

						$desc =~ s/<br>/\n/g;
						$desc =~ s/(.{1,65}|\S{66,})(?:\s[^\S\r\n]*|\Z)/$1<br>/g; 
						$desc =~ s/[\r\'\"]/ /g;
						$desc =~ s/[\n]|\\n/<br>/g;

						$ret .= "<td>$ch</td><td>$start</td><td>$end</td><td><a href=\"#!\" onclick=\"FW_okDialog(\'$desc\')\">$title</a></td>$View_Subtitle</tr>";
					} else {
						$ret .= "<td>$ch</td><td>$start</td><td>$end</td><td>$title</td>$View_Subtitle</tr>";
					}
				}
			}
			$ret .= "</table></div>";
		}
	}

	return $ret;
}

##################### (Aufbau HTML Tabelle available channels)
sub EPG_FW_Channels {
	my $name = shift;
	my $ret = "";
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my $Ch_sort = "";
	my $checked = "";
	my $style_background = "";

	Log3 $name, 4, "$name: FW_Channels is running";

	$ret.= "<table>";
	$ret.= "<tr style=\"text-decoration-line: underline;\"><td>no.</td><td>active</td><td>TV station name</td><td>FAV</td></tr>";

	for (my $i=0; $i<scalar(@channel_available); $i++) {
		$style_background = "background-color:#F0F0D8;" if ($i % 2 == 0);
		$style_background = "" if ($i % 2 != 0);
		$checked = "checked" if ($Ch_select && index($Ch_select,$channel_available[$i]) >= 0);
		$Ch_sort = $HTML->{$channel_available[$i]}{ch_wish} if($HTML->{$channel_available[$i]}{ch_wish} && $HTML->{$channel_available[$i]}{ch_wish} < 999);
		$ret.= "<tr style=\"$style_background\"><td align=\"center\">".($i + 1)."</td><td align=\"center\"><input type=\"checkbox\" id=\"".$i."\" name=\"".$channel_available[$i]."\" onclick=\"Checkbox(".$i.")\" $checked></td><td>". $channel_available[$i] ."</td><td> <input type=\"text\" pattern=\"[0-9]+\" id=\"".$i."\" value=\"$Ch_sort\" maxlength=\"3\" size=\"3\"> </td></tr>";
		$checked = "";
		$Ch_sort = "";
	}
	
	$ret.= "</table>";

	return $ret;
}

##################### (Anpassung Attribute Channels)
sub EPG_FW_Attr_Channels {
	my $name = shift;
	my $hash = $defs{$name};
	my $Ch_select = shift;
	my @Ch_select_array = split(",",$Ch_select);
	my $Ch_sort = shift;
	my @Ch_sort_array = split(",",$Ch_sort);

	Log3 $name, 4, "$name: FW_Attr_Channels is running";
	Log3 $name, 5, "$name: FW_Attr_Channels Ch_select $Ch_select";
	Log3 $name, 5, "$name: FW_Attr_Channels Ch_sort $Ch_sort";

	if ($Ch_select eq "") {
		Log3 $name, 4, "$name: FW_Attr_Channels all Channels delete and clean view";
		CommandDeleteAttr($hash,"$name Ch_select");
		CommandDeleteAttr($hash,"$name Ch_sort");
		readingsSingleUpdate($hash, "state", "no channels selected", 1);
		$HTML = {};

		FW_directNotify("FILTER=(room=)?$name", "#FHEMWEB:WEB", "location.reload('true')", "");
	} else {
		Log3 $name, 4, "$name: FW_Attr_Channels new Channels set";
		$HTML = {};
		CommandAttr($hash,"$name Ch_select $Ch_select");
		if ($Ch_sort !~ /^[0,]+$/) {
			CommandAttr($hash,"$name Ch_sort $Ch_sort");
		} else {
			CommandDeleteAttr($hash,"$name Ch_sort");		
		}

		CommandGet($hash, "$name loadEPG_now");

    ## list of all available channels - set ch_wish from HTML input ##
		foreach my $i (0 .. $#Ch_select_array) {
			if ($Ch_sort_array[$i] != 0) {
				Log3 $name, 4, "$name: FW_Attr_Channels new numbre of ".$Ch_select_array[$i]." set to ".$Ch_sort_array[$i];
				$HTML->{$Ch_select_array[$i]}{ch_wish} = $Ch_sort_array[$i];
			} else {
				$HTML->{$Ch_select_array[$i]}{ch_wish} = 999;                          # Reset Default
			}
		}
	}
}

#####################
sub EPG_PerformHttpRequest($) {
	my ($hash, $def) = @_;
	my $name = $hash->{NAME};
	my $DownloadURL = AttrVal($name, "DownloadURL", undef);
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);

	Log3 $name, 4, "$name: EPG_PerformHttpRequest is running";
	my $http_param = { 	url        => $DownloadURL.$DownloadFile,
											timeout    => 10,
											hash       => $hash,                                     # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
											method     => "GET",                                     # Lesen von Inhalten
											callback   => \&EPG_ParseHttpResponse                    # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
							};
	HttpUtils_NonblockingGet($http_param);                                       # Starten der HTTP Abfrage
}

#####################
sub EPG_ParseHttpResponse($$$) {
	my ($http_param, $err, $data) = @_;
	my $hash = $http_param->{hash};
	my $name = $hash->{NAME};
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);
	my $HttpResponse = "";
	my $state = "no information received";
	my $FileAge = undef;

	Log3 $name, 5, "$name: ParseHttpResponse - error: $err";
	Log3 $name, 5, "$name: ParseHttpResponse - http code: ".$http_param->{code};

	if ($err ne "") {                                                          # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
		$HttpResponse = $err;
		Log3 $name, 3, "$name: ParseHttpResponse - error: $err";
	} elsif ($http_param->{code} ne "200") {                                   # HTTP code
		$HttpResponse = "DownloadFile $DownloadFile was not found on URL" if (grep /$DownloadFile\swas\snot\sfound/, $data);
		$HttpResponse = "DownloadURL was not found" if (grep /URL\swas\snot\sfound/, $data);
		Log3 $name, 3, "$name: ParseHttpResponse - error:\n\n$data";
	} elsif ($http_param->{code} eq "200" && $data ne "") {                    # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
   	my $filename = "FHEM/EPG/$DownloadFile";
		open(my $file, ">", $filename);                                          # Datei schreiben
			print $file $data;
		close $file;

		local $SIG{CHLD} = 'DEFAULT';
		if ($DownloadFile =~ /.*\.gz$/) {
			qx(gzip -d -f /opt/fhem/FHEM/EPG/$DownloadFile 2>&1);                  # Datei Unpack gz
		} elsif ($DownloadFile =~ /.*\.xz$/) {
			qx(xz -df /opt/fhem/FHEM/EPG/$DownloadFile 2>&1);                      # Datei Unpack xz
		}

		if ($? != 0 && $DownloadFile =~ /\.(gz|xz)/) {
			@channel_available = ();
			%progamm = ();
			$state = "ERROR: unpack $DownloadFile";
		} else { 
			EPG_File_check($hash);
			FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "location.reload('true')", "");
			$state = "information received";
		}

		$HttpResponse = "downloaded";
	}

	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash, "HttpResponse", $HttpResponse);                  # HttpResponse Status
	readingsBulkUpdate($hash, "state", $state);
	readingsEndUpdate($hash, 1);

	HttpUtils_Close($http_param);
}

#####################
sub EPG_Notify($$) {
	my ($hash, $dev_hash) = @_;
	my $name = $hash->{NAME};
	my $typ = $hash->{TYPE};
	return "" if(IsDisabled($name));	                                        # Return without any further action if the module is disabled
	my $devName = $dev_hash->{NAME};	                                        # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);
	my $Variant = AttrVal($name, "Variant", undef);

	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}) && $typ eq "EPG") {
		Log3 $name, 5, "$name: Notify is running and starting";

		if ($Variant) {
			EPG_File_check($hash) if($DownloadFile);
			CommandGet($hash,"$name loadEPG_now") if($DownloadFile && $Ch_select);		
		}
	}

	return undef;
}

#####################
sub EPG_File_check {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $DownloadFile = AttrVal($name, "DownloadFile", "no file found");
	my $DownloadFile_found = 0;
	my $FileAge = "unknown";

	Log3 $name, 5, "$name: File_check is running";

	## check files ##
	opendir(DIR,"/opt/fhem/FHEM/EPG");																		# not need -> || return "ERROR: directory $path can not open!"
		while( my $directory_value = readdir DIR ){
			if (index($DownloadFile,$directory_value) >= 0 && $directory_value ne "." && $directory_value ne ".." && $directory_value !~ /\.(gz|xz)/) {
				Log3 $name, 4, "$name: File_check found $directory_value";
				$DownloadFile = $directory_value;
				$DownloadFile_found++;
			}
		}
	close DIR;

	if ($DownloadFile_found != 0) {
		Log3 $name, 4, "$name: File_check ready to search channel";	
		my @stat_DownloadFile = stat("/opt/fhem/FHEM/EPG/".$DownloadFile);  # Dateieigenschaften
		$FileAge = FmtDateTime($stat_DownloadFile[9]);                      # letzte Änderungszeit
	} else {
		Log3 $name, 4, "$name: File_check nothing found";
		$DownloadFile = "file not found";
	}

	$hash->{EPG_file_age} = $FileAge;
	$hash->{EPG_file_name} = $DownloadFile;

	CommandGet($hash,"$name available_channels") if($DownloadFile_found != 0);
}

# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;


# Beginn der Commandref

=pod
=item [helper]
=item summary TV-EPG Guide
=item summary_DE TV-EPG Guide

=begin html

<a name="EPG"></a>
<h3>EPG Modul</h3>
<ul>
The EPG module fetches the TV broadcast information from various sources.<br>
This is a module which retrieves the data for an electronic program guide and displays it immediately. (example: alternative for HTTPMOD + Readingsgroup & other)<br><br>
<i>Depending on the source and host country, the information can be slightly differentiated.<br> Each variant has its own read-in routine. When new sources become known, the module can be extended at any time.</i>
<br><br>
You have to choose a source and only then can the data of the TV Guide be displayed.<br>
The specifications for the attribute Variant | DownloadFile and DownloadURL are mandatory.
<br><br>
<ul><u>Currently the following services are supported:</u>
	<li>Rytec (Rytec EPG Downloader)<br><br>
			well-known sources:<br>
			<ul>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_Basic.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_Common.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_SportMovies.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://www.vuplus-community.net/rytec/rytecDE_Basic.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li>http://www.vuplus-community.net/rytec/rytecDE_Common.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li>http://www.vuplus-community.net/rytec/rytecDE_SportMovies.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li>http://www.xmltvepg.nl/rytecDE_Basic.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li>http://www.xmltvepg.nl/rytecDE_Common.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li><a href="http://rytecepg.epgspot.com/epg_data/" target=”_blank”>http://rytecepg.epgspot.com/epg_data/</a> <small>&nbsp;&nbsp;(&#10003; - Auswahl nach L&auml;ndern)</small></li>
				<li><a href="https://rytec.ricx.nl/epg_data/" target=”_blank”>https://rytec.ricx.nl/epg_data/</a> <small>&nbsp;&nbsp;(&#10003; - Auswahl nach L&auml;ndern)</small></li>
			</ul><br>
	</li>
	<li> IPTV_XML (<a href="https://iptv.community/threads/epg.5423" target="_blank">IPTV.community</a>) </li>
	<li> teXXas.de - RSS (<a href="http://www.texxas.de/rss/" target="_blank">TV-Programm RSS Feed</a>) </li>
	<li> xmltv.se (<a href="https://xmltv.se" target="_blank">Provides XMLTV schedules for Europe</a>) </li>
	
</ul>
<br><br>

<b>Define</b><br>
	<ul><code>define &lt;NAME&gt; EPG</code></ul>
<br><br>

<b>Get</b><br>
	<ul>
		<a name="available_channels"></a>
		<li>available_channels: retrieves all available channels</li><a name=""></a>
		<a name="loadEPG_now"></a>
		<li>loadEPG_now: let the EPG data of the selected channels at the present time</li><a name=""></a>
		<a name="loadEPG_Prime"></a>
		<li>loadEPG_Prime: let the EPG data of the selected channels be at PrimeTime 20:15</li><a name=""></a>
		<a name="loadEPG_today"></a>
		<li>loadEPG_today: let the EPG data of the selected channels be from the current day</li><a name=""></a>
	</ul>
<br><br>

<b>Attribute</b><br>
	<ul><li><a href="#disable">disable</a></li></ul><br>
	<ul><li><a name="Ch_select">Ch_select</a><br>
	This attribute will be filled automatically after entering the control panel "<code>list of all available channels</code>" and defined the desired channels.<br>
	<i>Normally you do not have to edit this attribute manually.</i></li><a name=" "></a></ul><br>
	<ul><li><a name="Ch_sort">Ch_sort</a><br>
	This attribute will be filled automatically after entering the control panel "<code>list of all available channels</code>" and defined the desired new channelnumbre.<br>
	<i>Normally you do not have to edit this attribute manually. Once you clear this attribute, there is no manual sort!</i></li><a name=" "></a></ul><br>
	<ul><li><a name="DownloadFile">DownloadFile</a><br>
	File name of the desired file containing the information.</li><a name=" "></a></ul><br>
	<ul><li><a name="DownloadURL">DownloadURL</a><br>
	Website URL where the desired file is stored.</li><a name=" "></a></ul><br>
	<ul><li><a name="Variant">Variant</a><br>
	Processing variant according to which method the information is processed or read.</li><a name=" "></a></ul><br>
	<ul><li><a name="View_Subtitle">View_Subtitle</a><br>
	Displays additional information of the shipment as far as available.</li><a name=" "></a></ul>

=end html


=begin html_DE

<a name="EPG"></a>
<h3>EPG Modul</h3>
<ul>
Das EPG Modul holt die TV - Sendungsinformationen aus verschiedenen Quellen.<br>
Es handelt sich hiermit um einen Modul welches die Daten f&uuml;r einen elektronischen Programmf&uuml;hrer abruft und sofort darstellt. (Bsp: Alternative f&uuml;r HTTPMOD + Readingsgroup & weitere)<br><br>
<i>Je nach Quelle und Aufnahmeland k&ouml;nnen die Informationen bei Ihnen geringf&uuml;gig abweichen.<br> Jede Variante besitzt ihre eigene Einleseroutine. Beim bekanntwerden neuer Quellen kann das Modul jederzeit erweitert werden.</i>
<br><br>
Sie m&uuml;ssen sich f&uuml;r eine Quelle entscheiden und erst danach k&ouml;nnen Daten des TV-Guides dargestellt werden.<br>
Die Angaben f&uuml;r die Attribut Variante | DownloadFile und DownloadURL sind zwingend notwendig.
<br><br>
<ul><u>Derzeit werden folgende Dienste unterst&uuml;tzt:</u>
	<li>Rytec (Rytec EPG Downloader)<br><br>
			bekannte Quellen:<br>
			<ul>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_Basic.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_Common.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_SportMovies.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://www.vuplus-community.net/rytec/rytecDE_Basic.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li>http://www.vuplus-community.net/rytec/rytecDE_Common.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li>http://www.vuplus-community.net/rytec/rytecDE_SportMovies.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li>http://www.xmltvepg.nl/rytecDE_Basic.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li>http://www.xmltvepg.nl/rytecDE_Common.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li>http://www.xmltvepg.nl/rytecDE_SportMovies.xz <small>&nbsp;&nbsp;(&#10003;)</small></li>
				<li><a href="http://rytecepg.epgspot.com/epg_data/" target=”_blank”>http://rytecepg.epgspot.com/epg_data/</a> <small>&nbsp;&nbsp;(&#10003; - Auswahl nach L&auml;ndern)</small></li>
				<li><a href="https://rytec.ricx.nl/epg_data/" target=”_blank”>https://rytec.ricx.nl/epg_data/</a> <small>&nbsp;&nbsp;(&#10003; - Auswahl nach L&auml;ndern)</small></li>
			</ul><br>
	</li>
	<li> IPTV_XML (<a href="https://iptv.community/threads/epg.5423" target="_blank">IPTV.community</a>) </li>
	<li> teXXas (<a href="http://www.texxas.de/rss/" target="_blank">teXXas.de - TV-Programm RSS Feed</a>) </li>
	<li> xmltv.se (<a href="https://xmltv.se" target="_blank">Provides XMLTV schedules for Europe</a>) </li>
	
</ul>
<br><br>

<b>Define</b><br>
	<ul><code>define &lt;NAME&gt; EPG</code></ul>
<br><br>

<b>Get</b><br>
	<ul>
		<a name="available_channels"></a>
		<li>available_channels: ruft alle verf&uuml;gbaren Kan&auml;le ab</li><a name=""></a>
		<a name="loadEPG_now"></a>
		<li>loadEPG_now: l&auml;d die EPG-Daten der ausgew&auml;hlten Kan&auml;le vom jetzigen Zeitpunkt</li><a name=""></a>
		<a name="loadEPG_Prime"></a>
		<li>loadEPG_Prime: l&auml;d die EPG-Daten der ausgew&auml;hlten Kan&auml;le von der PrimeTime 20:15Uhr</li><a name=""></a>
		<a name="loadEPG_today"></a>
		<li>loadEPG_today: l&auml;d die EPG-Daten der ausgew&auml;hlten Kan&auml;le vom aktuellen Tag</li><a name=""></a>
	</ul>
<br><br>

<b>Attribute</b><br>
	<ul><li><a href="#disable">disable</a></li></ul><br>
	<ul><li><a name="Ch_select">Ch_select</a><br>
	Dieses Attribut wird automatisch gef&uuml;llt nachdem man im Control panel mit "<code>list of all available channels</code>" die gew&uuml;nschten Kan&auml;le definierte.<br>
	<i>Im Normalfall muss man dieses Attribut nicht manuel bearbeiten.</i></li><a name=" "></a></ul><br>
	<ul><li><a name="Ch_sort">Ch_sort</a><br>
	Dieses Attribut wird automatisch gef&uuml;llt nachdem man im Control panel mit "<code>list of all available channels</code>" die gew&uuml;nschte neue Kanalnummer definierte.<br>
	<i>Im Normalfall muss man dieses Attribut nicht manuel bearbeiten. Sobald man dieses Attribut l&ouml;scht, ist keine manuelle Sortierung vorhanden!</i></li><a name=" "></a></ul><br>
	<ul><li><a name="DownloadFile">DownloadFile</a><br>
	Dateiname von der gew&uuml;nschten Datei welche die Informationen enth&auml;lt.</li><a name=" "></a></ul><br>
	<ul><li><a name="DownloadURL">DownloadURL</a><br>
	Webseiten URL wo die gew&uuml;nschten Datei hinterlegt ist.</li><a name=" "></a></ul><br>
	<ul><li><a name="Variant">Variant</a><br>
	Verarbeitungsvariante, nach welchem Verfahren die Informationen verarbeitet oder gelesen werden.</li><a name=" "></a></ul><br>
	<ul><li><a name="View_Subtitle">View_Subtitle</a><br>
	Zeigt Zusatzinformation der Sendung an soweit verf&uuml;gbar.</li><a name=" "></a></ul>

=end html_DE

# Ende der Commandref
=cut
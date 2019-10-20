#################################################################
# $Id: 66_EPG.pm 15699 2019-10-19 21:17:50Z HomeAuto_User $
#
# Github - FHEM Home Automation System
# https://github.com/fhem/EPG
#
# 2019 - HomeAuto_User & elektron-bbs
#################################################################

package main;

use strict;
use warnings;
use HttpUtils;					# https://wiki.fhem.de/wiki/HttpUtils
use Data::Dumper;

my $missingModulEPG = "";
eval "use XML::Simple;1" or $missingModulEPG .= "XML::Simple (cpanm XML::Simple)";
my @channel_available;
my %progamm;
my %HTML;

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
	$hash->{AttrList}              =	"disable DownloadURL DownloadFile Variant:Ryteg Channels";
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
	my $cmd2 = $a[0];
	my $getlist = "loadFile:noArg ";
	my $Channels = AttrVal($name, "Channels", undef);
	my $DownloadURL = AttrVal($name, "DownloadURL", undef);
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);
	my $Variant = AttrVal($name, "Variant", undef);
	my $TimeNow = FmtDateTime(time());
	
	if ($Variant && $Variant eq "Ryteg") {
		$getlist.= "available_channels:noArg " if (-e "/opt/fhem/FHEM/EPG/".substr($DownloadFile,0,-3) && $DownloadURL && $DownloadFile);	
	}

	if (AttrVal($name, "Channels", undef) && scalar(@channel_available) > 0 && AttrVal($name, "Channels", undef) ne "" && AttrVal($name, "Variant", undef)) {
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

	my $obj;
	my $state;
	my $xml;

	if ($cmd ne "?") {
		Log3 $name, 4, "$name: Get | $cmd";	
		return "ERROR: no Attribute Variant defined - Please check!" if (!$Variant);
		return "ERROR: no Attribute DownloadURL or DownloadFile defined - Please check!" if (!$DownloadURL || !$DownloadFile);
		return "ERROR: you need ".$missingModulEPG."package to use this command!" if ($missingModulEPG ne "");
		return "ERROR: You need the directory ./FHEM/EPG to download!" if (! -d "FHEM/EPG");
	}

	if ($cmd eq "loadFile") {
		EPG_PerformHttpRequest($hash);
		Log3 $name, 4, "$name: Get | $cmd successful";
		return undef;
	}

	if ($Variant && $Variant eq "Ryteg") {
		$DownloadFile = substr($DownloadFile,0,index($DownloadFile,".")) if (index($DownloadFile,".") != 0);
		my $ch_id;

		if ($cmd eq "available_channels") {
			Log3 $name, 4, "$name: Get | $cmd read file $DownloadFile";
			@channel_available = ();
			%progamm = ();
			
			if (-e "/opt/fhem/FHEM/EPG/$DownloadFile") {
				open (FileCheck,"</opt/fhem/FHEM/EPG/$DownloadFile");
					while (<FileCheck>) {
						$ch_id = $1 if ($_ =~ /<channel id="(.*)">/);
						if ($_ =~ /<display-name lang=".*">(.*)<.*/) {
							Log3 $name, 4, "$name: Get | $cmd id: $ch_id -> display_name: ".$1;
							$progamm{$ch_id}{name} = $1;
							push(@channel_available,$1);
						}
					}
				close FileCheck;

				@channel_available = sort @channel_available;
				$state = "available channels loaded";
				readingsSingleUpdate($hash, "state", $state, 1);
				FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "location.reload('true')", "");
			} else {
				$state = "ERROR: $Variant Canceled";
				Log3 $name, 3, "$name: $cmd | error, file $DownloadFile no found at ./opt/fhem/FHEM/EPG";
				return "ERROR: no file found!";
			}
			return undef;
		}

		if ($cmd =~ /^loadEPG/) {
			%HTML = ();           # reset hash for HTML
			my $start = "";       # TV time start
			my $end = "";         # TV time end
			my $ch_found = 0;     # counter to verification ch
			my $data_found = 0;   # counter to verification data
			my $ch_name = "";     # TV channel name
			my $title = "";       # TV title
			my $subtitle = "";    # TV subtitle
			my $desc = "";        # TV desc
			my $today_start = ""; # today time start
			my $today_end = "";   # today time end

			Log3 $name, 4, "$name: Get | $cmd from file";

			$TimeNow =~ s/-|:|\s//g;
			$TimeNow.= " +0200";                                     # loadEPG_now   20191016150432 +0200

			if ($cmd eq "loadEPG_Prime") {
				if (substr($TimeNow,8, 2) > 20) {                      # loadEPG_Prime 20191016201510 +0200	morgen wenn Prime derzeit läuft
					my @time = split(/-\s:/,FmtDateTime(time()));
					$TimeNow = FmtDateTime(time() - ($time[5] + $time[4] * 60 + $time[3] * 3600) + 86400);
					$TimeNow =~ s/-|:|\s//g;
					$TimeNow.= " +0200";
					substr($TimeNow, 8) = '201510 +0200';
				} else {                                               # loadEPG_Prime 20191016201510 +0200	heute
					substr($TimeNow, 8) = '201510 +0200';
				}
			}
			
			if ($cmd eq "loadEPG_today") {                           # Beginn und Ende von heute bestimmen
				$today_start = substr($TimeNow,0,8)."000000 +0200";
				$today_end = substr($TimeNow,0,8)."235959 +0200";
			}

			if ($cmd eq "loadEPG" && $cmd2 =~ /^[0-9]*_[0-9]*$/) {   # loadEPG 20191016_200010 +0200 stündlich ab jetzt
				$cmd2 =~ s/_//g;
				$cmd2.= '10 +0200';
				$TimeNow = $cmd2;
			}

			if (-e "/opt/fhem/FHEM/EPG/$DownloadFile") {
				open (FileCheck,"</opt/fhem/FHEM/EPG/$DownloadFile");
					while (<FileCheck>) {
						if ($_ =~ /<programme start="(.*)" stop="(.*)" channel="(.*)"/) {   ## find start | end | channel
							my $search = $progamm{$3}->{name};
							if (grep /$search($|,)/, $Channels) {                             ## find in attributes channel
								if ($cmd ne "loadEPG_today") { 
									if ($TimeNow gt $1 && $TimeNow lt $2) {                       ## Zeitpunktsuche, normal
										($start, $end, $ch_name) = ($1, $2, $progamm{$3}->{name});
										$ch_found++;
									}								
								} else {                                                        ## Zeitpunktsuche, kompletter Tag
									if ($today_end gt $1 && $today_start lt $2) {
										($start, $end, $ch_name) = ($1, $2, $progamm{$3}->{name});
										$ch_found++;
									}								
								}
							}
						}
						$title = $2 if ($_ =~ /<title lang="(.*)">(.*)<\/title>/ && $ch_found != 0);             ## find title
						$subtitle = $2 if ($_ =~ /<sub-title lang="(.*)">(.*)<\/sub-title>/ && $ch_found != 0);  ## find subtitle
						$desc = $2 if ($_ =~ /<desc lang="(.*)">(.*)<\/desc>/ && $ch_found != 0);                ## find desc

						if ($_ =~ /<\/programme>/ && $ch_found != 0) {   ## find end channel
							$data_found++;
							$HTML{$ch_name}{$data_found}{ch_name} = $ch_name;
							Log3 $name, 4, "$name: $cmd | ch_name  -> $ch_name";
							$HTML{$ch_name}{$data_found}{start} = $start;
							Log3 $name, 4, "$name: $cmd | start    -> $start";
							$HTML{$ch_name}{$data_found}{end} = $end;
							Log3 $name, 4, "$name: $cmd | end      -> $end";
							$HTML{$ch_name}{$data_found}{title} = $title;
							Log3 $name, 4, "$name: $cmd | title    -> $title";
							$HTML{$ch_name}{$data_found}{subtitle} = $subtitle;
							Log3 $name, 4, "$name: $cmd | subtitle -> $subtitle";
							$HTML{$ch_name}{$data_found}{desc} = $desc;
							Log3 $name, 4, "$name: $cmd | desc     -> $desc.\n";

							$ch_found = 0;
							$ch_name = "";
							$title = "";
							$subtitle = "";
							$desc = "";
						}
					}
				close FileCheck;

				$hash->{STATE_data} = "all channel information loaded" if ($data_found != 0);
				$hash->{STATE_data} = "no channel information available!" if ($data_found == 0);
			} else {
				readingsSingleUpdate($hash, "state", "ERROR: loaded Information Canceled. file not found!", 1);
				Log3 $name, 3, "$name: $cmd | error, file $DownloadFile no found at ./opt/fhem/FHEM/EPG";
				return "ERROR: no file found!";
			}
			
			#Log3 $name, 3, "$name: ".Dumper\%HTML;
			FW_directNotify("FILTER=(room=)?$name", "#FHEMWEB:WEB", "location.reload('true')", "") if (scalar keys %HTML  != 0);
			return undef;
		}
	}
	return "Unknown argument $cmd, choose one of $getlist";
}

#####################
sub EPG_Attr() {
	my ($cmd, $name, $attrName, $attrValue) = @_;
	my $hash = $defs{$name};
	my $typ = $hash->{TYPE};

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
	}
}

#####################
sub EPG_FW_Detail($@) {
	my ($FW_wname, $name, $room, $pageHash) = @_;
	my $hash = $defs{$name};
	my $Channels = AttrVal($name, "Channels", undef);
	my $cnt = 0;
	my $ret = "";
	
	Log3 $name, 4, "$name: FW_Detail is running";

	if ($Channels) {
		my @Channels_value = split(",", $Channels);
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
							var allVals = [];
							$("#EPG_ListWindow input:checkbox:checked").each(function() {
							allVals.push($(this).attr(\'name\'));
							})
							FW_cmd(FW_root+ \'?XHR=1"'.$FW_CSRF.'"&cmd={EPG_FW_Attr_Channels("'.$name.'","\'+allVals+\'")}\');

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
		
		$ret .= "<div id=\"table\"><center>- no EPG Data -</center></div>" if (scalar keys %HTML  == 0);
		if (scalar keys %HTML != 0) {
			my $ch_name = "";
			my $start = "";
			my $end = "";
			my $title = "";
			my $subtitle = "";
			my $desc = "";
			my $cnt_infos = 0;

			$ret .= "<div id=\"table\"><table class=\"block wide\">";
			$ret .= "<tr class=\"even\" style=\"text-decoration:underline; text-align:left;\"><th>Sender</th><th>Start</th><th>Ende</th><th>Sendung</th></tr>";
	
			foreach my $ch (sort keys %HTML) {
				foreach my $value (sort {$a <=> $b} keys %{$HTML{$ch}}) {
					foreach my $d (keys %{$HTML{$ch}{$value}}) {
						$ch_name = $HTML{$ch}{$value}{$d} if ($d eq "ch_name");
						$start = substr($HTML{$ch}{$value}{$d},8,2).":".substr($HTML{$ch}{$value}{$d},10,2) if ($d eq "start");
						$end = substr($HTML{$ch}{$value}{$d},8,2).":".substr($HTML{$ch}{$value}{$d},10,2) if ($d eq "end");
						$title = $HTML{$ch}{$value}{$d} if ($d eq "title");
						$desc = $HTML{$ch}{$value}{$d} if ($d eq "desc");					
					}
					$cnt_infos++;
					## Darstellung als Link wenn Sendungsbeschreibung ##
					$ret .= sprintf("<tr class=\"%s\">", ($cnt_infos & 1)?"odd":"even");
					if ($desc ne "") {
						#Log3 $name, 3, "$name: $desc";
						$desc =~ s/"/&quot;/g if (grep /"/, $desc);  # "
						$desc =~ s/'/\\'/g if (grep /'/, $desc);     # '
						$ret .= "<td>$ch_name</td><td>$start</td><td>$end</td><td><a href=\"#!\" onclick=\"FW_okDialog(\'$desc\')\">$title</a></td></tr>";
					} else {
						$ret .= "<td>$ch_name</td><td>$start</td><td>$end</td><td>$title</td></tr>";
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
	my $Channels = AttrVal($name, "Channels", undef);
	my $checked = "";
	my $style_background = "";

	Log3 $name, 4, "$name: FW_Channels is running";

	$ret.= "<table>";
	$ret.= "<tr style=\"text-decoration-line: underline;\"><td>no.</td><td>active</td><td>TV station name</td></tr>";

	for (my $i=0; $i<scalar(@channel_available); $i++) {
		$style_background = "background-color:#F0F0D8;" if ($i % 2 == 0);
		$style_background = "" if ($i % 2 != 0);
		$checked = "checked" if ($Channels && index($Channels,$channel_available[$i]) >= 0);
		$ret.= "<tr style=\"$style_background\"><td align=\"center\">".($i + 1)."</td><td align=\"center\"><input type=\"checkbox\" id=\"".$i."\" name=\"".$channel_available[$i]."\" onclick=\"Checkbox(".$i.")\" $checked></td><td>". $channel_available[$i] ."</td></tr>";
		$checked = "";
	}
	
	$ret.= "</table>";

	return $ret;
}

##################### (Anpassung Attribute Channels)
sub EPG_FW_Attr_Channels {
	my $name = shift;
	my $hash = $defs{$name};
	my $Channels = shift;

	Log3 $name, 4, "$name: FW_Attr_Channels is running";
	CommandAttr($hash,"$name Channels $Channels") if ($Channels ne "");
	CommandDeleteAttr($hash,"$name Channels") if ($Channels eq "");
}

#####################
sub EPG_PerformHttpRequest($) {
	my ($hash, $def) = @_;
	my $name = $hash->{NAME};
	my $DownloadURL = AttrVal($name, "DownloadURL", undef);
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);

	Log3 $name, 4, "$name: EPG_PerformHttpRequest is running";
	my $http_param = { 	url        => $DownloadURL.$DownloadFile,
											timeout    => 5,
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
	my $Variant = AttrVal($name, "Variant", undef);
	my $HttpResponse = "";
	my $state = "no information received";
	my $reload = 0;
	my $FileDate = undef;

	Log3 $name, 5, "$name: EPG_ParseHttpResponse - error: $err";
	Log3 $name, 5, "$name: EPG_ParseHttpResponse - http code: ".$http_param->{code};

	if ($err ne "") {                                                          # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
		$HttpResponse = $err;
		Log3 $name, 3, "$name: EPG_ParseHttpResponse - error: $err";
	} elsif ($http_param->{code} ne "200") {                                   # HTTP code
		$HttpResponse = "DownloadFile $DownloadFile was not found on URL" if (grep /$DownloadFile\swas\snot\sfound/, $data);
		$HttpResponse = "DownloadURL was not found" if (grep /URL\swas\snot\sfound/, $data);
		Log3 $name, 3, "$name: EPG_ParseHttpResponse - error:\n\n$data";
	} elsif ($http_param->{code} eq "200" && $data ne "") {                    # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
   	my $filename = "FHEM/EPG/$DownloadFile";
		open(my $file, ">", $filename);                                          # Datei schreiben
			print $file $data;
		close $file;

		if ($Variant eq "Ryteg") {
			if ($DownloadFile =~ /.*\.xz$/) {
				qx(xz -df /opt/fhem/FHEM/EPG/$DownloadFile 2>&1);                    # Datei Unpack
				$DownloadFile = substr($DownloadFile,0,-3);                          # Dateiname nach Unpack
			}
		}

		my @stat_DownloadFile = stat("/opt/fhem/FHEM/EPG/".$DownloadFile);       # Datei Eigenschaften
		$FileDate = FmtDateTime($stat_DownloadFile[9]);                          # Letzte Änderungszeit
		$HttpResponse = "downloaded";
		$state = "information received";
		$reload++;
	}
	
	FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "location.reload('true')", "") if ($reload != 0);

	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash, "HttpResponse", $HttpResponse);                  # HttpResponse Status
	readingsBulkUpdate($hash, "DownloadFile_date", $FileDate) if ($FileDate);  # Letzte Änderungszeit
	readingsBulkUpdate($hash, "state", $state);
	readingsEndUpdate($hash, 1);

	HttpUtils_Close($http_param);
}

#####################
sub EPG_Notify($$) {
	my ($hash, $dev_hash) = @_;
	my $name = $hash->{NAME};
	my $typ = $hash->{TYPE};
	return "" if(IsDisabled($name));	                                         # Return without any further action if the module is disabled
	my $devName = $dev_hash->{NAME};	                                         # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	my $Variant = AttrVal($name, "Variant", undef);
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);

	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}) && $typ eq "EPG") {
		Log3 $name, 5, "$name: Notify is running and starting $name";

		if($Variant) {
			my $FileDate = "not known";

			if ($Variant eq "Ryteg" && $DownloadFile) {
				if (-e "/opt/fhem/FHEM/EPG/".substr($DownloadFile,0,-3)) {
					my @stat_DownloadFile = stat("/opt/fhem/FHEM/EPG/".substr($DownloadFile,0,-3));  # Datei eigenschaften
					$FileDate = FmtDateTime($stat_DownloadFile[9]);                                  # Letzte Änderungszeit
				}
				readingsSingleUpdate($hash, "DownloadFile_date", $FileDate, 0);
			}
		}
	}

	return undef;
}

# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;


# Beginn der Commandref

=pod
=item [helper|device|command]
=item summary Kurzbeschreibung in Englisch was MYMODULE steuert/unterstützt
=item summary_DE Kurzbeschreibung in Deutsch was MYMODULE steuert/unterstützt

=begin html

<a name="EPG"></a>
<h3>EPG modul</h3>
<ul>
This is an example web module.<br>
</ul>
=end html


=begin html_DE

<a name="EPG"></a>
<h3>EPG Modul</h3>
<ul>
Das ist ein BeispielWeb Modul.<br><br>

http://www.vuplus-community.net/rytec/rytecDE_Basic.xz<br>
http://www.xmltvepg.nl/rytecDE_Basic.xz<br>
http://91.121.106.172/~rytecepg/epg_data/rytecDE_Basic.xz<br>
http://www.vuplus-community.net/rytec/rytecDE_Common.xz<br>
http://www.xmltvepg.nl/rytecDE_Common.xz<br>
http://91.121.106.172/~rytecepg/epg_data/rytecDE_Common.xz<br>
http://www.vuplus-community.net/rytec/rytecDE_SportMovies.xz<br>
http://www.xmltvepg.nl/rytecDE_SportMovies.xz<br>
http://91.121.106.172/~rytecepg/epg_data/rytecDE_SportMovies.xz<br>

</ul>
=end html_DE

# Ende der Commandref
=cut
#################################################################
# $Id: 66_EPG.pm 15699 2019-12-13 00:01:50Z HomeAuto_User $
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
# Note´s
# - ??? input EPG filtre s/["`;']//g;
# - !!! Umlaute Readings
#
# Features:
# - definierbare CommandFunktion bei Onklick
#################################################################

package main;

use strict;
use warnings;

use HttpUtils;					# https://wiki.fhem.de/wiki/HttpUtils
use Data::Dumper;

my %EPG_transtable_EN = ( 
		## Days ##
		"day0"                =>  "Sunday",
		"day1"                =>  "Monday",
		"day2"                =>  "Tuesday",
		"day3"                =>  "Wednesday",
		"day4"                =>  "Thursday",
		"day5"                =>  "Friday",
		"day6"                =>  "Saturday",
		## Months ##
		"months1"             =>  "January",
		"months2"             =>  "February",
		"months3"             =>  "March",
		"months4"             =>  "April",
		"months5"             =>  "May",
		"months6"             =>  "June",
		"months7"             =>  "July",
		"months8"             =>  "August",
		"months9"             =>  "September",
		"months10"            =>  "October",
		"months11"            =>  "November",
		"months12"            =>  "December",
		## EPG_Get ##
		"get_available_ch"    =>  "available_channels search",
		"get_loadEPG"         =>  "accomplished",
		## EPG_FW_Detail ##
		"control_pan_btn"     =>  "list of all available channels",
    "broadcast"           =>  "Broadcast",
    "channel"             =>  "Channel",
    "control_pan"         =>  "Control panel",
    "description"         =>  "Description",
    "end"                 =>  "End",
    "epg_info"            =>  "no EPG Data",
    "read_ch"             =>  "readed channels",
    "select_ch"           =>  "selected channels",
    "start"               =>  "Start",
    "date"                =>  "Date",
		## EPG_FW_Popup_Channels ##
    "active"              =>  "active",
    "no"                  =>  "no.",
    "tv_fav"              =>  "FAV",
    "tv_name"             =>  "TV station name",
		## EPG_FW_set_Attr_Channels ##
    "set_Attr_Ch_eq"      =>  "no channel selected",
    "set_Attr_Ch_state"   =>  "EPG available with get loadEPG command",
		## EPG_ParseHttpResponse ##
    "ParseHttp_state1"    =>  "no information received",
		"ParseHttp_state2"    =>  "downloading not finish in the maximum time from HTTP_TimeOut",
		"ParseHttp_state_ok"  =>  "data received",
		"ParseHttp_gz_error"  =>  "ERROR: unpack gz failed,",
		"ParseHttp_xz_error"  =>  "ERROR: unpack xz failed,",
		"ParseHttp_Http_ok"   =>  "downloaded",
		"ParseHttp_Http_URL"  =>  "DownloadURL was not found",
		"ParseHttp_Http_file" =>  "DownloadFile was not found on URL",
		## EPG_File_check ##
		"File_check_fileage"  =>  "unknown",
		"File_check_DownFile" =>  "file not found",
		## EPG_nonBlock_available_channels ##
		"available_ch_ok"     =>  "ERROR: EPG_file no found at ./FHEM/EPG",
    ## EPG_nonBlock_available_channelsDone ##
		"chDone_state1"       =>  "unknown methode, need development",
		"chDone_msg_OK"       =>  "EPG available with get loadEPG command!",
		"chDone_msg_OK2"      =>  "available_channels loaded, Please select channel on Control panel",
		## EPG_nonBlock_loadEPG_v1Done ##
		"loadEPG_v1Done"      =>  "decode_json failed, use verbose 5 to view more",
		## EPG_nonBlock_loadEPG ##
		"loadEPG_msg1"        =>  "all EPG channel information loaded",
		"loadEPG_msg2"        =>  "no EPG channel information available",
		"loadEPG_msg3"        =>  "ERROR: loaded Information canceled, file not found",
		## EPG_nonBlock_abortFn ##
		"nonBlock_abortFn"    =>  "timeout nonBlock function"
		);
    
 my %EPG_transtable_DE = ( 
		## Days ##
		"day0"                =>  "Sonntag",
		"day1"                =>  "Montag",
		"day2"                =>  "Dienstag",
		"day3"                =>  "Mittwoch",
		"day4"                =>  "Donnerstag",
		"day5"                =>  "Freitag",
		"day6"                =>  "Sonnabend",
		## Months ##
		"months1"             =>  "Januar",
		"months2"             =>  "Februar",
		"months3"             =>  "März",
		"months4"             =>  "April",
		"months5"             =>  "Mai",
		"months6"             =>  "Juni",
		"months7"             =>  "Juli",
		"months8"             =>  "August",
		"months9"             =>  "September",
		"months10"            =>  "Oktober",
		"months11"            =>  "November",
		"months12"            =>  "Dezember",
		## EPG_Get ##
		"get_available_ch"    =>  "verfügbare Kanäle werden gesucht",
		"get_loadEPG"         =>  "angenommen",
		## EPG_FW_Detail ##
		"control_pan_btn"     =>  "Liste der verfügbaren Kanäle",
    "broadcast"           =>  "Sendung",
    "channel"             =>  "Sender",
    "control_pan"         =>  "Bedienfeld",
    "description"         =>  "Beschreibung",
    "end"                 =>  "Ende",
    "epg_info"            =>  "keine EPG Daten",
    "read_ch"             =>  "eingelesene Kanäle",
    "select_ch"           =>  "ausgewählte Kanäle",
    "start"               =>  "Start",
    "date"                =>  "Datum",
		## EPG_FW_Popup_Channels ##
    "active"              =>  "aktiv",
    "no"                  =>  "Nr.",
    "tv_fav"              =>  "FAV",
    "tv_name"             =>  "TV Sendername",
		## EPG_FW_set_Attr_Channels ##
    "set_Attr_Ch_eq"      =>  "keinen Kanal ausgewählt",
    "set_Attr_Ch_state"   =>  "EPG verfügbar mit dem Befehl get loadEPG",
		## EPG_ParseHttpResponse ##
    "ParseHttp_state1"    =>  "keine Informationen erhalten",
		"ParseHttp_state2"    =>  "Der Download ist nicht in der maximalen Zeit von HTTP_TimeOut beendet.",
		"ParseHttp_state_ok"  =>  "Daten empfangen",
		"ParseHttp_gz_error"  =>  "ERROR: unpack gz fehlgeschlagen,",
		"ParseHttp_xz_error"  =>  "ERROR: unpack xz fehlgeschlagen,",
		"ParseHttp_Http_ok"   =>  "heruntergeladen",
		"ParseHttp_Http_URL"  =>  "DownloadURL wurde nicht gefunden",
		"ParseHttp_Http_file" =>  "DownloadFile wurde in der URL nicht gefunden",
		## EPG_File_check ##
		"File_check_fileage"  =>  "unbekannt",
		"File_check_DownFile" =>  "Datei nicht gefunden",
		## EPG_nonBlock_available_channels ##
		"available_ch_ok"     =>  "ERROR: EPG Datei nicht gefunden in ./FHEM/EPG",
    ## EPG_nonBlock_available_channelsDone ##
		"chDone_state1"       =>  "unbekannte Methode, Entwicklung notwendig",
		"chDone_msg_OK"       =>  "EPG mit get loadEPG Befehlen verfügbar",
		"chDone_msg_OK2"      =>  "verfügbaren Kanäle geladen! Bitte mit dem Bedienfeld Ihren Kanal auswählen.",
		## EPG_nonBlock_loadEPG_v1Done ##
		"loadEPG_v1Done"      =>  "decode_json fehlgeschlagen, bitte benutze verbose 5 um mehr zu erkennen",
		## EPG_nonBlock_loadEPG ##
		"loadEPG_msg1"        =>  "alle EPG Daten geladen",
		"loadEPG_msg2"        =>  "keine EPG Daten verfügbar",
		"loadEPG_msg3"        =>  "ERROR: Information laden abgebrochen, Datei nicht gefunden",
		## EPG_nonBlock_abortFn ##
		"nonBlock_abortFn"    =>  "Zeitüberschreitung nonBlock Funktion"
    );

my $EPG_tt;
my $missingModulEPG = "";
my $osname = $^O;
my $gzError;
my $xzError;

eval "use Encode qw(encode encode_utf8 decode_utf8);1" or $missingModulEPG .= "Encode || libencode-perl, ";
eval "use JSON;1" or $missingModulEPG .= "JSON || libjson-perl, ";
eval "use XML::Simple;1" or $missingModulEPG .= "XML::Simple || libxml-simple-perl, ";

my @tools = ("gzip","xz");
my @channel_available;
my $HTML = {};

#####################
sub EPG_Initialize($) {
	my ($hash) = @_;

	$hash->{AttrFn}                = "EPG_Attr";
	$hash->{DefFn}                 = "EPG_Define";
	$hash->{GetFn}                 = "EPG_Get";
	$hash->{NotifyFn}              = "EPG_Notify";
	$hash->{SetFn}                 = "EPG_Set";
	$hash->{UndefFn}               = "EPG_Undef";
  $hash->{FW_detailFn}           = "EPG_FW_Detail";
	$hash->{FW_deviceOverview}     = 1;
	$hash->{FW_addDetailToSummary} = 1;  # displays html in fhemweb room-view
	$hash->{AttrList}              =	"Ch_select Ch_sort Ch_Info_to_Reading:yes,no ".
                                    "DownloadFile DownloadURL HTTP_TimeOut ".
																		"FavoriteShows ".
                                    "Table:on,off Table_view_Subtitle:no,yes disable ".
                                    "Variant:Rytec,TvProfil_XMLTV,WebGrab+Plus,XMLTV.se,teXXas_RSS";
												             #$readingFnAttributes;

	## in any attribute redefinition readjust language ##
	my $lang = AttrVal("global","language","EN");
  if($lang eq "DE") {
		$EPG_tt = \%EPG_transtable_DE;
	} else {
		$EPG_tt = \%EPG_transtable_EN;
	}

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

	return "ERROR: you need ".$missingModulEPG."package to use this module" if ($missingModulEPG ne "");
	return "Usage: define <name> $name"  if(@arg != 2);

  ## readjust language ##
  my $lang = AttrVal("global","language","EN");
  if( $lang eq "DE"){
    $EPG_tt = \%EPG_transtable_DE;
  }else{
    $EPG_tt = \%EPG_transtable_EN;
  }

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

	$hash->{VERSION} = "20191209";

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
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);
	my $DownloadURL = AttrVal($name, "DownloadURL", undef);
	my $Variant = AttrVal($name, "Variant", "unknown");
	$cmd2 = "" if (!$cmd2);

	my $getlist = "loadFile:noArg ";
	$getlist.= "available_channels:noArg " if (ReadingsVal($name, "HttpResponse", undef) && 
	                                           ReadingsVal($name, "HttpResponse", undef) eq $EPG_tt->{"ParseHttp_Http_ok"} &&
                                             ReadingsVal($name, "EPG_file_name", undef) ne $EPG_tt->{"File_check_DownFile"});
	$getlist.= "loadEPG_Fav:noArg " if (AttrVal($name, "FavoriteShows", undef) && $Variant ne "unknown" &&
	                                    AttrVal($name, "Ch_select", undef) && AttrVal($name, "Ch_select", undef) ne "" &&
																	    scalar(@channel_available) > 0 ); # favorite shows

	if ($cmd ne "?") {
		return "ERROR: Attribute DownloadURL or DownloadFile not right defined - Please check!\n\n<u>example:</u>\n".
		"DownloadURL - http://rytecepg.epgspot.com/epg_data/\n".
		"DownloadFile - rytecAT_Basic.xz\n".
		"\nnote: The two attributes must be entered separately!" if (!$DownloadURL || !$DownloadFile);
		## check directory and create ##
		if (! -d "./FHEM/EPG") {
			my $ok = mkdir("FHEM/EPG");
			if ($ok == 1) {
				Log3 $name, 4, "$name: Get - directory automatic created ($!)"; 
			} else {
				Log3 $name, 4, "$name: Get - directory check - ERROR $ok";
			}
		}
	}

	if ($cmd eq "loadFile") {
		EPG_PerformHttpRequest($hash);
		return undef;
	}

	if ($cmd eq "available_channels") {
		Log3 $name, 4, "$name: get $cmd - starting File_check";
		EPG_File_check($hash);
		return "ERROR: no EPG_file found! Please use \"get $name loadFile\" and try again." if (not ReadingsVal($name, "EPG_file_name", undef));
		Log3 $name, 4, "$name: get $cmd - starting blocking call";
		@channel_available = ();

		readingsSingleUpdate($hash, "state", $EPG_tt->{"get_available_ch"}, 1);
    $hash->{helper}{RUNNING_PID} = BlockingCall("EPG_nonBlock_available_channels", $name."|".ReadingsVal($name, "EPG_file_name", undef), "EPG_nonBlock_available_channelsDone", 60 , "EPG_nonBlock_abortFn", $hash) unless(exists($hash->{helper}{RUNNING_PID}));
		return undef;
	}

	if ($Variant eq "Rytec" || $Variant eq "TvProfil_XMLTV" || $Variant eq "WebGrab+Plus" || $Variant eq "XMLTV.se") {
		if ( AttrVal($name, "Ch_select", undef) && AttrVal($name, "Ch_select", undef) ne "" && scalar(@channel_available) > 0 ) {
			$getlist.= "loadEPG_now:noArg ";               # now
			$getlist.= "loadEPG_Prime:noArg ";             # Primetime
			$getlist.= "loadEPG_today:noArg ";             # today all

			my $TimeNowMod = FmtDateTime(time());
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

		if ($cmd =~ /^loadEPG/ && $cmd ne "loadEPG_Fav") {
 			$HTML = {};
			readingsSingleUpdate($hash, "state", "$cmd ".$EPG_tt->{"get_loadEPG"}, 1);
			Log3 $name, 4, "$name: get $cmd - starting blocking call";

			$hash->{helper}{RUNNING_PID} = BlockingCall("EPG_nonBlock_loadEPG_v1", $name."|".ReadingsVal($name, "EPG_file_name", undef)."|".$cmd."|".$cmd2, "EPG_nonBlock_loadEPG_v1Done", 60 , "EPG_nonBlock_abortFn", $hash) unless(exists($hash->{helper}{RUNNING_PID}));
			return undef;
		}

		if ($cmd eq "loadEPG_Fav") {
			Log3 $name, 3, "$name: get $cmd - looking for favorite shows with $Variant";

			$hash->{helper}{RUNNING_PID} = BlockingCall("EPG_nonBlock_loadEPG_v1", $name."|".ReadingsVal($name, "EPG_file_name", undef)."|".$cmd."|".$cmd2, "EPG_nonBlock_loadEPG_v1Done", 60 , "EPG_nonBlock_abortFn", $hash) unless(exists($hash->{helper}{RUNNING_PID}));
			return undef;
		}
	}

	if ($Variant eq "teXXas_RSS" ) {
		if (AttrVal($name, "Ch_select", undef) && scalar(@channel_available) > 0 && AttrVal($name, "Ch_select", undef) ne "") {
			$getlist.= "loadEPG_now:noArg " if ($hash->{helper}{programm} && $hash->{helper}{programm} eq "now" && AttrVal($name, "Ch_select", undef) && AttrVal($name, "Ch_select", undef) ne "");
			$getlist.= "loadEPG_Prime:noArg " if ($hash->{helper}{programm} && $hash->{helper}{programm} eq "20:15" && AttrVal($name, "Ch_select", undef) && AttrVal($name, "Ch_select", undef) ne "");
		}
 		
		if ($cmd =~ /^loadEPG/ && $cmd ne "loadEPG_Fav") {
			$HTML = {};
			readingsSingleUpdate($hash, "state", "$cmd ".$EPG_tt->{"get_loadEPG"}, 1);
			Log3 $name, 4, "$name: get $cmd - starting blocking call";

			$hash->{helper}{RUNNING_PID} = BlockingCall("EPG_nonBlock_loadEPG_v2", $name."|".ReadingsVal($name, "EPG_file_name", undef)."|".$cmd."|".$cmd2, "EPG_nonBlock_loadEPG_v2Done", 60 , "EPG_nonBlock_abortFn", $hash) unless(exists($hash->{helper}{RUNNING_PID}));
			return undef;
		}
		
		if ($cmd eq "loadEPG_Fav") {
			Log3 $name, 3, "$name: get $cmd - looking for favorite shows with $Variant";
			return "still in development - $cmd on $Variant";
		}
	}

	return "Unknown argument $cmd, choose one of $getlist";
}

#####################
sub EPG_Attr() {
	my ($cmd, $name, $attrName, $attrValue) = @_;
	my $hash = $defs{$name};
	my $typ = $hash->{TYPE};

  ## in any attribute redefinition readjust language ##
  my $lang = AttrVal("global","language","EN");
  if( $lang eq "DE"){
    $EPG_tt = \%EPG_transtable_DE;
  } else {
    $EPG_tt = \%EPG_transtable_EN;
  }

	if ($cmd eq "set" && $init_done == 1 ) {
		if ($attrName eq "Ch_Info_to_Reading" && $attrValue eq "no") {
			EPG_readingsDeleteChannel($hash);
		}

		if ($attrName eq "DownloadURL") {
			return "Your website entry must end with /\n\nexample: $attrValue/" if ($attrValue !~ /.*\/$/);
			return "Your input must begin with http:// or https://" if ($attrValue !~ /^htt(p|ps):\/\//);
		}
		
		if ($attrName eq "HTTP_TimeOut") {
			return "to small (standard 10)" if ($attrValue < 5);
			return "to long (standard 10)" if ($attrValue > 90);
		}
	
	}
	
	if ($cmd eq "del") {
		if ($attrName eq "Variant") {
			delete $hash->{helper}{programm} if ($hash->{helper}{programm});
			return undef;
		}
		if ($attrName eq "Ch_Info_to_Reading") {
			EPG_readingsDeleteChannel($hash);
		}
	}
}

#####################
sub EPG_FW_Detail($@) {
	my ($FW_wname, $name, $room, $pageHash) = @_;
	my $hash = $defs{$name};
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my $Table = AttrVal($name, "Table", "on");
	my $Table_view_Subtitle = "";
	my $cnt_ch_select = 0;
	my $cnt_ch = 0;
	my $ret = "";
	my $HTML_switch = 0;
	my @Channels_value;

  ## readjust language ##
  my $lang = AttrVal("global","language","EN");
  if($lang eq "DE") {
    $EPG_tt = \%EPG_transtable_DE;
  } else {
    $EPG_tt = \%EPG_transtable_EN;
  }

	Log3 $name, 5, "$name: FW_Detail is running (Tableview=$Table, language=$lang)";
	Log3 $name, 5, "$name: FW_Detail - channel_available: ".scalar(@channel_available);

	if ($Ch_select) {
		@Channels_value = split(",", $Ch_select);
		$cnt_ch_select = scalar(@Channels_value);
		Log3 $name, 5, "$name: FW_Detail - channel_select: ".$cnt_ch_select;
	}

	if (scalar(@channel_available) > 0) {
		if ($FW_detail) {
			### Control panel ###
			$ret .= "<div class='makeTable wide'><span>".$EPG_tt->{"control_pan"}."</span>
							<table class='block wide' id='EPG_InfoMenue' nm='$hash->{NAME}' class='block wide'>
							<tr class='even'>";

			$ret .= "<td><a href='#button1' id='button1'>".$EPG_tt->{"control_pan_btn"}."</a></td>";
			$ret .= "<td>".$EPG_tt->{"read_ch"}.": ". scalar(@channel_available) ."</td>";
			$ret .= "<td>".$EPG_tt->{"select_ch"}.": ". $cnt_ch_select ."</td>";
			$ret .= "</tr></table></div>";
		}

		### Javascript ###
		$ret .= '
			<script>

			$( "#button1" ).click(function(e) {
				e.preventDefault();
				FW_cmd(FW_root+\'?cmd={EPG_FW_Popup_Channels("'.$name.'")}&XHR=1"'.$FW_CSRF.'"\', function(data){EPG_ListWindow(data)});
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
							FW_cmd(FW_root+ \'?XHR=1"'.$FW_CSRF.'"&cmd={EPG_FW_set_Attr_Channels("'.$name.'","\'+Channel+\'","\'+desired_channel+\'")}\');

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

			/* checkBox Werte von Checkboxen */
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
		return $ret if ($Table eq "off");
		$ret .= "<div><br></div>" if ($FW_detail eq "");

		foreach my $d (keys %{$HTML}) {
			if ($HTML->{$d}{EPG}) {
				$cnt_ch++;
				Log3 $name, 5, "$name: FW_Detail - found information for channel ".$d;
				$HTML_switch++ if (exists $HTML->{$d}{title_wish});
				#Log3 $name, 5, "$name: FW_Detail Dumper: ".Dumper\$HTML;
			}
		}

		$ret .= "<div id=\"table\"><center>- ".$EPG_tt->{"epg_info"}." -</center></div>" if not ($Ch_select && $cnt_ch != 0);
		#Log3 $name, 3, "$name: FW_Detail Dumper: ".Dumper\$HTML;

		if ($Ch_select && $cnt_ch != 0) {
			my $cnt_infos = 0;
			my $date;
			my $desc = "";
			my $end = "";
			my $start = "";
			my $subtitle = "";
			my $title = "";

			$Table_view_Subtitle = "<th>".$EPG_tt->{"description"}."</th>" if (AttrVal($name, "Table_view_Subtitle", "no") eq "yes");
			$ret .= "<div id=\"table\"><table class=\"block wide\">";

			if ($HTML_switch == 0) { # other view if loadEPG_Fav
				my ($sec,$min,$hour,$mday,$mon,$year,$wday,$ydat,$isdst) = localtime();
				#Log3 $name, 3, "$name: FW_Detail sec:$sec, min:$min, hour:$hour, mday:$mday, mon:$mon, year:$year, wday:$wday, ydat:$ydat, isdst:$isdst";
				$date = $EPG_tt->{"day".$wday}.", ".sprintf("%02s",$mday)." ".$EPG_tt->{"months".($mon + 1)}." ".($year + 1900);

				$ret .= "<tr class=\"even\" style=\"text-decoration:underline; text-align:left;\"><th>".$EPG_tt->{"channel"}."</th><th>".$EPG_tt->{"start"}."</th><th>".$EPG_tt->{"end"}."</th><th>".$EPG_tt->{"broadcast"}."<small> (".$date.")</small></th>".$Table_view_Subtitle."</tr>";
			} else {
				$ret .= "<tr class=\"even\" style=\"text-decoration:underline; text-align:left;\"><th>".$EPG_tt->{"channel"}."</th><th>".$EPG_tt->{"date"}."</th><th>".$EPG_tt->{"start"}."</th><th>".$EPG_tt->{"end"}."</th><th>".$EPG_tt->{"broadcast"}."</th>".$Table_view_Subtitle."</tr>";
			}

			my @positioned = sort { $HTML->{$a}{ch_wish} <=> $HTML->{$b}{ch_wish} or lc ($HTML->{$a}{ch_name}) cmp lc ($HTML->{$b}{ch_name}) } keys %$HTML;

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
						if ($d eq "start") {
							$start = substr($value->{$d},8,2).":".substr($value->{$d},10,2);
							my ($sec,$min,$hour,$mday,$mon,$year) = (substr($value->{$d},12,2),substr($value->{$d},10,2),substr($value->{$d},8,2),substr($value->{$d},6,2),substr($value->{$d},4,2) - 1,substr($value->{$d},0,4) - 1900);
							my $timestamp = fhemTimeGm($sec, $min, $hour, $mday, $mon, $year);
							my $wday;
							($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime($timestamp);
							$date = $EPG_tt->{"day".$wday}.", ".sprintf("%02s",$mday)." ".$EPG_tt->{"months".($mon + 1)}." ".($year + 1900);
						}

						$end = substr($value->{$d},8,2).":".substr($value->{$d},10,2) if ($d eq "end");
						$title = $value->{$d} if ($d eq "title");
						$desc = $value->{$d} if ($d eq "desc");
						$subtitle = $value->{$d} if ($d eq "subtitle");
					}
					$cnt_infos++;
					## Darstellung als Link wenn Sendungsbeschreibung ##
					$ret .= sprintf("<tr class=\"%s\">", ($cnt_infos & 1)?"odd":"even");
					$Table_view_Subtitle = "<td>$subtitle</td>" if (AttrVal($name, "Table_view_Subtitle", "no") eq "yes");

					if ($desc ne "") {
						#$desc =~ s/"/&quot;/g if (grep /"/, $desc);  # "
						#$desc =~ s/'/\\'/g if (grep /'/, $desc);     # '

						$desc =~ s/<br>/\n/g;
						$desc =~ s/(.{1,65}|\S{66,})(?:\s[^\S\r\n]*|\Z)/$1<br>/g; 
						$desc =~ s/[\r\'\"]/ /g;
						$desc =~ s/[\n]|\\n/<br>/g;

						$ret .= "<td>$ch</td><td>$start</td><td>$end</td><td><a href=\"#!\" onclick=\"FW_okDialog(\'$desc\')\">$title</a></td>$Table_view_Subtitle</tr>" if ($HTML_switch == 0);
						$ret .= "<td>$ch</td><td>".$date."</td><td>$start</td><td>$end</td><td><a href=\"#!\" onclick=\"FW_okDialog(\'$desc\')\">$title</a></td>$Table_view_Subtitle</tr>" if ($HTML_switch != 0);
						### TEST ###
						#$ret .= "<td>".FW_makeImage('tvmovie/tvlogo_ard_b')."</td><td>$start</td><td>$end</td><td><a href=\"#!\" onclick=\"FW_okDialog(\'$desc\')\">$title</a></td>$Table_view_Subtitle</tr>";
						### TEST ###
					} else {
						$ret .= "<td>$ch</td><td>$start</td><td>$end</td><td>$title</td>$Table_view_Subtitle</tr>" if ($HTML_switch == 0);
						$ret .= "<td>$ch</td><td>".$date."</td><td>$start</td><td>$end</td><td>$title</td>$Table_view_Subtitle</tr>" if ($HTML_switch != 0);
					}
				}
			}
			$ret .= "</table></div>";			
		}
	} else {
		EPG_readingsDeleteChannel($hash);
	}

	return $ret;
}

##################### (PopUp to view HTML for available channels)
sub EPG_FW_Popup_Channels {
	my $name = shift;
	my $ret = "";
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my $Ch_sort = "";
	my $checked = "";
	my $style_background = "";

	Log3 $name, 4, "$name: FW_Channels is running";

	$ret.= "<table>";
	$ret.= "<tr style=\"text-decoration-line: underline;\"><td>".$EPG_tt->{"no"}."</td><td>".$EPG_tt->{"active"}."</td><td>".$EPG_tt->{"tv_name"}."</td><td>".$EPG_tt->{"tv_fav"}."</td></tr>";

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

##################### (SAVE Button on PopUp -> Anpassung Attribute Channels)
sub EPG_FW_set_Attr_Channels {
	my $name = shift;
	my $hash = $defs{$name};
	my $Ch_select = shift;
	my @Ch_select_array = split(",",$Ch_select);
	my $Ch_sort = shift;
	my @Ch_sort_array = split(",",$Ch_sort);

	Log3 $name, 4, "$name: FW_set_Attr_Channels is running";
	Log3 $name, 5, "$name: FW_set_Attr_Channels Ch_select $Ch_select";
	Log3 $name, 5, "$name: FW_set_Attr_Channels Ch_sort $Ch_sort";

	if ($Ch_select eq "") {
		Log3 $name, 4, "$name: FW_set_Attr_Channels all Channels delete and clean view";
		CommandDeleteAttr($hash,"$name Ch_select");
		CommandDeleteAttr($hash,"$name Ch_sort");
		InternalTimer(gettimeofday()+2, "EPG_readingsSingleUpdate_later", "$name,".$EPG_tt->{"set_Attr_Ch_eq"});
		$HTML = {};

		FW_directNotify("FILTER=(room=)?$name", "#FHEMWEB:WEB", "location.reload('true')", "");
	} else {
		Log3 $name, 4, "$name: FW_set_Attr_Channels new Channels set";
		$HTML = {};
		CommandAttr($hash,"$name Ch_select $Ch_select");
		if ($Ch_sort !~ /^[0,]+$/) {
			CommandAttr($hash,"$name Ch_sort $Ch_sort");
		} else {
			CommandDeleteAttr($hash,"$name Ch_sort");		
		}

    ## list of all available channels - set ch_wish from HTML input ##
		foreach my $i (0 .. $#Ch_select_array) {
			if ($Ch_sort_array[$i] != 0) {
				Log3 $name, 4, "$name: FW_set_Attr_Channels new numbre of ".$Ch_select_array[$i]." set to ".$Ch_sort_array[$i];
				$HTML->{$Ch_select_array[$i]}{ch_wish} = $Ch_sort_array[$i];
				$HTML->{$Ch_select_array[$i]}{ch_name} = $Ch_select_array[$i];         # need, if channel not PEG Data (sort $HTML)
			} else {
				$HTML->{$Ch_select_array[$i]}{ch_wish} = 999;                          # Reset Default
				$HTML->{$Ch_select_array[$i]}{ch_name} = $Ch_select_array[$i];         # need, if channel not PEG Data (sort $HTML)
			}
		}
		readingsSingleUpdate($hash, "state" , $EPG_tt->{"set_Attr_Ch_state"}, 1);
	}
	#Log3 $name, 5, "$name: FW_set_Attr_Channels ".Dumper\$HTML;
}

#####################
sub EPG_PerformHttpRequest($) {
	my ($hash, $def) = @_;
	my $name = $hash->{NAME};
	my $DownloadURL = AttrVal($name, "DownloadURL", undef);
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);
	my $HTTP_TimeOut = AttrVal($name, "HTTP_TimeOut", 10);

	Log3 $name, 4, "$name: PerformHttpRequest is running";
	my $http_param = { 	url        => $DownloadURL.$DownloadFile,
											timeout    => $HTTP_TimeOut,
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
	my $HTTP_TimeOut = AttrVal($name, "HTTP_TimeOut", 10);
	my $state = $EPG_tt->{"ParseHttp_state1"};
	my $FileAge = undef;

	Log3 $name, 5, "$name: ParseHttpResponse - error: $err";
	Log3 $name, 5, "$name: ParseHttpResponse - http code: ".$http_param->{code};

	if ($err ne "") {                                                          # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
		$HttpResponse = $err;
		Log3 $name, 3, "$name: ParseHttpResponse - error: $err";
		$state = $EPG_tt->{"ParseHttp_state2"} if (grep /timed out/, $err);
	} elsif ($http_param->{code} ne "200") {                                   # HTTP code
		$HttpResponse = $EPG_tt->{"ParseHttp_Http_file"} if (grep /$DownloadFile\swas\snot\sfound/, $data);
		$HttpResponse = $EPG_tt->{"ParseHttp_Http_URL"} if (grep /URL\swas\snot\sfound/, $data);
		Log3 $name, 3, "$name: ParseHttpResponse - error:\n\n$data";
	} elsif ($http_param->{code} eq "200" && $data ne "") {                    # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
   	my $filename = "FHEM/EPG/$DownloadFile";
		open(my $file, ">", $filename);                                          # Datei schreiben
			print $file $data;
		close $file;

		Log3 $name, 4, "$name: ParseHttpResponse - returned ".length($data)." bytes Data";

		if ($DownloadFile =~ /.*\.gz$/) {
			Log3 $name, 4, "$name: ParseHttpResponse - unpack methode gz on $osname";
			($gzError, $DownloadFile) = EPG_UnCompress_gz($hash,$DownloadFile);    # Datei Unpack gz
			if ($gzError) {
				Log3 $name, 2, "$name: ParseHttpResponse unpack of $DownloadFile failed! ($gzError)";
				readingsSingleUpdate($hash, "state", $EPG_tt->{"ParseHttp_gz_error"}." $gzError", 1);
				return $gzError
			};
		} elsif ($DownloadFile =~ /.*\.xz$/) {
			Log3 $name, 4, "$name: ParseHttpResponse - unpack methode xz on $osname";
			($xzError, $DownloadFile) = EPG_UnCompress_xz($hash,$DownloadFile);    # Datei Unpack xz
			if ($xzError) {
				Log3 $name, 2, "$name: ParseHttpResponse unpack of $DownloadFile failed! ($xzError)";
				readingsSingleUpdate($hash, "state", $EPG_tt->{"ParseHttp_xz_error"}." $gzError", 1);
				return $xzError;
			}
		}

		EPG_File_check($hash) if ($osname ne "MSWin32");
		FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "location.reload('true')", "");
		$state = 	$EPG_tt->{"ParseHttp_state_ok"};
		$HttpResponse = $EPG_tt->{"ParseHttp_Http_ok"};
	}

	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash, "HttpResponse", $HttpResponse);                  # HttpResponse Status
	readingsBulkUpdate($hash, "state", $state);
	readingsEndUpdate($hash, 1);

	HttpUtils_Close($http_param);
}

#####################
sub EPG_UnCompress_gz($$) {
	my ($hash,$file) = @_;
	my $name = $hash->{NAME};
	my $input = "./FHEM/EPG/".$file;
	my $gzipfound = 0;

	if ($^O ne 'MSWin32') {
		## gzip -> gzip ##
		if (-d "/bin") {
			if ( -f "/bin/$tools[0]" && -x _ ) {
				$gzipfound++;
				Log3 $name, 4, "$name: UnCompress_gz - found $tools[0] on /bin";
			}
		}

		if ($gzipfound == 0) {
			Log3 $name, 4, "$name: UnCompress_gz - no found $tools[0]";
			return ("missing $tools[0] package",$input);
		}
	} else {
		return ("please unpack manually [example 7Zip]",$input);
	}

	local $SIG{CHLD} = 'DEFAULT';
	my $ok = qx(gzip -d -f $input 2>&1);   # Datei Unpack gz

	if ($ok ne "" || $? != 0) {
		Log3 $name, 4, "$name: UnCompress_gz - ERROR: $ok $?";
		return ("$ok $?",$input);
	}

	return (undef,$input);
}

#####################
sub EPG_UnCompress_xz($$) {
	my ($hash,$file) = @_;
	my $name = $hash->{NAME};
	my $input = "./FHEM/EPG/".$file;
	my $path_separator = ':';
	my $xzfound = 0;

	if ($^O ne 'MSWin32') {
		## xz -> xz-utils ##
		for my $path ( split /$path_separator/, $ENV{PATH} ) {
			#Log3 $name, 3, "$name: $cmd - \$ENV\{PATH\}: " .$path;
			if ( -f "$path/$tools[1]" && -x _ ) {
				$xzfound++;
				Log3 $name, 4, "$name: UnCompress_xz - found $tools[1] on " .$path;
				last;
			}
		}

		if ($xzfound == 0) {
			Log3 $name, 4, "$name: UnCompress_xz - no found $tools[1]";
			return ("missing $tools[0] (xz-utils) package",$input);
		}
	} else {
		return ("please unpack manually! [example 7Zip]",$input);
	}

	local $SIG{CHLD} = 'DEFAULT';
	my $ok = qx(xz -df $input 2>&1);   # Datei Unpack xz

	if ($ok ne "" || $? != 0) {
		Log3 $name, 4, "$name: UnCompress_xz - ERROR: $ok $?";
		return ("$ok $?",$input);
	}

	return (undef,$input);
}

#####################
sub EPG_Notify($$) {
	my ($hash, $dev_hash) = @_;
	my $name = $hash->{NAME};
	my $typ = $hash->{TYPE};
	return "" if(IsDisabled($name));	                                        # Return without any further action if the module is disabled
	my $devName = $dev_hash->{NAME};	                                        # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	my $DownloadFile = AttrVal($name, "DownloadFile", undef);
	my $Variant = AttrVal($name, "Variant", undef);

	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}) && $typ eq "EPG") {
		Log3 $name, 5, "$name: Notify is running and starting";
		CommandGet($hash, "$name available_channels");
	}
	return undef;
}

#####################
sub EPG_Undef($$) {
	my ($hash, $arg) = @_;
	my $name = $hash->{NAME};

	RemoveInternalTimer($hash);
	BlockingKill($hash->{helper}{RUNNING_PID}) if(defined($hash->{helper}{RUNNING_PID}));
	return undef;
}

#####################
sub EPG_File_check {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $DownloadFile = AttrVal($name, "DownloadFile", "no file found");
	my $DownloadFile_found = 0;
	my $FileAge = $EPG_tt->{"File_check_fileage"};

	## check files ##
	opendir(DIR,"./FHEM/EPG");																		# not need -> || return "ERROR: directory $path can not open!"
		while( my $directory_value = readdir DIR ){
			if ($directory_value ne "." && $directory_value ne "..") {
				Log3 $name, 5, "$name: File_check - look for file -> $directory_value";
				if (index($DownloadFile,$directory_value) >= 0 ) {
					Log3 $name, 5, "$name: File_check found index $directory_value in $DownloadFile";
					if ($directory_value ne "." && $directory_value ne ".." && $directory_value !~ /\.(gz|xz)/) {
						Log3 $name, 4, "$name: File_check found $directory_value";
						$DownloadFile = $directory_value;
						$DownloadFile_found++;
						last;
					}
				}
			}
		}
	close DIR;

	if ($DownloadFile_found != 0) {
		Log3 $name, 4, "$name: File_check ready to search properties on $DownloadFile";	
		my @stat_DownloadFile = stat("./FHEM/EPG/".$DownloadFile);  # Dateieigenschaften
		$FileAge = FmtDateTime($stat_DownloadFile[9]);              # letzte Änderungszeit

		Log3 $name, 5, "$name: File_check ready - file rights: ".substr((sprintf "%#o", $stat_DownloadFile[2]),1);
		Log3 $name, 5, "$name: File_check ready - file owner-ID numbre: ".$stat_DownloadFile[4];
		Log3 $name, 5, "$name: File_check ready - file group-ID numbre: ".$stat_DownloadFile[5];
		Log3 $name, 5, "$name: File_check ready - file size: ".$stat_DownloadFile[7]." byte";
	} else {
		Log3 $name, 5, "$name: File_check nothing file found";
		$DownloadFile = $EPG_tt->{"File_check_DownFile"};
	}

	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash, "EPG_file_age" , $FileAge);
	readingsBulkUpdate($hash, "EPG_file_name" , $DownloadFile);
	readingsEndUpdate($hash, 0);
}

#####################
sub EPG_nonBlock_available_channels($) {
	my ($string) = @_;
	my ($name, $EPG_file_name) = split("\\|", $string);
  my $hash = $defs{$name};
  my $return;
	my $Variant = "unknown";
	my $ch_id;
	my $ok = "ok";
	my $additive_info = "";

  Log3 $name, 4, "$name: nonBlocking_available_channels running";
  Log3 $name, 5, "$name: nonBlocking_available_channels string=$string";

	if (-e "./FHEM/EPG/$EPG_file_name") {
		open (FileCheck,"<./FHEM/EPG/$EPG_file_name");
			my $line_cnt = 0;
			while (<FileCheck>) {
				my $ch_name;
				$line_cnt++;
				if ($line_cnt > 0 && $line_cnt <= 3) {
					my $line = $_;
					chomp ($line);
					Log3 $name, 5, "$name: nonBlocking_available_channels line: ".$line;
				}
				# <tv generator-info-name="Rytec" generator-info-url="http://forums.openpli.org">
				$Variant = "Rytec" if ($_ =~ /.*generator-info-name="Rytec".*/);
				# <tv source-data-url="http://api.tvprofil.net/" source-info-name="TvProfil API v1.7 - XMLTV" source-info-url="https://tvprofil.com">
				$Variant = "TvProfil_XMLTV" if ($_ =~ /.*source-info-name="TvProfil.*/);
				# <tv generator-info-name="WebGrab+Plus/w MDB &amp; REX Postprocess -- version V2.1.5 -- Jan van Straaten" generator-info-url="http://www.webgrabplus.com">
				$Variant = "WebGrab+Plus" if ($_ =~ /.*generator-info-name="WebGrab\+Plus.*/);
				#XMLTV.se       <tv generator-info-name="Vind 2.52.12" generator-info-url="https://xmltv.se">
				$Variant = "XMLTV.se" if ($_ =~ /.*generator-info-url="https:\/\/xmltv.se.*/);
				#teXXas via RSS  <channel><title>teXXas - 
				$Variant = "teXXas_RSS" if ($_ =~ /.*<channel><title>teXXas -.*<link>http:\/\/www.texxas.de\/tv\/programm.*/);

				if ($Variant eq "Rytec" || $Variant eq "TvProfil_XMLTV" || $Variant eq "WebGrab+Plus" || $Variant eq "XMLTV.se") {
					$ch_id = $1 if ($_ =~ /<channel id="(.*)">/);        # other
					$ch_id = $1 if ($_ =~ /\schannel="(.*)"\s?start=/);  # XMLTV.se

					if ($_ =~ /<display-name lang=".*">(.*)<.*/) {
						Log3 $name, 5, "$name: nonBlocking_available_channels id: $ch_id -> display_name: ".$1;
						$ch_name = $1;
					}

					$ch_name = $ch_id if ($Variant eq "XMLTV.se");
					Log3 $name, 4, "$name: nonBlocking_available_channels with variant=$Variant and without ch_id. need help!" if (!$ch_name && $line_cnt == 4);
					Log3 $name, 4, "$name: nonBlocking_available_channels with variant=$Variant" if ($ch_name && $line_cnt == 4);

					## nonBlocking_available_channels set helper ##
					if ($ch_name && (not grep /^$ch_name$/, @channel_available)) {
						Log3 $name, 5, "$name: nonBlocking_available_channels added $ch_name with ch_id $ch_id";
						$hash->{helper}{programm}{$ch_id}{name} = $ch_name;
						push(@channel_available,$ch_name);					
					}
				} elsif ($Variant eq "teXXas_RSS") {
					$hash->{helper}{programm} = "now" if ($_ =~ /<link>http:\/\/www.texxas.de\/tv\/programm\/jetzt\//);
					$hash->{helper}{programm} = "20:15" if ($_ =~ /<link>http:\/\/www.texxas.de\/tv\/programm\/heute\/2015\//);
					## nonBlocking_available_channels set helper ##
					my @RRS = split("<item>", $_);
					my $remove = shift @RRS;
					for (@RRS) {
						push(@channel_available,$1) if ($_ =~ /<dc:subject>(.*)<\/dc:subject>/);
					}
				}
			}
		close FileCheck;

		if ($Variant eq "Rytec" || $Variant eq "TvProfil_XMLTV" || $Variant eq "WebGrab+Plus" || $Variant eq "XMLTV.se") {
			$additive_info = JSON->new->utf8(0)->encode($hash->{helper}{programm});
			Log3 $name, 4, "$name: nonBlocking_available_channels read additive_info with variant $Variant";
		} elsif ($Variant eq "teXXas_RSS") {
			$additive_info = $hash->{helper}{programm};	
		}
	} else {
		$ok = $EPG_tt->{"available_ch_ok"};
		Log3 $name, 4, "$name: nonBlocking_available_channels file $EPG_file_name not found, need help!";
	}

	### for TEST ###
	# foreach my $ch (sort keys %{$hash->{helper}{programm}}) {
		# Log3 $name, 3, $hash->{helper}{programm}{$ch}{name};
	# }

	my $ch_available = join(";", @channel_available);
	$return = $name."|".$EPG_file_name."|".$ok."|".$Variant."|".$ch_available."|".$additive_info;

	return $return;
}

#####################
sub EPG_nonBlock_available_channelsDone($) {
	my ($string) = @_;
	my ($name, $EPG_file_name, $ok, $Variant, $ch_available, $additive_info) = split("\\|", $string);
  my $hash = $defs{$name};
	my $ch_table = "";
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my @Ch_select_array = split(",",$Ch_select) if ($Ch_select);

	return unless(defined($string));
  Log3 $name, 4, "$name: nonBlock_available_channelsDone running";
  Log3 $name, 5, "$name: nonBlock_available_channelsDone string=$string";
	delete($hash->{helper}{RUNNING_PID});

	if ($Variant eq "unknown") {
		readingsSingleUpdate($hash, "state", $EPG_tt->{"chDone_state1"}, 1);
		return "";
	}

	if ($ok ne "ok") {
		readingsSingleUpdate($hash, "state", "$ok", 1);
		return "";
	}

  @channel_available = split(';', $ch_available);
	@channel_available = sort @channel_available;

	## check channels in attr Ch_select available in file (new available channels) ##
	if ($Ch_select) {
		for(my $i=0;$i<=$#Ch_select_array;$i++) {
			if (not grep /^$Ch_select_array[$i]$/, @channel_available) {
				my %mod = map { ($_ => 1) }
							grep { $_ !~ m/^$Ch_select_array[$i](:.+)?$/ }
							split(",", $Ch_select);
				$attr{$name}{Ch_select} = join(",", sort keys %mod);
				delete $attr{$name}{Ch_select} if( (!keys %mod && defined($attr{$name}{Ch_select})) || (defined($attr{$name}{Ch_select}) && $attr{$name}{Ch_select} eq "") );
				Log3 $name, 4, "$name: nonBlock_available_channelsDone delete $Ch_select_array[$i] from list Ch_select -> not available";
			}
		}
	}

	if ($Variant eq "Rytec" || $Variant eq "TvProfil_XMLTV" || $Variant eq "WebGrab+Plus" || $Variant eq "XMLTV.se") {
		$additive_info = eval {encode_utf8( $additive_info )};
		$ch_table = decode_json($additive_info);

		foreach my $ch (sort keys %{$ch_table}) {
			Log3 $name, 5, "$name: nonBlock_available_channelsDone channel ".$ch . " -> " . $ch_table->{$ch}->{name};
		}	
	}

	$ch_table = $additive_info if ($Variant eq "teXXas_RSS");

	$hash->{helper}{programm} = $ch_table;
	CommandAttr($hash,"$name Variant $Variant") if ($Variant ne "unknown");
	FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "location.reload('true')", "");		            # reload Webseite
	
	if (AttrVal($name, "Ch_select", undef)) {
		InternalTimer(gettimeofday()+2, "EPG_readingsSingleUpdate_later", "$name,".$EPG_tt->{"chDone_msg_OK"});
	} else {
		InternalTimer(gettimeofday()+2, "EPG_readingsSingleUpdate_later", "$name,".$EPG_tt->{"chDone_msg_OK2"});
	}
}

#####################
sub EPG_nonBlock_loadEPG_v1($) {
	my ($string) = @_;
	my ($name, $EPG_file_name, $cmd, $cmd2) = split("\\|", $string);
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my $Ch_sort = AttrVal($name, "Ch_sort", undef);
	my $FavoriteShows = AttrVal($name, "FavoriteShows", undef) if ($cmd eq "loadEPG_Fav");
	my @FavoriteShows_array = split(";",$FavoriteShows) if ($FavoriteShows);
  my $hash = $defs{$name};
  my $return;

  Log3 $name, 4, "$name: nonBlock_loadEPG_v1 running, $cmd from file $EPG_file_name";
  Log3 $name, 5, "$name: nonBlock_loadEPG_v1 string=$string";

	my $off_h = 0;
	my @gmt = (gmtime(time+$off_h*60*60));
	my @local = (localtime(time+$off_h*60*60));
	my $TimeLocaL_GMT_Diff = $gmt[2]-$local[2] + ($gmt[5] <=> $local[5] || $gmt[7] <=> $local[7])*24;

	my $EPG_info = "";
	my $ch_found = 0;          # counter to verification ch
	my $ch_id = "";            # TV channel channel id
	my $ch_name = "";          # TV channel display-name
	my $ch_name_before = "";   # TV channel display-name before
	my $data_found = -1;       # counter to verification data
	my $desc = "";             # TV desc
	my $end = "";              # TV time end
	my $hour_diff_read = "";   # hour diff from file
	my $start = "";            # TV time start
	my $subtitle = "";         # TV subtitle
	my $title = "";            # TV title
	my $title_wish;            # TV marker for loadEPG_Fav
	my $today_end = "";        # today time end
	my $today_start = "";      # today time start

	my @Ch_select_array = split(",",$Ch_select) if ($Ch_select);
	my @Ch_sort_array = split(",",$Ch_sort) if ($Ch_sort);

	if ($TimeLocaL_GMT_Diff < 0) {
		$TimeLocaL_GMT_Diff = abs($TimeLocaL_GMT_Diff);
		$TimeLocaL_GMT_Diff = "+".sprintf("%02s", abs($TimeLocaL_GMT_Diff))."00";
	} else {
		$TimeLocaL_GMT_Diff = sprintf("-%02s", $TimeLocaL_GMT_Diff) ."00";
	}

	Log3 $name, 4, "$name: nonBlock_loadEPG_v1 localtime     ".localtime(time+$off_h*60*60);
	Log3 $name, 4, "$name: nonBlock_loadEPG_v1 gmtime        ".gmtime(time+$off_h*60*60);
	Log3 $name, 4, "$name: nonBlock_loadEPG_v1 diff (GMT-LT) " . $TimeLocaL_GMT_Diff;

	my $TimeNow = FmtDateTime(time());
	$TimeNow =~ s/-|:|\s//g;
	$TimeNow.= " $TimeLocaL_GMT_Diff";                       # loadEPG_now   20191016150432 +0200

	if ($cmd eq "loadEPG_Prime") {
		if (substr($TimeNow,8, 2) > 20) {                      # loadEPG_Prime 20191016201510 +0200	morgen wenn Prime derzeit läuft
			my @time = split(/-|\s|:/,FmtDateTime(time()));
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
	
	Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | TimeNow          -> $TimeNow";
	#Log3 $name, 3, "$name: nonBlock_loadEPG_v1 ".Dumper\$hash->{helper}{programm};

	if (-e "./FHEM/EPG/$EPG_file_name") {
		open (FileCheck,"<./FHEM/EPG/$EPG_file_name");
			while (<FileCheck>) {
				if ($_ =~ /<programme start="(.*\s+(.*))" stop="(.*)" channel="(.*)"/) {      # find start | end | channel
					my $search = $hash->{helper}{programm}{$4}->{name};
					#Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | data for channel    -> $search";
					($start, $hour_diff_read, $end, $ch_id, $ch_name) = ($1, $2, $3, $4, $search);

					if ($TimeLocaL_GMT_Diff ne $hour_diff_read) {
						Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | Time must be recalculated! local=$TimeLocaL_GMT_Diff read=$2";
						my $hour_diff = substr($TimeLocaL_GMT_Diff,0,1).substr($TimeLocaL_GMT_Diff,2,1);
						Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | hour_diff_result $hour_diff";

						my @start_new = split("",$start);
						my @end_new = split("",$end);
						Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | ".'sec | min | hour | mday | month | year';
						Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | $start_new[12]$start_new[13]  | $start_new[10]$start_new[11]  |  $start_new[8]$start_new[9]  | $start_new[6]$start_new[7]   | $start_new[4]$start_new[5]    | $start_new[0]$start_new[1]$start_new[2]$start_new[3]";
						Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | $end_new[12]$end_new[13]  | $end_new[10]$end_new[11]  |  $end_new[8]$end_new[9]  | $end_new[6]$end_new[7]   | $end_new[4]$end_new[5]    | $end_new[0]$end_new[1]$end_new[2]$end_new[3]";
						Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | UTC start        -> ".fhemTimeLocal(($start_new[12].$start_new[13]), ($start_new[10].$start_new[11]), ($start_new[8].$start_new[9]), ($start_new[6].$start_new[7]), (($start_new[4].$start_new[5])*1-1), (($start_new[0].$start_new[1].$start_new[2].$start_new[3])*1-1900));
						Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | UTC end          -> ".fhemTimeLocal(($end_new[12].$end_new[13]), ($end_new[10].$end_new[11]), ($end_new[8].$end_new[9]), ($end_new[6].$end_new[7]), (($end_new[4].$end_new[5])*1-1), (($end_new[0].$end_new[1].$end_new[2].$end_new[3])*1-1900));
						Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | start            -> $start";             # 20191023211500 +0000
						Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | end              -> $end";               # 20191023223000 +0000

						if (index($hour_diff,"-")) {
							$start = fhemTimeLocal(($start_new[12].$start_new[13]), ($start_new[10].$start_new[11]), ($start_new[8].$start_new[9]), ($start_new[6].$start_new[7]), (($start_new[4].$start_new[5])*1-1), (($start_new[0].$start_new[1].$start_new[2].$start_new[3])*1-1900)) + (60*60*abs(substr($TimeLocaL_GMT_Diff,2,1)));
							$end = fhemTimeLocal(($end_new[12].$end_new[13]), ($end_new[10].$end_new[11]), ($end_new[8].$end_new[9]), ($end_new[6].$end_new[7]), (($end_new[4].$end_new[5])*1-1), (($end_new[0].$end_new[1].$start_new[2].$start_new[3])*1-1900)) + (60*60*abs(substr($TimeLocaL_GMT_Diff,2,1)));
						} else {
							$start = fhemTimeLocal(($start_new[12].$start_new[13]), ($start_new[10].$start_new[11]), ($start_new[8].$start_new[9]), ($start_new[6].$start_new[7]), (($start_new[4].$start_new[5])*1-1), (($start_new[0].$start_new[1].$start_new[2].$start_new[3])*1-1900)) - (60*60*abs(substr($TimeLocaL_GMT_Diff,2,1)));
							$end = fhemTimeLocal(($end_new[12].$end_new[13]), ($end_new[10].$end_new[11]), ($end_new[8].$end_new[9]), ($end_new[6].$end_new[7]), (($end_new[4].$end_new[5])*1-1), (($end_new[0].$end_new[1].$start_new[2].$start_new[3])*1-1900)) - (60*60*abs(substr($TimeLocaL_GMT_Diff,2,1)));
						}
							
						#Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | UTC start new    -> $start";
						#Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | UTC end new      -> $end";

						$start = FmtDateTime($start);
						$end = FmtDateTime($end);
						$start =~ s/-|:|\s//g;
						$end =~ s/-|:|\s//g;
						$start.= " $TimeLocaL_GMT_Diff";
						$end.= " $TimeLocaL_GMT_Diff";

						#Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | start new        -> $start";
						#Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | end new          -> $end";
					}

					if ($cmd ne "loadEPG_Fav" && grep /$search($|,)/, $Ch_select) {             # find in attributes channel
						if ($cmd ne "loadEPG_today") {
							$ch_found++ if ($TimeNow gt $start && $TimeNow lt $end);                           # Zeitpunktsuche, normal
						} else {
              # Zeitpunktsuche, kompletter Tag
							if (($start eq $today_start || $start gt $today_start) && ($end eq $today_end || $end lt $today_end) || ($start lt $today_end && ($end gt $today_end || $end eq $today_end))) {
								# Log3 $name, 3, "$name: nonBlock_loadEPG_v1 | start            -> $start";
								# Log3 $name, 3, "$name: nonBlock_loadEPG_v1 | today_start      -> $today_start";
								# Log3 $name, 3, "$name: nonBlock_loadEPG_v1 | end              -> $end";
								# Log3 $name, 3, "$name: nonBlock_loadEPG_v1 | today_end        -> $today_end";
								$ch_found++;
							}
						}
					}
				}

				if ($_ =~ /<title lang="(.*)">(.*)<\/title>/) {
					my $search = $2;
					$search =~ s/\*/\\*/g;                           # mod for regex check
					$title = $2 if ($ch_found != 0);                 # title
					if (grep /$search/, @FavoriteShows_array) {
						$title = $2;                                   # title
						$title_wish = "yes";
						$ch_found++;
						Log3 $name, 3, "$name: nonBlock_loadEPG_v1 | found FavoriteShow: $2";
					}
				}

				if ($_ =~ /<sub-title lang="(.*)">(.*)<\/sub-title>/) {
					$subtitle = $2 if ($ch_found != 0);  # subtitle
				}

				if ($_ =~ /<desc lang="(.*)">(.*)<\/desc>/) {
					$desc = $2 if ($ch_found != 0);                         # desc
				}

				if ($_ =~ /<\/programme>/ && $ch_found != 0) {            # find end channel
					$data_found = -1 if ($ch_name_before ne $ch_name);      # Reset bei Kanalwechsel
					$data_found++;
					Log3 $name, 4, "#################################################";
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | ch_name          -> $ch_name";
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | ch_before        -> $ch_name_before";
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | EPG information  -> $data_found (value of array)";
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | start            -> $start";
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | end              -> $end";
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1 | title            -> $title";
					Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | subtitle         -> $subtitle";
					Log3 $name, 5, "$name: nonBlock_loadEPG_v1 | desc             -> $desc.\n";

					$hash->{helper}{HTML}{$ch_name}{ch_name} = $ch_name;
					$hash->{helper}{HTML}{$ch_name}{ch_id} = $ch_id;

					if ($Ch_select && $Ch_sort && (grep /$ch_name/, $Ch_select)) {
						foreach my $i (0 .. $#Ch_select_array) {
							if ($Ch_select_array[$i] eq $ch_name) {
								my $value_new = 999;
								$value_new = $Ch_sort_array[$i] if ($Ch_sort_array[$i] != 0);
								$hash->{helper}{HTML}{$Ch_select_array[$i]}{ch_wish} = $value_new;
								Log3 $name, 4, "$name: nonBlock_loadEPG_v1 old numbre of ".$Ch_select_array[$i]." set to ".$value_new;
							}
						}
					} else {
						$hash->{helper}{HTML}{$ch_name}{ch_wish} = 999;
					}

					my $mod_cnt;
					($title, $subtitle, $desc, $mod_cnt) = EPG_SyntaxCheck_for_JSON_v1($hash, $title, $subtitle, $desc);

					$hash->{helper}{HTML}{$ch_name}{title_wish} = "yes" if ($title_wish);
					$hash->{helper}{HTML}{$ch_name}{EPG}[$data_found]{start} = $start;
					$hash->{helper}{HTML}{$ch_name}{EPG}[$data_found]{end} = $end;
					$hash->{helper}{HTML}{$ch_name}{EPG}[$data_found]{hour_diff} = $hour_diff_read;
					$hash->{helper}{HTML}{$ch_name}{EPG}[$data_found]{title} = $title;
					$hash->{helper}{HTML}{$ch_name}{EPG}[$data_found]{subtitle} = $subtitle;
					$hash->{helper}{HTML}{$ch_name}{EPG}[$data_found]{desc} = $desc;

					### if modify JSON ###
					Log3 $name, 5, "$name: nonBlock_loadEPG_v1 Dumper: ".Dumper\$hash->{helper}{HTML}{$ch_name}{EPG}[$data_found] if ($mod_cnt != 0);

					$ch_found = 0;
					$ch_name_before = $ch_name;
					$ch_name = "";
					$desc = "";
					$hour_diff_read = "";
					$subtitle = "";
					$title = "";
				}
			}
		close FileCheck;

		$EPG_info = $EPG_tt->{"loadEPG_msg1"} if ($data_found != -1);
		$EPG_info = $EPG_tt->{"loadEPG_msg2"} if ($data_found == -1);
	} else {
		$EPG_info = $EPG_tt->{"loadEPG_msg3"};
		Log3 $name, 3, "$name: nonBlock_loadEPG_v1 | error, file $EPG_file_name no found at ./opt/fhem/FHEM/EPG";
	}

	my $json_HTML;
	$json_HTML = JSON->new->utf8(0)->encode($hash->{helper}{HTML}) if ($data_found != -1);
	$json_HTML = "" if ($data_found == -1);

	Log3 $name, 5, "$name: nonBlock_loadEPG_v1 value JSON for delivery: $json_HTML";
	$return = $name."|".$EPG_file_name."|".$EPG_info."|".$cmd."|".$json_HTML;
	return $return;
}

#####################
sub EPG_nonBlock_loadEPG_v1Done($) {
	my ($string) = @_;
	my ($name, $EPG_file_name, $EPG_info, $cmd, $json_HTML) = split("\\|", $string);
  my $hash = $defs{$name};
	my $Ch_Info_to_Reading = AttrVal($name, "Ch_Info_to_Reading", "no");
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my @Ch_select_array = split(",",$Ch_select) if ($Ch_select);

  Log3 $name, 4, "$name: nonBlock_loadEPG_v1Done running, $cmd from file $EPG_file_name";
  Log3 $name, 5, "$name: nonBlock_loadEPG_v1Done string=$string";

	delete($hash->{helper}{RUNNING_PID});

	$json_HTML = eval {encode_utf8( $json_HTML )};
	$HTML = eval { decode_json( $json_HTML ) } if ($json_HTML ne "");

	if ($@) {
		Log3 $name, 3, "$name: nonBlock_loadEPG_v1Done decode_json failed: ".$@;

		readingsBeginUpdate($hash);
		readingsBulkUpdate($hash, "state", "#### ERROR JSON ####");
		readingsBulkUpdate($hash, "state", $@);
		readingsBulkUpdate($hash, "state", "$json_HTML");
		readingsBulkUpdate($hash, "state", $EPG_tt->{"loadEPG_v1Done"});
		readingsEndUpdate($hash, 1);

		return "ERROR";
	}
	
	if ($Ch_Info_to_Reading eq "yes") {
		## delete old Readings ##
		foreach my $reading (keys %{$hash->{READINGS}}) {
			if ($reading =~ /^x_.*/ && (not grep /^$reading$/, @Ch_select_array)) {
				Log3 $name, 5, "$name: nonBlock_loadEPG_v1Done delete reading $reading";
				readingsDelete($hash,$reading);
			}
		}

		if ($cmd eq "loadEPG_now" || $cmd eq "loadEPG_Prime" || $cmd eq "loadEPG_today") {
			## create Readings ##
			readingsBeginUpdate($hash);

			foreach my $ch (sort keys %{$HTML}) {
				## Kanäle ##
				Log3 $name, 4, "#################################################";
				Log3 $name, 4, "$name: nonBlock_loadEPG_v1Done ch          -> $ch";
				# start end title
				for (my $i=0;$i<@{$HTML->{$ch}{EPG}};$i++){
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1Done array value -> ".$i;
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1Done start       -> ".$HTML->{$ch}{EPG}[$i]{start};
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1Done end         -> ".$HTML->{$ch}{EPG}[$i]{end};
					Log3 $name, 4, "$name: nonBlock_loadEPG_v1Done title       -> ".$HTML->{$ch}{EPG}[$i]{title};

					my $time = substr($HTML->{$ch}{EPG}[$i]{start},8,2).":".substr($HTML->{$ch}{EPG}[$i]{start},10,2)."-".substr($HTML->{$ch}{EPG}[$i]{end},8,2).":".substr($HTML->{$ch}{EPG}[$i]{end},10,2);
					#Log3 $name, 4, "$name: nonBlock_loadEPG_v1Done time fromto -> ".$time;
					readingsBulkUpdate($hash, "x_".$ch."_".$time, $HTML->{$ch}{EPG}[$i]{title});
				}
			}

			readingsEndUpdate($hash, 1);
		}
	}

	FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "location.reload('true')", "");		            # reload Webseite
	InternalTimer(gettimeofday()+2, "EPG_readingsSingleUpdate_later", "$name,$EPG_info");
}

#####################
sub EPG_nonBlock_loadEPG_v2($) {
	my ($string) = @_;
	my ($name, $EPG_file_name, $cmd, $cmd2) = split("\\|", $string);
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my $Ch_sort = AttrVal($name, "Ch_sort", undef);
  my $hash = $defs{$name};
  my $return;

  Log3 $name, 4, "$name: nonBlock_loadEPG_v2 running, $cmd from file $EPG_file_name";
  Log3 $name, 5, "$name: nonBlock_loadEPG_v2 string=$string";

	my @Ch_select_array = split(",",$Ch_select) if ($Ch_select);
	my @Ch_sort_array = split(",",$Ch_sort) if ($Ch_sort);

	my $EPG_info = "";	
	my $data_found = -1;         # counter to verification data

	if (-e "./FHEM/EPG/$EPG_file_name") {
		open (FileCheck,"<./FHEM/EPG/$EPG_file_name");
			my $string = "";
			while (<FileCheck>) {
				$string .= $_;
			}
		close FileCheck;
		#Log3 $name, 4, "$name: nonBlock_loadEPG_v2 $string";
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
				Log3 $name, 5, "$name: nonBlock_loadEPG_v2 look for    -> ".$1." selection in $Ch_select" if ($Ch_select);
				my $search = $1;
				if (index($search,"+") >= 0) {
					substr($search,index($search,"+"),1,'\+');
				}

				if ( ($Ch_select) && (grep /$search($|,)/, $Ch_select) ) {
					#Log3 $name, 3, "$name: $cmd $_";
					Log3 $name, 4, "$name: nonBlock_loadEPG_v2             -> $1 found";
					$ch_name = $1;
					$ch_found++;
					$data_found++;
				} else {
					Log3 $name, 5, "$name: nonBlock_loadEPG_v2             -> not $1 found";
				}
			}

			if($_ =~ /:\s(.*)<\/title>/ && $ch_found != 0) {
				Log3 $name, 4, "$name: nonBlock_loadEPG_v2 channel     -> ".$ch_name;
				Log3 $name, 4, "$name: nonBlock_loadEPG_v2 title       -> ".$1 ;

				$hash->{helper}{HTML}{$ch_name}{EPG}[0]{title} = $1;

				### need check
				if ($Ch_select && $Ch_sort && (grep /$ch_name/, $Ch_select)) {
					foreach my $i (0 .. $#Ch_select_array) {
						if ($Ch_select_array[$i] eq $ch_name) {
							my $value_new = 999;
							$value_new = $Ch_sort_array[$i] if ($Ch_sort_array[$i] != 0);
							$hash->{helper}{HTML}{$Ch_select_array[$i]}{ch_wish} = $value_new;
							Log3 $name, 4, "$name: nonBlock_loadEPG_v2 ch numbre   -> set to ".$value_new;
						}
					}
				} else {
					$hash->{helper}{HTML}{$ch_name}{ch_wish} = 999;
				}
				### need check attribut
				$hash->{helper}{HTML}{$ch_name}{ch_name} = $ch_name;
			}

			if($_ =~ /<!\[CDATA\[(.*)?((.*)?\d{2}\.\d{2}\.\d{4}\s(\d{2}:\d{2})\s+-\s+(\d{2}:\d{2}))(<br>)?((.*)((\n.*)?)+)]]/ && $ch_found != 0) {
				Log3 $name, 4, "$name: nonBlock_loadEPG_v2 time        -> ".$2;    # 02.11.2019 13:35 - 14:30
				$time = $2;
				Log3 $name, 4, "$name: nonBlock_loadEPG_v2 start       -> ".$4;
				$start = substr($2,6,4).substr($2,3,2).substr($2,0,2).substr($4,0,2).substr($4,3,2) . "";
				Log3 $name, 4, "$name: nonBlock_loadEPG_v2 start mod   -> ".$start;
				Log3 $name, 4, "$name: nonBlock_loadEPG_v2 end         -> ".$5;
				$end = substr($2,6,4).substr($2,3,2).substr($2,0,2).substr($5,0,2).substr($5,3,2) . "";
				Log3 $name, 4, "$name: nonBlock_loadEPG_v2 end mod     -> ".$end;
				$desc = $7;
				$desc = encode_utf8($desc);
				Log3 $name, 4, "$name: nonBlock_loadEPG_v2 description -> ".$desc;
				Log3 $name, 4, "#################################################";

				#my $mod_cnt;
				#($title, $desc, $mod_cnt) = EPG_SyntaxCheck_for_JSON_v2($hash, $title, $desc);

				$hash->{helper}{HTML}{$ch_name}{EPG}[0]{start} = $start;
				$hash->{helper}{HTML}{$ch_name}{EPG}[0]{end} = $end;
				$hash->{helper}{HTML}{$ch_name}{EPG}[0]{desc} = $desc;
			}
		}
		$EPG_info = $EPG_tt->{"loadEPG_msg1"} if ($data_found != -1);
		$EPG_info = $EPG_tt->{"loadEPG_msg2"} if ($data_found == -1);
	} else {
		$EPG_info = $EPG_tt->{"loadEPG_msg3"};
		Log3 $name, 3, "$name: nonBlock_loadEPG_v2 | error, file $EPG_file_name no found at ./opt/fhem/FHEM/EPG";
	}

	my $json_HTML = JSON->new->utf8(0)->encode($hash->{helper}{HTML});

	$return = $name."|".$EPG_file_name."|".$EPG_info."|".$cmd."|".$json_HTML;
	return $return;
}

#####################
sub EPG_nonBlock_loadEPG_v2Done($) {
	my ($string) = @_;
	my ($name, $EPG_file_name, $EPG_info, $cmd, $json_HTML) = split("\\|", $string);
  my $hash = $defs{$name};
	my $Ch_Info_to_Reading = AttrVal($name, "Ch_Info_to_Reading", "no");
	my $Ch_select = AttrVal($name, "Ch_select", undef);
	my @Ch_select_array = split(",",$Ch_select) if ($Ch_select);

	Log3 $name, 4, "$name: nonBlock_loadEPG_v2Done running, $cmd from file $EPG_file_name";
  Log3 $name, 5, "$name: nonBlock_loadEPG_v2Done string=$string";
	delete($hash->{helper}{RUNNING_PID});
	
	$json_HTML = eval {encode_utf8( $json_HTML )};
	$HTML = decode_json($json_HTML);

	#Log3 $name, 3, "$name: nonBlock_loadEPG_v2Done ".Dumper\$HTML;

	if ($Ch_Info_to_Reading eq "yes") {
		## delete old Readings ##
		foreach my $reading (keys %{$hash->{READINGS}}) {
			if ($reading =~ /^x_.*/ && (not grep /^$reading$/, @Ch_select_array)) {
				Log3 $name, 5, "$name: nonBlock_loadEPG_v2Done delete reading $reading";
				readingsDelete($hash,$reading);
			}
		}

		if ($cmd =~ /loadEPG_(Prime|now)/) {
			## create Readings ##
			readingsBeginUpdate($hash);

			foreach my $ch (sort keys %{$HTML}) {
				## Kanäle ##
				Log3 $name, 4, "#################################################";
				Log3 $name, 4, "$name: nonBlock_loadEPG_v2Done ch          -> $ch";
				# start end title
				for (my $i=0;$i<@{$HTML->{$ch}{EPG}};$i++){
					# Log3 $name, 4, "$name: nonBlock_loadEPG_v2Done start       -> ".$HTML->{$ch}{EPG}[$i]{start};
					# Log3 $name, 4, "$name: nonBlock_loadEPG_v2Done end         -> ".$HTML->{$ch}{EPG}[$i]{end};
					Log3 $name, 4, "$name: nonBlock_loadEPG_v2Done title       -> ".$HTML->{$ch}{EPG}[$i]{title};

					readingsBulkUpdate($hash, "x_".$ch, $HTML->{$ch}{EPG}[$i]{title});
				}
			}
			readingsEndUpdate($hash, 1);
		}
	}

	FW_directNotify("FILTER=$name", "#FHEMWEB:WEB", "location.reload('true')", "");		            # reload Webseite
	InternalTimer(gettimeofday()+2, "EPG_readingsSingleUpdate_later", "$name,$EPG_info");
}

#####################
sub EPG_nonBlock_abortFn($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	delete($hash->{helper}{RUNNING_PID});

  Log3 $name, 4, "$name: nonBlock_abortFn running";
	readingsSingleUpdate($hash, "state", $EPG_tt->{"nonBlock_abortFn"},1);
}

#####################
sub EPG_readingsSingleUpdate_later {
	my ($param) = @_;
	my ($name,$txt) = split(",", $param);
	my $hash = $defs{$name};

  Log3 $name, 4, "$name: readingsSingleUpdate_later running";
	readingsSingleUpdate($hash, "state", $txt,1);
}

#####################
sub EPG_readingsDeleteChannel($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};

	foreach my $reading (keys %{$hash->{READINGS}}) {
		if ($reading =~ /^x_.*/) {
			Log3 $name, 5, "$name: readingsDeleteChannel delete $reading";
			readingsDelete($hash,$reading);		
		}
	}
}

#####################
sub EPG_SyntaxCheck_for_JSON_v1($$$$) {
	my ($hash, $title, $subtitle, $desc) = @_;
	my $name = $hash->{NAME};
	my @values;
	my $error_cnt = 0;
	my $mod_cnt = 0;
	
	## http://jsoneditoronline.org/ ##
	Log3 $name, 5, "$name: SyntaxCheck_for_JSON_v1 is running";
	
	push (@values,$title);
	push (@values,$subtitle) if $subtitle;
	push (@values,$desc) if $desc;

	for(my $i=0;$i<=$#values;$i++) {
		if ($values[$i]) {
			if ($values[$i] =~ /\s\\\s/) {
				$error_cnt++;
				if ($error_cnt != 0) {
					Log3 $name, 4, "$name: SyntaxCheck_for_JSON_v1 found wrong syntax ".'-> \ <-';
					Log3 $name, 4, "$name: SyntaxCheck_for_JSON_v1 orginal: ".$values[$i];
				}
				$values[$i] =~ s/\s\\\s/ /g;
				$mod_cnt++;
				Log3 $name, 4, "$name: SyntaxCheck_for_JSON_v1 modded: ".$values[$i];
			}
			if ($values[$i] =~ /\\"/) {
				$error_cnt++;
				if ($error_cnt != 0) {
					Log3 $name, 4, "$name: SyntaxCheck_for_JSON_v1 found wrong syntax ".'->\\"<-';
					Log3 $name, 4, "$name: SyntaxCheck_for_JSON_v1 orginal: ".$values[$i];
				}
				$values[$i] =~ s/\\"//g;
				$mod_cnt++;
				Log3 $name, 4, "$name: SyntaxCheck_for_JSON_v1 modded: ".$values[$i];
			}
			if ($values[$i] =~ /\|/) {
				$error_cnt++;
				if ($error_cnt != 0) {
					Log3 $name, 4, "$name: SyntaxCheck_for_JSON_v1 found wrong syntax ".'->|<-';
					Log3 $name, 4, "$name: SyntaxCheck_for_JSON_v1 orginal: ".$values[$i];
				}
				$values[$i] =~ s/\|/,/g;
				$mod_cnt++;
				Log3 $name, 4, "$name: SyntaxCheck_for_JSON_v1 modded: ".$values[$i];
			}
		}

		$title = $values[$i] if($i == 0 && $error_cnt != 0);
		$subtitle = $values[$i] if($i == 1 && $error_cnt != 0);
		$desc = $values[$i] if($i == 2 && $error_cnt != 0);
		$error_cnt = 0;
	}
	return ($title, $subtitle, $desc, $mod_cnt);
}

#####################
sub EPG_SyntaxCheck_for_JSON_v2($$$) {
	my ($hash, $title, $desc) = @_;
	my $name = $hash->{NAME};
	my @values;
	my $error_cnt = 0;
	my $mod_cnt = 0;

	## http://jsoneditoronline.org/ ##
	Log3 $name, 5, "$name: SyntaxCheck_for_JSON_v2 is running";

	push (@values,$title);
	push (@values,$desc) if $desc;

	for(my $i=0;$i<=$#values;$i++) {
		if ($values[$i]) {
			if ($values[$i] =~ /\s\\\s/) {
				$error_cnt++;
				if ($error_cnt != 0) {
					Log3 $name, 3, "$name: SyntaxCheck_for_JSON_v2 found wrong syntax ".'-> \ <-';
					Log3 $name, 3, "$name: SyntaxCheck_for_JSON_v2 orginal: ".$values[$i];
				}
				$values[$i] =~ s/\s\\\s/ /g;
				$mod_cnt++;
				Log3 $name, 3, "$name: SyntaxCheck_for_JSON_v2 modded: ".$values[$i];
			}
			if ($values[$i] =~ /\\"/) {
				$error_cnt++;
				if ($error_cnt != 0) {
					Log3 $name, 3, "$name: SyntaxCheck_for_JSON_v2 found wrong syntax ".'->\\"<-';
					Log3 $name, 3, "$name: SyntaxCheck_for_JSON_v2 orginal: ".$values[$i];
				}
				$values[$i] =~ s/\\"//g;
				$mod_cnt++;
				Log3 $name, 3, "$name: SyntaxCheck_for_JSON_v2 modded: ".$values[$i];
			}
		}

		$title = $values[$i] if($i == 0 && $error_cnt != 0);
		$desc = $values[$i] if($i == 2 && $error_cnt != 0);
		$error_cnt = 0;
	}

	return ($title, $desc, $mod_cnt);
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
<u>The module has dependencies:</u><br>
<ul>
<li>Encode (encode encode_utf8 decode_utf8)</li>
<li>JSON (encode decode_json)</li>
<li>XML::Simple</li>
<li>gzip</li>
<li>xz (xz-utils)</li>
</ul><br>
<i>Depending on the source and host country, the information can be slightly differentiated.<br> Each variant has its own read-in routine. When new sources become known, the module can be extended at any time.</i>
<br><br>
You have to choose a source and only then can the data of the TV Guide be displayed.<br>
The specifications for the attribute Variant | DownloadFile and DownloadURL are mandatory.
<br><br>
<ul>
	<u>Currently the following file extensions are supported</u><br>
	<li>.gz</li>
	<li>.xml</li>
	<li>.xml.gz</li>
	<li>.xz</li>
	<br>
	<u>Currently the following services are supported:</u>
	<li>Rytec (Rytec EPG Downloader)<br><br>
			well-known sources:<br>
			<ul>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_Basic.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_Common.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_SportMovies.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://epg.energyiptv.com/epg/epg.xml.gz <small>&nbsp;&nbsp;(&#10003; slowly due to dataset)</small></li>
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
		<li>loadFile: load the file with the information</li><a name=""></a>
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
	<ul><li><a name="Ch_Info_to_Reading">Ch_Info_to_Reading</a><br>
	You can write the data in readings (yes | no = default)</a></ul><br>
	<ul><li><a name="DownloadFile">DownloadFile</a><br>
	File name of the desired file containing the information.</li><a name=" "></a></ul><br>
	<ul><li><a name="DownloadURL">DownloadURL</a><br>
	Website URL where the desired file is stored.</li><a name=" "></a></ul><br>
	<ul><li><a name="FavoriteShows">FavoriteShows</a><br>
	Names of programs which are searched for separately. (values ​​must be separated by a semicolon)</a></ul><br>
	<ul><li><a name="HTTP_TimeOut">HTTP_TimeOut</a><br>
	Maximum time in seconds for the download. (default 10 | maximum 90)</li><a name=" "></a></ul><br>
	<ul><li><a name="Table">Table</a><br>
	Displays the EPG data in a predefined table. (on = default | off) </li><a name=" "></a></ul><br>
	<ul><li><a name="Table_view_Subtitle">Table_view_Subtitle</a><br>
	Displays additional information of the shipment as far as available.</li><a name=" "></a></ul><br>
	<ul><li><a name="Variant">Variant</a><br>
	Processing variant according to which method the information is processed or read.</li><a name=" "></a></ul>

=end html


=begin html_DE

<a name="EPG"></a>
<h3>EPG Modul</h3>
<ul>
Das EPG Modul holt die TV - Sendungsinformationen aus verschiedenen Quellen.<br>
Es handelt sich hiermit um einen Modul welches die Daten f&uuml;r einen elektronischen Programmf&uuml;hrer abruft und sofort darstellt. (Bsp: Alternative f&uuml;r HTTPMOD + Readingsgroup & weitere)<br><br>
<u>Das Modul besitzt Abh&auml;ngigkeiten:</u><br>
<ul>
<li>Encode (encode encode_utf8 decode_utf8)</li>
<li>JSON (encode decode_json)</li>
<li>XML::Simple</li>
<li>gzip</li>
<li>xz (xz-utils)</li>
</ul><br>

<i>Je nach Quelle und Aufnahmeland k&ouml;nnen die Informationen bei Ihnen geringf&uuml;gig abweichen.<br> Jede Variante besitzt ihre eigene Einleseroutine. Beim bekanntwerden neuer Quellen kann das Modul jederzeit erweitert werden.</i>
<br><br>
Sie m&uuml;ssen sich f&uuml;r eine Quelle entscheiden und erst danach k&ouml;nnen Daten des TV-Guides dargestellt werden.<br>
Die Angaben f&uuml;r die Attribut Variante | DownloadFile und DownloadURL sind zwingend notwendig.
<br><br>
<ul>
	<u>Derzeit werden folgende Dateiendungen unterst&uuml;tzt:</u><br>
	<li>.gz</li>
	<li>.xml</li>
	<li>.xml.gz</li>
	<li>.xz</li>
	<br>

	<u>Derzeit werden folgende Dienste unterst&uuml;tzt:</u>
	<li>Rytec (Rytec EPG Downloader)<br><br>
			bekannte Quellen:<br>
			<ul>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_Basic.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_Common.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://91.121.106.172/~rytecepg/epg_data/rytecDE_SportMovies.xz <small>&nbsp;&nbsp;(x)</small></li>
				<li>http://epg.energyiptv.com/epg/epg.xml.gz <small>&nbsp;&nbsp;(&#10003; langsam aufgrund Datenmenge)</small></li>
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
		<li>loadFile: l&auml;d die Datei mit den Informationen herunter</li><a name=""></a>
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
	<ul><li><a name="Ch_Info_to_Reading">Ch_Info_to_Reading</a><br>
	Hiermit kann man die Daten in Readings schreiben lassen (yes | no = default)</a></ul><br>
	<ul><li><a name="DownloadFile">DownloadFile</a><br>
	Dateiname von der gew&uuml;nschten Datei welche die Informationen enth&auml;lt.</li><a name=" "></a></ul><br>
	<ul><li><a name="DownloadURL">DownloadURL</a><br>
	Webseiten URL wo die gew&uuml;nschten Datei hinterlegt ist.</li><a name=" "></a></ul><br>
	<ul><li><a name="FavoriteShows">FavoriteShows</a><br>
	Namen von Sendungen welche gezielt gesucht werden k&ouml;nnen. (mehrere Werte m&uuml;ssen durch ein Semikolon getrennt werden)</a></ul><br>
	<ul><li><a name="HTTP_TimeOut">HTTP_TimeOut</a><br>
	Maximale Zeit in Sekunden für den Download. (Standard 10 | maximal 90)</li><a name=" "></a></ul><br>
	<ul><li><a name="Table">Table</a><br>
	Zeigt die EPG-Daten in einer vordefinierten Tabelle an. (on = default | off) </li><a name=" "></a></ul><br>
	<ul><li><a name="Table_view_Subtitle">Table_view_Subtitle</a><br>
	Zeigt Zusatzinformation der Sendung an soweit verf&uuml;gbar.</li><a name=" "></a></ul><br>
	<ul><li><a name="Variant">Variant</a><br>
	Verarbeitungsvariante, nach welchem Verfahren die Informationen verarbeitet oder gelesen werden.</li><a name=" "></a></ul>

=end html_DE

# Ende der Commandref
=cut
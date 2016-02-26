##
##	TvMaze by T-101 / Darklite ^ Primitive
##
##	Fetch previous and upcoming dates of your favorite tv shows
##
##	Usage: !tv show		(name can contain spaces)
##	Examples: 
##		!tv simpsons
##		!tv family guy
##
##	Also you need to set which channels you want to bot respond.
##	In the eggdrop partyline do: .+chanset #channel +tvmaze
##
##	Use at own risk, and be nice towards www.tvmaze.com for
##	such an awesome, free service
##
##	2016 | darklite.org | primitive.be | IRCNet
##
##
## Version history:
##		1.0	-	Initial release

namespace eval ::tvmaze {

	set tvVersion "v1.0"

	setudef flag tvmaze

	bind pub - !tv ::tvmaze::announce

	package require http
	package require json

	proc fetchData { type args } {
		# Are we fetching show info or episode info
		if { $type == "show" } {
			set input [parseInput $args]
			set url "http://api.tvmaze.com/singlesearch/shows?q=:$input"
		} else { set url $args }

	    set userAgent "Chrome 45.0.2454.101"
	    ::http::config -useragent $userAgent
	    set httpHandler [::http::geturl $url]
	    set data [split [::http::data $httpHandler] "\n"]
		set code [::http::code $httpHandler]
	    ::http::cleanup $httpHandler
	    return $data
	}

    proc getShow { args } {
    	set data [join [fetchData show $args]]
    	if {![string length $data]} {return {"No search results"} }

    	# Some heavylifting with json to fetch data that is not always there
    	set json [::json::json2dict $data]
    	if {[dict exists $json id]} { set id [dict get $json id] } else { set id "" }
    	if {[dict exists $json name]} {	set name [dict get $json name] } else { set name "" }
    	if {[dict exists $json status]} { set status [dict get $json status] } else { set status "" }
    	if {[dict exists $json premiered]} {
    		set premiered [clock format [clock scan [dict get $json premiered]] -format %Y]
    	} else { set premiered "" }
    	if {[dict exists $json _links] && [dict exists $json _links previousepisode href]} {
    		set previousepisode [dict get $json _links previousepisode href]
    		set previousEpisodeDict [getEpisode $previousepisode]
    	}
    	if {$status == "Ended"} { set nextepisode $status } else {
	    	if {[dict exists $json _links] && [dict exists $json _links nextepisode href]} {
	    		set nextepisode [dict get $json _links nextepisode href]
	    		set nextEpisodeDict [getEpisode $nextepisode]
	    	}
    	}

    	# Put fetched data in a neat little output
    	set previousEpisodeInfo "Unknown"
    	set nextEpisodeInfo "Unknown"
    	if {[info exists previousEpisodeDict]} {
    		set previousEpisodeInfo [dict get $previousEpisodeDict name]
    		set previousEpisodeInfo "$previousEpisodeInfo [dict get $previousEpisodeDict number]"
    		set previousEpisodeInfo "$previousEpisodeInfo [dict get $previousEpisodeDict time]"
    	}
    	if {[info exists nextEpisodeDict]} {
    		set nextEpisodeInfo [dict get $nextEpisodeDict name]
    		set nextEpisodeInfo "$nextEpisodeInfo [dict get $nextEpisodeDict number]"
    		set nextEpisodeInfo "$nextEpisodeInfo [dict get $nextEpisodeDict time]"
    	}
    	lappend output "$name ($premiered) - $previousEpisodeInfo"
    	if {$status != "Ended"} { 
    		lappend output "$name ($premiered) - $nextEpisodeInfo" } else {
    		lappend output "Series ended"
    		}
    	return $output
    }

	proc getEpisode { args } {
    	set data [join [fetchData episode $args]]
    	set json [::json::json2dict $data]

    	# Get episode data and format it a little
    	if {[dict exists $json name]} {	set name [dict get $json name] } else { set name "Unknown" }
    	if {[dict exists $json season]} {
    		set season [format "%02d" [dict get $json season]]
    	} else { set season "?" }
    	if {[dict exists $json number]} {
    		set number [format "%02d" [dict get $json number]]
    	} else {
    		set number "?" }
    	if {[dict exists $json airstamp]} { set airstamp [dict get $json airstamp] } else { set airstamp "Airtime unknown" }

    	# Convert airtimes from ISO-8601 to a more human friendly format and add formatting based on time
    	if {$airstamp != "Airtime unknown" } {
	    	set airtime [clock scan $airstamp -format {%Y-%m-%dT%T%z}]
	    	if {[clock seconds] > $airtime} {
	    		set minutes [expr ([clock seconds] - $airtime) / 60]
	    		set hours [expr ([clock seconds] - $airtime) / 60 / 60]
	    		set days [expr ([clock seconds] - $airtime) / 60 / 60 / 24]
				set years [expr ([clock seconds] - $airtime) / 60 / 60 / 24 / 365]
				set airtime "$years years ago"
				if {$years < 1 } { set airtime "$days days ago" }
	    		if {$days < 1 } { set airtime "$hours hours ago" }
	    		if {$hours < 1 } { set airtime "$minutes minutes ago" }
	    	} else {
	    		set minutes [expr ($airtime - [clock seconds]) / 60]
	    		set hours [expr ($airtime - [clock seconds]) / 60 / 60]
	    		set days [expr ($airtime - [clock seconds]) / 60 / 60 / 24]
	    		set airtime "in $minutes minutes"
	    		if {$minutes > 60 } { set airtime "in $hours hours" }
	    		if {$hours > 24 } { set airtime "in $days days" }
	    	}
    	} 

    	dict set episodeData name $name
    	dict set episodeData number "(S${season}E$number)"
    	dict set episodeData time $airtime
    	return $episodeData
	}

	proc parseInput { args } {
		# Convert everything to lower case, and remove anything except letter, numbers, spaces or dashes
		set input [regsub -all {[^\u0061-\u007a\u002d\u0020\u0030-\u0039]+} [string tolower $args] {}]
		#convert whitespace and dash to url-codes
		set stringMapping { " " %20 "-" %2D}
		return [string map $stringMapping $input]
	}

	proc announce { nick mask hand channel args } {
		# Is the channel set for using this script
		if {[channel get $channel epguides] && [onchan $nick $channel]} {
			if {[llength [lindex $args 0]]} {
				set showData [getShow $args]
				foreach item $showData { putquick "PRIVMSG $channel :$item" }
			} else { putquick "PRIVMSG $channel :Usage: !tv name. Name can contain spaces" }
		}
	}

	putlog "TvMaze by T-101 $tvVersion loaded"
}
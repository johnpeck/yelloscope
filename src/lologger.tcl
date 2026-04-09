# Local logger module
#
# Tcl already has a logger module, so we want to be unique

# initialize logger subsystems
# two loggers are created
# 1. main
# 2. a separate logger for plugins
set log [logger::init main]
set log [logger::init global]
${::log}::setlevel $loglevel; # Set the log level

set log_directory log

namespace eval lologger {
    proc new_log_file {} {
	# Get a new filename for the execution log
	global log
	global state_dict
	global log_directory
	# Make sure the log directory exists
	file mkdir $log_directory
	set first_logfile "${log_directory}/[dict get $state_dict program_name]_debug.log"
	set logfile $first_logfile
	set suffixnum 1
	while {[file exists $logfile]} {
	    set logfile [file rootname ${first_logfile}]_${suffixnum}.log
	    incr suffixnum
	}
	return $logfile
    }

    proc send_message_to_file {txt} {
	global log
	global state_dict
	if {[string equal [dict get $state_dict debug_log_file] "none"]} {
	    set log_file [new_log_file]
	    dict set state_dict debug_log_file $log_file
	} else {
	    set log_file [dict get $state_dict debug_log_file]
	}
	set f [open $log_file a+]
	fconfigure $f -encoding utf-8
	puts $f $txt
	close $f
    }

    # Send log messages to wherever they need to go
    proc message_manager {lvl txt} {
	# Make the timestamp
	set time_now_ms [clock milliseconds]
	set time_now_s [expr double($time_now_ms)/1000]
	# set ms_remainder [expr int($time_delta_s * 1000 - int($time_delta_s) * 1000)]
	set ms_remainder [expr $time_now_ms - int($time_now_ms / 1000) * 1000]
	set time_string [format "%s.%03d" [clock format [expr int($time_now_s)] -format \
					       "%Y-%m-%d %H:%M:%S"] $ms_remainder]
	set msg "\[ $time_string \] \[ $lvl \] $txt"
	# The logfile output
	send_message_to_file $msg

	if {[namespace exists ::console_log_window]} {
	    # The console logger output.  Mark the level names and color them
	    # after the text has been inserted.
	    set text_box .console_log_window.console_log_frame.text

	    if {[string compare $lvl debug] == 0} {
		# Debug level logging
		set msg "\[ $lvl \] $txt \n"
		$text_box insert end $msg
		$text_box tag add debugtag \
		    {insert linestart -1 lines +2 chars} \
		    {insert linestart -1 lines +7 chars}
		$text_box tag configure debugtag -foreground blue
	    }
	    if {[string compare $lvl info] == 0} {
		# Info level logging
		set msg "\[ $lvl \] $txt \n"
		$text_box insert end $msg
		$text_box tag add infotag \
		    {insert linestart -1 lines +2 chars} \
		    {insert linestart -1 lines +7 chars}
		$text_box tag configure infotag -foreground green
	    }
	    if {[string compare $lvl warn] == 0} {
		# Warn level logging
		set msg "\[ $lvl \] $txt \n"
		$text_box insert end $msg
		$text_box tag add warntag \
		    {insert linestart -1 lines +2 chars} \
		    {insert linestart -1 lines +7 chars}
		$text_box tag configure warntag -foreground orange
	    }
	    if {[string compare $lvl error] == 0} {
		# Error level logging
		set msg "\[ $lvl \] $txt \n"
		$text_box insert end $msg
		$text_box tag add errortag \
		    {insert linestart -1 lines +2 chars} \
		    {insert linestart -1 lines +7 chars}
		$text_box tag configure errortag -foreground red
	    }
	    # Scroll to the end
	    $text_box see end
	}
    }

}

# Define the callback function for the logger for each log level
foreach lvl [logger::levels] {
    # Create new commands for the different log levels
    interp alias {} log_manager_$lvl {} lologger::message_manager $lvl
    ${log}::logproc $lvl log_manager_$lvl
}

toplevel .console_log_window
menu .console_log_window.menubar
.console_log_window configure -menu .console_log_window.menubar -height 150

wm title .console_log_window "Console Log"

# Help menu
menu .console_log_window.menubar.help -tearoff 0
.console_log_window.menubar add cascade -label Help -menu .console_log_window.menubar.help -underline 0
.console_log_window.menubar.help add command -label "About the console log..." \
    -underline 0 -command console_log_window::help

namespace eval console_log_window {

    proc cancel {} {
	# Kill the window without writing the settings
	destroy .console_log_window
    }

}

########################### Create widgets ###########################

# Console log frame label
ttk::label .console_log_window.console_log_frame_label \
    -text "Console Log" \
    -font frame_label_font

# The console log frame
ttk::labelframe .console_log_window.console_log_frame \
    -labelwidget .console_log_window.console_log_frame_label \
    -labelanchor n \
    -borderwidth 1 \
    -relief groove

# The debug console text widget
text .console_log_window.console_log_frame.text -yscrollcommand {.console_log_window.console_log_frame.scroll set} \
    -width 100 \
    -height 10 \
    -font log_font

# The debug console scrollbar
scrollbar .console_log_window.console_log_frame.scroll -orient vertical -command {.console_log_window.console_log_frame.text yview}

########################## Position widgets ##########################

set console_log_window_row 0

grid config .console_log_window.console_log_frame \
    -column 0 \
    -row $console_log_window_row \
    -columnspan 1 -rowspan 1 \
    -padx $widget_params::all_around_padding -pady $widget_params::all_around_padding \
    -sticky "snew"

# Allow the console log frame to expand
grid columnconfigure .console_log_window 0 -weight 1
grid rowconfigure .console_log_window 0 -weight 1

grid config .console_log_window.console_log_frame.text \
    -column 0 \
    -row 0 \
    -columnspan 1 -rowspan 1 \
    -padx $widget_params::all_around_padding -pady $widget_params::all_around_padding \
    -sticky "snew"

# Allow the text box to expand
grid rowconfigure .console_log_window.console_log_frame 0 -weight 1
grid columnconfigure .console_log_window.console_log_frame 0 -weight 1

grid config .console_log_window.console_log_frame.scroll \
    -column 0 \
    -row 0 \
    -columnspan 1 -rowspan 1 \
    -padx $widget_params::all_around_padding -pady $widget_params::all_around_padding \
    -sticky "nse"

# Get rid of the namespace when the window is closed
bind .console_log_window <Destroy> {
    global state_dict
    global log
    # set channel [dict get $state_dict command_channel]
    # try {
    # 	# Turn off the event handler
    # 	chan event $channel readable ""
    # } trap {} {message optdict} {
    # 	${log}::debug "No channel to generate events"
    # }
    # set channel [dict get $state_dict debug_channel]
    # try {
    # 	# Turn off the event handler
    # 	chan event $channel readable ""
    # } trap {} {message optdict} {
    # 	${log}::debug "No channel to generate events"
    # }

    # tcl calls this script multiple times.  Only delete the namespace
    # if it still exists.
    if {[namespace exists console_log_window]} {
	namespace delete console_log_window
    }

}

raise .console_log_window


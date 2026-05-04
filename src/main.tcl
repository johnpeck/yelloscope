# Hey Emacs, use -*- Tcl -*- mode

set thisfile [file normalize [info script]]

# The name of this program.  This will get used to identify logfiles,
# configuration files and other file outputs.
set program_name [file rootname [file tail $thisfile]]

# Directory where this script lives
set program_directory [file dirname $thisfile]

# Directory from which the script was invoked
set invoked_directory [pwd]

# Syscomp Unified CircuitGear Graphic User Interface
# JG

set softwareVersion "2.19"

set program_name cgr201

#Copyright 2014-2016 Syscomp Electronic Design
#www.syscompdesign.com

#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License as
#published by the Free Software Foundation; either version 2 of
#the License, or (at your option) any later verison.
#
#This program is distributed in the hope that it will be useful, but
#WITHOUT ANY WARRANTY; without even the implied warranty of
#MECHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
#the GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
#USA

#Procedure Index - main.tcl
#	showAbout
#	initializeCGR
#	showManual
#	showChangeLog

#Non-volatile addresses for saving parameters to the device (DO NOT CHANGE THESE, EVER)
set nvmAddressOffsets 0
set nvmAddressVertical 128
set nvmAddressShifts 256
set nvmAddressWaveOffset 384
#Note wave offset uses 384 through 415
set nvmAddressWaveOffsetValue 400
set nvmAddressSignature 416
set nvmAddressFrequency 512
set nvmAddressSigVoltage 528
set nvmAddressSigCurrent 544

#Folder location for GUI Images
set images [file join $program_directory Images]
set icons [file join $program_directory Icons]

# modinfo is needed to show loaded package versions
proc modinfo {modname} {
    # Return loaded module details.
    set modver [package require $modname]
    set modlist [package ifneeded $modname $modver]
    set modpath [lindex $modlist end]
    return "Loaded $modname module version $modver from ${modpath}."
}

# Create a dictionary to keep track of global state
# State variables:
#   program_name --  Name of this program (for naming the window)
#   program_version -- Version of this program
#   thisos  -- Name of the os this program is running on
#   serial_port_alias -- The human-readable name of the serial port connection
set state_dict [dict create \
		    program_name $program_name \
		    program_version $softwareVersion \
		    serial_port_alias none \
		    debug_log_file none \
		    serlog none
	       ]

########################### Set up logger ############################

# Set the log level.  Known values are:
# debug
# info
# notice
# warn
# error
# critical
# alert
# emergency
set loglevel debug

# The logging system will use the console text widget for visual
# logging.

package require logger
source [file join $program_directory lologger.tcl]
${log}::info [modinfo logger]

#Critical Packages
#Img package required for screen captures
package require Img
${log}::info [modinfo Img]

#BWidget package used for comboboxes
package require BWidget

#TKtable package used for table widgets
package require Tktable

#Status Indicator
for {set i 0} {$i < 15} {incr i} {
    set statusImage($i) [image create photo -file $images/Connection$i.png]
}
set statusState 0

set scopeAnimateIndex 0
set netAnimateIndex 0
set sigAnimateIndex 0

#Scope Mode Icon
for {set i 0} {$i < 14} {incr i} {
    set scopeIcon($i) [image create photo -file $icons/Scope/Scope$i.png]
}

#Network Analyzer Icon
for {set i 0} {$i < 16} {incr i} {
    set netIcon($i) [image create photo -file $icons/NetworkAnalyzer/NetworkAnalyzer$i.png]
}

#Signature Analyzer Icon
for {set i 0} {$i < 15} {incr i} {
    set sigIcon($i) [image create photo -file $icons/Signature/Signature$i.png]
}

# Debug level for printing messages to the console
set debugLevel 0

#Operating Mode
set opMode "CircuitGear"

#Figure out which operating system we're running on
set osType $tcl_platform(platform)
if {$osType == "unix"} {
    if {[exec uname] == "Darwin"} {set osType "Darwin"}
}

set deviceType unknown

#---=== Core Includes ===----
source [file join $program_directory widget_params.tcl]
source [file join $program_directory fonts.tcl]
source [file join $program_directory console_log_window.tcl]
source [file join $program_directory usbSerial.tcl]
source [file join $program_directory scope.tcl]
source [file join $program_directory dialog.tcl]
source [file join $program_directory display.tcl]
source [file join $program_directory cursors.tcl]
source [file join $program_directory vertical.tcl]
source [file join $program_directory recorder.tcl]
source [file join $program_directory timebase.tcl]
source [file join $program_directory trigger.tcl]
source [file join $program_directory waveform.tcl]
source [file join $program_directory digio.tcl]
source [file join $program_directory firmware.tcl]
source [file join $program_directory netalyzer.tcl]
source [file join $program_directory interpolation.tcl]

# Bring public commands into the global namespace
namespace import ::usbSerial::*

#---=== Core Procedures ===---

# showAbout
#
# Displays the about dialog box with software version and firmware revision from the device.
proc showAbout {} {
    tk_messageBox	\
	-message "Syscomp Electronic Design Ltd.\nCircuitGear GUI Version $::softwareVersion\n$usbSerial::firmwareIdent\nwww.syscompdesign.com"	\
	-default ok	\
	-icon info	\
	-title "About"
}

# initializeCGR
#
# Initializes the hardware on startup.  This procedure sends all the necessary commands to the hardware
# to ensure that it comes up in a predictable state.
proc initializeCGR {} {

    fconfigure $::portHandle -translation {binary lf}

    # Initialize device components
    wave::initWave

    # Start sampling the digital inputs every 500ms on the MK2
    if {$::deviceType == "mk2"} {
	sendCommand "d 15625"
    }

    # Turn off strip chart mode, in case it is enabled
    sendCommand "X"

    #Read vertical scale calibration from the device
    cal::readConfig

    #Read frequency calibration from the device
    wave::readFreqCalibration

    #Read signature analyzer voltage and current calibration
    if {$::deviceType=="sig"} {
	sig::restoreCal
    }

    #Read the stored offset calibration values from the device
    scope::restoreOffsetCal
    if {($::deviceType=="mini") || ($::deviceType =="sig")} {
	trigger::restoreOffsetCal
    }
    #Add offset calibration command to "Tools" menu
    .menubar.tools.toolsMenu add command	\
	-label "Calibrate Scope Offsets"	\
	-command scope::showOffsetCal

    #Read the stored shift calibration values from the device
    if {$::deviceType=="mk2"} {
	scope::restoreShiftCal
	#Add shift calibration command to the tools menu
	.menubar.tools.toolsMenu add separator
	.menubar.tools.toolsMenu add command	\
	    -label "Calibrate Scope Shift"	\
	    -command scope::showShiftCal
    }

    #Update the vertical scale settings in the hardware to match the GUI
    vertical::updateVertical

    #Set AC/DC coupling for both channels
    vertical::updateCoupling .scope.verticalA A
    vertical::updateCoupling .scope.verticalB B

    #Set the shift voltages to their initial values
    vertical::updateShift A 0
    update
    vertical::updateShift B 0
    update

    #Initialize the timebase & sampling settings
    timebase::adjustTimebase update

    #Initialize the trigger mode (auto)
    trigger::selectTriggerMode

    #Set up the trigger level
    trigger::updateTriggerLevel
    #Update the trigger hysteresis levels
    sendCommand "H $trigger::triggerLow $trigger::triggerHigh"

    #Trigger Calibration (CGR-MINI and Signature Analyzer only)
    if {($::deviceType=="mini") || ($::deviceType=="sig")} {
	.menubar.tools.toolsMenu add separator
	.menubar.tools.toolsMenu add command	\
	    -label "Calibrate Trigger Offsets"	\
	    -command trigger::showOffsetCal
    }

    #Initialize waveform generator controls
    set wavePath [wave::getWavePath]
    wave::adjustAmplitude [$wavePath.amp.ampSlider get]
    wave::adjustOffset [$wavePath.off.offSlider get]
    $wavePath.freq.freqSlider set 171
    $wavePath.wave.sine invoke
    $wavePath.wave.sine invoke

    #USB Voltage Reading
    if {$::deviceType=="mk2"} {
	grid .menubar.usbVoltage -row 0 -column 8 -sticky w -padx 10
	#Get the USB Voltage
	sendCommand V
    } elseif {$::deviceType=="sig"} {
	grid .menubar.usbVoltage -row 0 -column 8 -sticky w -padx 2
	grid .menubar.wallVoltage -row 0 -column 9 -sticky w -padx 2
	#Get the USB Voltage
	sendCommand V
    }

    #PWM Frequency Limit
    if {$::deviceType=="mk2"} {
	set digio::maxFrequencyLimit $digio::mk2MaxFrequencyLimit
    }

    #Trigger Out Pulse Width (1 ms)
    if {$::deviceType=="mk2"} {
	sendCommand "J 255 99 192"
    }

    #Waveform offset zeroing
    #if {$::deviceType=="mk2"} {
    wave::restoreZeroOffset
    #}

    #Signature Analyzer Scope Mode
    if {$::deviceType == "sig"} {
	grid .modes.sig -row 0 -column 2 -padx 10 -pady 5
	#sig::scopeMode

	#set ::opMode "Signature"
	#net::toggleOpMode
    }

    #Waveform trigger controls
    if {$::deviceType == "mk2"} {
	wave::selectWaveTriggerMode
	wave::selectWaveOutputMode
	wave::selectTriggerSource
	wave::updateOnCycles
	wave::updateOffCycles
	wave::updateRepeatCycles

	sendCommand "WWD"
    }

    #Start acquiring waveforms
    scope::acquireWaveform

}

# showManual
#
# Displays the device manual (PDF).  This procedure uses the operating system to open
# the PDF manual.
proc showManual {} {

    #Get the directory we are running in
    set scriptPath [file dirname [info script]]

    #Determine which operating system we are using - Windows or Linux/Mac
    if {$::osType=="windows"} {
	if {$::deviceType=="mini"} {
	    #Open the manual from the documentation directory if this is a full install
	    if {[file exists "$scriptPath/../Documentation/CGM101-manual.pdf"]} {
		puts "Launching manual from Documenation directory"
		eval exec [auto_execok start] \"\" [list "$scriptPath/../Documentation/CGM101-manual.pdf"]
	    } else {
		#Open the manual from the source code directory
		puts "Launcing manual from Source directory"
		eval exec [auto_execok start] \"\" [list "CGM101-manual.pdf"]
	    }
	} elseif {$::deviceType=="sig"} {
	    if {[file exists "$scriptPath/../Documentation/SIG101-manual.pdf"]} {
		puts "Launching manual from Documenation directory"
		eval exec [auto_execok start] \"\" [list "$scriptPath/../Documentation/SIG101-manual.pdf"]
	    } else {
		#Open the manual from the source code directory
		puts "Launcing manual from Source directory"
		eval exec [auto_execok start] \"\" [list "SIG101-manual.pdf"]
	    }
	} else {
	    #Open the manual from the documentation directory if this is a full install
	    if {[file exists "$scriptPath/../Documentation/CGR-201-Manual.pdf"]} {
		puts "Launching manual from Documenation directory"
		eval exec [auto_execok start] \"\" [list "$scriptPath/../Documentation/CGR-201-Manual.pdf"]
	    } else {
		#Open the manual from the source code directory
		puts "Launcing manual from Source directory"
		eval exec [auto_execok start] \"\" [list "CGR-201-Manual.pdf"]
	    }
	}

    } else {
	if {$::deviceType=="mini"} {
	    #Linux - use the "see" command to have the OS pick the best application to open the PDF
	    eval exec see [list "CGM101-manual.pdf"]
	} else {
	    #Linux - use the "see" command to have the OS pick the best application to open the PDF
	    eval exec see [list "CGR-201-Manual.pdf"]
	}

    }
}

# showChangeLog
#
# Displays the change log in a separate window with appropriate window dressings (scroll bars, etc)
proc showChangeLog {} {

    #Make sure the change log isn't already open
    if {[winfo exists .changeLog]} {
	raise .changeLog
	focus .changeLog
	return
    }

    #Create a new window to hold the log
    toplevel .changeLog
    wm title .changeLog "CGM-101 Change Log"

    #Open the change log and read it
    set fileId [open "Changes.txt" r]
    set changeData [read $fileId]
    close $fileId

    #Build widgets to display the log
    text .changeLog.log	\
	-width 80	\
	-yscrollcommand ".changeLog.scrollVert set"	\
	-xscrollcommand ".changeLog.scrollHor set"	\
	-wrap none

    .changeLog.log insert end $changeData
    .changeLog.log configure -state disabled

    scrollbar .changeLog.scrollVert	\
	-command ".changeLog.log yview"	\
	-orient vertical

    scrollbar .changeLog.scrollHor	\
	-command ".changeLog.log xview"	\
	-orient horizontal

    grid .changeLog.log -row 0 -column 0 -sticky news
    grid .changeLog.scrollVert -row 0 -column 1 -sticky ns
    grid .changeLog.scrollHor -row 1 -column 0 -sticky we
    grid rowconfigure .changeLog .changeLog.log -weight 1
    grid rowconfigure .changeLog .changeLog.scrollVert -weight 1
    grid columnconfigure .changeLog .changeLog.log -weight 1
    grid columnconfigure .changeLog .changeLog.scrollHor -weight 1

}

proc saveSettings {} {

    set types {
	{{Config Files}	{.cfg}}
    }

    set settingsFile [tk_getSaveFile -filetypes $types]

    if {$settingsFile == ""} {return}

    if {[catch {open "$settingsFile.cfg" w} fileId]} {
	tk_messageBox	\
	    -message "Unable to write to saved settings file."	\
	    -type ok	\
	    -icon error
	saveSettings
	return
    }

    #Save the vertical settings
    puts $fileId $vertical::verticalIndexA
    puts $fileId $vertical::verticalIndexB
    puts $fileId $vertical::scopeProbeA
    puts $fileId $vertical::scopeProbeB

    #Save the timebase settings
    puts $fileId $timebase::timebaseIndex

    #Save trigger settings
    puts $fileId $trigger::triggerMode
    puts $fileId $trigger::triggerSlope
    puts $fileId $trigger::triggerSource

    #Save waveform generator frequency
    puts $fileId $wave::waveFrequency

    #Save waveform generator amplitude
    puts $fileId $wave::amplitude

    #Save waveform generator offset
    puts $fileId $wave::offset

    #Save current waveform file name
    puts $fileId $wave::currentWaveform

    #Save waveform generator frequency slider mode
    puts $fileId $wave::sliderMode

    #Save the state of the digital outputs
    puts $fileId $digio::digout(0)
    puts $fileId $digio::digout(1)
    puts $fileId $digio::digout(2)
    puts $fileId $digio::digout(3)
    puts $fileId $digio::digout(4)
    puts $fileId $digio::digout(5)
    puts $fileId $digio::digout(6)
    puts $fileId $digio::digout(7)

    #Save the pwm settings
    puts $fileId $digio::pwmDuty
    puts $fileId $digio::frequencyPosition

    #Save cursor settings
    if {$trigger::triggerSource == "A"} {
	puts $fileId [expr {$cursor::trigPos-$cursor::chAGndPos}]
    } else {
	puts $fileId [expr {$cursor::trigPos-$cursor::chBGndPos}]
    }
    puts $fileId $cursor::chAGndPos
    puts $fileId $cursor::chBGndPos

    #Save the probe settings
    puts $fileId $vertical::scopeProbeA
    puts $fileId $vertical::scopeProbeB

    #Save VNA settings
    puts $fileId $net::startValuePow
    puts $fileId $net::startFrequency

    puts $fileId $net::endValuePow
    puts $fileId $net::endFrequency

    puts $fileId $net::frequencyStepMode
    puts $fileId $net::frequencyLogStep
    puts $fileId $net::frequencyLinStep

    puts $fileId $net::maxAmplitude

    close $fileId

}

proc loadSettings {} {

    set types {
	{{Config Files}	{.cfg}}
    }

    set settingsFile [tk_getOpenFile -filetypes $types]
    if {$settingsFile == ""} {
	return
    }

    #Open the file for reading
    if {[catch {open $settingsFile r}  fileId]} {
	tk_messageBox	\
	    -message "Unable to open settings file."	\
	    -type ok	\
	    -icon warning
	return
    }

    #Read out all settings from the file
    set settings {}
    while {[gets $fileId line] >= 0} {
	lappend settings $line
    }
    close $fileId

    #Restore vertical settings
    set vertical::verticalIndexA [lindex $settings 0]
    set vertical::verticalIndexB [lindex $settings 1]
    vertical::adjustVertical .scope.verticalA A update
    vertical::adjustVertical .scope.verticalB B update
    cursor::measureVoltageCursors
    set vertical::probeA [lindex $settings 2]
    set vertical::probeB [lindex $settings 3]

    #Restore timebase setting
    set timebase::newTimebaseIndex [lindex $settings 4]
    timebase::adjustTimebase update

    #Restore trigger settings
    set trigger::triggerMode [lindex $settings 5]
    set trigger::triggerSlope [lindex $settings 6]
    set trigger::triggerSource [lindex $settings 7]
    trigger::selectTriggerMode

    #Restore waveform generator frequency
    set wave::waveFrequency [lindex $settings 8]
    wave::sendFrequency $wave::waveFrequency
    set wave::frequencyDisplay "$wave::waveFrequency Hz"

    #Restore waveform generator amplitude
    set wave::amplitude [lindex $settings 9]
    #wave::adjustAmplitude $wave::amplitude
    [wave::getWavePath].amp.ampSlider set $wave::amplitude

    #Restore waveform generator offset
    set wave::offset [lindex $settings 10]
    #wave::adjustOffset $wave::offset
    [wave::getWavePath].off.offSlider set $wave::offset

    #Restore current waveform
    switch [lindex $settings 11] {
	"sine" {
	    [wave::getWavePath].wave.sine invoke
	} "square" {
	    [wave::getWavePath].wave.square invoke
	} "sawtooth" {
	    [wave::getWavePath].wave.sawtooth invoke
	} "custom" {
	    [wave::getWavePath].wave.custom invoke
	}
    }

    #Restore waveform generator frequency slider mode
    set wave::sliderMode [lindex $settings 12]

    #Restore digital outputs
    if {[lindex $settings 13]} {digio::toggleOutBit 0}
    if {[lindex $settings 14]} {digio::toggleOutBit 1}
    if {[lindex $settings 15]} {digio::toggleOutBit 2}
    if {[lindex $settings 16]} {digio::toggleOutBit 3}
    if {[lindex $settings 17]} {digio::toggleOutBit 4}
    if {[lindex $settings 18]} {digio::toggleOutBit 5}
    if {[lindex $settings 19]} {digio::toggleOutBit 6}
    if {[lindex $settings 20]} {digio::toggleOutBit 7}

    #Restore PWM settings
    set digio::pwmDuty [lindex $settings 21]
    digio::updatePWM
    [digio::getDigioPath].pwm.freq.slider set [lindex $settings 22]

    #Restore cursor settings
    #set cursor::trigPos [lindex $settings 23]
    #set cursor::yStart  [expr {($display::yAxisEnd-$display::yAxisStart)/2.0}]
    #cursor::moveTrigger [expr {($display::yAxisEnd-$display::yAxisStart)/2.0 + $cursor::trigPos}]
    #set cursor::chAGndPos [lindex $settings 24]
    #set cursor::yStart [expr {($display::yAxisEnd-$display::yAxisStart)/2.0}]
    #cursor::moveChAGnd $cursor::chAGndPos
    #set cursor::chBGndPos [lindex $settings 25]
    #set cursor::yStart  [expr {($display::yAxisEnd-$display::yAxisStart)/2.0}]
    #cursor::moveChBGnd $cursor::chBGndPos

    #Restore the probe settings
    set vertical::scopeProbeA [lindex $settings 26]
    set vertical::scopeProbeB [lindex $settings 27]
    vertical::updateIndicator .scope.verticalA A
    vertical::updateIndicator .scope.verticalB B

    #Restore the VNA settings
    set net::startValuePow [lindex $settings 28]
    set net::startFrequency [lindex $settings 29]

    set net::endValuePow [lindex $settings 30]
    set net::endFrequency [lindex $settings 31]

    set net::frequencyStepMode [lindex $settings 32]
    set net::frequencyLogStep [lindex $settings 33]
    set net::frequencyLinStep [lindex $settings 34]

    set net::maxAmplitude [lindex $settings 35]

}

proc animateScopeIcon {} {

    showModeTooltip .modes.oscilloscope "CircuitGear Mode\nOscilloscope"

    bind .modes.oscilloscope <Any-Leave>    [list after 1 [list destroy .modes.oscilloscope.tooltip]]
    bind .modes.oscilloscope <Any-KeyPress> [list after 1 [list destroy .modes.oscilloscope.tooltip]]
    bind .modes.oscilloscope <Any-Button>   [list after 1 [list destroy .modes.oscilloscope.tooltip]]

    set ::scopeAnimateIndex 0
    animateScopeService
}

proc animateScopeService {} {

    if {$::scopeAnimateIndex < 14} {
	.modes.oscilloscope configure -image $::scopeIcon($::scopeAnimateIndex)
	incr ::scopeAnimateIndex
	after 33 animateScopeService
    }
}

proc animateNetIcon {} {

    showModeTooltip .modes.net "Network Analyzer\nBode Plotter"

    bind .modes.net <Any-Leave>    [list after 1 [list destroy .modes.net.tooltip]]
    bind .modes.net <Any-KeyPress> [list after 1 [list destroy .modes.net.tooltip]]
    bind .modes.net <Any-Button>   [list after 1 [list destroy .modes.net.tooltip]]

    set ::netAnimateIndex 0
    animateNetService
}

proc animateNetService {} {
    if {$::netAnimateIndex < 16} {
	.modes.net configure -image $::netIcon($::netAnimateIndex)
	incr ::netAnimateIndex
	after 33 animateNetService
    }
}

proc animateSigIcon {} {

    showModeTooltip .modes.sig "Signature Analyzer"

    bind .modes.sig <Any-Leave>    [list after 1 [list destroy .modes.sig.tooltip]]
    bind .modes.sig <Any-KeyPress> [list after 1 [list destroy .modes.sig.tooltip]]
    bind .modes.sig <Any-Button>   [list after 1 [list destroy .modes.sig.tooltip]]

    set ::sigAnimateIndex 0
    animateSigService
}

proc animateSigService {} {
    if {$::sigAnimateIndex < 15} {
	.modes.sig configure -image $::sigIcon($::sigAnimateIndex)
	incr ::sigAnimateIndex
	after 33 animateSigService
    }
}

proc showModeTooltip {widget text} {
    global tcl_platform

    # puts "Entering tooltip"

    # puts "widget is $widget"

    if { [string match $widget* [winfo containing  [winfo pointerx .] [winfo pointery .]] ] == 0  } {
	return
    }

    # puts "Widget match"

    catch { destroy $widget.tooltip }

    set scrh [winfo screenheight $widget]    ; # 1) flashing window fix
    set scrw [winfo screenwidth $widget]     ; # 1) flashing window fix
    set tooltip [toplevel $widget.tooltip -bd 1 -bg black]
    wm geometry $tooltip +$scrh+$scrw        ; # 1) flashing window fix
    wm overrideredirect $tooltip 1

    if {$tcl_platform(platform) == {windows}} { ; # 3) wm attributes...
	wm attributes $tooltip -topmost 1   ; # 3) assumes...
    }                                           ; # 3) Windows
    pack [label $tooltip.label -bg lightyellow -fg black -text $text -justify center -font {-weight bold -size -12}]

    set width [winfo reqwidth $tooltip.label]
    set height [winfo reqheight $tooltip.label]

    set pointer_below_midline [expr [winfo pointery .] > [expr [winfo screenheight .] / 2.0]]                ; # b.) Is the pointer in the bottom half of the screen?

    set positionX [expr [winfo rootx $widget]]
    set positionY [expr [winfo rooty $widget] + $height + 10]

    #set positionX [expr [winfo pointerx .] - round($width / 2.0)]    ; # c.) Tooltip is centred horizontally on pointer.
    #set positionY [expr [winfo pointery .] + 35 * ($pointer_below_midline * -2 + 1) - round($height / 2.0)]  ; # b.) Tooltip is displayed above or below depending on pointer Y position.

    # a.) Ad-hockery: Set positionX so the entire tooltip widget will be displayed.
    # c.) Simplified slightly and modified to handle horizontally-centred tooltips and the left screen edge.
    if  {[expr $positionX + $width] > [winfo screenwidth .]} {
	set positionX [expr [winfo screenwidth .] - $width]
    } elseif {$positionX < 0} {
	set positionX 0
    }

    wm geometry $tooltip [join  "$width x $height + $positionX + $positionY" {}]
    raise $tooltip

    # 2) Kludge: defeat rare artifact by passing mouse over a tooltip to destroy it.
    #bind $widget.tooltip <Any-Enter> {destroy %W}
    #bind $widget.tooltip <Any-Leave> {destroy %W}
}

#---=== GUI Construction ===---
wm title . "Oscilloscope"
wm resizable . 0 0

#Create the menu bar
frame .menubar -relief raised -borderwidth 1

#Create the drop down menus

#File Menu
menubutton .menubar.file	\
    -text "File"		\
    -menu .menubar.file.filemenu
menu .menubar.file.filemenu -tearoff 0
.menubar.file.filemenu add command	\
    -label "Save Settings"	\
    -command saveSettings
.menubar.file.filemenu add command 	\
    -label "Load Settings"	\
    -command loadSettings
.menubar.file.filemenu add separator
.menubar.file.filemenu add command	\
    -label "Exit"	\
    -command {destroy .}

#View Menu
menubutton .menubar.scopeView \
    -text "View"	\
    -menu .menubar.scopeView.viewMenu
menu .menubar.scopeView.viewMenu -tearoff 0
if {$osType == "windows"} {
    .menubar.scopeView.viewMenu add command	\
	-label "Debug Console"	\
	-command {console show}
    .menubar.scopeView.viewMenu add separator
}
#Color Options
.menubar.scopeView.viewMenu add command	\
    -label "Color Options"	\
    -command display::showColorOptions
.menubar.scopeView.viewMenu add separator
#XY Mode selector
.menubar.scopeView.viewMenu add check	\
    -label "XY Mode"	\
    -variable display::xyEnable	\
    -command display::toggleXYMode
#Cursors
cursor::addCursorMenu
#Interpolation
#.menubar.scopeView.viewMenu add separator
#.menubar.scopeView.viewMenu add check	\
    #	-label "Interpolation"	\
    #	-variable interpEnable
set ::interpEnable 0

#Tools Menu
menubutton .menubar.tools	\
    -text "Tools"	\
    -menu .menubar.tools.toolsMenu
menu .menubar.tools.toolsMenu -tearoff 0
#WaveMaker command
.menubar.tools.toolsMenu add command	\
    -label "WaveMaker Waveform Editor"	\
    -command waveMaker::showWaveMaker
.menubar.tools.toolsMenu add separator
.menubar.tools.toolsMenu add command	\
    -label "Calibrate Waveform Generator"	\
    -command wave::waveCal
.menubar.tools.toolsMenu add separator

#Hardware Menu
menubutton .menubar.hardware	\
    -text "Hardware"	\
    -menu .menubar.hardware.hardwareMenu
menu .menubar.hardware.hardwareMenu	-tearoff 0
.menubar.hardware.hardwareMenu add command	\
    -label "Connect..."	\
    -command ::usbSerial::openSerialPort
.menubar.hardware.hardwareMenu add separator
#Selector for CircuitGear Mode
#.menubar.hardware.hardwareMenu add check	\
    #	-label "CircuitGear Mode"	\
    #	-variable opMode			\
    #	-onvalue "CircuitGear"		\
    #	-command net::toggleOpMode
#Selector for Network Analyzer Mode
#.menubar.hardware.hardwareMenu add check	\
    #	-label "Network Analyzer Mode"	\
    #	-variable opMode			\
    #	-onvalue "Netalyzer"		\
    #	-command net::toggleOpMode
#Selector for Signature Analyzer Mode
#.menubar.hardware.hardwareMenu add check	\
    #	-label "Signature Analyzer Mode"	\
    #	-variable opMode	\
    #	-onvalue "Signature"	\
    #	-command net::toggleOpMode
#Selector for Impedance Analyzer Mode
#.menubar.hardware.hardwareMenu add check	\
    #	-label "Impedance Analyser Mode"	\
    #	-variable opMode	\
    #	-onvalue "Impedance"	\
    #	-command net::toggleOpMode

#Help Menu
menubutton .menubar.help	\
    -text "Help"		\
    -menu .menubar.help.helpMenu
menu .menubar.help.helpMenu -tearoff 0
.menubar.help.helpMenu add command	\
    -label "About"	\
    -command showAbout
.menubar.help.helpMenu add separator
.menubar.help.helpMenu add command	\
    -label "Manual (pdf)"	\
    -command showManual
.menubar.help.helpMenu add separator
.menubar.help.helpMenu add command	\
    -label "Change Log"	\
    -command showChangeLog
.menubar.help.helpMenu add separator
.menubar.help.helpMenu add command	\
    -label "Firmware Upgrade..."	\
    -command {firmware::showFirmware 1}
.menubar.help.helpMenu add separator

#Label for USB Voltage
label .menubar.usbVoltage	\
    -text "USB Voltage: -.--V"

#Label for 12V Wall Adapter Voltage
label .menubar.wallVoltage	\
    -text "12V Input: -.--V"

#Create an indicator for the status of the serial-usb connection
label .menubar.serialPortStatus	\
    -textvariable ::usbSerial::serialStatus	\
    -background red

#Place the menus on the menubar
grid .menubar.file -row 0 -column 0 -sticky w
grid .menubar.scopeView -row 0 -column 1 -sticky w
grid .menubar.tools -row 0 -column 2 -sticky w
grid .menubar.hardware -row 0 -column 3 -sticky w
grid .menubar.help -row 0 -column 4 -sticky w
grid .menubar.serialPortStatus -row 0 -column 6 -sticky w -padx 10

#Frame for mode controls

labelframe .modes	\
    -text "Hardware Mode"	\
    -relief groove	\
    -borderwidth 2

button .modes.oscilloscope	\
    -image $scopeIcon(13)	\
    -command {set opMode "CircuitGear";net::toggleOpMode}
bind .modes.oscilloscope <Enter> {animateScopeIcon}

button .modes.net	\
    -image $netIcon(15)	\
    -command {set opMode "Netalyzer";net::toggleOpMode}
bind .modes.net <Enter> {animateNetIcon}

button .modes.sig	\
    -image $sigIcon(14)	\
    -command {set opMode "Signature";net::toggleOpMode}
bind .modes.sig <Enter> {animateSigIcon}

grid .modes.oscilloscope -row 0 -column 0 -padx 10 -pady 5
grid .modes.net -row 0 -column 1 -padx 10 -pady 5
#grid .modes.sig -row 0 -column 2 -padx 10 -pady 5

#Build the Oscilloscope
scope::buildScope

#Build the Waveform Generator
toplevel .wave
wm title .wave "Waveform Generator"
wm resizable .wave 0 0
wm protocol .wave WM_DELETE_WINDOW {
    wm iconify .wave
}
wave::setWavePath .wave
wave::buildWave

#Build the Digital I/O Controls
toplevel .digio
wm title .digio "Digital I/O"
wm resizable .digio 0 0
wm protocol .digio WM_DELETE_WINDOW {
    wm iconify .digio
}
digio::setDigioPath .digio
digio::buildDigio

wm protocol .console_log_window WM_DELETE_WINDOW {
    wm iconify .console_log_window
}

#Connection Animation
label .connection	\
    -image $statusImage(0)

#Place the major Frames
grid .menubar -row 0 -column 0 -sticky w
grid .connection -row 0 -column 1 -sticky e
grid .modes -row 1 -column 0 -sticky w -padx 2 -pady 2
grid .scope -row 2 -column 0 -columnspan 2

# Position windows
wm geometry . "+0+0"
wm geometry .digio "+0+0"
wm geometry .wave "+0+0"
wm geometry .console_log_window "+0+0"

display::readColorSettings

#Add-ons
source [file join $program_directory wavemaker.tcl]
source [file join $program_directory FFT.tcl]
source [file join $program_directory automeasure.tcl]
source [file join $program_directory math.tcl]
source [file join $program_directory export.tcl]
source [file join $program_directory updateCheck.tcl]
source [file join $program_directory persist.tcl]
source [file join $program_directory calibration.tcl]
source [file join $program_directory tooltip.tcl]
source [file join $program_directory average.tcl]
source [file join $program_directory signature.tcl]

#Open a connection to the device
usbSerial::getStoredPort
usbSerial::openSerialPort

${log}::info "This is $program_name version $softwareVersion"
${log}::info "Sending logger output above level $loglevel to [dict get $state_dict debug_log_file]"


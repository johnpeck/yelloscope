#File: netalyzer.tcl
#Syscomp Electronic Design
#Network Analysis Toolbox

#JG
#Copyright 2008 Syscomp Electronic Design
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

namespace eval net {

    #Frequency Parameters
    #set startFrequency 10
    set startFrequency 10
    #set endFrequency 200000
    set endFrequency 100E3
    #set startValuePow -1
    set startValuePow [expr {log10($startFrequency)}]
    set endValuePow [expr {log10($endFrequency)}]
    set frequencyLogStep 1.1
    set frequencyLinStep 100
    set frequencyStepMode "log"

    #Device Status
    set currentFrequency 1
    set currentFrequencyDisplay 1
    set chAScale "25V Max"
    set chBScale "25V Max"
    set status "Idle"
    set analyzeEnable 0

    #Graph Geometry
    set plotWidth 500
    set plotHeight 300
    set minimumGraphWidth $plotWidth
    set minimumGraphHeight $plotHeight
    set topBorder 15
    set bottomBorder 15
    set leftBorder 30
    set rightBorder 30

    #Scope Display Geometry
    set scopePlotWidth 256
    set scopePlotHeight 256

    set testFrequencies {}

    set sineRef {}
    set cosRef {}

    set testFrequencies {}
    set testFrequencyIndex 0
    set xValues {}

    set captureOK 0
    set numIterations 0
    set netTimeout 0

    set xFreq {}
    set yMag {}
    set yPhase {}
    set quality {}

    set refFreq {}
    set refMag {}
    set refPhase {}
    set refQuality {}
    set referenceEnabled 0

    #Constants
    set pi [expr {atan(1) * 4}]

    set topTick 0
    set botTick 0

    set maxAmplitude 0

    set scientificNotation 1

    set phaseOffset 180

    set resonantEnable 0

    set gripperImage [image create photo -file $::images/Gripper.gif]

    set buildOutResistorValues {"50\u2126" "5k\u2126" "500k\u2126"}
    set buildOutResistorUnicode [lindex $buildOutResistorValues 0]
    set buildOutResitorValue 50

    set snapToTrace 0

    set debugEnable 0

}

proc net::toggleOpMode {} {

    if {($::opMode == "Netalyzer") || ($::opMode == "Impedance")} {
	#Go away, scope
	grid forget .scope
	wm withdraw .wave
	wm withdraw .digio
	#Get rid of existing network/impedance analyser controls
	destroy .net
	destroy .menubar.netView
	
	#Stop any on-going scope captures
	set trigger::triggerMode "Single-Shot"
	trigger::selectTriggerMode
	trigger::manualTrigger
	
	#Remove the scope view menu
	grid remove .menubar.scopeView
	
	net::buildNetalyzer
	
    } elseif {($::opMode =="Signature")} {
	
	#Go away, other modes
	grid forget .scope
	wm withdraw .wave
	wm withdraw .digio
	
	.menubar.file configure -menu .menubar.file.sigFileMenu
	.menubar.scopeView configure -menu .menubar.scopeView.sigViewMenu
	.menubar.tools configure -menu .menubar.tools.sigToolsMenu
	.menubar.hardware configure -menu .menubar.hardware.sigHardwareMenu
	.menubar.help configure -menu .menubar.help.sigHelpMenu
	
	if {$net::analyzeEnable} {
	    set net::analyzeEnable 0
	    after 3000 {set net::status "Idle"}
	    while {$net::status!="Idle"} {
		update
	    }
	}
	destroy .net
	destroy .sig
	
	sig::buildSignature
	
	if {$::deviceType == "sig"} {
	    sig::signatureMode
	}
	
	update
	
	#Make sure we are in auto trigger mode
	set trigger::triggerMode "Auto"
	trigger::selectTriggerMode
	
    } else {
	#Switch back to scope mode
	
	if {$net::analyzeEnable} {
	    set net::analyzeEnable 0
	    after 3000 {set net::status "Idle"}
	    while {$net::status!="Idle"} {
		update
	    }
	}
	
	#Remove the other GUIs
	destroy .net
	destroy .sig
	
	wm deiconify .wave
	wm deiconify .digio
	
	.menubar.file configure -menu .menubar.file.filemenu
	.menubar.scopeView configure -menu .menubar.scopeView.viewMenu
	.menubar.tools configure -menu .menubar.tools.toolsMenu
	.menubar.hardware configure -menu .menubar.hardware.hardwareMenu
	.menubar.help configure -menu .menubar.help.helpMenu
	
	if {$::deviceType == "sig"} {
	    sig::scopeMode
	}
	
	#Find the "Clear plots command in the view menu and remove it"
	#set temp [.menubar.view.viewmenu index "Clear Bode Plots"]
	#.menubar.view.viewmenu delete $temp
	set trigger::triggerMode "Auto"
	trigger::selectTriggerMode
	
	grid .scope -row 2 -column 0 -columnspan 2
	
	vertical::updateVertical
	timebase::adjustTimebase update

	destroy .menubar.netView
	grid .menubar.scopeView -row 0 -column 1
    }


}

proc net::buildNetalyzer {} {
    global osType

    if {$::opMode=="Impedance"} {
	set labelText "Impedance Analyser"
    } else {
	set labelText "Network Analyser"
    }
    
    labelframe .net	\
	-relief groove	\
	-borderwidth 2	\
	-text $labelText	\
	-font {-weight bold -size -12}
    
    frame .net.controls
    
    frame .net.controls.inputs	\
	-relief groove	\
	-borderwidth 2
    
    label .net.controls.inputs.startLabel	\
	-text "Start Frequency"	\
	-width 20	\
	-font {-weight bold -size -12}
    
    button .net.controls.inputs.startValue	\
	-textvariable net::startFrequency	\
	-width 10	\
	-command net::setStartFrequency
    
    #Minimum frequency is 10^(-1)=0.1Hz
    set logMin -1.0
    
    if {$::deviceType=="mk2"} {
	#Maximum frequency is 10^7=10MHz
	set logLimit 7.0
    } else {
	#Maximum frequency is 10^5.3=200kHz
	set logLimit 5.301029996
    }
    
    scale .net.controls.inputs.startFrequency	\
	-length 200		\
	-from $logMin		\
	-to $logLimit			\
	-orient horizontal	\
	-command {net::clearPlots;net::updateStartValue}	\
	-variable net::startValuePow	\
	-showvalue 0	\
	-resolution 0.01
    
    #.net.controls.inputs.startFrequency set 1.0
    
    label .net.controls.inputs.endLabel	\
	-text "End Frequency"	\
	-width 20	\
	-font {-weight bold -size -12}
    
    button .net.controls.inputs.endValue	\
	-textvariable net::endFrequency	\
	-width 10	\
	-command net::setEndFrequency
    
    
    
    scale .net.controls.inputs.endFrequency	\
	-length 200		\
	-from $logMin		\
	-to $logLimit		\
	-orient horizontal	\
	-command {net::clearPlots;net::updateEndValue}	\
	-variable net::endValuePow	\
	-showvalue 0	\
	-resolution 0.01
    
    label .net.controls.inputs.stepLabel	\
	-text "Frequency Step"	\
	-width 20	\
	-font {-weight bold -size -12}
    
    button .net.controls.inputs.stepValue	\
	-textvariable net::frequencyLogStep	\
	-width 10	\
	-command net::setFrequencyStep
    
    scale .net.controls.inputs.frequencyStep	\
	-length 200		\
	-orient horizontal	\
	-showvalue 0
    #Set up the scale parameters	
    net::selectStepMode
    
    frame .net.controls.inputs.stepMode
    
    radiobutton .net.controls.inputs.stepMode.log	\
	-text "Logarithmic"	\
	-value "log"	\
	-variable net::frequencyStepMode	\
	-command net::selectStepMode
    
    radiobutton .net.controls.inputs.stepMode.linear	\
	-text "Linear"	\
	-value "linear"	\
	-variable net::frequencyStepMode	\
	-command net::selectStepMode
    
    grid .net.controls.inputs.stepMode.log -row 0 -column 0
    grid .net.controls.inputs.stepMode.linear -row 0 -column 1
    
    label .net.controls.inputs.waveAmpLabel	\
	-text "Max Waveform Amplitude"	\
	-font {-weight bold -size -12}
    
    label .net.controls.inputs.waveAmpValue	\
	-textvariable net::maxAmplitude	\
	-width 10
    
    scale .net.controls.inputs.waveAmp	\
	-from 0	\
	-to 100	\
	-variable net::maxAmplitude	\
	-orient horizontal	\
	-length 200		\
	-showvalue 0	\
	-tickinterval 25	\
	-resolution 1
    
    frame .net.controls.inputs.buttons
    
    button .net.controls.inputs.buttons.start	\
	-text "START"		\
	-width 8			\
	-height 2			\
	-command {set net::analyzeEnable 1; net::analyze}
    
    button .net.controls.inputs.buttons.stop	\
	-text "STOP"		\
	-width 8			\
	-height 2			\
	-command net::stop_analyzer
    
    grid .net.controls.inputs.buttons.start -row 0 -column 0 
    grid .net.controls.inputs.buttons.stop -row 0 -column 1 	
    
    grid .net.controls.inputs.startLabel -row 0 -column 0 -sticky w
    grid .net.controls.inputs.startValue -row 0 -column 1
    grid .net.controls.inputs.startFrequency -row 1 -column 0 -columnspan 2
    
    grid .net.controls.inputs.endLabel -row 2 -column 0 -sticky w
    grid .net.controls.inputs.endValue -row 2 -column 1
    grid .net.controls.inputs.endFrequency -row 3 -column 0 -columnspan 2
    
    grid .net.controls.inputs.stepLabel -row 4 -column 0 -sticky w
    grid .net.controls.inputs.stepValue -row 4 -column 1
    grid .net.controls.inputs.frequencyStep -row 5 -column 0 -columnspan 2
    grid .net.controls.inputs.stepMode -row 6 -column 0 -columnspan 2
    
    grid .net.controls.inputs.waveAmpLabel -row 7 -column 0
    grid .net.controls.inputs.waveAmpValue -row 7 -column 1
    grid .net.controls.inputs.waveAmp -row 8 -column 0 -columnspan 2
    
    grid .net.controls.inputs.buttons -row 9 -column 0 -columnspan 2

    
    frame .net.controls.readouts	\
	-relief groove	\
	-borderwidth 2
    
    label .net.controls.readouts.frequencyLabel	\
	-text "Current Frequency:"
    
    label .net.controls.readouts.frequency	\
	-textvariable net::currentFrequencyDisplay	\
	-width 10	\
	-relief sunken
    
    label .net.controls.readouts.chALabel	\
	-text "Channel A Preamp:"
    
    label .net.controls.readouts.chA	\
	-textvariable net::chAScale	\
	-width 10	\
	-relief sunken
    
    label .net.controls.readouts.chBLabel	\
	-text "Channel B Preamp:"
    
    label .net.controls.readouts.chB	\
	-textvariable net::chBScale	\
	-width 10	\
	-relief sunken
    
    label .net.controls.readouts.ampLabel	\
	-text "Waveform Amplitude (%):"
    
    label .net.controls.readouts.amp	\
	-textvariable wave::amplitude	\
	-width 10	\
	-relief sunken
    
    label .net.controls.readouts.stateLabel	\
	-text "Analyzer Status:"
    
    label .net.controls.readouts.state		\
	-textvariable net::status		\
	-width 10	\
	-relief sunken
    
    grid .net.controls.readouts.frequencyLabel -row 0 -column 0
    grid .net.controls.readouts.frequency -row 0 -column 1
    grid .net.controls.readouts.chALabel -row 1 -column 0
    grid .net.controls.readouts.chA -row 1 -column 1
    grid .net.controls.readouts.chBLabel -row 2 -column 0
    grid .net.controls.readouts.chB -row 2 -column 1
    grid .net.controls.readouts.ampLabel -row 3 -column 0
    grid .net.controls.readouts.amp -row 3 -column 1
    grid .net.controls.readouts.stateLabel -row 4 -column 0
    grid .net.controls.readouts.state -row 4 -column 1
    
    grid .net.controls.inputs -row 0 -column 0 -pady 10
    grid .net.controls.readouts -row 1 -column 0 -padx 5 -pady 10 
    
    #Frame for impedance analyzer build out resistor
    frame .net.buildout	\
	-relief groove	\
	-borderwidth 2
    
    label .net.buildout.title	\
	-text "Select Buildout Resistance:"
    
    ttk::combobox .net.buildout.resistorValue	\
	-justify center	\
	-textvariable net::buildOutResistorUnicode	\
	-values $net::buildOutResistorValues	\
	-width 10
    
    grid .net.buildout.title -row 0 -column 0
    grid .net.buildout.resistorValue -row 1 -column 0
    
    #Frame for graphs
    frame .net.graphs	\
	-relief groove	\
	-borderwidth 2
    
    #Magnitude Response Canvas
    canvas .net.graphs.mag	\
	-width [expr {$net::plotWidth+$net::leftBorder+$net::rightBorder}]	\
	-height [expr {$net::plotHeight+$net::topBorder+$net::bottomBorder}]	\
	-background white	\
	-borderwidth 2
    
    #Draw Magnitude Y-Axis
    .net.graphs.mag create line	\
	$net::leftBorder [expr {$net::topBorder+$net::plotHeight}]	\
	$net::leftBorder [expr {$net::topBorder}]
    
    #Phase Response Canvas
    canvas .net.graphs.phase	\
	-width [expr {$net::plotWidth+$net::leftBorder+$net::rightBorder}]	\
	-height [expr {$net::plotHeight+$net::topBorder+$net::bottomBorder}]	\
	-background white	\
	-borderwidth 2
    
    label .net.graphs.gripper	\
	-image $net::gripperImage
    
    bind .net.graphs.gripper <Button-1> {set net::gripperStart [list %X %Y]}
    bind .net.graphs.gripper <B1-Motion> {net::moveGripper %X %Y}
    
    #Draw Phase Axes
    .net.graphs.phase create line	\
	$net::leftBorder $net::topBorder	\
	[expr {$net::leftBorder+$net::plotWidth}] $net::topBorder
    .net.graphs.phase create line	\
	$net::leftBorder $net::topBorder	\
	$net::leftBorder [expr {$net::topBorder+$net::plotHeight}]
    net::yScale phase
    
    grid .net.graphs.mag -row 0 -column 0
    grid .net.graphs.phase -row 1 -column 0
    grid .net.graphs.gripper -row 1 -column 0 -sticky se -ipadx 0 -ipady 0 -padx 0 -pady 0
    
    #Cursors
    bind .net.graphs.mag <Enter> {.net.graphs.mag configure -cursor crosshair}
    bind .net.graphs.phase <Enter> {.net.graphs.phase configure -cursor crosshair}
    bind .net.graphs.mag <Motion> {net::updateMagCursor %x %y}
    bind .net.graphs.phase <Motion> {net::updatePhaseCursor %x %y}
    bind .net.graphs.mag <Leave> {.net.graphs.mag delete magCursor}
    bind .net.graphs.phase <Leave> {.net.graphs.phase delete phaseCursor}
    
    #Frame for scope display
    frame .net.scope	\
	-relief groove	\
	-borderwidth 2
    
    label .net.scope.title	\
	-text "Oscilloscope Display"	\
	-font {-weight bold -size 10}
    
    canvas .net.scope.display	\
	-width $net::scopePlotWidth	\
	-height  $net::scopePlotHeight	\
	-background white
    
    grid .net.scope.title -row 0 -column 0
    grid .net.scope.display -row 1 -column 0
    
    if {$::opMode == "Impedance"} {
	grid .net.buildout -row 0 -column 0
    }
    grid .net.controls -row 1 -column 0
    grid .net.graphs -row 0 -column 1 -rowspan 2 -padx 10
    grid .net.scope -row 0 -column 2 -rowspan 2
    
    grid .net -row 2 -column 0 -padx 5 -columnspan 2
    
    #View menu for the network analyzer
    #View Menu
    menubutton .menubar.netView \
	-text "View"	\
	-menu .menubar.netView.viewMenu
    menu .menubar.netView.viewMenu -tearoff 0
    if {$osType == "windows"} {
	.menubar.netView.viewMenu add command	\
	    -label "Debug Console"	\
	    -command {console show}
    }
    #Command to clear bode plots
    .menubar.netView.viewMenu add command	\
	-label "Clear Bode Plots"	\
	-command {net::clearPlots}
    #Command to select scientific notation
    .menubar.netView.viewMenu add check	\
	-label "Scientific Notation"	\
	-variable net::scientificNotation	\
	-command net::drawXScale
    grid .menubar.netView -row 0 -column 1
    #Command to save current plot as reference plot
    .menubar.netView.viewMenu add command	\
	-label "Save Plots as Reference"	\
	-command net::saveReference
    #Command to select reference plot
    .menubar.netView.viewMenu add check	\
	-label "Show Reference Plots"		\
	-variable net::referenceEnabled	\
	-command net::toggleReference
    
    net::drawXScale

    #Pop up window for selecting phsae offset
    menu .net.graphs.phase.popup -tearoff 0
    .net.graphs.phase.popup add radiobutton	\
	-label "Phase Axis: \[+360,0\]"	\
	-variable net::phaseOffset	\
	-value 360	\
	-command {net::yScale phase}
    .net.graphs.phase.popup add radiobutton	\
	-label "Phase Axis: \[+270,-90\]"	\
	-variable net::phaseOffset	\
	-value 270	\
	-command {net::yScale phase}
    .net.graphs.phase.popup add radiobutton	\
	-label "Phase Axis: \[+180,-180\]"	\
	-variable net::phaseOffset	\
	-value 180	\
	-command {net::yScale phase}
    .net.graphs.phase.popup add radiobutton	\
	-label "Phase Axis: \[+90,-270\]"	\
	-variable net::phaseOffset	\
	-value 90	\
	-command {net::yScale phase}
    .net.graphs.phase.popup add radiobutton	\
	-label "Phase Axis: \[0, -360\]"	\
	-variable net::phaseOffset	\
	-value 0	\
	-command {net::yScale phase}
    bind .net.graphs.phase <Button-3> {+tk_popup .net.graphs.phase.popup %X %Y}

    #Pop-up Menu for magnitue plot
    menu .net.graphs.mag.popup -tearoff 0
    .net.graphs.mag.popup add checkbutton	\
	-label "Peak Detection"	\
	-variable net::resonantEnable	\
	-command net::findResonantPeak
    .net.graphs.mag.popup add checkbutton	\
	-label "Snap to Trace"	\
	-variable net::snapToTrace
    bind .net.graphs.mag <Button-3> {+tk_popup .net.graphs.mag.popup %X %Y}
    
}

proc net::updateStartValue {dummy} {

    if {$net::startValuePow >= $net::endValuePow} {
	set net::startValuePow [expr {$net::endValuePow-0.1}]
    }
    
    set net::startFrequency [format %.1f [expr {pow(10,$net::startValuePow)}]]

    net::drawXScale

}

proc net::updateEndValue {dummy} {

    if {$net::endValuePow <= $net::startValuePow} {
	set net::endValuePow [expr {$net::startValuePow+0.1}]
    }

    set net::endFrequency [format %.1f [expr {pow(10,$net::endValuePow)}]]
    
    net::drawXScale

}

proc net::drawXScale {} {
    variable testFrequencies
    global log

    if {![winfo exists .net.graphs.mag]} {return}

    .net.graphs.mag delete xScaleTag
    .net.graphs.phase delete xScaleTag
    
    if {$net::frequencyStepMode == "log"} {
	
	#Determine which decade the start frequency is in
	set startDecade [expr round(floor($net::startValuePow))]
	
	#Determine which decade the end frequency is in
	set endDecade [expr {floor($net::endValuePow)}]

	#Determine how many decades we are going to span
	if {[expr {abs($net::endValuePow-int($net::endValuePow))}] > 0} {
	    set decadeSpan [expr {$endDecade-$startDecade+1}]
	} else {
	    set decadeSpan [expr {$endDecade-$startDecade}]
	}
	
	${log}::debug "$startDecade $endDecade $decadeSpan"
	
	set decadeWidth [expr {$net::plotWidth/$decadeSpan}]

	for {set decade $startDecade} {$decade <=[expr {$endDecade+1}]} {incr decade} {
	    if {$net::scientificNotation} {
		set tickText "1E$decade"
	    } else {
		set tickText [expr {round(pow(10,$decade))}]
	    }
	    .net.graphs.mag create text 	\
		[expr {$net::leftBorder + (log(pow(10,$decade)/pow(10,$startDecade)))/log(10)*$decadeWidth }] [expr {$net::plotHeight+$net::topBorder +10}]	\
		-text $tickText	\
		-font {-size 8}	\
		-tag xScaleTag
	    for {set i 1} {$i < 10} {incr i} {
		#x location of tick
		set frequency [expr {$i*pow(10,$decade)}]
		set currentX [expr {$::net::leftBorder+(log($frequency/pow(10,$startDecade)))/log(10)*$decadeWidth}]
		set currentX [expr {round($currentX)}]
		.net.graphs.mag create line \
		    $currentX $net::topBorder		\
		    $currentX [expr {$net::plotHeight+$net::topBorder + 3}]	\
		    -tag xScaleTag
		.net.graphs.phase create line	\
		    $currentX $net::topBorder	\
		    $currentX [expr {$net::plotHeight+$net::topBorder+3}]	\
		    -tag xScaleTag
	    }
	}
	
    } else {
	
	#set startFrequency [expr {pow(10,$net::startValuePow)}]
	${log}::debug "Start frequency is $net::startFrequency"
	
	#set endFrequency [expr {pow(10,$net::endValuePow)}]
	${log}::debug "End frequency is $net::endFrequency"
	
	set j 0
	for {set i $net::startFrequency} {$i <= $net::endFrequency} {set i [expr {$i+($net::endFrequency-$net::startFrequency)/10.0}]} {
	    
	    ${log}::debug "i $i"
	    set currentX [expr {$net::leftBorder + $net::plotWidth*$j/10.0}]
	    
	    if {$i > 1E6} {
		set tickText [format "%3.3f" [expr $i/1E6]]
		append tickText "M"
	    } elseif { $i > 1E3} {
		set tickText [format "%3.3f" [expr $i/1E3]]
		append tickText "k"
	    } else {
		set tickText [format "%3.3f" $i]
	    }
	    
	    .net.graphs.mag create text	\
		$currentX [expr {$net::plotHeight+$net::topBorder + 10}]	\
		-text $tickText	\
		-font {-size 8}	\
		-tag xScaleTag
	    
	    .net.graphs.mag create line \
		$currentX $net::topBorder		\
		$currentX [expr {$net::plotHeight+$net::topBorder + 3}]	\
		-tag xScaleTag
	    .net.graphs.phase create line	\
		$currentX $net::topBorder	\
		$currentX [expr {$net::plotHeight+$net::topBorder+3}]	\
		-tag xScaleTag
	    
	    incr j
	    
	}
	
	
    }
    
    if {$net::referenceEnabled} {
	net::plotRefMag
	net::plotRefPhase
    }
    
}

proc net::analyze {} {
    variable testFrequencies
    variable testFrequencyIndex
    variable currentFrequency
    global log
    
    if {$net::maxAmplitude == 0} {
	tk_messageBox		\
	    -title "Amplitude Warning"	\
	    -message "Please set the maximum waveform amplitude above 0%"	\
	    -type ok	\
	    -icon warning
	return
    }
    
    set net::status "Analyzing"
    
    #Put the scope in normal triggger mode
    set trigger::triggerMode "Auto"
    trigger::selectTriggerMode
    
    #Set up lists to hold the results of the analysis
    set net::xFreq {}
    set net::yMag {}
    set net::yPhase {}
    set net::quality {}
    
    #Set up for analysis - set preamps to high scale
    set vertical::verticalIndexA 6
    set net::chAScale "25V Max"
    vertical::adjustVertical .scope.verticalA A same

    set vertical::verticalIndexB 6
    set net::chBScale "25V Max"
    vertical::adjustVertical .scope.verticalB B same
    
    #Make sure we're using a sine wave for analysis
    sendCommand "WW0"
    
    #Set the output of the waveform generator
    #set wave::amplitude $net::maxAmplitude
    #wave::adjustAmplitude $wave::amplitude
    [wave::getWavePath].amp.ampSlider set $net::maxAmplitude
    update
    wave::adjustAmplitude [[wave::getWavePath].amp.ampSlider get]
    update
    
    #Set up the frequency list
    set net::testFrequencies {}
    set net::xValues {}
    set temp $net::startFrequency
    
    if {$net::frequencyStepMode == "log"} {
	
	#Determine which decade the start frequency is in
	set startDecade [expr round(floor($net::startValuePow))]
	
	#Determine which decade the end frequency is in
	set endDecade [expr {floor($net::endValuePow)}]

	#Determine how many decades we are going to span
	#set decadeSpan [expr {$endDecade-$startDecade+1}]
	if {[expr {abs($net::endValuePow-int($net::endValuePow))}] > 0} {
	    set decadeSpan [expr {$endDecade-$startDecade+1}]
	} else {
	    set decadeSpan [expr {$endDecade-$startDecade}]
	}
	${log}::debug "$startDecade $endDecade $decadeSpan"
	
	set decadeWidth [expr {$net::plotWidth/$decadeSpan}]
	
	#Add the first point to the lists
	while {$temp <= $net::endFrequency} {
	    #Calculate the frequency value
	    lappend net::testFrequencies $temp
	    #Calculate the corresponding x location for this frequency
	    set currentX [expr {$::net::leftBorder+log($temp/(pow(10,floor($net::startValuePow))))/log(10)*$decadeWidth}]
	    lappend net::xValues [expr {round($currentX)}]
	    #Increment to the next frequency point
	    set temp [expr {$temp*$net::frequencyLogStep}]
	}
    } else {
	#Linear Step Mode
	
	#Populate the X-Coordinate and Test Frequency Lists
	for {set i $net::startFrequency} {$i <= $net::endFrequency} {set i [expr {$i+$net::frequencyLinStep}]} {
	    #Store the frequency value
	    lappend net::testFrequencies $i
	    #Calculate the corresponding x-coordinate for this frequency
	    set currentX [expr {$net::leftBorder+($i-$net::startFrequency)/($net::endFrequency-$net::startFrequency)*$net::plotWidth}]
	    lappend net::xValues $currentX
	}
    }
    
    #Start the analysis
    set testFrequencyIndex 0
    set currentFrequency [lindex $testFrequencies $testFrequencyIndex]
    ${log}::debug "=================="
    ${log}::debug "Testing at $currentFrequency Hz"
    
    #Analyze this frequency point
    set numIterations 0
    net::analyzeFrequency $currentFrequency
    
    #Everything else is taken care of by the data event handler
    
}

#This process starts the hardware analyzing the currentFrequency point
proc net::analyzeFrequency { freq } {
    variable captureOK
    variable numIterations
    variable netTimeout
    variable numIterations
    global log

    #Update the display
    set net::currentFrequencyDisplay [cursor::formatFrequency $freq 1]
    
    #Set the output frequency of the generator
    wave::sendFrequency $freq
    update
    
    #Set the sample rate to match the output frequency
    net::adjustSampleRate $freq
    update
    
    #Enable AC coupling for both channels
    set vertical::couplingA AC
    vertical::updateCoupling .scope.verticalA A
    update
    set vertical::couplingB AC
    vertical::updateCoupling .scope.verticalB B
    update
    
    #Set the trigger level to 0V, we always trigger off channel A
    #The trigger level has to be updated on each pass because the hardware offset
    #values are specific to the range setting of the preamp and this range can change
    #during the recursion.
    set cursor::trigPos [expr {($display::yAxisEnd-$display::yAxisStart)/2.0+$display::yAxisStart}]
    set trigger::triggerVoltage 0.0
    trigger::updateTriggerLevel
    update
    
    #Acquire the waveform
    ${log}::debug "REQUESTING FREQUENCY POINT"
    scope::acquireWaveform
    set netTimeout [after 12000 {set scope::scopeData -1}]
    update
    
}

#This process is called after new data is received from the hardware
proc net::processFreqPoint {} {
    variable netTimeout
    variable currentFrequency
    variable testFrequencies
    variable testFrequencyIndex
    variable numIterations
    global log
    
    ${log}::debug "...PROCESSING FREQUENCY POINT"
    
    #Check to see if the acquisition was successful
    if {$scope::scopeData == -1} {
	if {!$net::analyzeEnable} {return}
	tk_messageBox		\
	    -title "Analyzer Error"	\
	    -message "Input signal was not detected.\nPlease ensure that the waveform generator and channel A of\nthe oscilloscope are connected to the input of the circuit under test.\nConnect channel B to the output of your circuit."	\
	    -type ok	\
	    -icon warning
	set net::analyzeEnable 0
    } else {
	after cancel $netTimeout
    }
    
    #Check to make sure that the net analyzer is still enabled
    if {$net::analyzeEnable} {
	#net::updateScopeDisplay
    } else {
	return
    }
    
    #See if we're in an infinite loop
    incr numIterations
    if {$numIterations > 50} {
	tk_messageBox		\
	    -title "Analysis Failure"	\
	    -message "Analysis Failed."	\
	    -type ok	\
	    -icon warning
	set net::analyzeEnable 0
	return
    }
    
    #Get samples from scope
    set dataA [lindex $scope::scopeData 0]
    set dataB [lindex $scope::scopeData 1]
    
    #Calculate Channel A Min/Max
    set temp [net::findMinMax $dataA]
    set minimum [lindex $temp 0]
    set maximum [lindex $temp 1]
    set average [net::calculateAverage $dataA]
    set sigAmplitudeA [expr {$maximum - $minimum}]
    ${log}::debug "A: min $minimum max $maximum average $average sigAmp $sigAmplitudeA"
    
    if {($::deviceType=="mini")||($::deviceType=="sig")} {
	set minAmplitude 106
	set minAverage 852
	set maxAverage 1196
	set maxAmplitude 2000
	set floorAmplitude 56
    } else {
	set minAmplitude 53
	set minAverage 426
	set maxAverage 598
	set maxAmplitude 1000
	set floorAmplitude 28
    }
    
    #Check to see if we need to change the preamp on channel A
    if {$sigAmplitudeA < $minAmplitude && ($vertical::verticalIndexA == 6)&&($average > $minAverage && $average < $maxAverage)} {
	set vertical::verticalIndexA 3
	set net::chAScale "2.5V Max"
	vertical::adjustVertical .scope.verticalA A same
	update
	${log}::debug "Adjusting Channel A preamp to 2.5V scale."
	#Do another analysis at this frequency
	net::analyzeFrequency [lindex $testFrequencies $testFrequencyIndex]
	return
    } 
    if {($maximum > $maxAmplitude || $minimum < $floorAmplitude) && ($vertical::verticalIndexA == 3) } {
	set vertical::verticalIndexA 6
	set net::chAScale "25V Max"
	vertical::adjustVertical .scope.verticalA A same
	update
	${log}::debug "Adjusting Channel A preamp to 25V scale."
	#Do another analysis at this frequency
	net::analyzeFrequency [lindex $testFrequencies $testFrequencyIndex]
	return
    } elseif {$maximum > $maxAmplitude} {
	${log}::debug "Input signal is too large!"
	#Do another analysis at this frequency
	net::analyzeFrequency [lindex $testFrequencies $testFrequencyIndex]
	return
    }
    
    #Calculate Channel B Min/Max
    set temp [net::findMinMax $dataB]
    set minimum [lindex $temp 0]
    set maximum [lindex $temp 1]
    set average [net::calculateAverage $dataB]
    set sigAmplitudeB [expr {$maximum-$minimum}]
    ${log}::debug "B: min $minimum max $maximum average $average sigAmp $sigAmplitudeB"
    
    ${log}::debug "sigAmplitudeB $sigAmplitudeB average $average index $vertical::verticalIndexB"
    
    #Check to see if we need to change the preamp on channel B
    if {($sigAmplitudeB < $minAmplitude) && ($vertical::verticalIndexB == 6)&&($average > $minAverage) && ($average < $maxAverage)} {
	set vertical::verticalIndexB 3
	set net::chBScale "2.5V Max"
	vertical::adjustVertical .scope.verticalB B same
	${log}::debug "Adjusting Channel B preamp to 2.5V scale."
	update
	#Do another analysis at this frequency
	net::analyzeFrequency [lindex $testFrequencies $testFrequencyIndex]
	return
    } elseif {$sigAmplitudeB < $minAmplitude && $wave::amplitude < $net::maxAmplitude} {
	#Increase the waveform amplitude
	set temp $wave::amplitude
	set temp [expr {round($temp*1.1)}]
	if {$temp > 100} {set temp 100}
	[wave::getWavePath].amp.ampSlider set $temp
	${log}::debug "!!!!!Increasing waveform output amplitude to $temp%"
	#Do another analysis at this frequency
	net::analyzeFrequency [lindex $testFrequencies $testFrequencyIndex]
	return
    }
    
    if {($maximum > $maxAmplitude || $minimum < $floorAmplitude) && ($vertical::verticalIndexB == 3)} {
	set vertical::verticalIndexB 6
	set net::chBScale "25V Max"
	vertical::adjustVertical .scope.verticalB B same
	update
	#Do another analysis at this frequency
	net::analyzeFrequency [lindex $testFrequencies $testFrequencyIndex]
	return
    } elseif {($maximum > $maxAmplitude || $minimum < $floorAmplitude)  && $wave::amplitude > 1} {
	#Decrease the waveform amplitude
	set temp $wave::amplitude
	set temp [expr {round($temp*0.9)}]
	if {$temp < 1} { set temp 1}
	[wave::getWavePath].amp.ampSlider set $temp
	${log}::debug "!!!!!Decreasing waveform output amplitude to $temp%"
	#Do another analysis at this frequency
	net::analyzeFrequency [lindex $testFrequencies $testFrequencyIndex]
	return
    }
    
    #See if we need to flag this reading as questionable
    if {$sigAmplitudeB < 10} {
	set captureOK 2
    } else {
	set captureOK 1
    }
    
    #Measure the actual output frequency
    set mFreq [net::measureFrequency]
    ${log}::debug "Test frequency $currentFrequency Actual Frequency: $mFreq"
    if {$mFreq > 0} {
	set freq $mFreq
    } else {
	set freq [lindex $testFrequencies $testFrequencyIndex]
    }
    
    #set freq [lindex $testFrequencies $testFrequencyIndex]
    
    #Create the reference sine wave for this frequency
    net::createSineRef $freq
    
    #Create the reference cosine wave for this frequency
    net::createCosRef $freq
    
    #Retrieve data from scope and convert it
    set dataARaw $dataA
    set dataA {}
    foreach datum $dataARaw {
	lappend dataA [vertical::convertSampleVoltage $datum A]
    }
    set dataBRaw $dataB
    set dataB {}
    foreach datum $dataBRaw {
	lappend dataB [vertical::convertSampleVoltage $datum B]
    }
    
    #Components for Channel A
    set eii [net::multiplyWaveforms $dataA $net::sineRef]
    set iPhaseA [net::integrateWaveform $eii]
    
    set eiq [net::multiplyWaveforms $dataA $net::cosRef]
    set qPhaseA [net::integrateWaveform $eiq]
    
    #Calculate magnitude
    set magA [expr {(2.0)*sqrt(pow($iPhaseA,2)+pow($qPhaseA,2))}]
    
    ${log}::debug "Frequency: $freq"
    ${log}::debug "	Channel A"
    ${log}::debug "	iPhase $iPhaseA"
    ${log}::debug "	qPhase $qPhaseA"
    ${log}::debug "	mag $magA"
    
    #Calculate phase
    set radA [expr {atan2($qPhaseA,$iPhaseA)}]
    set degA [expr {$radA/$net::pi*180.0}]

    #Components for Channel B
    set eii [net::multiplyWaveforms $dataB $net::sineRef]
    set iPhaseB [net::integrateWaveform $eii]
    
    set eiq [net::multiplyWaveforms $dataB $net::cosRef]
    set qPhaseB [net::integrateWaveform $eiq]

    #Calculate magnitude
    set magB [expr {(2.0)*sqrt(pow($iPhaseB,2)+pow($qPhaseB,2))}]
    
    #Calculate phase
    set radB [expr {atan2($qPhaseB,$iPhaseB)}]
    set degB [expr {$radB/$net::pi*180.0}]

    ${log}::debug "	Channel B"
    ${log}::debug "	iPhase $iPhaseB"
    ${log}::debug "	qPhase $qPhaseB"
    ${log}::debug "	mag $magB"

    #Calculate the overall phase response
    set phase [expr {$degB-$degA}]
    if {$phase > $net::phaseOffset} {
	set phase [expr {-360 + $phase} ]
    } elseif { $phase < [expr {$net::phaseOffset-360}]} {
	set phase [expr {360 + $phase}]
    }
    
    set ratio [expr {20.0*log($magB/$magA)/log(10)}]
    
    #Record the magnitude and phase values
    lappend net::xFreq $currentFrequency
    lappend net::yMag $ratio
    lappend net::yPhase $phase
    lappend net::quality $captureOK
    
    #Dynamically update the display
    net::plotRefMag
    net::plotMag 
    net::plotRefPhase
    net::plotPhase
    
    if {$net::debugEnable} {
	set answer [tk_messageBox	\
			-type yesnocancel	\
			-message "Dump analysis point to CSV?"	\
			-default no]
	
	if {$answer == "cancel"} {
	    set net::analyzeEnable 0
	} elseif {$answer == "yes"} {
	    set fileId [open "NetDebug.csv" w]
	    ${log}::debug $fileId "Frequency,$freq"
	    ${log}::debug $fileId "Channel A"
	    ${log}::debug $fileId "iPhase,qPhase,mag"
	    ${log}::debug $fileId "$iPhaseA,$qPhaseA,$magA"
	    ${log}::debug $fileId "Channel B"
	    ${log}::debug $fileId "iPhase,qPhase,mag"
	    ${log}::debug $fileId "$iPhaseB,$qPhaseB,$magB"
	    
	    ${log}::debug $fileId "Data A, DataB,Sine Ref,Cos Ref"
	    foreach sampleA $dataA sampleB $dataB sampleSin $net::sineRef sampleCos $net::cosRef {
		${log}::debug $fileId "$sampleA,$sampleB,$sampleSin,$sampleCos"
	    }
	    close $fileId
	    ${log}::debug "Data written"
	}
    }
    
    #Check to see if the user cancelled the analysis
    if {!$net::analyzeEnable} {
	set net::status "Idle"
	return
    } else {
	net::updateScopeDisplay
	#Start analysis of the next point
	incr testFrequencyIndex
	if {$testFrequencyIndex < [llength $testFrequencies]} {
	    set currentFrequency [lindex $testFrequencies $testFrequencyIndex]
	    set numIterations 0
	    net::analyzeFrequency $currentFrequency
	} else {
	    set net::status "Idle"
	    set net::analyzeEnable 0
	}
    }
    
    
}

proc net::adjustSampleRate {freq} {

    if {($::deviceType=="mini")||($::deviceType=="sig")} {
	if {$freq >= 5030} {
	    #Sample rate = 1 MHz
	    #Sample time = 1024/1000000 = 1024 us
	    #Maximum frequency = 1.95313 kHz+
	    #set sampleRate 1
	    set sampleRate 2
	} elseif {$freq >= 2030} {
	    #Sample rate = 500 kHz
	    #Sample time = 1024/500000 = 2.048 ms
	    #Maximum frequency = 488.28Hz
	    #set sampleRate 2
	    set sampleRate 3
	} elseif {$freq >= 1040} {
	    #Sample rate = 250 kHz
	    #Sample time = 1024/250000 = 4.096 ms
	    #Maximum frequency = 244.14Hz
	    #set sampleRate 3
	    set sampleRate 4
	} elseif {$freq >= 508} {
	    #Sample rate = 125 kHz
	    #Sample time = 1024/125000 = 8.192 ms
	    #Maximum frequency = 122.07Hz
	    #set sampleRate 4
	    set sampleRate 7
	} elseif { $freq >= 214} {
	    #Sample rate = 62.5 kHz
	    #Sample time = 1024/62500 = 16.384 ms
	    #Maximum frequency = 61.035Hz
	    #set sampleRate 5
	    set sampleRate 8
	} elseif {$freq >= 104} {
	    #Sample rate = 51.2 kHz
	    #Sample time = 1024/51200 = 20 ms
	    #Maximum frequency = 50.0Hz
	    #set sampleRate 6
	    set sampleRate 9
	} elseif {$freq >= 51.2} {
	    #Sample rate = 25.6 kHz
	    #Sample time = 1024/25600 = 40 ms
	    #Maximum frequency = 25.0Hz
	    #set sampleRate 7
	    set sampleRate A
	} elseif {$freq >=20.6} {
	    #Sample rate = 10.24 kHz
	    #Sample time = 1024/10240 = 100 ms
	    #Maximum frequency = 10.0Hz
	    #set sampleRate 8
	    set sampleRate B
	} elseif {$freq >=10.4} {
	    #Sample rate = 5.12 kHz
	    #Sample time = 1024/5120 = 200 ms
	    #Maximum frequency = 5.0Hz
	    #set sampleRate 9
	    set sampleRate C
	} elseif {$freq >=5.2} {
	    #Sample rate = 2.56 kHz
	    #Sample time = 1024/2560 = 400 ms
	    #Maximum frequency = 2.5Hz
	    #set sampleRate A
	    set sampleRate C
	} elseif {$freq >= 2.1} {
	    #Sample rate = 1024 Hz
	    #Sample time = 1024/1024 = 1 second
	    #Maximum frequency = 1.0Hz
	    #set sampleRate B
	    set sampleRate D
	} else {
	    #Sample rate = 512Hz
	    #Sample time = 1024/512 = 2 seconds
	    #Maximum frequency = 1/2 = 0.5Hz
	    set sampleRate D
	}
    } else {
	if {$freq >= 65536} {
	    #Sample rate = 40 MHz
	    #Sample time = 4096/40000000 = 102.4 us
	    #Maximum frequency = 9.765 kHz
	    #Capture 8 cycles, minimum 8*9.765Hz = 78.12 kHz
	    set sampleRate 0
	} elseif {$freq >= 32768} {
	    #Sample rate = 20 MHz
	    #Sample time = 4096/20000000 = 204.8 us
	    #Maximum frequency = 4.88 kHz
	    #Capture 8 cycles, minimum 8*4.88Hz = 390625 kHz
	    set sampleRate 1
	} elseif {$freq >= 16384} {
	    #Sample rate = 10 MHz
	    #Sample time = 4096/10000000 = 409.6 us
	    #Maximum frequency = 2.44 kHz
	    #Capture 8 cycles, minimum 8*2.44kHz = 19.53 kHz
	    set sampleRate 2
	} elseif {$freq >= 8192} {
	    #Sample rate = 5 MHz
	    #Sample time = 4096/5000000 = 819.2 us
	    #Maximum frequency = 1.22 kHz
	    #Capture 8 cycles, minimum 8*1.22kHz = 9.76 kHz
	    set sampleRate 3
	} elseif {$freq >= 4096} {
	    #Sample rate = 2.5 MHz
	    #Sample time = 4096/2500000 = 1.6 us
	    #Maximum frequency = 610 Hz
	    #Capture 8 cycles, minimum 8*305 = 4.88 kHz
	    set sampleRate 4
	} elseif {$freq >= 2048} {
	    #Sample rate = 1.25 MHz
	    #Sample time = 4096/1250000 = 3.2768 us
	    #Maximum frequency = 305 Hz
	    #Capture 8 cycles, minimum 8*305 = 2.44 kHz
	    set sampleRate 5
	} elseif {$freq >= 1024} {
	    #Sample rate = 625 kHz
	    #Sample time = 4096/625000 = 6.6 ms
	    #Maximum frequency = 152 Hz
	    #Capture 8 cycles, minimum 8*152 = 1.22 kHz
	    set sampleRate 6
	} elseif {$freq >= 512} {
	    #Sample rate = 312.5 kHz
	    #Sample time = 4096/312500 = 13.1 ms
	    #Maximum frequency = 76 Hz
	    #Capture 8 cycles, minimum 8*76 = 608 Hz
	    set sampleRate 7
	} elseif {$freq >= 256} {
	    #Sample rate = 156.25 kHz
	    #Sample time = 4096/156250 = 26.2 ms
	    #Maximum frequency = 38 Hz
	    #Capture 8 cycles, minimum 8*38 = 304 Hz
	    set sampleRate 8
	} elseif { $freq >= 128} {
	    #Sample rate = 78.125 kHz
	    #Sample time = 4096/78125 = 52 ms
	    #Maximum frequency = 19 Hz
	    #Caputre 8 cycles, minimum 8*19 = 152 Hz
	    set sampleRate 9
	} elseif {$freq >= 64} {
	    #Sample rate = 39.0625 kHz
	    #Sample time = 4096/39062.5 = 103 ms
	    #Maximum frequency = 9.6Hz
	    #Capture 8 cycles, minimum 8*9.6 = 76 Hz
	    set sampleRate A
	} elseif {$freq >= 32} {
	    #Sample rate = 19.531 kHz
	    #Sample time = 4096/19531 = 209 ms
	    #Maximum frequency = 4.7Hz
	    #Capture 8 cycles, minimum 8*4.7 = 37.6 Hz
	    set sampleRate B
	} elseif {$freq >= 16} {
	    #Sample rate = 9.765 kHz
	    #Sample time = 4096/9765 = 419 ms
	    #Maximum frequency = 2.3Hz
	    #Capture 8 cycles, minimum 8*2.3 = 18.4Hz
	    set sampleRate C
	} elseif {$freq >= 8} {
	    #Sample rate = 4.882 kHz
	    #Sample time = 4096/4882 = 839 ms
	    #Maximum frequency = 1.2Hz
	    #Capture 8 cycles, minimum 8*1.2 = 9.6 Hz
	    set sampleRate D
	} elseif {$freq >= 4.0} {
	    #Sample rate = 2.441 kHz
	    #Sample time = 4096/4882 = 1.678 s
	    #Maximum frequency = 0.6Hz
	    #Capture 8 cycles, minimum 4*0.6 = 4.8 Hz
	    set sampleRate E
	} else {
	    #Sample rate = 2441 Hz
	    #Sample time = 4096/2441 = 1.678 seconds
	    #Maximum frequency = 0.6Hz
	    set sampleRate F
	}
    }
    
    
    #Find the timebase index that corresponds to the correct sample rate
    set timebaseIndex 0
    foreach timebaseSetting $timebase::validTimebases {
	if {[lindex $timebaseSetting 1] == $sampleRate} {
	    set timebase::newTimebaseIndex $timebaseIndex
	    timebase::adjustTimebase update
	    return
	}
	incr timebaseIndex
    }

}

proc net::createSineRef {freq} {

    if {($::deviceType=="mini")||($::deviceType=="sig")} {
	set sampleDepth 1024
    } else {
	set sampleDepth 4096
    }

    set net::sineRef {}
    
    set tStep [expr {1.0/[timebase::getSamplingRate]}]
    
    for {set i 0} {$i < $sampleDepth} {incr i} {
	set t [expr {$i*$tStep}]
	set temp [expr {sin(2*$net::pi*$freq*$t)}]
	lappend net::sineRef $temp
    }

}

proc net::createCosRef {freq} {

    if {($::deviceType=="mini")||($::deviceType=="sig")} {
	set sampleDepth 1024
    } else {
	set sampleDepth 4096
    }

    set net::cosRef {}
    
    set tStep [expr {1.0/[timebase::getSamplingRate]}]
    
    for {set i 0} {$i < $sampleDepth} {incr i} {
	set t [expr {$i*$tStep}]
	set temp [expr {cos(2*$net::pi*$freq*$t)}]
	lappend net::cosRef $temp
    }

}

proc net::multiplyWaveforms {waveA waveB} {
    
    set product {}
    
    set averageA [calculateAverage $waveA]
    set averageB [calculateAverage $waveB]
    
    foreach pointA $waveA pointB $waveB {
	lappend product [expr {($pointA-$averageA)*($pointB-$averageB)}]
    }
    
    return $product
}

proc net::integrateWaveform {waveform} {
    
    set length [llength $waveform]
    set sum 0
    foreach point $waveform {
	set sum [expr {$sum+$point}]
    }
    return [expr {$sum*1.0/$length}]
}

proc net::findMinMax {data} {

    #set average [calculateAverage $data]

    set length [llength $data]
    set length [expr {$length - 1}]
    set maximum 0
    if {($::deviceType=="mini")||($::deviceType=="sig")} {
	set minimum 2047
    } else {
	set minimum 1023
    }
    
    for {set i 0} {$i < $length} {incr i} {
	set datum [lindex $data $i]
	#set datum [expr {$datum - $average}]
	if {$datum > $maximum} {
	    set maximum $datum
	}
	if {$datum < $minimum} {
	    set minimum $datum
	}
    }
    set returnValues {}
    lappend returnValues $minimum
    lappend returnValues $maximum
    return $returnValues
}

proc net::calculateAverage {data} {
    #Determine the number of samples
    set numSamples [llength $data]
    
    #Determine the average of the samples
    set average 0
    for {set i 0} {$i < $numSamples} {incr i} {
	set average [expr {$average + [lindex $data $i]}]
    }
    set average [expr {$average*1.0/$numSamples}]
    return $average
}


proc net::plotMag {} {

    set y $net::yMag

    set length [llength $y]
    if {$length < 2} {return}
    
    .net.graphs.mag delete magTag

    net::yScale mag
    
    #Determine how many ticks to display
    set ticks [expr {($net::topTick-$net::botTick)/20}]
    set magMajorTick [expr {$net::plotHeight/$ticks}]
    
    for {set index 1} {$index < $length} {incr index} {
	
	set x1 [lindex $net::xValues [expr {$index-1}]]
	set x2 [lindex $net::xValues $index]
	set y1 [lindex $y [expr {$index-1}]]
	set y1 [expr {$net::topBorder+($net::topTick-$y1)/20*($magMajorTick)}]
	set y2 [lindex $y $index]
	set y2 [expr {$net::topBorder+($net::topTick-$y2)/20*($magMajorTick)}]
	
	if { [lindex $net::quality $index] == 1 } {
	    .net.graphs.mag create line	\
		$x1 $y1 $x2 $y2	\
		-tag magTag	\
		-fill red	\
		-width 2	
	} else {
	    .net.graphs.mag create line	\
		$x1 $y1 $x2 $y2	\
		-tag magTag	\
		-fill red	\
		-width 2	\
		-dash .
	}
    }
    
    .net.graphs.mag delete resonantTag
    if {$net::resonantEnable} {
	net::findResonantPeak
    }

}

proc net::plotRefMag {} {

    #Make sure the reference plot is enabled
    if {!$net::referenceEnabled} {return}

    set y $net::refMag

    set length [llength $y]
    if {$length < 2} {return}
    
    .net.graphs.mag delete refMagTag

    net::yScale mag
    
    #Determine how many ticks to display
    set ticks [expr {($net::topTick-$net::botTick)/20}]
    set magMajorTick [expr {$net::plotHeight/$ticks}]
    
    #Determine which decade the start frequency is in
    set startDecade [expr round(floor($net::startValuePow))]
    
    #Determine which decade the end frequency is in
    set endDecade [expr {floor($net::endValuePow)}]

    #Determine how many decades we are going to span
    #set decadeSpan [expr {$endDecade-$startDecade+1}]
    if {[expr {abs($net::endValuePow-int($net::endValuePow))}] > 0} {
	set decadeSpan [expr {$endDecade-$startDecade+1}]
    } else {
	set decadeSpan [expr {$endDecade-$startDecade}]
    }
    
    
    #Calculate the corresponding x location for this frequency
    set decadeWidth [expr {$net::plotWidth/$decadeSpan}]
    
    for {set index 1} {$index < $length} {incr index} {
	
	#Get the frequency value for this sample
	set temp [lindex $net::refFreq [expr {$index-1}]]
	if {$net::frequencyStepMode == "log"} {
	    set currentX [expr {$::net::leftBorder+log($temp/(pow(10,floor($net::startValuePow))))/log(10)*$decadeWidth}]
	    set x1 [expr {round($currentX)}]
	} else {
	    set x1 [expr {$net::leftBorder+($temp-$net::startFrequency)/($net::endFrequency-$net::startFrequency)*$net::plotWidth}]
	}
	
	#Get the frequency value for this sample
	set temp [lindex $net::refFreq $index]
	#Calculate the corresponding x location for this frequency
	if {$net::frequencyStepMode == "log"} {
	    set currentX [expr {$::net::leftBorder+log($temp/(pow(10,floor($net::startValuePow))))/log(10)*$decadeWidth}]
	    set x2 [expr {round($currentX)}]
	} else {
	    set x2 [expr {$net::leftBorder+($temp-$net::startFrequency)/($net::endFrequency-$net::startFrequency)*$net::plotWidth}]
	}
	
	set y1 [lindex $y [expr {$index-1}]]
	set y1 [expr {$net::topBorder+($net::topTick-$y1)/20*($magMajorTick)}]
	set y2 [lindex $y $index]
	set y2 [expr {$net::topBorder+($net::topTick-$y2)/20*($magMajorTick)}]
	
	if { [lindex $net::refQuality $index] == 1 } {
	    .net.graphs.mag create line	\
		$x1 $y1 $x2 $y2	\
		-tag refMagTag	\
		-fill grey	\
		-width 2	
	} else {
	    .net.graphs.mag create line	\
		$x1 $y1 $x2 $y2	\
		-tag refMagTag	\
		-fill grey	\
		-width 2	\
		-dash .
	}


    }

}

proc net::plotPhase {} {
    
    #Get the phase values from the analysis variable
    set y $net::yPhase
    
    #Make sure we have at least 2 points to plot
    set length [llength $y]
    if {$length < 2} {return}
    
    #Clear the display
    .net.graphs.phase delete phaseTag
    
    #Plot data points
    set plotData {}
    for {set index 1} {$index < $length} {incr index} {
	set x1 [lindex $net::xValues [expr {$index-1}]]
	set x2 [lindex $net::xValues $index]
	set y1 [lindex $y [expr {$index-1}]]
	set y1 [expr {$net::topBorder + ($net::plotHeight/2.0)- (($y1+180-$net::phaseOffset)/360)*$net::plotHeight}]
	set y2 [lindex $y $index]
	set y2 [expr {$net::topBorder + ($net::plotHeight/2.0)- (($y2+180-$net::phaseOffset)/360)*$net::plotHeight}]
	
	if {[lindex $net::quality $index] == 1} {
	    .net.graphs.phase create line	\
		$x1 $y1 $x2 $y2	\
		-tag phaseTag	\
		-fill red	\
		-width 2
	} else {
	    .net.graphs.phase create line	\
		$x1 $y1 $x2 $y2	\
		-tag phaseTag	\
		-fill red	\
		-width 2	\
		-dash .
	}

    }
}

proc net::plotRefPhase {} {
    
    #Make sure the reference plot is enabled
    if {!$net::referenceEnabled} {return}
    
    #Get the phase values from the analysis variable
    set y $net::refPhase
    
    #Make sure we have at least 2 points to plot
    set length [llength $y]
    if {$length < 2} {return}
    
    #Clear the display
    .net.graphs.phase delete refPhaseTag
    
    #Determine which decade the start frequency is in
    set startDecade [expr round(floor($net::startValuePow))]
    
    #Determine which decade the end frequency is in
    set endDecade [expr {floor($net::endValuePow)}]

    #Determine how many decades we are going to span
    #set decadeSpan [expr {$endDecade-$startDecade+1}]
    if {[expr {abs($net::endValuePow-int($net::endValuePow))}] > 0} {
	set decadeSpan [expr {$endDecade-$startDecade+1}]
    } else {
	set decadeSpan [expr {$endDecade-$startDecade}]
    }
    
    #Calculate the corresponding x location for this frequency
    set decadeWidth [expr {$net::plotWidth/$decadeSpan}]
    
    #Plot data points
    set plotData {}
    for {set index 1} {$index < $length} {incr index} {
	
	#Get the frequency value for this sample
	set temp [lindex $net::refFreq [expr {$index-1}]]
	if {$net::frequencyStepMode == "log"} {
	    set currentX [expr {$::net::leftBorder+log($temp/(pow(10,floor($net::startValuePow))))/log(10)*$decadeWidth}]
	    set x1 [expr {round($currentX)}]
	} else {
	    set x1 [expr {$net::leftBorder+($temp-$net::startFrequency)/($net::endFrequency-$net::startFrequency)*$net::plotWidth}]
	}
	
	#Get the frequency value for this sample
	set temp [lindex $net::refFreq $index]
	#Calculate the corresponding x location for this frequency
	if {$net::frequencyStepMode == "log"} {
	    set currentX [expr {$::net::leftBorder+log($temp/(pow(10,floor($net::startValuePow))))/log(10)*$decadeWidth}]
	    set x2 [expr {round($currentX)}]
	} else {
	    set x2 [expr {$net::leftBorder+($temp-$net::startFrequency)/($net::endFrequency-$net::startFrequency)*$net::plotWidth}]
	}
	
	set y1 [lindex $y [expr {$index-1}]]
	set y1 [expr {$net::topBorder + ($net::plotHeight/2.0)- (($y1+180-$net::phaseOffset)/360)*$net::plotHeight}]
	set y2 [lindex $y $index]
	set y2 [expr {$net::topBorder + ($net::plotHeight/2.0)- (($y2+180-$net::phaseOffset)/360)*$net::plotHeight}]
	
	if {[lindex $net::refQuality $index] == 1} {
	    .net.graphs.phase create line	\
		$x1 $y1 $x2 $y2	\
		-tag refPhaseTag	\
		-fill grey	\
		-width 2
	} else {
	    .net.graphs.phase create line	\
		$x1 $y1 $x2 $y2	\
		-tag refPhaseTag	\
		-fill grey	\
		-width 2	\
		-dash .
	}
    }
}

proc net::yScale {graph} {
    variable referenceEnabled

    if {$graph == "mag"} {
	
	#Find the maximum and minimum magnitude values in the current magnitude data
	set minimum 60
	set maximum -60
	foreach mag $net::yMag {
	    if {$mag > $maximum} {
		set maximum $mag
	    }
	    if {$mag < $minimum} {
		set minimum $mag
	    }
	}
	
	#Check the reference magnitude data too, if it is enabled
	if {$net::referenceEnabled} {
	    foreach refMag $net::refMag {
		if {$refMag > $maximum} {
		    set maximum $refMag
		}
		if {$refMag < $minimum} {
		    set minimum $refMag
		}
	    }
	}
	
	#Determine the largest tick mark
	if {$maximum < 0} {
	    set topTick 0
	} elseif {$maximum < 20} {
	    set topTick 20
	} elseif {$maximum < 40} {
	    set topTick 40
	} else {
	    set topTick 60
	}
	
	#Determine the smallest tick mark
	if {$minimum > 0} {
	    set botTick 0
	} elseif {$minimum > -20} {
	    set botTick -20
	} elseif {$minimum > -40} {
	    set botTick -40
	} else {
	    set botTick -60
	}
	
	set net::topTick $topTick
	set net::botTick $botTick
	
	#Determine how many ticks to display
	set ticks [expr {($topTick-$botTick)/20}]
	set magMajorTick [expr {$net::plotHeight/$ticks}]
	
	#Draw the scale
	.net.graphs.mag delete magScale
	set tickValue $topTick
	for {set i 0} {$i <= $ticks} {incr i} {
	    set y [expr {$net::topBorder +$i*$magMajorTick}]
	    set tickValue [expr {$topTick - 20*$i}]
	    .net.graphs.mag create text	\
		[expr {$net::leftBorder - 15}] $y	\
		-text $tickValue	\
		-font {-size 8}	\
		-tag magScale
	    .net.graphs.mag create line	\
		$net::leftBorder $y	\
		[expr {$net::leftBorder+$net::plotWidth}] $y	\
		-tag magScale
	}
    } elseif {$graph == "phase"} {

	#Delete any previous markings
	.net.graphs.phase delete phaseScale

	#Split the display into 90 degree increments
	set phaseMajorTick [expr {$net::plotHeight/4}]
	
	#Draw the horizontal ticks
	for {set i 0} {$i< 5} {incr i} {
	    set y [expr {$net::topBorder + $i*$phaseMajorTick}]
	    .net.graphs.phase create text	\
		[expr {$net::leftBorder - 15}] $y	\
		-text [expr {$net::phaseOffset-90*$i}] 	\
		-font {-size 8}	\
		-tag phaseScale
	    .net.graphs.phase create line	\
		$net::leftBorder $y	\
		[expr {$net::leftBorder+$net::plotWidth}] $y	\
		-tag phaseScale
	}
    }

}

proc net::clearPlots {} {
    
    .net.graphs.mag delete magTag
    .net.graphs.phase delete phaseTag

}

proc net::findMax {dataA dataB} {
    
    set max 0
    foreach datumA $dataA datumB $dataB {
	if {$datumA > $max} {
	    set max $datumA
	}
	if {$datumB > $max} {
	    set max $datumB
	}
    }
    
    return $max

}

proc net::updateScopeDisplay {} {

    if {($::deviceType=="mini")||($::deviceType=="sig")} {
	set sampleDepth 1024
	#set sigMax 2047.0
    } else {
	set sampleDepth 4096
	#set sigMax 1023.0
    }

    set dataA [lindex $scope::scopeData 0]
    set dataB [lindex $scope::scopeData 1]
    
    set averageA [calculateAverage $dataA]
    set averageB [calculateAverage $dataB]

    set sigMax [findMax $dataA $dataB]
    if {$sigMax < 128} {
	set sigMax 1024
    }
    
    for {set i 1} {$i < $sampleDepth} {incr i} {
	set j [expr {$i-1}]
	if {([lindex $dataA $j] < $averageA) && ([lindex $dataA $i] > $averageA)} {
	    set startPoint $i
	    break
	}
    }

    


    .net.scope.display delete netWaveA
    .net.scope.display delete netWaveB
    
    #Plot channel A waveform
    set plotData {}
    for {set i 0} {$i < 128} {incr i} {
	#lappend plotData [expr {$i/($sampleDepth/$net::scopePlotWidth)}]
	lappend plotData [expr {$i/(128.0/$net::scopePlotWidth)}]
	#set datum [lindex $dataA $i]
	set datum [lindex $dataA [expr {$i+$startPoint}]]
	set datum [expr {$datum-$averageA}]
	lappend plotData [expr {$net::scopePlotHeight/2+$datum/($sigMax/$net::scopePlotHeight)}]
    }
    .net.scope.display create line	\
	$plotData	\
	-tag netWaveA	\
	-fill red
    
    #Plot channel B waveform
    set plotData {}
    for {set i 0} {$i < 128} {incr i} {
	#lappend plotData [expr {$i/($sampleDepth/$net::scopePlotWidth)}]
	lappend plotData [expr {$i/(128.0/$net::scopePlotWidth)}]
	#set datum [lindex $dataB $i]
	set datum [lindex $dataB [expr {$i+$startPoint}]]
	set datum [expr {$datum-$averageB}]
	lappend plotData [expr {$net::scopePlotHeight/2+$datum/($sigMax/$net::scopePlotHeight)}]
    }
    .net.scope.display create line	\
	$plotData	\
	-tag netWaveB	\
	-fill blue
    
    update

}

#Save current network data as refence plot
proc net::saveReference {} {

    set net::refMag $net::yMag
    set net::refPhase $net::yPhase
    set net::refFreq $net::xFreq
    set net::refQuality $net::quality

}

proc net::toggleReference {} {

    if {$net::referenceEnabled} {
	net::plotRefMag
	net::plotRefPhase
    } else {
	.net.graphs.mag delete refMagTag
	.net.graphs.phase delete refPhaseTag
    }

}

proc net::setStartFrequency {} {

    #Dialog box for new frequency
    set newFreq [Dialog_Prompt newFstart "Set Start Frequency:"]
    
    if {$newFreq == ""} {return}
    
    #Make sure that we got a valid frequency setting
    if { [string is double -strict $newFreq] } {
	if { $newFreq >= 0.1 && $newFreq <= $net::endFrequency} {
	    set net::startValuePow [expr {log10($newFreq)}]
	    set net::startFrequency [format %.1f $newFreq]
	    net::clearPlots
	    net::updateStartValue $net::startValuePow
	} else {
	    tk_messageBox	\
		-title "Invalid Frequency"	\
		-default ok		\
		-message "Frequency out of range.  Start frequency must be greater than 0.1Hz\nand less than the end frequency."	\
		-type ok			\
		-icon warning
	}
    } else {
	tk_messageBox	\
	    -title "Invalid Frequency"	\
	    -default ok		\
	    -message "Frequency must be a number\nbetween 0.1 Hz and 200 kHz."	\
	    -type ok			\
	    -icon warning
    }
    

}

proc net::setEndFrequency {} {

    if {($::deviceType=="mini")||($::deviceType=="sig")} {
	set freqMax 200000
	set maxString "200kHz"
    } else {
	set freqMax 10E6
	set maxString "10MHz"
    }

    #Dialog box for new frequency
    set newFreq [Dialog_Prompt newFend "Set End Frequency:"]
    
    if {$newFreq == ""} {return}
    
    #Make sure that we got a valid frequency setting
    if { [string is double -strict $newFreq] } {
	if { $newFreq >= $net::startFrequency && $newFreq <= $freqMax} {
	    set net::endValuePow [expr {log10($newFreq)}]
	    set net::endFrequency [format %.1f $newFreq]
	    net::clearPlots
	    net::updateEndValue $net::endValuePow
	} else {
	    tk_messageBox	\
		-title "Invalid Frequency"	\
		-default ok		\
		-message "Frequency out of range.  End frequency must be less than $maxString \nand greater than the starting frequency."	\
		-type ok			\
		-icon warning
	}
    } else {
	tk_messageBox	\
	    -title "Invalid Frequency"	\
	    -default ok		\
	    -message "Frequency must be a number\nbetween 0.1 Hz and $maxString."	\
	    -type ok			\
	    -icon warning
    }
    

}

proc net::selectStepMode {} {

    if {$net::frequencyStepMode == "log"} {
	.net.controls.inputs.frequencyStep	configure	\
	    -from 1.01		\
	    -to 1.25		\
	    -resolution 0.01	\
	    -variable net::frequencyLogStep
	
	.net.controls.inputs.stepValue configure	\
	    -textvariable net::frequencyLogStep
	
    } else {
	.net.controls.inputs.frequencyStep	configure	\
	    -from 0.1		\
	    -to 100000		\
	    -resolution 0.1	\
	    -variable net::frequencyLinStep
	
	.net.controls.inputs.stepValue configure	\
	    -textvariable net::frequencyLinStep
    }
    
    net::drawXScale

}

proc net::setFrequencyStep {} {

    #Dialog box for new frequency
    set newStep [Dialog_Prompt newFstep "Set Frequency Step:"]
    
    if {$newStep == ""} {return}
    
    #Make sure that we got a valid frequency setting
    if { [string is double -strict $newStep] } {
	if {$net::frequencyStepMode == "log"} {
	    if {$newStep >= 1.01 && $newStep <= 1.25} {
		set net::frequencyLogStep $newStep
	    } else {
		tk_messageBox	\
		    -title "Invalid Frequency"	\
		    -default ok		\
		    -message "Frequency out of range.  Logarithmic frequency step must be between 1.01 and 1.25"	\
		    -type ok			\
		    -icon warning
	    }
	} else {
	    if {$newStep >= 0.1 && $newStep <= 100000} {
		set net::frequencyLinStep $newStep
	    } else {
		tk_messageBox	\
		    -title "Invalid Frequency"	\
		    -default ok		\
		    -message "Frequency out of range.  Linear frequency step must be between 0.1 and 100kHz"	\
		    -type ok			\
		    -icon warning
	    }
	}
    } else {
	if {$net::frequencyStepMode == "log"} {
	    tk_messageBox	\
		-title "Invalid Frequency"	\
		-default ok		\
		-message "Logarithmic frequency step must be a number\nbetween 1.01 and 1.25"	\
		-type ok			\
		-icon warning
	} else {
	    tk_messageBox	\
		-title "Invalid Frequency"	\
		-default ok		\
		-message "Linear frequency step must be a number\nbetween 0.1 and 100000"	\
		-type ok			\
		-icon warning
	}
    }
    

}

proc net::updateMagCursor {xCoord yCoord} {

    #puts "$xCoord,$yCoord"
    .net.graphs.mag delete magCursor
    
    if {$xCoord < $net::leftBorder} {return}
    
    #Calculate the frequency coordinate
    if {$net::frequencyStepMode=="log"} {
	#Determine which decade the start frequency is in
	set startDecade [expr round(floor($net::startValuePow))]
	
	#Determine which decade the end frequency is in
	set endDecade [expr {floor($net::endValuePow)}]

	#Determine how many decades we are going to span
	#set decadeSpan [expr {$endDecade-$startDecade+1}]
	if {[expr {abs($net::endValuePow-int($net::endValuePow))}] > 0} {
	    set decadeSpan [expr {$endDecade-$startDecade+1}]
	} else {
	    set decadeSpan [expr {$endDecade-$startDecade}]
	}
	
	set decadeWidth [expr {$net::plotWidth/$decadeSpan}]
	
	set currentDecade [expr {$startDecade+($xCoord-$net::leftBorder)/$decadeWidth}]
	#puts "Current Decade $currentDecade"
	
	set f [expr {pow(10,$currentDecade)}]
	#puts "Frequency $f"
    } else {
	
	set f [expr {$net::startFrequency+1.0*($xCoord-$net::leftBorder)/$net::plotWidth*($net::endFrequency-$net::startFrequency)}]
	#puts "f $f"
    }
    
    if {$net::snapToTrace} {
	
	set xDistance {}
	foreach xValue $net::xValues {
	    lappend xDistance [expr {abs($xCoord-$xValue)}]
	}
	${log}::debug "Distances: $xDistance"
	
	set min [lindex $xDistance 0]
	set minIndex 0
	for {set i 1} {$i < [llength $xDistance]} {incr i} {
	    if {[lindex $xDistance $i] < $min} {
		set min [lindex $xDistance $i]
		set minIndex $i
	    }
	}
	
	if {[llength $net::yMag] < $minIndex} {
	    return
	}
	
	.net.graphs.mag create line	\
	    [lindex $net::xValues $minIndex] 0	\
	    [lindex $net::xValues $minIndex] 250	\
	    -tag magCursor	\
	    -fill red	\
	    -width 2
	
    }

    if {$f > 1E6} {
	set freqText [format "%3.3f" [expr $f/1E6]]
	append freqText "M"
    } elseif { $f > 1E3} {
	set freqText [format "%3.3f" [expr $f/1E3]]
	append freqText "k"
    } else {
	set freqText [format "%3.3f" $f]
    }
    append freqText "Hz"

    #Determine which side of the cursor to position the reading
    if {$xCoord < [expr {$net::plotWidth/2.0}]} {
	set anchorPos "w"
	set anchorX [expr {$xCoord+5}]
    } else {
	set anchorPos "e"
	set anchorX [expr {$xCoord-5}]
    }

    .net.graphs.mag create text 	\
	$anchorX [expr {$yCoord-5}]	\
	-text $freqText	\
	-font {-size -15 -weight bold}	\
	-fill red	\
	-anchor $anchorPos	\
	-tag magCursor
    
    if {($net::topTick == 0) && ($net::botTick == 0)} {
	return
    }
    
    #Determine the amplitude reading
    
    set amp [expr {$net::topTick+1.0*($yCoord-$net::topBorder)/($net::plotHeight)*($net::botTick-$net::topTick)}]
    
    set ampText [format %.3f $amp]
    append ampText "dB"
    
    .net.graphs.mag create text	\
	$anchorX [expr {$yCoord+10}]	\
	-text $ampText	\
	-font {-size -15 -weight bold}	\
	-fill red	\
	-anchor $anchorPos	\
	-tag magCursor

}

proc net::updatePhaseCursor {xCoord yCoord} {

    .net.graphs.phase delete phaseCursor
    
    if {$xCoord < $net::leftBorder} {return}
    
    #Calculate the frequency coordinate
    if {$net::frequencyStepMode=="log"} {
	#Determine which decade the start frequency is in
	set startDecade [expr round(floor($net::startValuePow))]
	
	#Determine which decade the end frequency is in
	set endDecade [expr {floor($net::endValuePow)}]

	#Determine how many decades we are going to span
	#set decadeSpan [expr {$endDecade-$startDecade+1}]
	if {[expr {abs($net::endValuePow-int($net::endValuePow))}] > 0} {
	    set decadeSpan [expr {$endDecade-$startDecade+1}]
	} else {
	    set decadeSpan [expr {$endDecade-$startDecade}]
	}
	
	set decadeWidth [expr {$net::plotWidth/$decadeSpan}]
	
	set currentDecade [expr {$startDecade+($xCoord-$net::leftBorder)/$decadeWidth}]
	
	set f [expr {pow(10,$currentDecade)}]
    } else {
	
	set f [expr {$net::startFrequency+1.0*($xCoord-$net::leftBorder)/$net::plotWidth*($net::endFrequency-$net::startFrequency)}]
	#puts "f $f"
    }

    if {$f > 1E6} {
	set freqText [format "%3.3f" [expr $f/1E6]]
	append freqText "M"
    } elseif { $f > 1E3} {
	set freqText [format "%3.3f" [expr $f/1E3]]
	append freqText "k"
    } else {
	set freqText [format "%3.3f" $f]
    }
    append freqText "Hz"

    #Determine which side of the cursor to position the reading
    if {$xCoord < [expr {$net::plotWidth/2.0}]} {
	set anchorPos "w"
	set anchorX [expr {$xCoord+5}]
    } else {
	set anchorPos "e"
	set anchorX [expr {$xCoord-5}]
    }

    .net.graphs.phase create text 	\
	$anchorX [expr {$yCoord-5}]	\
	-text $freqText	\
	-font {-size -15 -weight bold}	\
	-fill red	\
	-anchor $anchorPos	\
	-tag phaseCursor
    
    #Determine the phase reading
    set phase [expr {$net::phaseOffset+(-360.0)*($yCoord-$net::topBorder)/($net::plotHeight)}]
    
    set phaseText [format %.1f $phase]
    append phaseText "deg"
    
    .net.graphs.phase create text	\
	$anchorX [expr {$yCoord+10}]	\
	-text $phaseText	\
	-font {-size -15 -weight bold}	\
	-fill red	\
	-anchor $anchorPos	\
	-tag phaseCursor

}

proc net::findResonantPeak {} {

    if {!$net::resonantEnable} {
	.net.graphs.mag delete resonantTag
	return
    }

    set y $net::yMag

    set length [llength $y]
    if {$length < 2} {return}
    
    .net.graphs.mag delete resonantTag

    set max [lindex $y 0]
    set maxIndex 0
    set currentIndex 0
    foreach magPoint $y {
	if {$magPoint > $max} {
	    set maxIndex $currentIndex
	    set max $magPoint
	}
	incr currentIndex
    }
    
    set peakMagnitude [format "%.3f" $max]
    append peakMagnitude "dB"
    
    set freqText [lindex $net::xFreq $maxIndex]
    #if {$peakFrequency > 1E6} {
    #	set freqText [format "%3.3f" [expr $peakFrequency/1E6]]
    #	append freqText "M"
    #} elseif { $peakFrequency > 1E3} {
    #	set freqText [format "%3.3f" [expr $peakFrequency/1E3]]
    #	append freqText "k"
    #} else {
    #	set freqText [format "%3.3f" $peakFrequency]
    #}
    #append freqText "Hz"
    
    set peakText "Peak\n$peakMagnitude\n$freqText"

    #Determine how many ticks to display
    set ticks [expr {($net::topTick-$net::botTick)/20}]
    set magMajorTick [expr {$net::plotHeight/$ticks}]
    
    .net.graphs.mag create text 	\
	[lindex $net::xValues $maxIndex] [expr {$net::topBorder+($net::topTick-$max)/20*($magMajorTick)-35}]	\
	-text $peakText	\
	-font {-size -15 -weight bold}	\
	-fill blue	\
	-anchor center	\
	-justify center	\
	-tag resonantTag

    .net.graphs.mag create line	\
	[expr {[lindex $net::xValues $maxIndex]-10}] [expr {$net::topBorder+($net::topTick-$max)/20*($magMajorTick)-10}]	\
	[expr {[lindex $net::xValues $maxIndex]}] [expr {$net::topBorder+($net::topTick-$max)/20*($magMajorTick)}]	\
	[expr {[lindex $net::xValues $maxIndex]+10}] [expr {$net::topBorder+($net::topTick-$max)/20*($magMajorTick)-10}]	\
	-tag resonantTag	\
	-fill blue	\
	-width 2
    
}

proc net::moveGripper {x y} {

    #Pull the last x,y coordinates
    set prevX [lindex $net::gripperStart 0]
    set prevY [lindex $net::gripperStart 1]
    
    #Calculate the change in position of the gripper
    set deltaX [expr {$x-$prevX}]
    set deltaY [expr {$y-$prevY}]

    #Resize the graph area
    net::resizeDisplay [expr {$net::plotWidth+$deltaX}] [expr {$net::plotHeight+$deltaY}]
    
    #Store the current gripper position for next time
    set net::gripperStart [list $x $y]

}

proc net::resizeDisplay {w h} {
    variable yPlotStart
    variable yPlotEnd
    variable xPlotStart
    variable xPlotEnd
    variable xMid
    variable yMid
    
    #Save the new geometry
    set net::plotWidth $w
    set net::plotHeight $h
    
    #Make sure we don't make the graph too small
    if {$net::plotWidth < $net::minimumGraphWidth} {
	set net::plotWidth $net::minimumGraphWidth
    }
    if {$net::plotHeight < $net::minimumGraphHeight} {
	set net::plotHeight $net::minimumGraphHeight
    }
    
    #Make sure the display is square
    #if {$scope::yPlotHeight!=$scope::xPlotWidth} {
    #	set scope::xPlotWidth $scope::yPlotHeight
    #}

    #Resize the display
    .net.graphs.mag configure	\
	-width [expr {$net::plotWidth+$net::leftBorder+$net::rightBorder}]	\
	-height [expr {$net::plotHeight+$net::topBorder+$net::bottomBorder}]
    
    .net.graphs.phase configure	\
	-width [expr {$net::plotWidth+$net::leftBorder+$net::rightBorder}]	\
	-height [expr {$net::plotHeight+$net::topBorder+$net::bottomBorder}]
    
    #Redraw the axes
    net::drawXScale
    net::yScale phase

    
    #Remove the traces
    net::clearPlots

}

proc net::measureFrequency {} {
    global log
    
    set dataA [lindex $scope::scopeData 0]
    
    #Calculate the average value of the waveforms
    set averageA 0
    set i 0
    foreach datumA $dataA {
	set averageA [expr {$averageA+$datumA}]
	incr i
    }
    set averageA [expr {$averageA*1.0/$i}]
    
    set prevCompA 0
    set compOutA {}
    set upperThresholdA [expr {$averageA + 2}]
    set lowerThresholdA [expr {$averageA - 2}]
    set i 0
    set crossingsA {}
    foreach datumA $dataA {
	#Channel A Comparator
	if {($prevCompA == 0)} {
	    if {$datumA > $upperThresholdA} {
		lappend compOutA 1
		set prevCompA 1
		lappend crossingsA $i
	    } else {
		lappend compOutA 0
	    }
	} else {
	    if {$datumA < $lowerThresholdA} {
		lappend compOutA 0
		set prevCompA 0
	    } else {
		lappend compOutA 1
	    }
	}
	incr i
    }
    
    ${log}::debug "CROSSINGS LENGTH [llength $crossingsA]"
    
    #Compute the frequency and period for channel A
    if {[llength $crossingsA] >= 3} {
	
	#Strip off the first crossing as it is an artifact of the hysterisis
	set crossingsA [lrange $crossingsA 1 end]
	
	#Determine the average number of samples 
	#between  average crossings
	set betweenCrossingsA 0
	for {set i 1} {$i < [llength $crossingsA]} {incr i} {
	    set betweenCrossingsA [expr {$betweenCrossingsA + [expr [lindex $crossingsA $i] - [lindex $crossingsA [expr $i-1]]]}]
	}
	set betweenCrossingsA [expr {$betweenCrossingsA*1.0/[expr {[llength $crossingsA]-1}]}]
	
	#Determine the amount of time represented by the
	#average  number of samples between average crossings
	set samplePeriod [timebase::getSamplingPeriod]
	set periodA [expr {$betweenCrossingsA*$samplePeriod}]
	set frequencyA [expr {1.0/$periodA}]
    } else {
	set frequencyA -1
    }
    
    return $frequencyA

}

proc net::stop_analyzer {} {
    # Called when the STOP button is pushed in the Network Analyzer
    # window

    # Disable the Network Analyzer mode
    set net::analyzeEnable 0

    # Set the waveform amplitude to 0 by first setting the slider to 0
    # on the main waveform generator window, then sending the slider
    # value to the hardware.
    [wave::getWavePath].amp.ampSlider set 0
    wave::adjustAmplitude [[wave::getWavePath].amp.ampSlider get]
}

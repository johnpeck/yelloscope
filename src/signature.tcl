#File: signature.tcl
#Syscomp Electronic Design
#Signature Analyzer GUI

#JG
#Copyright 2016 Syscomp Electronic Design
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

package require math::statistics

namespace eval sig {

#Sensitivity controls
set canvasSize 75
set voltageValues {0.01 0.02 0.05 0.1 0.2 0.5 1 2 5}
set currentValues {0.0001 0.0002 0.0005 0.001 0.002 0.005 0.01 0.02 0.05}
set voltageIndex 6
set currentIndex 6
set attenA 0
set attenB 0
set voltageStepSize 0.01245711
set currentStepSize 49.299E-6

#Scope Display Geometry
set minimumGraphWidth 400
set minimumGraphHeight 400
set graphWidth 400
set graphHeight 400
set leftMargin 20
set rightMargin 20
set bottomMargin 15
set topMargin 15
set yAxisStart $topMargin
set yAxisEnd [expr {$graphHeight-$bottomMargin}]
set xAxisStart $leftMargin
set xAxisEnd [expr {$graphWidth-$rightMargin}]

#Grid Parameters
set axisColor black
set backgroundColor white
set xGridColor grey
set yGridColor grey
set xGridEnabled 1
set yGridEnabled 1

#Display mode
set displayMode iv

set resistorImage [image create photo -file $::images/resistor.png]
set capacitorImage [image create photo -file $::images/capacitor.png]
set inductorImage [image create photo -file $::images/inductor.png]
set diodeImage [image create photo -file $::images/diode.png]

set sigData {}

set capPresets {"<100nF" "100nF-1uF" "1uF-10uF" "10uF-100uF" ">100uF"}
set capPreset [lindex $capPresets 1]

set indPresets {"<100uH" "100uH-1mH" ">1mH"}
set indPreset [lindex $indPresets 1]

set diodePresets {"Small Signal +/-1V" "Power +/-2V" "Zener +/-10V"}
set diodePreset [lindex $diodePresets 0]

set deviceMode "?"

set measureEnable 1
set resValue "?"
set sineRef {}
set cosRef {}
set capResValue "?"
set capCapValue "?"
set capMode "parallel"
set indResValue "?"
set indIndValue "?"

#Reference Waveform
set referenceActive 0
set referenceCurve {}

}

proc sig::buildSignature {} {
    
    labelframe .sig \
        -relief groove  \
        -borderwidth 2  \
        -text "Signature Analysis"  \
        -font {-weight bold -size -12}
    
    labelframe .sig.voltage   \
        -text "X-Axis: Voltage" \
        -labelanchor n  \
        -font {-weight bold -size -12}
    
    #Create a canvas to indicate the voltage sensitivity
	canvas .sig.voltage.display	\
		-width $sig::canvasSize	\
		-height $sig::canvasSize	\
		-background white
	#Draw a box
	.sig.voltage.display create rectangle	\
		4 4	\
		 [expr {$sig::canvasSize-1}]  [expr {$sig::canvasSize-1}]	\
		 -dash {10 10} \
		 -fill ""	\
		 -outline black	\
		 -width 2
	sig::updateIndicator voltage

	#Button to increase the vertical sensitivity
	button .sig.voltage.zoomIn	\
		-image $vertical::zoomInImage	\
		-command "sig::adjustVoltage in"
		
	#Button to decrease the vertical sensitivity
	button .sig.voltage.zoomOut	\
		-image $vertical::zoomOutImage	\
		-command "sig::adjustVoltage out"
    
    labelframe .sig.current   \
        -text "Y-Axis: Current" \
        -labelanchor n  \
        -font {-weight bold -size -12}
    
    #Create a canvas to indicate the vertical sensitivity
	canvas .sig.current.display	\
		-width $sig::canvasSize	\
		-height $sig::canvasSize	\
		-background white
	#Draw a box
	.sig.current.display create rectangle	\
		4 4	\
		 [expr {$sig::canvasSize-1}]  [expr {$sig::canvasSize-1}]	\
		 -dash {10 10} \
		 -fill ""	\
		 -outline black	\
		 -width 2
	sig::updateIndicator current

	#Button to increase the vertical sensitivity
	button .sig.current.zoomIn	\
		-image $vertical::zoomInImage	\
		-command "sig::adjustCurrent in"
		
	#Button to decrease the vertical sensitivity
	button .sig.current.zoomOut	\
		-image $vertical::zoomOutImage	\
		-command "sig::adjustCurrent out"
    
    #Main signature analysis display canvas
    canvas .sig.display \
        -background $sig::backgroundColor   \
        -width $sig::graphWidth \
        -height $sig::graphHeight
    
    #Button for swapping the axes
    button .sig.swap    \
        -text "Swap"    \
        -width 8        \
        -height 3       \
        -command sig::swapAxes
    
    #Small handle for resizing the display
    label .sig.gripper  \
        -image [image create photo -file "$::images/Gripper.gif"]
    
    bind .sig.gripper <Button-1> {set sig::gripperStart [list %X %Y]}
    bind .sig.gripper <B1-Motion> {sig::moveGripper %X %Y}

    #Frame for right side controls
    frame .sig.right    \
        -relief groove  \
        -borderwidth 1
    
    #Frame for device selection
    labelframe .sig.right.device    \
        -text "Device"
    
    button .sig.right.device.resistor   \
        -image $sig::resistorImage  \
        -command {sig::selectDevice resistor}
    
    button .sig.right.device.capacitor   \
        -image $sig::capacitorImage \
        -command {sig::selectDevice capacitor}
    
    button .sig.right.device.inductor   \
        -image $sig::inductorImage  \
        -command {sig::selectDevice inductor}
    
    button .sig.right.device.diode  \
        -image $sig::diodeImage \
        -command {sig::selectDevice diode}
    
    grid .sig.right.device.resistor -row 0 -column 0 -ipadx 2 -ipady 2 -padx 2 -pady 2
    grid .sig.right.device.capacitor -row 0 -column 1 -ipadx 2 -ipady 2 -padx 2 -pady 2
    grid .sig.right.device.inductor -row 1 -column 0 -ipadx 2 -ipady 2 -padx 2 -pady 2
    grid .sig.right.device.diode -row 1 -column 1 -ipadx 2 -ipady 2 -padx 2 -pady 2
    
    #Frame for resistor controls
    labelframe .sig.right.resistor  \
        -text "Resistor"
    
    label .sig.right.resistor.freqLabel \
        -text "Test Frequency:" \
        -width 20
    
    label .sig.right.resistor.freq  \
        -text "500 Hz"  \
        -relief sunken  \
        -width 10
    
    labelframe .sig.right.resistor.amplitude   \
        -text "Amplitude"
    
    scale .sig.right.resistor.amplitude.slider \
        -from 0 \
        -to 100 \
        -length 225 \
        -orient horizontal  \
        -resolution 5   \
        -tickinterval 20    \
        -command wave::adjustAmplitude
    pack .sig.right.resistor.amplitude.slider
    
    label .sig.right.resistor.resLabel  \
        -text "Measured Resistance (Slope):"
    
    label .sig.right.resistor.resValue  \
        -textvariable sig::resValue \
        -width 20   \
        -relief sunken
    
    grid .sig.right.resistor.freqLabel -row 0 -column 0
    grid .sig.right.resistor.freq -row 0 -column 1
    grid .sig.right.resistor.amplitude -row 1 -column 0 -columnspan 2 -pady 10
    grid .sig.right.resistor.resLabel -row 2 -column 0 -columnspan 2 -sticky w
    grid .sig.right.resistor.resValue -row 3 -column 0 -columnspan 2 -sticky we
    
    #Frame for capacitor controls
    labelframe .sig.right.capacitor  \
        -text "Capacitor"
    
    label .sig.right.capacitor.presetLabel  \
        -text "Presets:"
    
    ttk::combobox .sig.right.capacitor.presets	\
		-justify center	\
		-textvariable sig::capPreset	\
		-values $sig::capPresets	\
		-width 10
	bind .sig.right.capacitor.presets <<ComboboxSelected>> sig::selectCapacitorPreset
    
    labelframe .sig.right.capacitor.amplitude   \
        -text "Amplitude"
    
    scale .sig.right.capacitor.amplitude.slider \
        -from 0 \
        -to 100 \
        -length 225 \
        -orient horizontal  \
        -resolution 5   \
        -tickinterval 20    \
        -command wave::adjustAmplitude
    pack .sig.right.capacitor.amplitude.slider
    
    labelframe .sig.right.capacitor.frequency   \
        -text "Frequency"
    
    scale .sig.right.capacitor.frequency.slider \
		-from 1	\
		-to $::wave::sliderRange		\
		-variable ::wave::frequencyPosition	\
		-orient horizontal	\
		-tickinterval 0	\
		-resolution 1	\
		-showvalue 0	\
		-length 225	\
		-command {wave::adjustFrequency $wave::frequencyPosition; sig::adjustTimebase}
    
    label .sig.right.capacitor.frequency.minFreq \
        -text "1Hz"
    
    label .sig.right.capacitor.frequency.currentFreq    \
        -relief sunken  \
        -borderwidth 3  \
        -textvariable wave::frequencyDisplay    \
        -width 10
    
    label .sig.right.capacitor.frequency.maxFreq    \
        -text "100kHz"
    
    grid .sig.right.capacitor.frequency.slider -row 0 -column 0 -columnspan 3
    grid .sig.right.capacitor.frequency.minFreq -row 1 -column 0 -sticky w
    grid .sig.right.capacitor.frequency.currentFreq -row 1 -column 1 -sticky we
    grid .sig.right.capacitor.frequency.maxFreq -row 1 -column 2 -sticky e
    
    labelframe .sig.right.capacitor.offset  \
        -text "Offset"
    
    scale .sig.right.capacitor.offset.slider	\
		-from 3.0	\
		-to -3.0	\
		-variable wave::offset	\
		-orient horizontal	\
		-showvalue 1	\
		-length 225	\
		-tickinterval 1	\
		-resolution 0.1	\
		-command wave::adjustOffset
    pack .sig.right.capacitor.offset.slider
    
    labelframe .sig.right.capacitor.measurements    \
        -text "Measurements"
    
    checkbutton .sig.right.capacitor.measurements.enable    \
        -text "Enable"  \
        -variable sig::measureEnable
    
    labelframe .sig.right.capacitor.measurements.mode   \
        -text "Mode"
    
    radiobutton .sig.right.capacitor.measurements.mode.parallel  \
        -text "Parallel"    \
        -value "parallel"   \
        -variable sig::capMode
    
    radiobutton .sig.right.capacitor.measurements.mode.series    \
        -text "Series"  \
        -value "series" \
        -variable sig::capMode
    
    grid .sig.right.capacitor.measurements.mode.parallel -row 0 -column 0 -sticky we
    grid .sig.right.capacitor.measurements.mode.series -row 0 -column 1 -sticky we
    grid columnconfigure .sig.right.capacitor.measurements.mode 0 -weight 1
    grid columnconfigure .sig.right.capacitor.measurements.mode 1 -weight 1
    
    label .sig.right.capacitor.measurements.resistanceLabel \
        -text "Resistance:"
    label .sig.right.capacitor.measurements.resistance  \
        -relief sunken  \
        -width 15   \
        -textvariable sig::capResValue
    
    label .sig.right.capacitor.measurements.capacitanceLabel \
        -text "Capacitance:"
    label .sig.right.capacitor.measurements.capacitance  \
        -relief sunken  \
        -width 15   \
        -textvariable sig::capCapValue
    
    grid .sig.right.capacitor.measurements.enable -row 0 -column 0 -columnspan 2 -sticky we
    grid .sig.right.capacitor.measurements.mode -row 1 -column 0 -columnspan 2 -sticky we
    grid .sig.right.capacitor.measurements.resistanceLabel -row 2 -column 0 -pady 5
    grid .sig.right.capacitor.measurements.resistance -row 2 -column 1 -pady 5
    grid .sig.right.capacitor.measurements.capacitanceLabel -row 3 -column 0 -pady 5
    grid .sig.right.capacitor.measurements.capacitance -row 3 -column 1 -pady 5
    grid columnconfigure .sig.right.capacitor.measurements 0 -weight 1
    grid columnconfigure .sig.right.capacitor.measurements 1 -weight 1
    
    grid .sig.right.capacitor.presetLabel -row 0 -column 0
    grid .sig.right.capacitor.presets -row 1 -column 0
    grid .sig.right.capacitor.amplitude -row 2 -column 0 -padx 5 -pady 5
    grid .sig.right.capacitor.frequency -row 3 -column 0 -padx 5 -pady 5
    grid .sig.right.capacitor.offset -row 4 -column 0 -padx 5 -pady 5
    grid .sig.right.capacitor.measurements -row 2 -column 1 -rowspan 4 -sticky nwe -padx 5 -pady 5
    
    #Frame for inductor controls
    labelframe .sig.right.inductor  \
        -text "Inductor"
    
    label .sig.right.inductor.presetLabel  \
        -text "Presets:"
    
    ttk::combobox .sig.right.inductor.presets	\
		-justify center	\
		-textvariable sig::indPreset	\
		-values $sig::indPresets	\
		-width 10
	bind .sig.right.inductor.presets <<ComboboxSelected>> sig::selectInductorPreset
    
    labelframe .sig.right.inductor.amplitude   \
        -text "Amplitude"
    
    scale .sig.right.inductor.amplitude.slider \
        -from 0 \
        -to 100 \
        -length 225 \
        -orient horizontal  \
        -resolution 5   \
        -tickinterval 20    \
        -command wave::adjustAmplitude
    pack .sig.right.inductor.amplitude.slider
    
    labelframe .sig.right.inductor.frequency   \
        -text "Frequency"
    
    scale .sig.right.inductor.frequency.slider \
		-from 1	\
		-to $::wave::sliderRange		\
		-variable ::wave::frequencyPosition	\
		-orient horizontal	\
		-tickinterval 0	\
		-resolution 1	\
		-showvalue 0	\
		-length 225	\
		-command {wave::adjustFrequency $wave::frequencyPosition; sig::adjustTimebase}
    
    label .sig.right.inductor.frequency.minFreq \
        -text "1Hz"
    
    label .sig.right.inductor.frequency.currentFreq    \
        -relief sunken  \
        -borderwidth 3  \
        -textvariable wave::frequencyDisplay    \
        -width 10
    
    label .sig.right.inductor.frequency.maxFreq    \
        -text "100kHz"
    
    grid .sig.right.inductor.frequency.slider -row 0 -column 0 -columnspan 3
    grid .sig.right.inductor.frequency.minFreq -row 1 -column 0 -sticky w
    grid .sig.right.inductor.frequency.currentFreq -row 1 -column 1 -sticky we
    grid .sig.right.inductor.frequency.maxFreq -row 1 -column 2 -sticky e
    
    labelframe .sig.right.inductor.offset  \
        -text "Offset"
    
    scale .sig.right.inductor.offset.slider	\
		-from 3.0	\
		-to -3.0	\
		-variable wave::offset	\
		-orient horizontal	\
		-showvalue 1	\
		-length 225	\
		-tickinterval 1	\
		-resolution 0.1	\
		-command wave::adjustOffset
    pack .sig.right.inductor.offset.slider
	
	labelframe .sig.right.inductor.measurements    \
        -text "Measurements"
    
    checkbutton .sig.right.inductor.measurements.enable    \
        -text "Enable"  \
        -variable sig::measureEnable
    
    labelframe .sig.right.inductor.measurements.mode   \
        -text "Mode"
    
    radiobutton .sig.right.inductor.measurements.mode.parallel  \
        -text "Parallel"    \
        -value "parallel"   \
        -variable sig::capMode
    
    radiobutton .sig.right.inductor.measurements.mode.series    \
        -text "Series"  \
        -value "series" \
        -variable sig::capMode
    
    grid .sig.right.inductor.measurements.mode.parallel -row 0 -column 0 -sticky we
    grid .sig.right.inductor.measurements.mode.series -row 0 -column 1 -sticky we
    grid columnconfigure .sig.right.inductor.measurements.mode 0 -weight 1
    grid columnconfigure .sig.right.inductor.measurements.mode 1 -weight 1
    
    label .sig.right.inductor.measurements.resistanceLabel \
        -text "Resistance:"
    label .sig.right.inductor.measurements.resistance  \
        -relief sunken  \
        -width 15   \
        -textvariable sig::indResValue
    
    label .sig.right.inductor.measurements.inductanceLabel \
        -text "Inductance:"
    label .sig.right.inductor.measurements.inductance  \
        -relief sunken  \
        -width 15   \
        -textvariable sig::indIndValue
    
    grid .sig.right.inductor.measurements.enable -row 0 -column 0 -columnspan 2 -sticky we
    grid .sig.right.inductor.measurements.mode -row 1 -column 0 -columnspan 2 -sticky we
    grid .sig.right.inductor.measurements.resistanceLabel -row 2 -column 0 -pady 5
    grid .sig.right.inductor.measurements.resistance -row 2 -column 1 -pady 5
    grid .sig.right.inductor.measurements.inductanceLabel -row 3 -column 0 -pady 5
    grid .sig.right.inductor.measurements.inductance -row 3 -column 1 -pady 5
    grid columnconfigure .sig.right.inductor.measurements 0 -weight 1
    grid columnconfigure .sig.right.inductor.measurements 1 -weight 1
	
    
    grid .sig.right.inductor.presetLabel -row 0 -column 0
    grid .sig.right.inductor.presets -row 1 -column 0
    grid .sig.right.inductor.amplitude -row 2 -column 0 -padx 5 -pady 5
    grid .sig.right.inductor.frequency -row 3 -column 0 -padx 5 -pady 5
    grid .sig.right.inductor.offset -row 4 -column 0 -padx 5 -pady 5
    grid .sig.right.inductor.measurements -row 2 -column 1 -rowspan 4 -sticky nwe -padx 5 -pady 5
    
    #Frame for diode controls
    labelframe .sig.right.diode \
        -text "Diode"
    
    label .sig.right.diode.presetLabel  \
        -text "Presets:"
    
    ttk::combobox .sig.right.diode.presets	\
		-justify center	\
		-textvariable sig::diodePreset	\
		-values $sig::diodePresets	\
		-width 20
	bind .sig.right.diode.presets <<ComboboxSelected>> sig::selectDiodePreset
    
    labelframe .sig.right.diode.amplitude   \
        -text "Amplitude"
    
    scale .sig.right.diode.amplitude.slider \
        -from 0 \
        -to 100 \
        -length 225 \
        -orient horizontal  \
        -resolution 5   \
        -tickinterval 20    \
        -command wave::adjustAmplitude
    pack .sig.right.diode.amplitude.slider
    
    labelframe .sig.right.diode.offset  \
        -text "Offset"
    
    scale .sig.right.diode.offset.slider	\
		-from 3.0	\
		-to -3.0	\
		-variable wave::offset	\
		-orient horizontal	\
		-showvalue 1	\
		-length 225	\
		-tickinterval 1	\
		-resolution 0.1	\
		-command wave::adjustOffset
    pack .sig.right.diode.offset.slider
    
    grid .sig.right.diode.presetLabel -row 0 -column 0
    grid .sig.right.diode.presets -row 1 -column 0
    grid .sig.right.diode.amplitude -row 2 -column 0
    grid .sig.right.diode.offset -row 3 -column 0
    
    
    grid .sig.right.device -row 0 -column 0 -sticky n -padx 4
    
    grid .sig.display -row 0 -column 1
    grid .sig.gripper -row 0 -column 1 -sticky se -ipadx 0 -pady 0 -padx 0 -pady 0
    grid .sig.swap -row 1 -column 0 -sticky ne
    grid .sig.right -row 0 -column 2 -rowspan 3 -sticky n -padx 2 -ipadx 2
    
    grid .sig -row 2 -column 0 -padx 5 -columnspan 2
    
    sig::updateControlLayout
    
    sig::drawAxes
    
}

proc sig::swapAxes {} {
    if {$sig::displayMode=="iv"} {
        set sig::displayMode "vi" 
    } else {
        set sig::displayMode "iv"
    }
    sig::updateControlLayout
    sig::updateIndicator voltage
    sig::updateIndicator current
    sig::plotReference
}

proc sig::updateControlLayout {} {
    
    grid remove .sig.voltage.display
    grid remove .sig.voltage.zoomIn
    grid remove .sig.voltage.zoomOut
    
    grid remove .sig.current.display
    grid remove .sig.current.zoomIn
    grid remove .sig.current.zoomOut
    
    if {$sig::displayMode=="iv"} {
        #Current is the y-axis, voltage is the x-axis
        grid .sig.voltage.display -row 0 -column 1 -sticky we -columnspan 1
        grid .sig.voltage.zoomIn -row 0 -column 0 -sticky we
        grid .sig.voltage.zoomOut -row 0 -column 2 -sticky we
        .sig.voltage configure -text "X-Axis: Voltage"
        
        grid .sig.current.display -row 0 -column 0 -columnspan 2 -sticky we
        grid .sig.current.zoomIn -row 1 -column 0 -sticky we
        grid .sig.current.zoomOut -row 1 -column 1 -sticky we
        .sig.current configure -text "Y-Axis:\nCurrent"
        
        grid .sig.current -row 0 -column 0
        grid .sig.voltage -row 1 -column 1
    } else {
        #Voltage is the y-axis, current is the x-axis
        grid .sig.current.display -row 0 -column 1 -sticky we -columnspan 1
        grid .sig.current.zoomIn -row 0 -column 0 -sticky we
        grid .sig.current.zoomOut -row 0 -column 2 -sticky we
        .sig.current configure -text "X-Axis: Current"
        
        grid .sig.voltage.display -row 0 -column 0 -columnspan 2 -sticky we
        grid .sig.voltage.zoomIn -row 1 -column 0 -sticky we
        grid .sig.voltage.zoomOut -row 1 -column 1 -sticky we
        .sig.voltage configure -text "Y-Axis:\nVoltage"
        
        grid .sig.voltage -row 0 -column 0
        grid .sig.current -row 1 -column 1
    }
}

proc sig::moveGripper {x y} {
    
    #Pull the last x,y coordinates
	set prevX [lindex $sig::gripperStart 0]
	set prevY [lindex $sig::gripperStart 1]
	
	#Calculate the change in position of the gripper
	set deltaX [expr {$x-$prevX}]
	set deltaY [expr {$y-$prevY}]

	#Resize the graph area
	sig::resizeDisplay [expr {$sig::graphWidth+$deltaX}] [expr {$sig::graphHeight+$deltaY}]
	
	#Store the current gripper position for next time
	set sig::gripperStart [list $x $y]
    
}

proc sig::resizeDisplay {w h} {
	variable yAxisStart
	variable yAxisEnd
	variable xAxisStart
	variable xAxisEnd
	variable displayMode
	
	#Save the new geometry
	set sig::graphWidth $w
	set sig::graphHeight $h
	
	#Make sure we don't make the graph too small
	if {$sig::graphWidth < $sig::minimumGraphWidth} {
		set sig::graphWidth $sig::minimumGraphWidth
	}
	if {$sig::graphHeight < $sig::minimumGraphHeight} {
		set sig::graphHeight $sig::minimumGraphHeight
	}
	
	#Make sure the display is square
	if {$sig::graphHeight!=$sig::graphWidth} {
		set sig::graphWidth $sig::graphHeight
	}

	#Resize the signature canvas
	.sig.display configure -width $sig::graphWidth -height $sig::graphHeight
	
	#Resize the plot area
	set yAxisEnd [expr {$sig::graphHeight-$sig::bottomMargin}]
	set newEnd [expr {$sig::graphWidth-$sig::rightMargin}]
	set deltaWidth [expr {$newEnd-$xAxisEnd}]
	set xAxisEnd $newEnd
	
	#Redraw the axes
	sig::drawAxes
	
    if {$sig::referenceActive} {
        sig::plotReference
    }
    
	#Remove the traces - they will be redrawn on the next sample update
	#display::clearDisplay

}

proc sig::plotData {} {
    
    
    #Make sure signature analysis mode is enabled
	if {$::opMode != "Signature"} {return}
    
    #Make sure the display exists (sometimes we can receive data while the signature analysis GUI is being constructed)
    if {![winfo exists .sig.display]} {return}
	
	#Remove the previous trace
	.sig.display delete sigPlotTag
	
	#Get the current scope data
	set dataA [lindex $scope::scopeData 0]
	set dataB [lindex $scope::scopeData 1]
    
    set voltageData {}
    set currentData {}
    
    if {$sig::displayMode=="iv"} {
        #X-Data created from channel A (voltage sense)
        set xData {}
        foreach datumA $dataA {
            set actualVoltage  [sig::convertSampleVoltage $datumA voltage]
            lappend voltageData $actualVoltage
            set numDiv [expr {$actualVoltage/[sig::getBoxSize voltage]}]
            set screenx [expr {$sig::xAxisStart+$numDiv*(($sig::xAxisEnd-$sig::xAxisStart)/10.0)+(($sig::xAxisEnd-$sig::xAxisStart)/2.0)}]
            lappend xData $screenx
        }
        #Y-Data created from channel B (current sense)
        set yData {}
        foreach datumB $dataB {
            set actualVoltage [sig::convertSampleVoltage $datumB current]
            lappend currentData $actualVoltage
            set numDiv [expr {$actualVoltage/[sig::getBoxSize current]}]
            set screeny [expr {$sig::yAxisStart+$numDiv*(($sig::yAxisEnd-$sig::yAxisStart)/-10.0)+(($sig::yAxisEnd-$sig::yAxisStart)/2.0)}]
            lappend yData $screeny
        }
    } else {
		#X-Data created from channel B (current sense)
        set xData {}
        foreach datumB $dataB {
            set actualVoltage  [sig::convertSampleVoltage $datumB current]
            lappend currentData $actualVoltage
            set numDiv [expr {$actualVoltage/[sig::getBoxSize current]}]
            set screenx [expr {$sig::xAxisStart+$numDiv*(($sig::xAxisEnd-$sig::xAxisStart)/10.0)+(($sig::xAxisEnd-$sig::xAxisStart)/2.0)}]
            lappend xData $screenx
        }
        #Y-Data created from channel A (voltage sense)
        set yData {}
        foreach datumA $dataA {
            set actualVoltage [sig::convertSampleVoltage $datumA voltage]
            lappend voltageData $actualVoltage
            set numDiv [expr {$actualVoltage/[sig::getBoxSize voltage]}]
            set screeny [expr {$sig::yAxisStart+$numDiv*(($sig::yAxisEnd-$sig::yAxisStart)/-10.0)+(($sig::yAxisEnd-$sig::yAxisStart)/2.0)}]
            lappend yData $screeny
        }
    }
    
    set sig::sigData [list $voltageData $currentData]
	
	#Build the X-Y trace data array
	set plotData {}
	foreach xDatum $xData yDatum $yData {
		lappend plotData $xDatum $yDatum
	}
	
	#Draw the X-Y trace
	.sig.display create line	\
		$plotData		\
		-tag sigPlotTag	\
		-fill black
    
    sig::autoMeasurements
    
}

proc sig::loadReference {} {
    
    #Get the save file
	set types {
		{{CSV Files} {.csv}}
	}
	
	set dataFile [tk_getOpenFile	\
		-filetypes $types	\
		-defaultextension .csv]
		
	if {$dataFile == ""} {return}
	
	#Open the file for reading
	if {[catch {open $dataFile r} fileId]} {
		tk_messageBox	\
			-title "File I/O Error"	\
			-default ok	\
			-message "Unable to open file for reading:\n$dataFile"	\
			-type ok	\
			-icon error
		return
	}

	sig::loadReferenceCurve $fileId
    
}

proc sig::loadReferenceCurve {fileId} {

	#Column labels are on the first line
	set header [gets $fileId]
	
	set voltageData {}
    set currentData {}
	
    while {[gets $fileId line]>= 0} {
        set temp [split $line ","]
        lappend voltageData [lindex $temp 0]
        lappend currentData [lindex $temp 1]
    }
    set sig::referenceCurve [list $voltageData $currentData]
	
	close $fileId
	
	set sig::referenceActive 1
	
	sig::plotReference
	
}

proc sig::plotReference {} {
    
    #Make sure signature analysis mode is enabled
    if {$::opMode != "Signature"} {return}
    
	#Make sure the display exists (sometimes we can receive data while the signature analysis GUI is being constructed)
	if {![winfo exists .sig.display]} {return}
	
    #Make sure there is a reference waveform to display
    if {$sig::referenceCurve == {}} {return}
    
	#Remove the previous trace
	.sig.display delete sigRefTag
	    
    set voltageData [lindex $sig::referenceCurve 0]
    set currentData [lindex $sig::referenceCurve 1]
    
    if {$sig::displayMode=="iv"} {
        #X-Data created from channel A (voltage sense)
        set xData {}
        foreach datumV $voltageData {
            set numDiv [expr {$datumV/[sig::getBoxSize voltage]}]
            set screenx [expr {$sig::xAxisStart+$numDiv*(($sig::xAxisEnd-$sig::xAxisStart)/10.0)+(($sig::xAxisEnd-$sig::xAxisStart)/2.0)}]
            lappend xData $screenx
        }
        #Y-Data created from channel B (current sense)
        set yData {}
        foreach datumI $currentData {
            set numDiv [expr {$datumI/[sig::getBoxSize current]}]
            set screeny [expr {$sig::yAxisStart+$numDiv*(($sig::yAxisEnd-$sig::yAxisStart)/-10.0)+(($sig::yAxisEnd-$sig::yAxisStart)/2.0)}]
            lappend yData $screeny
        }
    } else {
		#X-Data created from channel B (current sense)
        set xData {}
        foreach datumI $currentData {
            set numDiv [expr {$datumI/[sig::getBoxSize current]}]
            set screenx [expr {$sig::xAxisStart+$numDiv*(($sig::xAxisEnd-$sig::xAxisStart)/10.0)+(($sig::xAxisEnd-$sig::xAxisStart)/2.0)}]
            lappend xData $screenx
        }
        #Y-Data created from channel A (voltage sense)
        set yData {}
        foreach datumV $voltageData {
            set numDiv [expr {$datumV/[sig::getBoxSize voltage]}]
            set screeny [expr {$sig::yAxisStart+$numDiv*(($sig::yAxisEnd-$sig::yAxisStart)/-10.0)+(($sig::yAxisEnd-$sig::yAxisStart)/2.0)}]
            lappend yData $screeny
        }
    }
    
	#Build the X-Y trace data array
	set plotData {}
	foreach xDatum $xData yDatum $yData {
		lappend plotData $xDatum $yDatum
	}
	
	#Draw the X-Y trace
	.sig.display create line	\
		$plotData		\
		-tag sigRefTag	\
		-fill red
    
}

proc sig::updateIndicator {channelName} {
	variable voltageValues
    variable currentValues
	variable voltageIndex
	variable currentIndex

	#Channel Specific Parameters
	switch $channelName {
        "current" {
            set channelColor $display::channelAColor
            set sensitivity [sig::formatAmplitude [sig::getBoxSize current] current]
            if $vertical::invertA {
				set inverted 1
			} else {
				set inverted 0
			}
            if {$vertical::couplingA == "DC"} {
				set coupling DC
			} else {
				set coupling AC
			}
            set probe [format "%.0d" [expr {round($vertical::scopeProbeA)}]]
			append probe "X"
            
            .sig.current.display delete sensitivity
            
            #Draw Arrows
            if {$sig::displayMode =="iv"} {
                .sig.current.display create line	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0-10}]	\
                    [expr {$sig::canvasSize/2.0}] 4	\
                    -width 2	\
                    -arrow last	\
                    -fill $channelColor	\
                    -tag sensitivity
                .sig.current.display create line	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0+10}]	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize-1}]	\
                    -width 2	\
                    -arrow last	\
                    -fill $channelColor	\
                    -tag sensitivity
            } else {
                .sig.current.display create line	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0+10}]	\
                    4 [expr {$sig::canvasSize/2.0+10}]	\
                    -width 2	\
                    -arrow last	\
                    -fill $channelColor	\
                    -tag sensitivity
                .sig.current.display create line	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0+10}]	\
                    [expr {$sig::canvasSize-1}] [expr {$sig::canvasSize/2.0+10}]	\
                    -width 2	\
                    -arrow last	\
                    -fill $channelColor	\
                    -tag sensitivity
            }
            
            
            #Update the Sensitivity
            .sig.current.display create text	\
                [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0}]	\
                -anchor center	\
                -text $sensitivity	\
                -fill $channelColor	\
                -font {-weight bold -size -12}	\
                -tag sensitivity
                
            #Update the inverted symbol
            .sig.current.display delete invertedSymbol
            if $inverted {
                .sig.current.display create oval	\
                    [expr {$sig::canvasSize/2.0+10}] [expr {$sig::canvasSize/2.0+10}]	\
                    [expr {$sig::canvasSize/2.0+30}] [expr {$sig::canvasSize/2.0+30}]	\
                    -fill yellow	\
                    -outline black	\
                    -width 2	\
                    -tag invertedSymbol
                .sig.current.display create text	\
                    [expr {$sig::canvasSize/2.0+20}] [expr {$sig::canvasSize/2.0+20}]	\
                    -anchor center	\
                    -fill black	\
                    -text "I"	\
                    -font {-weight bold -size -12}	\
                    -tag invertedSymbol
            }
            
            #Update the AC/DC symbol
            .sig.current.display delete couplingSymbol
            .sig.current.display create text	\
                [expr {$sig::canvasSize/2.0+20}] [expr {$sig::canvasSize/2.0-20}]	\
                -anchor center	\
                -fill black	\
                -text $coupling	\
                -font {-weight bold -size -12}	\
                -tag couplingSymbol
                
            #Update the probe indicator
            .sig.current.display delete probeSymbol
            .sig.current.display create text	\
                [expr {$sig::canvasSize/2.0-20}] [expr {$sig::canvasSize/2.0-20}]	\
                -anchor center	\
                -fill black	\
                -text $probe	\
                -font {-weight bold -size -10}	\
                -tag probeSymbol
        } "voltage" {
			set channelColor $display::channelBColor
            set sensitivity [sig::formatAmplitude [sig::getBoxSize voltage] voltage]
			if $vertical::invertB {
				set inverted 1
			} else {
				set inverted 0
			}
			if {$vertical::couplingB == "DC"} {
				set coupling DC
			} else {
				set coupling AC
			}
			set probe [format "%.0d" [expr {round($vertical::scopeProbeB)}]]
			append probe "X"
            
            .sig.voltage.display delete sensitivity
	
            #Draw Arrows
            if {$sig::displayMode == "vi"} {
                .sig.voltage.display create line	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0-10}]	\
                    [expr {$sig::canvasSize/2.0}] 4	\
                    -width 2	\
                    -arrow last	\
                    -fill $channelColor	\
                    -tag sensitivity
                .sig.voltage.display create line	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0+10}]	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize-1}]	\
                    -width 2	\
                    -arrow last	\
                    -fill $channelColor	\
                    -tag sensitivity
            } else {
                .sig.voltage.display create line	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0+10}]	\
                    4 [expr {$sig::canvasSize/2.0+10}]	\
                    -width 2	\
                    -arrow last	\
                    -fill $channelColor	\
                    -tag sensitivity
                .sig.voltage.display create line	\
                    [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0+10}]	\
                    [expr {$sig::canvasSize-1}] [expr {$sig::canvasSize/2.0+10}]	\
                    -width 2	\
                    -arrow last	\
                    -fill $channelColor	\
                    -tag sensitivity
            }
            
            
            #Update the Sensitivity
            .sig.voltage.display create text	\
                [expr {$sig::canvasSize/2.0}] [expr {$sig::canvasSize/2.0}]	\
                -anchor center	\
                -text $sensitivity	\
                -fill $channelColor	\
                -font {-weight bold -size -12}	\
                -tag sensitivity
                
            #Update the inverted symbol
            .sig.voltage.display delete invertedSymbol
            if $inverted {
                .sig.voltage.display create oval	\
                    [expr {$sig::canvasSize/2.0+10}] [expr {$sig::canvasSize/2.0+10}]	\
                    [expr {$sig::canvasSize/2.0+30}] [expr {$sig::canvasSize/2.0+30}]	\
                    -fill yellow	\
                    -outline black	\
                    -width 2	\
                    -tag invertedSymbol
                .sig.voltage.display create text	\
                    [expr {$sig::canvasSize/2.0+20}] [expr {$sig::canvasSize/2.0+20}]	\
                    -anchor center	\
                    -fill black	\
                    -text "I"	\
                    -font {-weight bold -size -12}	\
                    -tag invertedSymbol
            }
            
            #Update the AC/DC symbol
            .sig.voltage.display delete couplingSymbol
            .sig.voltage.display create text	\
                [expr {$sig::canvasSize/2.0+20}] [expr {$sig::canvasSize/2.0-20}]	\
                -anchor center	\
                -fill black	\
                -text $coupling	\
                -font {-weight bold -size -12}	\
                -tag couplingSymbol
                
            #Update the probe indicator
            .sig.voltage.display delete probeSymbol
            .sig.voltage.display create text	\
                [expr {$sig::canvasSize/2.0-20}] [expr {$sig::canvasSize/2.0-20}]	\
                -anchor center	\
                -fill black	\
                -text $probe	\
                -font {-weight bold -size -10}	\
                -tag probeSymbol
		}
	}
}

proc sig::adjustVoltage {dir} {
	variable voltageIndex

	switch $dir {
		"in" {
            set voltageIndex [expr {$voltageIndex - 1}]
            if {$voltageIndex < 0} {set voltageIndex 0}
		} "out" {
			incr voltageIndex
			if {$voltageIndex > [expr [llength $sig::voltageValues]-1]} {
				set voltageIndex [expr [llength $sig::voltageValues]-1]
			}
		}
	}

	sig::updateIndicator voltage
    sig::plotReference

}

proc sig::adjustCurrent {dir} {
	variable currentIndex

	switch $dir {
		"in" {
            set currentIndex [expr {$currentIndex - 1}]
            if {$currentIndex < 0} {set currentIndex 0}
		} "out" {
			incr currentIndex
			if {$currentIndex > [expr [llength $sig::currentValues]-1]} {
				set currentIndex [expr [llength $sig::currentValues]-1]
			}
		}
	}

	sig::updateIndicator current
    sig::plotReference
}

proc sig::convertSampleVoltage {sample channel} {

	if {$channel=="current"} {
		#Convert the sample value to a voltage value using the current vertical scale
		set sampleValue [expr {($sample-1023)*[getStepSize current]}]
	} else {
		set sampleValue [expr {(1023-$sample)*[getStepSize voltage]}]
	}

	return $sampleValue
}

proc sig::getStepSize {channel} {
	switch $channel {
		"current" {
			return $sig::currentStepSize
		} "voltage" {
			return $sig::voltageStepSize
		}
	}
}

proc sig::getBoxSize {channelName} {

	if {$channelName=="current"} {
		return [expr {$vertical::scopeProbeA*[lindex $sig::currentValues $sig::currentIndex]}]
	} else {
		return [expr {$vertical::scopeProbeB*[lindex $sig::voltageValues $sig::voltageIndex]}]
	}
}

proc sig::drawAxes {} {
	
	#Remove the old axes
	.sig.display delete axis
	
	#Draw the X-Axis
	.sig.display create line	\
		$sig::xAxisStart $sig::yAxisEnd	\
		$sig::xAxisEnd $sig::yAxisEnd	\
		-tag axis	\
		-fill $sig::axisColor
	.sig.display create line	\
		$sig::xAxisStart $sig::yAxisStart	\
		$sig::xAxisEnd $sig::yAxisStart	\
		-tag axis	\
		-fill $sig::axisColor
		
	#Draw the Y-Axis
	.sig.display create line	\
		$sig::xAxisStart $sig::yAxisStart	\
		$sig::xAxisStart $sig::yAxisEnd	\
		-tag axis	\
		-fill $sig::axisColor
	.sig.display create line	\
		$sig::xAxisEnd $sig::yAxisStart	\
		$sig::xAxisEnd $sig::yAxisEnd	\
		-tag axis	\
		-fill $sig::axisColor
		
	#Draw the X-Grid
	.sig.display delete xAxisGrid
	if {$sig::xGridEnabled} {
		for {set i 1} {$i <10} {incr i} {
			set x [expr {$sig::xAxisStart + ($i/10.0)*($sig::xAxisEnd-$sig::xAxisStart)}]
			.sig.display create line	\
				$x $sig::yAxisStart	\
				$x $sig::yAxisEnd	\
				-tag xAxisGrid	\
				-fill $sig::xGridColor	\
				-dash .
		}
	}
	
	#Draw the Y-Grid
	.sig.display delete yAxisGrid
	if {$sig::yGridEnabled} {
		for {set i 1} {$i < 10} {incr i} {
			set y [expr {$sig::yAxisStart + ($i/10.0)*($sig::yAxisEnd-$sig::yAxisStart)}]
			.sig.display create line	\
				$sig::xAxisStart $y	\
				$sig::xAxisEnd $y	\
				-tag yAxisGrid	\
				-fill $sig::yGridColor	\
				-dash .
		}
	}
	
	#Draw y-axes and minor tick marks
	if {$sig::xGridEnabled} {
		.sig.display create line	\
			[expr {$sig::xAxisStart+($sig::xAxisEnd-$sig::xAxisStart)/2.0}] $sig::yAxisStart	\
			[expr {$sig::xAxisStart+($sig::xAxisEnd-$sig::xAxisStart)/2.0}] $sig::yAxisEnd	\
			-tag xAxisGrid	\
			-fill $sig::xGridColor	
		set tickLeft [expr {$sig::xAxisStart+($sig::xAxisEnd-$sig::xAxisStart)/2.0-($sig::xAxisEnd-$sig::xAxisStart)/100.0}]
		set tickRight [expr {$sig::xAxisStart+($sig::xAxisEnd-$sig::xAxisStart)/2.0+($sig::xAxisEnd-$sig::xAxisStart)/100.0}]
		for {set i 1} {$i < 50} {incr i} {
			.sig.display create line	\
				$tickLeft [expr {$sig::yAxisStart+($sig::yAxisEnd-$sig::yAxisStart)/50.0*$i}]	\
				$tickRight [expr {$sig::yAxisStart+($sig::yAxisEnd-$sig::yAxisStart)/50.0*$i}]	\
				-fill $sig::xGridColor	\
				-tag xAxisGrid
		}
	}
	
	#Draw x-axes and minor tick marks
	if {$sig::yGridEnabled} {
		.sig.display create line	\
			$sig::xAxisStart [expr {$sig::yAxisStart+($sig::yAxisEnd-$sig::yAxisStart)/2.0}]	\
			$sig::xAxisEnd [expr {$sig::yAxisStart+($sig::yAxisEnd-$sig::yAxisStart)/2.0}]	\
			-tag yAxisGrid	\
			-fill $sig::yGridColor	
		set tickTop [expr {$sig::yAxisStart+($sig::yAxisEnd-$sig::yAxisStart)/2.0-($sig::yAxisEnd-$sig::yAxisStart)/100.0}]
		set tickBottom [expr {$sig::yAxisStart+($sig::yAxisEnd-$sig::yAxisStart)/2.0+($sig::yAxisEnd-$sig::yAxisStart)/100.0}]
		for {set i 1} {$i < 50} {incr i} {
			.sig.display create line	\
				[expr {$sig::xAxisStart+($sig::xAxisEnd-$sig::xAxisStart)/50.0*$i}] $tickTop \
				[expr {$sig::xAxisStart+($sig::xAxisEnd-$display::xAxisStart)/50.0*$i}] $tickBottom	\
				-fill $sig::yGridColor	\
				-tag yAxisGrid
		}
	}

}

proc sig::formatAmplitude {amp type} {

    if {$type == "voltage"} {
       if {$amp < 1} {
            set temp [format "%.0f" [expr {$amp*1.0/0.001}]]
            return "$temp mV"
        } else {
            set temp [format "%.1f" $amp]
            return "$amp V"
        } 
    } else {
        if {$amp < 0.001} {
            set temp [format "%.0f" [expr {$amp*1.0/0.000001}]]
            return "$temp uA"
        } else {
            set temp [format "%.0f" [expr {$amp*1.0/0.001}]]
            return "$temp mA"
        }
        
    }
	
}

proc sig::selectDevice {deviceType} {
    
    #Make sure waveform sine wave output is selected
    sendCommand "WW0";
    sendCommand "WR";
    set wave::currentWaveform "sine"
            
    #Deselect all the buttons
    .sig.right.device.resistor configure -background LightGrey
    .sig.right.device.capacitor configure -background LightGrey
    .sig.right.device.inductor configure -background LightGrey
    .sig.right.device.diode configure -background LightGrey
    
    #Remove all device controls
    grid forget .sig.right.resistor
    grid forget .sig.right.capacitor
    grid forget .sig.right.inductor
    grid forget .sig.right.diode
    
    switch $deviceType {
        "resistor" {
            .sig.right.device.resistor configure -background red
            #Place the resistor controls
            grid .sig.right.resistor -row 1 -column 0
            sig::autoResistor
        } "capacitor" {
            .sig.right.device.capacitor configure -background red
            #Place the capacitor controls
            grid .sig.right.capacitor -row 1 -column 0
            update
            sig::selectCapacitorPreset
        } "inductor" {
            .sig.right.device.inductor configure -background red
            #Place the inductor controls
            grid .sig.right.inductor -row 1 -column 0
            update
            sig::selectInductorPreset
        } "diode" {
            .sig.right.device.diode configure -background red
            #Place the diode controls
            grid .sig.right.diode -row 1 -column 0
            update
            sig::selectDiodePreset
        }
    }
    
    set sig::deviceMode $deviceType
}

proc sig::autoResistor {} {
    #Waveform generator amplitude
    .sig.right.resistor.amplitude.slider set 80
    #Waveform generator frequency
    wave::sendFrequency 500
    #Set timebase to 2 ms
    set timebase::newTimebaseIndex 10
    timebase::adjustTimebase update
    #Set offset to zero
    wave::adjustOffset 0
    #Set voltage scale to 2V/div
    set sig::voltageIndex 7
    sig::updateIndicator voltage
}

proc sig::selectCapacitorPreset {} {
    set wave::maxFrequency 100E3
    set wave::minFrequency 1
    
    .sig.right.capacitor.amplitude.slider set 30
    .sig.right.capacitor.offset.slider set 0
    
    switch $sig::capPreset {
        "<100nF" {
            set wave::waveFrequency 100E3
        } "100nF-1uF" {
            set wave::waveFrequency 10E3
        } "1uF-10uF" {
            set wave::waveFrequency 1000
        } "10uF-100uF" {
            set wave::waveFrequency 100
        } ">100uF" {
            set wave::waveFrequency 1
        }
    }
    wave::sendFrequency $wave::waveFrequency
    sig::adjustTimebase 0
    set wave::frequencyDisplay "$wave::waveFrequency Hz"
}

proc sig::selectInductorPreset {} {
    set wave::maxFrequency 100E3
    set wave::minFrequency 1
    
    .sig.right.inductor.amplitude.slider set 30
    .sig.right.inductor.offset.slider set 0

    switch $sig::indPreset {
        "<100uH" {
            set wave::waveFrequency 100E3
        } "100uH-1mH" {
            set wave::waveFrequency 10E3
        } ">1mH" {
            set wave::waveFrequency 1000
        }
    }
    wave::sendFrequency $wave::waveFrequency
    sig::adjustTimebase 0
    set wave::frequencyDisplay "$wave::waveFrequency Hz"
}

proc sig::selectDiodePreset {} {
    
    .sig.right.capacitor.offset.slider set 0
    
    set wave::waveFrequency 100
    wave::sendFrequency $wave::waveFrequency
    #Set timebase to 5 ms
    set timebase::newTimebaseIndex 12
    timebase::adjustTimebase update
    
    switch $sig::diodePreset {
        "Small Signal +/-1V" {
            .sig.right.diode.amplitude.slider set 10
        } "Power +/-2V" {
            .sig.right.diode.amplitude.slider set 20
        } "Zener +/-10V" {
            .sig.right.diode.amplitude.slider set 100
        }
    }
}

proc sig::adjustTimebase {dummy} {
    
    if {$wave::waveFrequency > 50E3} {
        set timebase::newTimebaseIndex 3
    } elseif {$wave::waveFrequency > 5E3} {
        set timebase::newTimebaseIndex 6
    } elseif {$wave::waveFrequency > 500} {
        set timebase::newTimebaseIndex 9
    } elseif {$wave::waveFrequency > 50} {
        set timebase::newTimebaseIndex 12
    } else {
        set timebase::newTimebaseIndex 14
    }
    timebase::adjustTimebase update
}

proc sig::showCal {} {
    #Create a new window for the calibration controls
	if {[winfo exists .sigCal]} {
		raise .sigCal
		return
	}
	toplevel .sigCal
	wm title .sigCal "Signature Analyzer Calibration"

    labelframe .sigCal.voltage  \
        -text "Voltage"
    
    scale .sigCal.voltage.slider    \
        -from 9 \
        -to 15  \
        -orient horizontal   \
        -length 300 \
        -tickinterval 1.0   \
        -resolution 0.01    \
        -showvalue 1    \
        -variable sig::voltageSliderValue   \
        -command sig::adjustVoltageCal
    set sig::voltageSliderValue [expr {$sig::voltageStepSize/1E-3}]
    
    grid .sigCal.voltage.slider -row 0 -column 0
    
	labelframe .sigCal.current  \
        -text "Current"
    
    scale .sigCal.current.slider    \
        -from 40    \
        -to 70      \
        -orient horizontal    \
        -length 300 \
        -tickinterval 5 \
        -resolution 0.1 \
        -showvalue 1    \
        -variable sig::currentSliderValue   \
        -command sig::adjustCurrentCal
    set sig::currentSliderValue [expr {$sig::currentStepSize/1.0E-6}]
    
    grid .sigCal.current.slider -row 0 -column 0
    
    button .sigCal.saveButton   \
        -text "Save Calibration"    \
        -command sig::saveCal
    
    button .sigCal.exit \
        -text "Close"   \
        -command {destroy .sigCal}
    
    grid .sigCal.voltage -row 0 -column 0 -pady 5
    grid .sigCal.current -row 1 -column 0 -pady 5
    grid .sigCal.saveButton -row 2 -column 0 -pady 5 -sticky we
    grid .sigCal.exit -row 3 -column 0 -pady 5 -sticky we
}

proc sig::adjustCurrentCal {sliderArg} {
    variable currentStepSize
    
    set currentStepSize [expr {$sliderArg*1.0E-6}]
}

proc sig::adjustVoltageCal {sliderArg} {
    variable voltageStepSize
    
    set voltageStepSize [expr {$sliderArg*1.0E-3}]
}

proc sig::saveCal {} {
    
    cal::saveParameter $sig::voltageStepSize $::nvmAddressSigVoltage
    cal::saveParameter $sig::currentStepSize $::nvmAddressSigCurrent
    
    tk_messageBox	\
		-message "Configuration values saved."	\
		-type ok
        
}

proc sig::restoreCal {} {
    
    set temp [cal::readParameter $::nvmAddressSigVoltage]
	
	if {[string is double $temp]} {
		if {($temp >= 9.0E-3) && ($temp <= 15E-3)} {
			set sig::voltageStepSize $temp
			puts "Signature analyzer voltage calibration restored. $temp"
		} else {
			puts "Signature analyzer voltage calibration out of range! $temp"
		}
	} else {
		puts "Invalid signature analyzer voltage calibration: $temp"
	}
    
    set temp [cal::readParameter $::nvmAddressSigCurrent]
	
	if {[string is double $temp]} {
		if {($temp >= 40.0E-6) && ($temp <= 70E-6)} {
			set sig::currentStepSize $temp
			puts "Signature analyzer current calibration restored. $temp"
		} else {
			puts "Signature analyzer current calibration out of range! $temp"
		}
	} else {
		puts "Invalid signature analyzer current calibration: $temp"
	}
}

proc sig::formatResistance {resValue} {
    if {$resValue >= 1000} {
        set resValue [format "%.2f" [expr {$resValue/1000.0}]]
        return "$resValue k\u3A9"
    } else {
        set resValue [format "%.0f" [expr {$resValue}]]
        return "$resValue \u3A9"
    }
}

proc sig::formatCapacitance {capValue} {
    if {$capValue < 1.0E-6} {
        set capValue [format "%.3f" [expr {$capValue/1.0E-9}]]
        return "$capValue nF"
    } elseif {$capValue < 1.0E-3} {
        set capValue [format "%.3f" [expr {$capValue/1.0E-6}]]
        set capString "$capValue \u3BC"
        append capString "F"
        return $capString
    } else {
        set capValue [format "%.3f" [expr {$capValue/1.0E-3}]]
        return "$capValue mF"
    }
}

proc sig::formatInductance {indValue} {
    if {$indValue < 1.0E-6} {
        set indValue [format "%.3f" [expr {$indValue/1.0E-9}]]
        return "$indValue nH"
    } elseif {$indValue < 1.0E-3} {
        set indValue [format "%.3f" [expr {$indValue/1.0E-6}]]
        set indString "$indValue \u3BC"
        append indString "H"
        return $indString
    } else {
        set indValue [format "%.3f" [expr {$indValue/1.0E-3}]]
        return "$indValue mH"
    }
}

proc sig::autoMeasurements {} {
    
    switch $sig::deviceMode {
        "resistor" {
            set slope [math::statistics::linear-model [lindex $sig::sigData 0] [lindex $sig::sigData 1] 1]
            set slope [lindex $slope 1]
            set slope [expr {1.0/$slope}]
            set sig::resValue [sig::formatResistance $slope]
        } "capacitor" {
            if {!$sig::measureEnable} {return}
            
            set freq $wave::waveFrequency
            #Create the reference sine wave for this frequency
            sig::createSineRef $freq
            #Create the reference cosine wave for this frequency
            sig::createCosRef $freq
            #Retrieve data from scope and convert it
            set dataA [lindex $sig::sigData 0]
            set dataB [lindex $sig::sigData 1]
            
            #Components for Channel A
            set eii [net::multiplyWaveforms $dataA $sig::sineRef]
            set iPhaseA [net::integrateWaveform $eii]
            
            set eiq [net::multiplyWaveforms $dataA $sig::cosRef]
            set qPhaseA [net::integrateWaveform $eiq]
            
            #Calculate magnitude
            set magA [expr {(2.0)*sqrt(pow($iPhaseA,2)+pow($qPhaseA,2))}]
            
            #Calculate phase
            set radA [expr {atan2($qPhaseA,$iPhaseA)}]
            set degA [expr {$radA/$net::pi*180.0}]
        
            #Components for Channel B
            set eii [net::multiplyWaveforms $dataB $sig::sineRef]
            set iPhaseB [net::integrateWaveform $eii]
            
            set eiq [net::multiplyWaveforms $dataB $sig::cosRef]
            set qPhaseB [net::integrateWaveform $eiq]
        
            #Calculate magnitude
            set magB [expr {(2.0)*sqrt(pow($iPhaseB,2)+pow($qPhaseB,2))}]
            
            #Calculate phase
            set radB [expr {atan2($qPhaseB,$iPhaseB)}]
            set degB [expr {$radB/$net::pi*180.0}]
        
            #Calculate the overall phase response
            set phase [expr {$degB-$degA}]
            #if {$phase < 0} {set phase [expr {360.0 + $phase}]}
            
            #Find maximum voltage value
            set voltageMax [math::statistics::max $dataA]
            set voltageMin [math::statistics::min $dataA]
            set voltage [expr {$voltageMax-$voltageMin}]
            set currentMax [math::statistics::max $dataB]
            set currentMin [math::statistics::min $dataB]
            set current [expr {$currentMax-$currentMin}]
            #puts "Voltage: $voltage Current: $current Phase: $phase"
            
            #Calculate the resistive and reactive components
            set resistiveCurrent [expr {$current*cos($net::pi*$phase/180.0)}]
            set parallelResistance [expr {$voltage/$resistiveCurrent}]
            set reactiveCurrent [expr {$current*sin($net::pi*$phase/180.0)}]
            set parallelReactance [expr {$voltage/$reactiveCurrent}]
            set parallelCapacitance [expr {1.0/(2*$net::pi*$freq*$parallelReactance)}]
            set qp [expr {$parallelResistance/$parallelReactance}]
            set seriesResistance [expr {$parallelResistance/(pow($qp,2)+1)}]
            set seriesReactance [expr {$parallelReactance/(1+1/(pow($qp,2)))}]
            set seriesCapacitance [expr {1.0/(2*$net::pi*$freq*$seriesReactance)}]
            #puts "Phase $phase\nVoltage $voltage Current $current\nResistance $parallelResistance Capacitance $capacitance"
            
            if {$sig::capMode == "parallel"} {
                set sig::capResValue [sig::formatResistance $parallelResistance]
                set sig::capCapValue [sig::formatCapacitance $parallelCapacitance]
            } else {
                set sig::capResValue [sig::formatResistance $seriesResistance]
                set sig::capCapValue [sig::formatCapacitance $seriesCapacitance]
            }
            
        } "inductor" {
			if {!$sig::measureEnable} {return}
            
            set freq $wave::waveFrequency
            #Create the reference sine wave for this frequency
            sig::createSineRef $freq
            #Create the reference cosine wave for this frequency
            sig::createCosRef $freq
            #Retrieve data from scope and convert it
            set dataA [lindex $sig::sigData 0]
            set dataB [lindex $sig::sigData 1]
            
            #Components for Channel A
            set eii [net::multiplyWaveforms $dataA $sig::sineRef]
            set iPhaseA [net::integrateWaveform $eii]
            
            set eiq [net::multiplyWaveforms $dataA $sig::cosRef]
            set qPhaseA [net::integrateWaveform $eiq]
            
            #Calculate magnitude
            set magA [expr {(2.0)*sqrt(pow($iPhaseA,2)+pow($qPhaseA,2))}]
            
            #Calculate phase
            set radA [expr {atan2($qPhaseA,$iPhaseA)}]
            set degA [expr {$radA/$net::pi*180.0}]
        
            #Components for Channel B
            set eii [net::multiplyWaveforms $dataB $sig::sineRef]
            set iPhaseB [net::integrateWaveform $eii]
            
            set eiq [net::multiplyWaveforms $dataB $sig::cosRef]
            set qPhaseB [net::integrateWaveform $eiq]
        
            #Calculate magnitude
            set magB [expr {(2.0)*sqrt(pow($iPhaseB,2)+pow($qPhaseB,2))}]
            
            #Calculate phase
            set radB [expr {atan2($qPhaseB,$iPhaseB)}]
            set degB [expr {$radB/$net::pi*180.0}]
        
            #Calculate the overall phase response
            set phase [expr {$degA-$degB}]
            #if {$phase < 0} {set phase [expr {360.0 + $phase}]}
            
            #Find maximum voltage value
            set voltageMax [math::statistics::max $dataA]
            set voltageMin [math::statistics::min $dataA]
            set voltage [expr {$voltageMax-$voltageMin}]
            set currentMax [math::statistics::max $dataB]
            set currentMin [math::statistics::min $dataB]
            set current [expr {$currentMax-$currentMin}]
            puts "Voltage: $voltage Current: $current Phase: $phase"
            
            #Calculate the resistive and reactive components
            set resistiveCurrent [expr {$current*cos($net::pi*$phase/180.0)}]
            set parallelResistance [expr {$voltage/$resistiveCurrent}]
            set reactiveCurrent [expr {$current*sin($net::pi*$phase/180.0)}]
            set parallelReactance [expr {$voltage/$reactiveCurrent}]
            set parallelInductance [expr {$parallelReactance/(2*$net::pi*$freq)}]
            set qp [expr {$parallelResistance/$parallelReactance}]
            set seriesResistance [expr {$parallelResistance/(pow($qp,2)+1)}]
            set seriesReactance [expr {$parallelReactance/(1+1/(pow($qp,2)))}]
            set seriesInductance [expr {$seriesReactance/(2*$net::pi*$freq)}]
            #puts "Phase $phase\nVoltage $voltage Current $current\nResistance $parallelResistance Capacitance $capacitance"
            
            if {$sig::capMode == "parallel"} {
                set sig::capResValue [sig::formatResistance $parallelResistance]
                set sig::indIndValue [sig::formatInductance $parallelInductance]
            } else {
                set sig::capResValue [sig::formatResistance $seriesResistance]
                set sig::indIndValue [sig::formatInductance $seriesInductance]
            }
		}
    }
}

proc sig::createSineRef {freq} {

	set sampleDepth 1024

	set sig::sineRef {}
	
	set tStep [expr {1.0/[timebase::getSamplingRate]}]
	
	for {set i 0} {$i < $sampleDepth} {incr i} {
		set t [expr {$i*$tStep}]
		set temp [expr {sin(2*$net::pi*$freq*$t)}]
		lappend sig::sineRef $temp
	}
}

proc sig::createCosRef {freq} {

	set sampleDepth 1024

	set sig::cosRef {}
	
	set tStep [expr {1.0/[timebase::getSamplingRate]}]
	
	for {set i 0} {$i < $sampleDepth} {incr i} {
		set t [expr {$i*$tStep}]
		set temp [expr {cos(2*$net::pi*$freq*$t)}]
		lappend sig::cosRef $temp
	}
}

proc sig::measureFrequency {} {

	set dataA [lindex $sig::sigData 0]
	
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

#Different menu bar for signature analyzer
frame .sigmenu -relief raised -borderwidth 1

#File Menu
menu .menubar.file.sigFileMenu -tearoff 0
.menubar.file.sigFileMenu add command	\
	-label "Save Settings"	\
	-command sig::saveSettings
.menubar.file.sigFileMenu add command 	\
	-label "Load Settings"	\
	-command sig::loadSettings
.menubar.file.sigFileMenu add separator
.menubar.file.sigFileMenu add command	\
	-label "Exit"	\
	-command {destroy .}

#View Menu
menu .menubar.scopeView.sigViewMenu -tearoff 0
if {$osType == "windows"} {
	.menubar.scopeView.sigViewMenu add command	\
		-label "Debug Console"	\
		-command {console show}
	.menubar.scopeView.sigViewMenu add separator
}

#Tools Menu
menu .menubar.tools.sigToolsMenu -tearoff 0
.menubar.tools.sigToolsMenu add command	\
	-label "Export CSV..."	\
	-command export::exportCSV
.menubar.tools.sigToolsMenu add separator
.menubar.tools.sigToolsMenu add command	\
	-label "Load CSV..."	\
	-command sig::loadReference
.menubar.tools.sigToolsMenu add command \
    -label "Clear Reference"    \
    -command {set sig::referenceActive 0}
.menubar.tools.sigToolsMenu add separator
.menubar.tools.sigToolsMenu add command \
    -label "Calibration..." \
    -command sig::showCal

#Hardware Menu
menu .menubar.hardware.sigHardwareMenu -tearoff 0
#Selector for CircuitGear Mode
.menubar.hardware.sigHardwareMenu add check	\
	-label "CircuitGear Mode"	\
	-variable opMode			\
	-onvalue "CircuitGear"		\
	-command net::toggleOpMode
#Selector for Network Analyzer Mode
.menubar.hardware.sigHardwareMenu add check	\
	-label "Network Analyzer Mode"	\
	-variable opMode			\
	-onvalue "Netalyzer"		\
	-command net::toggleOpMode

#Help Menu
menu .menubar.help.sigHelpMenu -tearoff 0
.menubar.help.sigHelpMenu add command	\
	-label "About"	\
	-command showAbout
.menubar.help.sigHelpMenu add separator
.menubar.help.sigHelpMenu add command	\
	-label "Manual (pdf)"	\
	-command showManual
.menubar.help.sigHelpMenu add separator
.menubar.help.sigHelpMenu add command	\
	-label "Change Log"	\
	-command showChangeLog

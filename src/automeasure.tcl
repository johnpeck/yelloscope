#File: automeasure.tcl
#Syscomp Unified CircuitGear GUI
#Scope Automatic Measurements

#JG
#Copyright 2015 Syscomp Electronic Design
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

package provide automeasure 1.0

namespace eval automeasure {

	set enableA(frequency) 0
	set enableB(frequency) 0

	set measurementEnable 0
	
	#Images
	set autoFrequency [image create photo -file $::images/AutoFrequency.gif]
	set autoAverage [image create photo -file $::images/AutoAverage.gif]
	set autoMax [image create photo -file $::images/AutoMax.gif]
	set autoMin [image create photo -file $::images/AutoMin.gif]
	set autoPkPk [image create photo -file $::images/AutoPkPk.gif]
	set autoRMS [image create photo -file $::images/AutoRMS.gif]

	set rawAverageA 0
	set rawAverageB 0
	
	set autoFrequencyA ?
	set autoPeriodA ?
	set autoFrequencyB ?
	set autoPeriodB ?
}

# automeasure::showMeasurements
#
# Builds the auto measurements window
proc automeasure::showMeasurements {} {

	#Check to see if the measurements window is already open
	if {[winfo exists .measurements]} {
		wm deiconify .measurements
		raise .measurements
		focus .measurements
		return
	}

	#Create the mesurements window
	toplevel .measurements
	wm resizable .measurements 0 0
	wm title .measurements "Measurements Window"
	wm protocol .measurements WM_DELETE_WINDOW {set automeasure::measurementEnable 0; destroy .measurements}
	
	#Create a frame for the auto measurements
	frame .measurements.auto	\
		-relief groove	\
		-borderwidth 2
		
	label .measurements.auto.autoLabel	\
	-text "Auto Measurements"	\
	-font {-weight bold -size 10}
	label .measurements.auto.aLabel	\
		-text "A"	\
		-font {-weight bold -size 10}
	label .measurements.auto.bLabel	\
		-text "B"	\
		-font {-weight bold -size 10}
	label .measurements.auto.mathLabel	\
		-text "Math"	\
		-font {-weight bold -size 10}

	label .measurements.auto.freqLabel	\
		-text "Frequency:"	\
		-width 12
	label .measurements.auto.freqA	\
		-relief sunken	\
		-textvariable automeasure::autoFrequencyA	\
		-width 12
	label .measurements.auto.freqB	\
		-relief sunken	\
		-textvariable automeasure::autoFrequencyB	\
		-width 12
	label .measurements.auto.freqMath	\
		-relief sunken	\
		-textvariable automeasure::autoFrequencyMath	\
		-width 12
	label .measurements.auto.freqImage	\
		-image $automeasure::autoFrequency

	label .measurements.auto.periodLabel	\
		-text "Period:"	\
		-width 12
	label .measurements.auto.periodA	\
		-relief sunken	\
		-textvariable automeasure::autoPeriodA	\
		-width 12
	label .measurements.auto.periodB	\
		-relief sunken	\
		-textvariable automeasure::autoPeriodB	\
		-width 12
	label .measurements.auto.periodMath	\
		-relief sunken	\
		-textvariable automeasure::autoPeriodMath	\
		-width 12
		
	label .measurements.auto.averageLabel	\
		-text "Average:"	\
		-width 12
	label .measurements.auto.averageA	\
		-relief sunken	\
		-textvariable automeasure::autoAverageA	\
		-width 12
	label .measurements.auto.averageB	\
		-relief sunken	\
		-textvariable automeasure::autoAverageB	\
		-width 12
	label .measurements.auto.averageMath	\
		-relief sunken	\
		-textvariable automeasure::autoAverageMath	\
		-width 12
	label .measurements.auto.averageImage	\
		-image $automeasure::autoAverage
		
	label .measurements.auto.maxLabel	\
		-text "Maximum:"	\
		-width 12
	label .measurements.auto.maxA	\
		-relief sunken	\
		-textvariable automeasure::autoMaxA	\
		-width 12
	label .measurements.auto.maxB	\
		-relief sunken	\
		-textvariable automeasure::autoMaxB	\
		-width 12
	label .measurements.auto.maxMath	\
		-relief sunken	\
		-textvariable automeasure::autoMaxMath	\
		-width 12
	label .measurements.auto.maxImage	\
		-image $automeasure::autoMax

	label .measurements.auto.minLabel	\
		-text "Minimum:"	\
		-width 12
	label .measurements.auto.minA	\
		-relief sunken	\
		-textvariable automeasure::autoMinA	\
		-width 12
	label .measurements.auto.minB	\
		-relief sunken	\
		-textvariable automeasure::autoMinB	\
		-width 12
	label .measurements.auto.minMath	\
		-relief sunken	\
		-textvariable automeasure::autoMinMath	\
		-width 12
	label .measurements.auto.minImage	\
		-image $automeasure::autoMin
		
	label .measurements.auto.pkPkLabel	\
		-text "Peak-Peak:"	\
		-width 12
	label .measurements.auto.pkPkA	\
		-relief sunken	\
		-textvariable automeasure::autoPkPkA	\
		-width 12
	label .measurements.auto.pkPkB	\
		-relief sunken	\
		-textvariable automeasure::autoPkPkB	\
		-width 12
	label .measurements.auto.pkPkMath	\
		-relief sunken	\
		-textvariable automeasure::autoPkPkMath	\
		-width 12
	label .measurements.auto.pkPkImage	\
		-image $automeasure::autoPkPk
		
	label .measurements.auto.rmsLabel	\
		-text "RMS:"	\
		-width 12
	label .measurements.auto.rmsA	\
		-relief sunken	\
		-textvariable automeasure::autoRMSA	\
		-width 12
	label .measurements.auto.rmsB	\
		-relief sunken	\
		-textvariable automeasure::autoRMSB	\
		-width 12
	label .measurements.auto.rmsMath	\
		-relief sunken	\
		-textvariable automeasure::autoRMSMath	\
		-width 12
	label .measurements.auto.rmsImage	\
		-image $automeasure::autoRMS

	grid .measurements.auto.autoLabel -row 0 -column 0 -columnspan 4
	grid .measurements.auto.aLabel -row 1 -column 1
	grid .measurements.auto.bLabel -row 1 -column 2

	grid .measurements.auto.freqLabel -row 2 -column 0
	grid .measurements.auto.freqA -row 2 -column 1
	grid .measurements.auto.freqB -row 2 -column 2
	grid .measurements.auto.freqImage -row 2 -column 4 -rowspan 2

	grid .measurements.auto.periodLabel -row 3 -column 0
	grid .measurements.auto.periodA -row 3 -column 1
	grid .measurements.auto.periodB -row 3 -column 2

	grid .measurements.auto.averageLabel -row 4 -column 0
	grid .measurements.auto.averageA -row 4 -column 1
	grid .measurements.auto.averageB -row 4 -column 2
	grid .measurements.auto.averageImage -row 4 -column 4

	grid .measurements.auto.maxLabel -row 5 -column 0
	grid .measurements.auto.maxA -row 5 -column 1
	grid .measurements.auto.maxB -row 5 -column 2
	grid .measurements.auto.maxImage -row 5 -column 4

	grid .measurements.auto.minLabel -row 6 -column 0
	grid .measurements.auto.minA -row 6 -column 1
	grid .measurements.auto.minB -row 6 -column 2
	grid .measurements.auto.minImage -row 6 -column 4

	grid .measurements.auto.pkPkLabel -row 7 -column 0
	grid .measurements.auto.pkPkA -row 7 -column 1
	grid .measurements.auto.pkPkB -row 7 -column 2
	grid .measurements.auto.pkPkImage -row 7 -column 4

	grid .measurements.auto.rmsLabel -row 8 -column 0
	grid .measurements.auto.rmsA -row 8 -column 1
	grid .measurements.auto.rmsB -row 8 -column 2
	grid .measurements.auto.rmsImage -row 8 -column 4
	
	grid .measurements.auto -row 0 -column 0
	
	set automeasure::measurementEnable 1

}

# automeasure::automeasure
#
# Service routine for auto measurements.
proc automeasure::automeasure {} {

	if {$automeasure::measurementEnable} {
		automeasure::averages
		automeasure::frequencies
		automeasure::amplitude A
		automeasure::amplitude B
		if {$cursor::timeCursorsEnable} {
			automeasure::autoRMSVoltage [lindex $scope::scopeData 0] a
			automeasure::autoRMSVoltage [lindex $scope::scopeData 1] b
		}
		
	}
	
}

# automeasure::averages
#
# Calculates the average voltage and A/D value for each of the input channels
proc automeasure::averages {} {
	
	#Extract the scope data arrays and current vertical scale settings
	set dataA [lindex $scope::scopeData 0]
	set verticalBox [vertical::getBoxSize A]
	set dataB [lindex $scope::scopeData 1]
	set verticalBox [vertical::getBoxSize B]

	#Calculate the average value of the waveforms
	set averageA 0
	set averageB 0
	set i 0
	foreach datumA $dataA datumB $dataB {
		set averageA [expr {$averageA+$datumA}]
		set averageB [expr {$averageB+$datumB}]
		incr i
	}
	set averageA [expr {$averageA*1.0/$i}]
	set averageB [expr {$averageB*1.0/$i}]
	
	set automeasure::autoAverageA [cursor::formatAmplitude [vertical::convertSampleVoltage $averageA A]]
	set automeasure::autoAverageB [cursor::formatAmplitude [vertical::convertSampleVoltage $averageB B]]
	
	set automeasure::rawAverageA $averageA
	set automeasure::rawAverageB $averageB

}

# automeasure::frequencies
#
# Computes the frequency and period for each of the input channels.
# Frequency is computed by identifying when the input signal
# crosses the average value of the input signal and looking at
# the time between crossings.
proc automeasure::frequencies {} {

	#Grab the scope data
	set dataA [lindex $scope::scopeData 0]
	set dataB [lindex $scope::scopeData 1]
	
	#Grab the average for each channel
	set averageA $automeasure::rawAverageA
	set averageB $automeasure::rawAverageB
	
	#Identify when the input signals cross their averages
	set prevCompA 0
	set prevCompB 0
	set compOutA {}
	set compOutB {}
	set upperThresholdA [expr {$averageA + 2}]
	set upperThresholdB [expr {$averageB + 2}]
	set lowerThresholdA [expr {$averageA - 2}]
	set lowerThresholdB [expr {$averageB - 2}]
	set i 0
	set crossingsA {}
	set crossingsB {}
	foreach datumA $dataA datumB $dataB {
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
		#Channel B Comparator
		if {($prevCompB == 0)} {
			if {$datumB > $upperThresholdB} {
				lappend compOutB 1
				set prevCompB 1
				lappend crossingsB $i
			} else {
				lappend compOutB 0
			}
		} else {
			if {$datumB < $lowerThresholdB} {
				lappend compOutB 0
				set prevCompB 0
			} else {
				lappend compOutB 1
			}
		}
		
		incr i
	}
	
	#Compute the frequency and period for channel A
	if {[llength $crossingsA] >= 3} {
	
		#Strip off the first crossing as it is an artifact of the hysterisis
		set crossingsA [lrange $crossingsA 1 end]
	
		#Determine the average number of samples between  average crossings
		set betweenCrossingsA 0
		for {set i 1} {$i < [llength $crossingsA]} {incr i} {
			set betweenCrossingsA [expr {$betweenCrossingsA + [expr [lindex $crossingsA $i] - [lindex $crossingsA [expr $i-1]]]}]
		}
		set betweenCrossingsA [expr {$betweenCrossingsA*1.0/[expr {[llength $crossingsA]-1}]}]
		
		#Determine the amount of time represented by the average  number of samples between average crossings
		set samplePeriod [timebase::getSamplingPeriod]
		set periodA [expr {$betweenCrossingsA*$samplePeriod}]
		set frequencyA [expr {1.0/$periodA}]
		
		#Format the results for display
		set frequencyA [cursor::formatFrequency $frequencyA 1]
		set periodA [cursor::formatTime $periodA]
	} else {
		#Not enough crossings to compute the frequency
		set frequencyA "? Hz"
		set periodA "? s"
	}
	
	#Compute the frequency and period for channel B
	if {[llength $crossingsB] >= 3} {
	
		#Strip off the first crossing as it is an artifact of the hysterisis
		set crossingsB [lrange $crossingsB 1 end]
	
		#Determine the average number of samples between  average crossings
		set betweenCrossingsB 0
		for {set i 1} {$i < [llength $crossingsB]} {incr i} {
			set betweenCrossingsB [expr {$betweenCrossingsB + [expr [lindex $crossingsB $i] - [lindex $crossingsB [expr $i-1]]]}]
		}
		set betweenCrossingsB [expr {$betweenCrossingsB*1.0/[expr {[llength $crossingsB]-1}]}]
		
		#Determine the amount of time represented by the average  number of samples between average crossings
		set samplePeriod [timebase::getSamplingPeriod]
		set periodB [expr {$betweenCrossingsB*$samplePeriod}]
		set frequencyB [expr {1.0/$periodB}]
		
		#Format the results for display
		set frequencyB [cursor::formatFrequency $frequencyB 1]
		set periodB [cursor::formatTime $periodB]
	} else {
		#Not enough crossings to compute the frequency
		set frequencyB "? Hz"
		set periodB "? s"
	}
	
	set automeasure::autoFrequencyA $frequencyA
	set automeasure::autoPeriodA $periodA
	set automeasure::autoFrequencyB $frequencyB
	set automeasure::autoPeriodB $periodB
}

# automeasure::amplitude
#
# Measures the signal amplitude for the channel specified by "src".
# Measured amplitudes are placed in the appropriate global variables
proc automeasure::amplitude {src} {

	#Grab the scope data
	if {$src == "A"} {
		set data [lindex $scope::scopeData 0]
		set verticalBox [vertical::getBoxSize A]
	} else {
		set data [lindex $scope::scopeData 1]
		set verticalBox [vertical::getBoxSize B]
	}
	
	#Calculate the average value of the waveform
	set maximum -5000
	set minimum 5000
	foreach datum $data {
		set voltage [vertical::convertSampleVoltage $datum $src]
		if {$voltage > $maximum} {
			set maximum $voltage
		}
		if {$voltage < $minimum} {
			set minimum $voltage
		}
	}
	set peakToPeak [expr {$maximum - $minimum}]
	set maximum [cursor::formatAmplitude $maximum]
	set minimum [cursor::formatAmplitude $minimum]
	set peakToPeak [cursor::formatAmplitude $peakToPeak]

	#Stick the value into the appropriate global variables
	if {$src == "A"} {
		set automeasure::autoMaxA $maximum
		set automeasure::autoMinA $minimum
		set automeasure::autoPkPkA $peakToPeak
	} else {
		set automeasure::autoMaxB $maximum
		set automeasure::autoMinB $minimum
		set automeasure::autoPkPkB $peakToPeak
	}

}

# automeasure::autoRMSVoltage
#
# Calculates the RMS voltage value of the input data for the given channel (src)
# The RMS voltage calculation is performed between the time cursors on the display.
proc automeasure::autoRMSVoltage {data src} {

	if {[llength $data] == 0} {return}

	#Make sure the cursors aren't on top of one another
	if {$cursor::t1Pos==$cursor::t2Pos} {
		return "?"
	}
	
	#Determine relative position of cursors to one another
	if {$cursor::t1Pos>$cursor::t2Pos} {
		set start $cursor::t2Pos
		set end $cursor::t1Pos
	} else {
		set start $cursor::t1Pos
		set end $cursor::t2Pos
	}
	
	#Determine the sample position of each cursor
	set startSample [cursor::screenXToSampleIndex $start]
	set endSample [cursor::screenXToSampleIndex $end]

	#Calculate mean and rms voltage
	set sum 0
	for {set i $startSample} {$i <= $endSample} {incr i} {
		set datum [lindex $data $i]
		if {$src != "math"} {
			set datum [vertical::convertSampleVoltage $datum $src]
		}
		set sum [expr {$sum+($datum*$datum)}]
	}
	set mean [expr {$sum/($endSample-$startSample)}]
	set rms [expr {sqrt($mean)}]
	set rms [cursor::formatAmplitude $rms]
	
	#Stick the rms value in the appropriate global variable
	if {$src == "a"} {
		set automeasure::autoRMSA $rms
	} elseif {$src == "b"} {
		set automeasure::autoRMSB $rms
	} elseif {$src == "math"} {
		set automeasure::autoRMSMath $rms
	}

}

#Add a menu item for the auto measurements
.menubar.scopeView.viewMenu add separator
.menubar.scopeView.viewMenu add command \
	-label "Auto Measurements"	\
	-command automeasure::showMeasurements

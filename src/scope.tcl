#File: scope.tcl
#Syscomp CircuitGear Mini Oscilloscope
#JG

#Copyright 2012 Syscomp Electronic Design
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

#Procedure Index - scope.tcl
#	scope::buildScope
#	scope::processData
#	scope::acquireWaveform
#	scope::saveOffset
#	scope::restoreOffsetCal
#	scope::showOffsetCal
#	scope::startStripChart
#	scope::resetStripChart
#	scope::stopStripChart
#	scope::stripChartSample
#	scope::getStripSample

namespace eval scope {

    #Multi-Dimensional array to hold samples from the scope
    set scopeData {}

    #Offset calibration values
    set aLowOffsets {0 0 0 0 0 0 0}
    set aHighOffsets {0 0 0 0 0 0 0}
    set bLowOffsets {0 0 0 0 0 0 0}
    set bHighOffsets {0 0 0 0 0 0 0}
    set offsetA 0
    set offsetALow 0
    set offsetAHigh 0
    set offsetB 0
    set offsetBLow 0
    set offsetBHigh 0
    set offsetARange {}
    set offsetBRange {}
    set autoOffsetStatus ""
    set autoOffsetProgress 0
    set saveOffsetProgress 0

    #Strip chart array and pointers
    set stripData {}
    set stripSample 0
    set stripStart ""
    set writeToDiskThreshold 100
    set nextWriteToDisk $writeToDiskThreshold
    set stripChartEnabled 0
    set stripDataFile "stripChart.dat"
    set samplesOnDisk 0

    #Scope offset calibration
    set scopeOffsetCalibrationInProgress 0
    set scopeOffsetData {}

    #Scope vertical calibration
    set autoCalibrationProgress 0

    #Trigger State
    set triggerState 0

    #Input voltage monitoring
    set lastInputReading 0

}

# scope::buildScope
#
# Creates the various widgets that make up the oscilloscope display and
# arranges them.
proc scope::buildScope {} {

    #Main frame to hold all oscilloscope widgets
    labelframe .scope	\
	-relief groove	\
	-borderwidth 2	\
	-text "Oscilloscope"	\
	-font {-weight bold -size -12}

    #Construct the vertical controls
    labelframe .scope.verticalA	\
	-relief groove	\
	-borderwidth 2	\
	-text "Channel A"	\
	-font {-weight bold -size -12}
    vertical::buildVertical .scope.verticalA A
    labelframe .scope.verticalB	\
	-relief groove	\
	-borderwidth 2	\
	-text "Channel B"	\
	-font {-weight bold -size -12}
    vertical::buildVertical .scope.verticalB B

    #Create the scope display
    frame .scope.display -relief raised -borderwidth 2
    display::setDisplayPath .scope.display
    display::buildDisplay
    display::buildGraph
    display::setMode normal

    #Construct the timebase controls
    labelframe .scope.timebase	\
	-relief groove	\
	-borderwidth 2	\
	-text "Timebase"	\
	-font {-weight bold -size -12}

    timebase::buildControls .scope.timebase

    #Construct the trigger controls
    labelframe .scope.trigger	\
	-relief groove	\
	-borderwidth 2	\
	-text "Trigger"	\
	-font {-weight bold -size -12}
    trigger::buildControls .scope.trigger

    #Place scope frames
    grid .scope.verticalA -row 1 -column 0
    grid .scope.verticalB -row 2 -column 0
    grid .scope.display -row 1 -column 1 -padx 5 -rowspan 2
    grid .scope.timebase -row 1 -column 2 -padx 5
    grid .scope.trigger -row 2 -column 2 -padx 5
}

# scope::processData
#
# Accepts 1D array of data from the USB-serial port.  Converts data
# to 16-bit numbers and stores it in separate arrays for channel A and channel B
proc scope::processData {data} {
    variable scopeData
    variable triggerState
    global log

    # Create arrays for each channel
    set dataA {}
    set dataB {}

    if {($::deviceType=="mini")||($::deviceType=="sig")} {
	#Pull the trigger state out of the data
	set triggerState [lindex $data 0]
	set data [lrange $data 1 end]
    }

    # Pointer/counter for traversing data array
    set j 0

    # Process samples for each channel
    for {set i 0} {$i < $scope::sampleDepth} {incr i} {

	# Get sample A
	set datum [lindex $data $j]
	set sample [expr {256*$datum}]
	incr j
	set datum [lindex $data $j]
	set sample [expr {$sample+$datum}]
	# Save the sample value
	lappend dataA $sample
	incr j

	# Get sample B
	set datum [lindex $data $j]
	set sample [expr {256*$datum}]
	incr j
	set datum [lindex $data $j]
	set sample [expr {$sample+$datum}]
	# Save the sample value
	lappend dataB $sample
	incr j

    }

    # ${log}::debug "dataA is [llength $dataA] samples long, dataB is [llength $dataB] samples long"

    #Clear the existing scope data array and store the new values
    set scopeData [list $dataA $dataB]

    ##Save values for export
    #set export::exportData {}
    ##Add waveform data for channel A
    #lappend export::exportData $dataA
    ##Add waveform data for channel B
    #lappend export::exportData $dataB
    ##Add channel A step size
    #lappend export::exportData [vertical::getStepSize A]
    ##Add channel B step size
    #lappend export::exportData [vertical::getStepSize B]
    ##Add sampling rate
    #lappend export::exportData [timebase::getSamplingRate]

    if {$::opMode == "CircuitGear"} {
	# Draw the new data on the screen
	display::plotData

	# Update the trigger display
	if {$trigger::triggerMode == "External"} {
	    [display::getDisplayPath].statusBar configure -text "External Trigger"
	} else {
	    # The Mini sends its trigger state with the scope data
	    # The MK2 sends the trigger state automatically when a capture is started and
	    # the status test is udpated in the usbSerial::processResponse procedure
	    if {($::deviceType=="mini")||($::deviceType=="sig")} {
		if {$triggerState == 2} {
		    [display::getDisplayPath].statusBar configure -text "Triggered"
		} else {
		    [display::getDisplayPath].statusBar configure -text "Not Triggered"
		}
	    } else {
		sendCommand f
	    }
	}

	#XY Mode Service
	display::plotXY

	#Spectrum Analysis
	fft::updateFFT

	#Automatic measurements
	automeasure::automeasure

	#Math toolbox
	math::updateMath

	#Get the next capture from the scope
	if {$trigger::triggerMode!="Single-Shot"} {
	    after 10 {scope::acquireWaveform}
	}

	#See if we are calibrating scope offsets
	if {$scope::scopeOffsetCalibrationInProgress} {
	    set scope::scopeOffsetData $scopeData
	}
    } elseif {$::opMode=="Signature"} {
	sig::plotData

	after 10 {scope::acquireWaveform}
    } else {
	if {$net::analyzeEnable} {
	    net::processFreqPoint
	}
    }

}

# scope::acquireWaveform
#
# Requests a new capture from the hardware.
proc scope::acquireWaveform {} {

    #Make sure the sampling settings are up-to-date
    timebase::updateTimebase

    #Get the input voltages
    #if {$::deviceType=="sig"} {
    #	set temp [clock clicks -milliseconds]
    #	if {[expr {$temp - $scope::lastInputReading}] > 1000} {
    #		sendCommand V
    #		set scope::lastInputReading $temp
    #	}
    #}

    #Request a new capture
    sendCommand c
}

# scope::startStripChart
#
# This process switches the hardware from sampling mode to strip chart/scan mode.
proc scope::startStripChart {} {
    variable stripDataFile
    variable nextWriteToDisk
    variable writeToDiskThreshold
    variable samplesOnDisk

    #Figure out if we are in scan mode or strip chart mode
    if {$timebase::stripChartMode == "scan"} {
	#Scan mode - send the correct prescaler setting to the hardware for this timebase
	timebase::updateStripSamplePeriod [timebase::getPrescaler]
	#Update the status bar text
	[display::getDisplayPath].statusBar configure -text "Scan Mode"
    } else {
	#Strip chart mode - update the hardware with the correct sampling interval
	if {($::deviceType=="mini")||($::deviceType=="sig")} {
	    switch $timebase::stripChartSamplePeriod {
		"20" {timebase::updateStripSamplePeriod "D"}
		"50" {timebase::updateStripSamplePeriod "E"}
		"100" {timebase::updateStripSamplePeriod "F"}
		"200" {timebase::updateStripSamplePeriod "G"}
		"500" {timebase::updateStripSamplePeriod "H"}
		"1000" {timebase::updateStripSamplePeriod "I"}
		"2000" {timebase::updateStripSamplePeriod "J"}
	    }
	} else {
	    switch $timebase::stripChartSamplePeriod {
		"20" {timebase::updateStripSamplePeriod "G"}
		"50" {timebase::updateStripSamplePeriod "H"}
		"100" {timebase::updateStripSamplePeriod "I"}
		"200" {timebase::updateStripSamplePeriod "J"}
		"500" {timebase::updateStripSamplePeriod "K"}
		"1000" {timebase::updateStripSamplePeriod "L"}
		"2000" {timebase::updateStripSamplePeriod "M"}
	    }
	}
	#Update the status bar text
	[display::getDisplayPath].statusBar configure -text "Strip Chart Mode"
    }

    #Reset all counters and data structures
    scope::resetStripChart

    #If we are already in strip chart mode and the strip chart was running, stop here
    #because the user has restarted sampling with the start button
    if {$scope::stripChartEnabled} {
	return
    }

    # Check to see if we are going to write the strip chart data to the disk
    if {$recorder::streamEnable} {
	#Check to see if the data file already exists
	if {[file exists $scope::stripDataFile]} {
	    set answer [tk_messageBox	\
			    -default no	\
			    -icon warning	\
			    -message "Warning: Strip chart data file exists.\nOverwrite it?"	\
			    -parent .	\
			    -title "File Exists..."	\
			    -type yesno]
	    if {$answer!="yes"} {return}
	}
	# Open the file and close it to erase contents
	try {
	    set stripDataHandle [open $stripDataFile w]
	    close $stripDataHandle
	} trap {} {message optdict} {
	    ${log}::error $message
	}

	#Set up for the next write to the file
	set nextWriteToDisk [expr {$writeToDiskThreshold+1}]
	set samplesOnDisk 0
    }

    #If we are in strip chart mode, disable the stream controls so they cannot
    #be changed unless the recording is stopped and restarted
    if {$timebase::timebaseMode == "strip"} {
	.recorder.recording.streamEnable configure -state disabled
	.recorder.recording.selectFile configure -state disabled
    }

    #Start the strip chart sampler
    sendCommand "C"

    #Get a sample
    set scope::stripChartEnabled 1
    sendCommand "F"
}

# scope::resetStripChart
#
# This process clears all data structures used by the strip chart in preparation
# for a new capture.
proc scope::resetStripChart {} {
    variable stripData
    variable stripSample
    variable stripStart

    #Clear data strcutres
    set stripData {}
    set stripSample 0

    #Reset the plot position on the graph display
    set display::xStart 0
    set display::xEnd 10
    set display::xSpan 10

    #Get the current time
    set temp [clock milliseconds]
    set now [clock format $temp -format "%D %T"]
    set stripStart $now

    #Reset the data array in the data recorder window
    if {$timebase::stripChartMode=="strip"} {
	array unset recorder::dataTable
    }

    #Clear the plot display and reset the x-axis
    display::clearDisplay
    display::xAxisLabels

}

# scope::stopStripChart
#
# Stops the current strip chart sampling
proc scope::stopStripChart {} {

    #Stop the strip chart sampler
    set scope::stripChartEnabled 0
    sendCommand "X"

    #Re-enable the stream controls
    if {$timebase::timebaseMode == "strip"} {
	.recorder.recording.streamEnable configure -state normal
	.recorder.recording.selectFile configure -state normal
    }

}

# scope::stripChartSample
#
# Processes 1D strip chart data received from the USB-serial port.
proc scope::stripChartSample {data} {
    variable stripData
    variable stripSample
    variable nextWriteToDisk
    variable samplesOnDisk
    variable writeToDiskThreshold
    variable stripDataFile

    if {[llength $data]} {
	#Process the raw data from the hardware
	set dataA [expr {[lindex $data 0]*256+[lindex $data 1]}]
	set dataB [expr {[lindex $data 2]*256+[lindex $data 3]}]

	#If we're in scan mode, reset the plot data once it reaches the right-hand side of the screen
	if {$timebase::stripChartMode=="scan"} {

	    #Calculate the current x-position of the sample on the screen
	    set xT [expr {[timebase::getSamplingPeriod]*$stripSample}]

	    #Reset the current x-position if we have reached the right side of the screen
	    if {$xT > [expr {$timebase::timebaseSetting*10.0}]} {
		scope::resetStripChart
		set xT 0
	    }

	    #Save the current sample to the strip chart display data array
	    lappend stripData [list $stripSample $xT [vertical::convertSampleVoltage $dataA A] \
				   [vertical::convertSampleVoltage $dataB B]]
	    incr stripSample
	} else {
	    #Strip chart mode - calculate the x-position of this sample
	    set xT [expr {$timebase::stripChartSamplePeriod*1.0E-3*$stripSample}]

	    #Save the current samples to the strip chart display data array
	    lappend stripData [list $stripSample $xT [vertical::convertSampleVoltage $dataA A] \
				   [vertical::convertSampleVoltage $dataB B]]
	    incr stripSample

	    # Check to see if we need to update the table
	    if {$recorder::autoScroll} {
		set recorder::tableEndIndex $stripSample
		if {$recorder::tableEndIndex<10} {
		    set recorder::tableEndIndex 10
		}
		set recorder::tableStartIndex [expr {$stripSample-9}]
		if {$recorder::tableStartIndex<0} {
		    set recorder::tableStartIndex 0
		}
		recorder::updateDataTable
	    }
	    # See if we need to write this data to disk
	    if {$stripSample == $nextWriteToDisk} {
		puts "Sampled $stripSample points, time to write"
		if {$::debugLevel>2} {
		    puts "Strip chart write to disk"
		}
		try {
		    set fileHandle [open $stripDataFile a]
		    set count 1
		    foreach sample $stripData {
			if { $count > $samplesOnDisk} {
			    puts $fileHandle $sample
			}
			incr count
		    }
		    set samplesOnDisk $stripSample
		    set nextWriteToDisk [expr {$stripSample+$writeToDiskThreshold}]
		    close $fileHandle

		} trap {} {message optdict} {
		    ${log}::error $message
		}
	    }
	}

	#Plot the data on the screen
	if {$timebase::stripChartMode=="scan"} {
	    display::plotScan
	} else {
	    display::plotStrip
	}
    }

    #Get the next sample
    if {($timebase::timebaseMode=="strip")||($timebase::timebaseMode=="scan")} {
	#Check to see if we have already requested the next sample
	after 50 {sendCommand "F"}
    }
}

# scope::getStripSample
#
# Extracts a sample (sampleNum) from the strip chart data array
proc scope::getStripSample {sampleNum} {
    variable stripData
    variable stripDataFile

    return [lindex $stripData $sampleNum]

}

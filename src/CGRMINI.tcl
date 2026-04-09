#File: CGRMINI.tcl
#Syscomp Unified CircuitGear GUI
#CGR-MINI Device-specific procedures and values

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

namespace eval scope {
    set sampleDepth 1024
}

namespace eval vertical {
    variable stepSizeHighDefault 0.025
    variable stepSizeLowDefault 0.002481

    variable stepSizeAHigh $stepSizeHighDefault
    variable stepSizeALow $stepSizeLowDefault
    variable stepSizeBHigh $stepSizeHighDefault
    variable stepSizeBLow $stepSizeLowDefault
}

namespace eval trigger {
    set triggerHigh 15
    set triggerLow 15
}

namespace eval timebase {
    set baseSamplingRate 2.0E6
    set timebaseSetting 0.001
    set validTimebases {	\
				    {1E-6 1}	\
				    {2E-6 1}	\
				    {5E-6 1}	\
				    {10E-6 1}	\
				    {20E-6 1}	\
				    {50E-6 1}	\
				    {100E-6 2} \
				    {200E-6 3} \
				    {500E-6 5} \
				    {1E-3 6}	\
				    {2E-3 7}	\
				    {5E-3 8}	\
				    {10E-3 9}	\
				    {20E-3 A}	\
				    {50E-3 B}	\
				    {100E-3 C}	\
				    {200E-3 D}	\
				    {500E-3 E}	\
				    {1 F}	\
				    {2 G}	\
				    {5 H}	\
				    {10 I}	\
				    {20 J}
    }
    set timebaseIndex 10
    set newTimebaseIndex $timebaseIndex
    set samplingRates {
	2.0E6	\
	    1.0E6	\
	    500.0E3	\
	    250.0E3	\
	    125.0E3	\
	    62.5E3
    }
}

proc timebase::getSamplingRate {} {
    variable timebaseIndex
    variable validTimebases

    switch [timebase::getPrescaler] {
	"0" {return 2.0E6}
	"1" {return 1.0E6}
	"2" {return 500.0E3}
	"3" {return 250.0E3}
	"4" {return 125.0E3}
	"5" {return 62.5E3}
	"6" {return 51200.0}
	"7" {return 25600.0}
	"8" {return 10240.0}
	"9" {return 5120.0}
	"A" {return 2560.0}
	"B" {return 1024.0}
	"C" {return 512.0}
	"D" {return 50.0}
	"E" {return 20.0}
	"F" {return 10.0}
	"G" {return 5.0}
	"H" {return 2.0}
	"I" {return 1.0}
	"J" {return 0.5}
	default {return "?"}
    }

}

#Process Response
#-------------------
#This procedure processes the message received from the instrument.  It examines
#the "responseType" and calls the appropriate routine to deal with the message.
proc ::usbSerial::processResponse {} {

    #Read in all available data from the serial port
    set incomingData [read $::portHandle]

    #Convert the data bytes into signed integers
    if { [llength {$incomingData}] > 0 } {
	binary scan $incomingData c* signed
	#Convert the bytes into unsigned integers (0-255)
	foreach byte $signed {
	    lappend ::usbSerial::receivedData [lindex $::usbSerial::cvt [expr {$byte & 255}]]
	}
    }

    #See if we have data in the buffer to process
    if {[llength $usbSerial::receivedData] > 0} {
	set usbSerial::responseType [lindex $::usbSerial::receivedData 0]
	set usbSerial::responseType [format %c $usbSerial::responseType]
    } else {
	return
    }

    #Get the total length of the message (number of bytes)
    set responseLength [llength $usbSerial::receivedData]

    #Process the message based on it's message type
    switch $usbSerial::responseType {
	"D" {
	    #Data from scope capture
	    if {$responseLength >=4098} {
		#Sort out data received from scope
		set temp [lrange $usbSerial::receivedData 1 4098]
		#Deal with left-over data in the receive buffer
		if {$responseLength > 4098} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 4098 end]
		} else {
		    set usbSerial::receivedData {}
		}
		#Process the capture data returned from the scope
		scope::processData $temp
	    } else {
		#puts "Waiting for more data!"
		return
	    }
	} "T" {
	    if {$responseLength >=5} {
		set temp [lrange $usbSerial::receivedData 1 2]
		set bufferTemp [lrange $usbSerial::receivedData 3 4]
		if {$responseLength > 5} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 5 end]
		} else {
		    set usbSerial::receivedData {}
		}
		set ::triggerCount [expr {[lindex $temp 0]*256 + [lindex $temp 1]}]
		set ::bufferPtr [expr {[lindex $bufferTemp 0]*256 + [lindex $bufferTemp 1]}]
		#puts "temp $temp"
		puts "Trigger Count $::triggerCount"
		puts "Buffer Ptr $::bufferPtr"
	    } else {
		return
	    }
	} "e" {
	    if {$responseLength >= 2} {
		set usbSerial::eepromData [lindex $usbSerial::receivedData 1]
		if {$responseLength > 2} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 2 end]
		} else {
		    set usbSerial::receivedData {}
		}
	    } else {
		return
	    }
	} "S" {
	    if {$responseLength >=5} {
		set temp [lrange $usbSerial::receivedData 1 4]
		if {$responseLength > 5} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 5 end]
		} else {
		    set usbSerial::receivedData {}
		}
		scope::stripChartSample $temp
	    } else {
		return
	    }
	} "s" {
	    #Strip chart buffer is empty
	    if {$responseLength >= 1} {
		if {$responseLength > 1} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 1 end]
		} else {
		    set usbSerial::receivedData {}
		    #Only request a new sample if there is nothing else to process in this loop,
		    #otherwise requesting a sample will cause an infinite loop in this process because
		    #the fileevent will trigger immediately
		    scope::stripChartSample {}
		}
		#if {($timebase::timebaseMode == "scan")} {
		#	sendCommand F
		#} elseif {($timebase::timebaseMode == "strip")&&($scope::stripChartEnabled)} {
		#	sendCommand F
		#}
	    } else {
		return
	    }
	} "I" {
	    if {$responseLength >=2} {
		set temp [lrange $usbSerial::receivedData 0 1]
		if {$responseLength > 2} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 2 end]
		} else {
		    set usbSerial::receivedData {}
		}
		digio::updateDigIn [lindex $temp 1]
	    } else {
		return
	    }
	} "W" {
	    if {$responseLength >=257} {
		set waveformData [lrange $usbSerial::receivedData 1 256]
		if {$responseLength > 257} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 257 end]
		} else {
		    set usbSerial::receivedData {}
		}
		wave::updateDisplay $waveformData 256
	    } else {
		return
	    }
	} default {
	    #We received an unknown message type
	    puts "Unknown response: $usbSerial::responseType"
	    set temp [llength $usbSerial::receivedData]
	    puts "Buffer length $temp"
	    puts $usbSerial::receivedData
	    set usbSerial::receivedData {}
	}
    }

    incr ::statusState
    if {$::statusState > 14} {
	set ::statusState 0
    }
    .connection configure -image $::statusImage($::statusState)

    #If there is more data in the receive buffer, repeat this procedure
    if { [llength $usbSerial::receivedData] > 0 } {
	usbSerial::processResponse
    }

}

# scope::saveOffsets
#
# Save the current offset calibration values in the software to the hardware.
proc scope::saveOffsets {} {
    variable offsetALow
    variable offsetAHigh
    variable offsetBLow
    variable offsetBHigh

    #Replace the button with a progress bar while we save the values
    set scope::saveOffsetProgress 0

    set pos [grid info .offset.saveCal]
    grid remove .offset.saveCal
    grid .offset.saveProgress -row 3 -column 0 -pady 5 -columnspan 2
    update

    set sampleIndex 0
    set address $::nvmAddressOffsets
    for {set i 0} {$i <7} {incr i} {

	puts "Sample Index $sampleIndex"

	#Convert channel A calibration offsets to 12-bit unsigned values
	set aLow [expr {2047-[lindex $scope::aLowOffsets $sampleIndex]}]
	set aHigh [expr {2047-[lindex $scope::aHighOffsets $sampleIndex]}]

	#Convert channel B calibration offsets to 12-bit unsigned values
	set bLow [expr {2047-[lindex $scope::bLowOffsets $sampleIndex]}]
	set bHigh [expr {2047-[lindex $scope::bHighOffsets $sampleIndex]}]

	#Write the low range offsets for channel A to the device
	set byte1 [expr {round(floor($aLow/pow(2,8)))}]
	set byte0 [expr {$aLow%round(pow(2,8))}]
	sendCommand "E $address $byte1"
	after 100
	incr scope::saveOffsetProgress
	update
	incr address
	sendCommand "E $address $byte0"
	after 100
	incr scope::saveOffsetProgress
	update

	#Write the high range offsets for channel A to the device
	set byte1 [expr {round(floor($aHigh/pow(2,8)))}]
	set byte0 [expr {$aHigh%round(pow(2,8))}]
	incr address
	sendCommand "E $address $byte1"
	after 100
	incr scope::saveOffsetProgress
	update
	incr address
	sendCommand "E $address $byte0"
	after 100
	incr scope::saveOffsetProgress
	update

	#Write the low range offsets for channel B to the device
	set byte1 [expr {round(floor($bLow/pow(2,8)))}]
	set byte0 [expr {$bLow%round(pow(2,8))}]
	incr address
	sendCommand "E $address $byte1"
	after 100
	incr scope::saveOffsetProgress
	update
	incr address
	sendCommand "E $address $byte0"
	after 100
	incr scope::saveOffsetProgress
	update

	#Write the high range offsets for channel B to the device
	set byte1 [expr {round(floor($bHigh/pow(2,8)))}]
	set byte0 [expr {$bHigh%round(pow(2,8))}]
	incr address
	sendCommand "E $address $byte1"
	update
	after 100
	incr scope::saveOffsetProgress
	incr address
	sendCommand "E $address $byte0"
	update
	after 100
	incr scope::saveOffsetProgress

	incr address

	incr sampleIndex

    }

    grid remove .offset.saveProgress
    grid .offset.saveCal -row 3 -column 0 -pady 5 -columnspan 2

    tk_messageBox	\
	-default ok	\
	-message "Offsets saved to device."	\
	-parent .offset	\
	-title "Offsets Saved"	\
	-type ok

}

# scope::restoreOffsetCal
#
# Read offset calibration values from the device.
proc scope::restoreOffsetCal {} {

    set sampleIndex 0
    set address $::nvmAddressOffsets

    for {set i 0} {$i < 7} {incr i} {
	#Read the low range offset high byte for channel A
	sendCommand "e $address"
	vwait usbSerial::eepromData
	set byte1 $usbSerial::eepromData
	puts "Data $usbSerial::eepromData"

	#Check to see if the value is "blank" (unprogrammed eeprom)
	if {$byte1 == 255} {
	    puts "No scope offsets stored in hardware"
	    return
	}

	#Read the low range offset low byte for channel A
	incr address
	sendCommand "e $address"
	vwait usbSerial::eepromData
	set byte0 $usbSerial::eepromData
	set scope::aLowOffsets [lreplace $scope::aLowOffsets $sampleIndex $sampleIndex [expr {2047-(256*$byte1+$byte0)}]]
	puts "Data $usbSerial::eepromData"

	#Read the high range offset for channel A
	incr address
	sendCommand "e $address"
	vwait usbSerial::eepromData
	set byte1 $usbSerial::eepromData
	puts "Data $usbSerial::eepromData"
	incr address
	sendCommand "e $address"
	vwait usbSerial::eepromData
	set byte0 $usbSerial::eepromData
	set scope::aHighOffsets [lreplace $scope::aHighOffsets $sampleIndex $sampleIndex [expr {2047-(256*$byte1+$byte0)}]]
	puts "Data $usbSerial::eepromData"

	#Read the low range offset for channel B
	incr address
	sendCommand "e $address"
	vwait usbSerial::eepromData
	set byte1 $usbSerial::eepromData
	puts "Data $usbSerial::eepromData"
	incr address
	sendCommand "e $address"
	vwait usbSerial::eepromData
	set byte0 $usbSerial::eepromData
	set scope::bLowOffsets [lreplace $scope::bLowOffsets $sampleIndex $sampleIndex [expr {2047-(256*$byte1+$byte0)}]]
	puts "Data $usbSerial::eepromData"

	#Read the high range offset for channel B
	incr address
	sendCommand "e $address"
	vwait usbSerial::eepromData
	set byte1 $usbSerial::eepromData
	puts "Data $usbSerial::eepromData"
	incr address
	sendCommand "e $address"
	vwait usbSerial::eepromData
	set byte0 $usbSerial::eepromData
	set scope::bHighOffsets [lreplace $scope::bHighOffsets $sampleIndex $sampleIndex [expr {2047-(256*$byte1+$byte0)}]]
	puts "Data $usbSerial::eepromData"

	incr address

	incr sampleIndex
    }

    puts "Scope offsets restored.$address"

}

# scope::showOffsetCal
#
# Display a window with sliders which lets the user adjust the offset
# calibration values for the device.
proc scope::showOffsetCal {} {

    #Check to see if the window is already open
    if {![winfo exists .offset]} {

	#Create a new window
	toplevel .offset
	wm title .offset "Scope Offset Calibration"
	wm iconname .offset "Offset"
	wm resizable .offset 0 0

	#Combobox for selecting sampling rate
	label .offset.sampleLabel	\
	    -text "Sampling Rate:"
	ttk::combobox .offset.sampleRate	\
	    -values $timebase::samplingRates	\
	    -textvariable scope::offsetSampleRate
	set scope::offsetSampleRate 2.0E6
	bind .offset.sampleRate <<ComboboxSelected>> scope::selectOffsetSamplingRate

	#Frame to hold offset controls
	labelframe .offset.controlsA	\
	    -text "Channel A"	\
	    -relief groove	\
	    -borderwidth 2

	#Combobox for selecting the range
	ttk::combobox .offset.controlsA.rangeSelector	\
	    -values {"High Range (500mV - 5V)" "Low Range (20mV - 200mV)"}	\
	    -textvariable scope::offsetARange
	set scope::offsetARange "High Range (500mV - 5V)"
	bind .offset.controlsA.rangeSelector <<ComboboxSelected>> "scope::selectOffsetRange A"

	#Channel A High Range Offset Controls
	scale .offset.controlsA.aOffset	\
	    -from -300	\
	    -to 300	\
	    -length 150	\
	    -resolution 1	\
	    -showvalue 1	\
	    -variable scope::offsetA	\
	    -command "scope::offsetAdjustment A"

	grid .offset.controlsA.rangeSelector -row 0 -column 0
	grid .offset.controlsA.aOffset -row 1 -column 0

	#Frame to hold offset controls
	labelframe .offset.controlsB	\
	    -text "Channel B"	\
	    -relief groove	\
	    -borderwidth 2

	#Combobox for selecting the range
	ttk::combobox .offset.controlsB.rangeSelector	\
	    -values {"High Range (500mV - 5V)" "Low Range (20mV - 200mV)"}	\
	    -textvariable scope::offsetBRange
	set scope::offsetBRange "High Range (500mV - 5V)"
	bind .offset.controlsB.rangeSelector <<ComboboxSelected>> "scope::selectOffsetRange B"

	#Channel A High Range Offset Controls
	scale .offset.controlsB.bOffset	\
	    -from -300	\
	    -to 300	\
	    -length 150	\
	    -resolution 1	\
	    -showvalue 1	\
	    -variable scope::offsetB	\
	    -command "scope::offsetAdjustment B"

	grid .offset.controlsB.rangeSelector -row 0 -column 0
	grid .offset.controlsB.bOffset -row 1 -column 0

	#Button for autocalibration
	button .offset.autoCal	\
	    -text "Auto Calibrate..."	\
	    -command scope::autoOffsetCalibration

	#Button to save values to the hardware
	button .offset.saveCal	\
	    -text "Save Calibration Values to Device"	\
	    -command scope::saveOffsets

	#Progress bar for saving values to the hardware
	set scope::saveOffsetProgress 0
	ttk::progressbar .offset.saveProgress	\
	    -orient horizontal	\
	    -length 200	\
	    -mode determinate	\
	    -maximum 48	\
	    -variable scope::saveOffsetProgress

	grid .offset.sampleLabel -row 0 -column 0
	grid .offset.sampleRate -row 0 -column 1
	grid .offset.controlsA -row 1 -column 0
	grid .offset.controlsB -row 1 -column 1
	grid .offset.autoCal -row 2 -column 0 -columnspan 2
	grid .offset.saveCal -row 3 -column 0 -pady 5 -columnspan 2

	#Initalize
	scope::selectOffsetSamplingRate
	scope::selectOffsetRange A
	scope::selectOffsetRange B

    } else {
	#Get rid of the old offset cal window and create a new one
	destroy .offset
	scope::showOffsetCal
    }

}

# scope::selectOffsetSamplingRate
#
# Selects the appropriate timebase setting to match the current
# sampling rate in the offset calibration window
proc scope::selectOffsetSamplingRate {} {

    switch $scope::offsetSampleRate {
	2.0E6 {
	    set timebase::newTimebaseIndex 5
	    set sampleIndex 0
	} 1.0E6 {
	    set timebase::newTimebaseIndex 6
	    set sampleIndex 1
	} 500.0E3 {
	    set timebase::newTimebaseIndex 7
	    set sampleIndex 2
	} 250.0E3 {
	    set timebase::newTimebaseIndex 8
	    set sampleIndex 3
	} 125.0E3 {
	    set timebase::newTimebaseIndex 8
	    set sampleIndex 4
	} 62.5E3 {
	    set timebase::newTimebaseIndex 9
	    set sampleIndex 5
	}
    }

    set scope::offsetALow [lindex $scope::aLowOffsets $sampleIndex]
    set scope::offsetAHigh [lindex $scope::aHighOffsets $sampleIndex]
    set scope::offsetBLow [lindex $scope::bLowOffsets $sampleIndex]
    set scope::offsetBHigh [lindex $scope::bHighOffsets $sampleIndex]

    timebase::adjustTimebase update

    scope::selectOffsetRange A
    scope::selectOffsetRange B

}

# scope::saveOffsetToArray
#
# Saves the slider offsets to the offset arrays.
proc scope::saveOffsetToArray {} {

    switch $scope::offsetSampleRate {
	2.0E6 {
	    set sampleIndex 0
	} 1.0E6 {
	    set sampleIndex 1
	} 500.0E3 {
	    set sampleIndex 2
	} 250.0E3 {
	    set sampleIndex 3
	} 125.0E3 {
	    set sampleIndex 4
	} 62.5E3 {
	    set sampleIndex 5
	}
    }

    set scope::aLowOffsets [lreplace $scope::aLowOffsets $sampleIndex $sampleIndex $scope::offsetALow]
    set scope::aHighOffsets [lreplace $scope::aHighOffsets $sampleIndex $sampleIndex $scope::offsetAHigh]
    set scope::bLowOffsets [lreplace $scope::bLowOffsets $sampleIndex $sampleIndex $scope::offsetBLow]
    set scope::bHighOffsets [lreplace $scope::bHighOffsets $sampleIndex $sampleIndex $scope::offsetBHigh]

}

# scope::autoOffsetCabliration
#
# Iterates through all available sampling rates and calibrates the offset for each input channel and gain setting.
proc scope::autoOffsetCalibration {} {

    set answer [tk_messageBox	\
		    -default no	\
		    -icon warning	\
		    -message "WARNING: Auto-Calibrate will replace all scope offset values.\nThis process will take 1-2 minutes\nWould you like to continue?"	\
		    -parent .offset	\
		    -title "Auto-Calibrate Warning"	\
		    -type yesno]

    if {$answer=="no"} {return}

    tk_messageBox	\
	-default ok	\
	-icon warning	\
	-message "Remove all input signals, disconnect all BNC inputs and click OK to proceed"	\
	-parent .offset	\
	-title "Remove Input Sources"		\
	-type ok

    #Create a window to display the automatic offset calibration progress bar
    toplevel .autoOffset
    wm title .autoOffset "Automatic Offset Calibration"
    wm iconname .autoOffset "Auto Offset"
    wm resizable .autoOffset 0 0

    #Create a label to display the auto-calibration status
    set scope::autoOffsetStatus "Initializing..."
    label .autoOffset.status	\
	-textvariable scope::autoOffsetStatus

    #Create a progress bar
    set scope::autoOffsetProgress 0
    ttk::progressbar .autoOffset.progress	\
	-orient horizontal	\
	-length 200	\
	-mode determinate	\
	-maximum 12	\
	-variable scope::autoOffsetProgress

    grid .autoOffset.status -row 0 -column 0
    grid .autoOffset.progress -row 1 -column 0

    raise .autoOffset
    focus .autoOffset
    grab .autoOffset

    #Use single-shot trigger during auto-calibration
    set trigger::triggerMode "Single-Shot"
    trigger::selectTriggerMode
    trigger::manualTrigger

    #Flag to indicate that we are calibrating the offsets
    set scope::scopeOffsetCalibrationInProgress 1

    #Iterate through each sampling rate
    foreach sampleRate $timebase::samplingRates {
	#Update the sampling rate
	set scope::offsetSampleRate $sampleRate
	scope::selectOffsetSamplingRate

	#Select High Range for both channels
	set scope::autoOffsetStatus "Sample Rate: $sampleRate, Range: 0.5 - 5.0V"
	set vertical::verticalIndexA 5
	set vertical::verticalIndexB 5
	vertical::updateIndicator .scope.verticalA A
	vertical::updateIndicator .scope.verticalB B
	vertical::updateVertical

	set scope::offsetARange "High Range (500mV - 5V)"
	set scope::offsetBRange "High Range (500mV - 5V)"
	scope::selectOffsetRange A
	scope::selectOffsetRange B

	#Zero the offsets
	scope::zeroOffset A
	scope::zeroOffset B

	#Update the progress bar
	incr scope::autoOffsetProgress
	update

	#Select Low Range for both channels
	set scope::autoOffsetStatus "Sample Rate: $sampleRate, Range: 10mV - 200mV"
	set scope::offsetARange "Low Range (20mV - 200mV)"
	set scope::offsetBRange "Low Range (20mV - 200mV)"
	scope::selectOffsetRange A
	scope::selectOffsetRange B

	#Zero the offsets
	scope::zeroOffset A
	scope::zeroOffset B

	#Update the progress bar
	incr scope::autoOffsetProgress
	update

    }

    set trigger::triggerMode "Auto"
    trigger::selectTriggerMode

    set scope::scopeOffsetCalibrationInProgress 0

    set answer [tk_messageBox	\
		    -default yes	\
		    -message "Offset calibration complete.  Would you like to save the values?"	\
		    -parent .autoOffset	\
		    -title "Calibration Complete"	\
		    -type yesno]

    destroy .autoOffset
    update

    if {$answer == "yes"} {
	scope::saveOffsets
    }
}

proc scope::calculateAverage {channel} {

    for {set i 0} {$i < 5} {incr i} {
	#Capture one waveform
	trigger::singleShotReset
	trigger::manualTrigger
	#Wait for the data to arrive from the scope
	vwait scope::scopeOffsetData
    }

    if {$channel == "A"} {
	set data [lindex $scope::scopeData 0]
    } else {
	set data [lindex $scope::scopeData 1]
    }

    set average 0
    for {set i 0} {$i < 1024} {incr i} {
	set average [expr {$average+[lindex $data $i]}]
    }
    set average [expr {round($average/1024.0)}]

    return $average

}

proc scope::offsetAdjustment {channel newValue} {

    set offset [expr {2047+$newValue}]

    if {($channel=="A") || ($channel=="a")} {
	sendCommand "o A $offset"
	if {$scope::offsetARange == "High Range (500mV - 5V)"} {
	    set scope::offsetAHigh $newValue
	} else {
	    set scope::offsetALow $newValue
	}
    } else {
	sendCommand "o B $offset"
	if {$scope::offsetBRange == "High Range (500mV - 5V)"} {
	    set scope::offsetBHigh $newValue
	} else {
	    set scope::offsetBLow $newValue
	}
    }

    scope::saveOffsetToArray

}

proc scope::selectOffsetRange {channel} {

    if {$channel == "A"} {
	if {$scope::offsetARange == "High Range (500mV - 5V)"} {
	    set offset $scope::offsetAHigh
	    set vertical::verticalIndexA 5
	} else {
	    set offset $scope::offsetALow
	    set vertical::verticalIndexA 1
	}
	.offset.controlsA.aOffset set $offset
	vertical::updateIndicator .scope.verticalA A
	vertical::updateVertical
    } else {
	if {$scope::offsetBRange == "High Range (500mV - 5V)"} {
	    set offset $scope::offsetBHigh
	    set vertical::verticalIndexB 5
	} else {
	    set offset $scope::offsetBLow
	    set vertical::verticalIndexB 1
	}
	.offset.controlsB.bOffset set $offset
	vertical::updateIndicator .scope.verticalB B
	vertical::updateVertical
    }
}

proc scope::zeroOffset {channel} {

    set minValue -300
    set maxValue 300

    #Hunt down the correct offset
    for {set i 0} {$i <10} {incr i} {

	puts "Iteration $i"
	puts "Max $maxValue Min $minValue"

	set testOffset [expr {($maxValue-$minValue)/2+$minValue}]
	puts "Testing offset $testOffset"
	if {$channel == "A"} {
	    .offset.controlsA.aOffset set $testOffset
	} else {
	    .offset.controlsB.bOffset set $testOffset
	}

	set measuredOffset [scope::calculateAverage $channel]
	puts "Measured $measuredOffset"

	if {$measuredOffset == 1023} {
	    break
	}

	if {$measuredOffset > 1023} {
	    set maxValue $testOffset
	} else {
	    set minValue $testOffset
	}
	update
    }

}

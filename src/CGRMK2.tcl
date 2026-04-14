#File: CGRMK2.tcl
#Syscomp Unified CircuitGear GUI
#CGR-201 Device-specific procedures and values

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
    set sampleDepth 4096
}

namespace eval vertical {

    variable R1 909E3
    variable R8 90.9E3
    variable R5 1.87E3
    variable R2 7.5E3
    variable R3 4.64E3
    variable R9 510
    variable RA 20E3
    variable RB 20E3

    set k8High [expr {($R8/($R1+$R8)*($R5/$R2))}]
    set k8Low [expr {$k8High*(1+$R3/$R9)}]
    set k10 [expr {(1+$R5/$R2)*($RB/$RA)}]

    set shiftStepHighDefault [expr {4095.0*$k8High/($k10*1.24)}]
    set shiftStepLowDefault [expr {4095.0*$k8Low/($k10*1.24)}]

    variable shiftStepAHigh $shiftStepHighDefault
    variable shiftStepALow $shiftStepLowDefault
    variable shiftStepBHigh $shiftStepHighDefault
    variable shiftStepBLow $shiftStepLowDefault

    set stepSizeHighDefault [expr {1/1023.0*1.24/$k8High}]
    set stepSizeLowDefault [expr {1/1023.0*1.24/$k8Low}]

    variable stepSizeAHigh $stepSizeHighDefault
    variable stepSizeALow $stepSizeLowDefault
    variable stepSizeBHigh $stepSizeHighDefault
    variable stepSizeBLow $stepSizeLowDefault
}

namespace eval trigger {
    set triggerHigh 4
    set triggerLow 4
}

namespace eval timebase {
    set baseSamplingRate 40.0E6
    set timebaseSetting 0.001
    set validTimebases {	\
				    {50E-9 0}	\
				    {100E-9 0}	\
				    {200E-9 0}	\
				    {500E-9 0} 	\
				    {1E-6 0}	\
				    {2E-6 0}	\
				    {5E-6 0}	\
				    {10E-6 1}	\
				    {20E-6 2}	\
				    {50E-6 4}	\
				    {100E-6 5} \
				    {200E-6 6} \
				    {500E-6 7} \
				    {1E-3 8}	\
				    {2E-3 9}	\
				    {5E-3 A}	\
				    {10E-3 B}	\
				    {20E-3 C}	\
				    {50E-3 E}	\
				    {100E-3 F}	\
				    {200E-3 G}	\
				    {500E-3 H}	\
				    {1 I}	\
				    {2 J}	\
				    {5 K}	\
				    {10 L}	\
				    {20 M}
    }
    set timebaseIndex 13
    set newTimebaseIndex $timebaseIndex
    set samplingRates {
	40E6	\
	    20E6	\
	    10E6	\
	    5E6	\
	    2.5E6	\
	    1.25E6	\
	    625E3	\
	    312.5E3	\
	    156.25E3	\
	    78.125E3	\
	    39.0625E3	\
	    19.53125E3
    }
}

proc timebase::getSamplingRate {} {
    variable timebaseIndex
    variable validTimebases

    switch [timebase::getPrescaler] {
	"0" {return 40E6}
	"1" {return 20E6}
	"2" {return 10E6}
	"3" {return 5E6}
	"4" {return 2.5E6}
	"5" {return 1.25E6}
	"6" {return 625E3}
	"7" {return 312.5E3}
	"8" {return 156.25E3}
	"9" {return 78.125E3}
	"A" {return 39.0625E3}
	"B" {return 19.53125E3}
	"C" {return 9765.625}
	"D" {return 4882.8125}
	"E" {return 2441.40625}
	"F" {return 1220.703125}
	"G" {return 50}
	"H" {return 20}
	"I" {return 10}
	"J" {return 5}
	"K" {return 2}
	"L" {return 1}
	"M" {return 0.5}
	default {
	    puts "Unknown Prescaler [timebase::getPrescaler]"
	    return "?"}
    }

}

proc ::usbSerial::processResponse {} {
    # Process the message received from the hardware.  The message
    # contains a "responseType."  Call the appropriate procedure to
    # deal with the message according to the responseType.
    #
    # Arguments: none
    global log

    #Read in all available data from the serial port
    set incomingData [read $::portHandle]
    #puts "RX: $incomingData"

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
	    if {$responseLength >= 16385} {
		#Sort out data received from scope
		set temp [lrange $usbSerial::receivedData 1 16385]
		#Deal with left-over data in the receive buffer
		if {$responseLength > 16385} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 16385 end]
		} else {
		    set usbSerial::receivedData {}
		}
		#Process the capture data returned from the scope
		scope::processData $temp
	    } else {
		#puts "Waiting for more data! $responseLength"
		return
	    }
	} "?" {
	    #Scope state
	    if {$responseLength >=2} {
		set state [lindex $usbSerial::receivedData 1]
		${log}::debug "State: $state"
		switch $state {
		    "1" {
			[display::getDisplayPath].statusBar configure -text "Idle"
		    } "2" {
			[display::getDisplayPath].statusBar configure -text "Arming"
		    } "3" {
			[display::getDisplayPath].statusBar configure -text "Armed"
		    } "4" {
			[display::getDisplayPath].statusBar configure -text "Capturing"
		    } "5" {
			[display::getDisplayPath].statusBar configure -text "Reading"
		    }
		}
		if {$responseLength > 2} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 2 end]
		} else {
		    set usbSerial::receivedData {}
		}
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
	} "W" {
	    # puts "Waveform data received."
	    if {$responseLength >=2049} {
		set waveformData [lrange $usbSerial::receivedData 1 2048]
		if {$responseLength > 2049} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 2049 end]
		} else {
		    set usbSerial::receivedData {}
		}
		wave::updateDisplay $waveformData 2048
	    } else {
		return
	    }
	} "V" {
	    if {$responseLength >= 3} {
		set usbVoltage [expr {[lindex $usbSerial::receivedData 1]*256 + [lindex $usbSerial::receivedData 2]}]
		#puts "ADC raw $usbVoltage"
		set usbVoltage [expr {$usbVoltage/2047.0*1.24*5}]
		#puts "ADC voltage $usbVoltage"
		set usbVoltage [format "%.2f" $usbVoltage]
		set usbText "USB Voltage: "
		append usbText $usbVoltage
		append usbText "V"
		.menubar.usbVoltage configure -text $usbText
		if {$usbVoltage >=4.75} {
		    .menubar.usbVoltage configure -background green
		} elseif {$usbVoltage > 4.5} {
		    .menubar.usbVoltage configure -background yellow
		} else {
		    .menubar.usbVoltage configure -background red
		}
		if {$responseLength > 3} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 3 end]
		} else {
		    set usbSerial::receivedData {}
		}
		after 2000 {sendCommand V}
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
	} "f" {
	    if {$responseLength >=4} {
		set temp [lrange $usbSerial::receivedData 1 3]
		if {$responseLength > 4} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 4 end]
		} else {
		    set usbSerial::receivedData {}
		}
		set freqCount [expr {[lindex $temp 0]*65536+[lindex $temp 1]*256+[lindex $temp 2]}]
		set freqCount [cursor::formatFrequency [expr {$freqCount/2.56}] 1]
		[display::getDisplayPath].statusBar configure -text "Triggered $freqCount"
	    } else {
		return
	    }
	} "z" {
	    if {$responseLength >= 2} {
		puts -nonewline "Blank check status: "
		puts -nonewline $usbSerial::responseType
		puts [lindex $firmware::receivedData 1]
		if {$responseLength > 2} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 2 end]
		} else {
		    set usbSerial::receivedData {}
		}
	    } else {
		puts "Wait for blank check response."
		return
	    }
	} "F" {
	    if {$responseLength >= 2} {
		puts -nonewline "Write status: "
		puts -nonewline [format "%c" [lindex $usbSerial::receivedData 0]]
		puts [format "%c" [lindex $usbSerial::receivedData 1]]
		if {[format "%c" [lindex $usbSerial::receivedData 1]]=="C"} {
		    puts "Write Complete."
		    set firmware::status "WOK"
		} else {
		    puts "Write Failed."
		    set firmware::status "FAIL"
		}
		if {$responseLength > 2} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 2 end]
		} else {
		    set usbSerial::receivedData {}
		}
	    } else {
		puts "Wait for write response."
		return
	    }
	} "x" {
	    if {$responseLength >= 2} {
		puts -nonewline "Erase status: "
		puts -nonewline [format "%c" [lindex $usbSerial::receivedData 0]]
		puts [format "%c" [lindex $usbSerial::receivedData 1]]
		set firmware::eraseStatus [format "%c" [lindex $usbSerial::receivedData 1]]
		if {$responseLength > 2} {
		    set usbSerial::receivedData [lrange $usbSerial::receivedData 2 end]
		} else {
		    set usbSerial::receivedData {}
		}
	    } else {
		puts "Wait for erase response."
		return
	    }
	} "X" {
	    #FPGA Erase Complete
	    puts "Erase Complete."
	    set firmware::eraseStatus X
	    if {$responseLength > 1} {
		set usbSerial::receivedData [lrange $usbSerial::receivedData 1 end]
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
	    scope::acquireWaveform
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
    grid .offset.saveProgress -row 5 -column 0 -pady 5 -columnspan 2 -sticky we
    update

    set sampleIndex 0
    set address $::nvmAddressOffsets

    #Channel A Low Offset
    set temp [expr {2047-$offsetALow}]
    set byte1 [expr {round(floor($temp/pow(2,8)))}]
    set byte0 [expr {$temp%round(pow(2,8))}]
    sendCommand "E $address $byte1"
    after 100
    incr scope::saveOffsetProgress
    update
    incr address
    sendCommand "E $address $byte0"
    after 100
    incr scope::saveOffsetProgress
    update

    #Channel A High Offset
    set temp [expr {2047-$offsetAHigh}]
    set byte1 [expr {round(floor($temp/pow(2,8)))}]
    set byte0 [expr {$temp%round(pow(2,8))}]
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

    #Channel B Low Offset
    set temp [expr {2047-$offsetBLow}]
    set byte1 [expr {round(floor($temp/pow(2,8)))}]
    set byte0 [expr {$temp%round(pow(2,8))}]
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

    #Channel B High Offset
    set temp [expr {2047-$offsetBHigh}]
    set byte1 [expr {round(floor($temp/pow(2,8)))}]
    set byte0 [expr {$temp%round(pow(2,8))}]
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

    grid remove .offset.saveProgress
    grid .offset.saveCal -row 5 -column 0 -pady 5 -columnspan 2 -sticky we

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

    set address $::nvmAddressOffsets

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
    set scope::offsetALow [expr {2047-(256*$byte1+$byte0)}]
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
    set scope::offsetAHigh [expr {2047-(256*$byte1+$byte0)}]
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
    set scope::offsetBLow [expr {2047-(256*$byte1+$byte0)}]
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
    set scope::offsetBHigh [expr {2047-(256*$byte1+$byte0)}]
    puts "Data $usbSerial::eepromData"

    puts "Scope offsets restored."
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

	label .offset.aHighLabel	\
	    -text "Channel A\n1V-5V Range"		\
	    -font {-weight bold -size -12}

	scale .offset.aHighScale	\
	    -from 300	\
	    -to -300	\
	    -length 150	\
	    -resolution 1	\
	    -showvalue 1	\
	    -variable scope::offsetAHigh	\
	    -command "scope::offsetAdjustment A"

	label .offset.bHighLabel	\
	    -text "Channel B\n1V-5V Range"		\
	    -font {-weight bold -size -12}

	scale .offset.bHighScale	\
	    -from 300	\
	    -to -300	\
	    -length 150	\
	    -resolution 1	\
	    -showvalue 1	\
	    -variable scope::offsetBHigh	\
	    -command "scope::offsetAdjustment B"

	label .offset.aLowLabel	\
	    -text "Channel A\n50mV-500mV Range"		\
	    -font {-weight bold -size -12}

	scale .offset.aLowScale	\
	    -from 300	\
	    -to -300	\
	    -length 150	\
	    -resolution 1	\
	    -showvalue 1	\
	    -variable scope::offsetALow	\
	    -command "scope::offsetAdjustment A"

	label .offset.bLowLabel	\
	    -text "Channel B\n50mV-500mV Range"		\
	    -font {-weight bold -size -12}

	scale .offset.bLowScale	\
	    -from 300	\
	    -to -300	\
	    -length 150	\
	    -resolution 1	\
	    -showvalue 1	\
	    -variable scope::offsetBLow	\
	    -command "scope::offsetAdjustment B"

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

	#Button for autocalibration
	button .offset.autoCal	\
	    -text "Auto Calibrate..."	\
	    -command scope::autoOffsetCalibration

	grid .offset.aHighLabel -row 0 -column 0
	grid .offset.aHighScale -row 1 -column 0
	grid .offset.bHighLabel -row 0 -column 3
	grid .offset.bHighScale -row 1 -column 3
	grid .offset.aLowLabel -row 0 -column 1
	grid .offset.aLowScale -row 1 -column 1
	grid .offset.bLowLabel -row 0 -column 4
	grid .offset.bLowScale -row 1 -column 4
	grid .offset.autoCal -row 4 -column 0 -columnspan 5 -pady 10 -sticky we
	grid .offset.saveCal -row 5 -column 0 -columnspan 5 -pady 5 -sticky we

    } else {
	#Get rid of the old offset cal window and create a new one
	destroy .offset
	scope::showOffsetCal
    }

}

proc scope::offsetAdjustment {channel newValue} {

    set offset [expr {2047+$newValue}]
    sendCommand "o $channel $offset"

}

proc scope::showShiftCal {} {

    #Check to see if the window is already open
    if {![winfo exists .shift]} {

	#Create a new window
	toplevel .shift
	wm title .shift "Scope Shift Calibration"
	wm iconname .shift "Shift"
	wm resizable .shift 0 0

	label .shift.aHighLabel	\
	    -text "Channel A\n1V-5V Range"		\
	    -font {-weight bold -size -12}

	scale .shift.aHighScale	\
	    -from 90	\
	    -to 30	\
	    -length 150	\
	    -resolution 0.1	\
	    -showvalue 1	\
	    -variable vertical::shiftStepAHigh	\
	    -command "scope::shiftCalHandler A"

	label .shift.bHighLabel	\
	    -text "Channel B\n1V-5V Range"		\
	    -font {-weight bold -size -12}

	scale .shift.bHighScale	\
	    -from 90	\
	    -to 30	\
	    -length 150	\
	    -resolution 0.1	\
	    -showvalue 1	\
	    -variable vertical::shiftStepBHigh	\
	    -command "scope::shiftCalHandler B"

	label .shift.aLowLabel	\
	    -text "Channel A\n50mV-500mV Range"		\
	    -font {-weight bold -size -12}

	scale .shift.aLowScale	\
	    -from 900	\
	    -to 300	\
	    -length 150	\
	    -resolution 1	\
	    -showvalue 1	\
	    -variable vertical::shiftStepALow	\
	    -command "scope::shiftCalHandler A"

	label .shift.bLowLabel	\
	    -text "Channel B\n50mV-500mV Range"		\
	    -font {-weight bold -size -12}

	scale .shift.bLowScale	\
	    -from 900	\
	    -to 300	\
	    -length 150	\
	    -resolution 1	\
	    -showvalue 1	\
	    -variable vertical::shiftStepBLow	\
	    -command "scope::shiftCalHandler B"

	button .shift.autoCal	\
	    -text "Auto Calibrate Shift Voltages"	\
	    -command vertical::autoShiftCalibration

	button .shift.saveCal	\
	    -text "Save Calibration Values to Device"	\
	    -command scope::saveShiftCal

	#Progress bar for saving values to the hardware
	set scope::saveOffsetProgress 0
	ttk::progressbar .shift.saveProgress	\
	    -orient horizontal	\
	    -length 200	\
	    -mode determinate	\
	    -maximum 48	\
	    -variable scope::saveOffsetProgress

	grid .shift.aHighLabel -row 0 -column 0
	grid .shift.aHighScale -row 1 -column 0
	grid .shift.bHighLabel -row 0 -column 3
	grid .shift.bHighScale -row 1 -column 3
	grid .shift.aLowLabel -row 0 -column 1
	grid .shift.aLowScale -row 1 -column 1
	grid .shift.bLowLabel -row 0 -column 4
	grid .shift.bLowScale -row 1 -column 4
	grid .shift.saveCal -row 3 -column 0 -columnspan 5 -pady 5 -sticky we
	grid .shift.saveCal -row 4 -column 0 -columnspan 5 -pady 5 -sticky we

    } else {
	#Get rid of the old offset cal window and create a new one
	destroy .shift
	scope::showShiftCal
    }

}

proc scope::shiftCalHandler {channel scaleValue} {
    if {$channel == "A"} {
	vertical::updateShift A $cursor::chAGndVoltage
    } else {
	vertical::updateShift B $cursor::chBGndVoltage
    }

}

proc scope::saveShiftCal {} {
    variable offsetALow
    variable offsetAHigh
    variable offsetBLow
    variable offsetBHigh

    #Save Channel A High Range Step Size
    set address [expr {$::nvmAddressShifts+16}]
    set vertical::shiftStepAHigh [format "%.10f" $vertical::shiftStepAHigh]
    cal::saveParameter $vertical::shiftStepAHigh $address

    #Save Channel A Low Range Step Size
    set address [expr {$address+16}]
    set vertical::shiftStepALow [format "%.10f" $vertical::shiftStepALow]
    cal::saveParameter $vertical::shiftStepALow $address

    #Save Channel B High Range Step Size
    set address [expr {$address+16}]
    set vertical::shiftStepBHigh [format "%.10f" $vertical::shiftStepBHigh]
    cal::saveParameter $vertical::shiftStepBHigh $address

    #Save Channel B Low Range Step Size
    set address [expr {$address+16}]
    set vertical::shiftStepBLow [format "%.10f" $vertical::shiftStepBLow]
    cal::saveParameter $vertical::shiftStepBLow $address

    #Write custom calibration identifier
    cal::saveParameter 1 $::nvmAddressShifts

    tk_messageBox	\
	-message "Configuration values saved."	\
	-type ok

}

proc scope::restoreShiftCal {} {
    set address $::nvmAddressShifts

    set shiftCalibrated [cal::readParameter $address]

    if {$shiftCalibrated=="1"} {
	puts "Custom shift calibration detected, loading from device"
    } else {
	puts "No custom shift calibration stored in device, using defaults"
	set vertical::shiftStepAHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepBHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepALow $vertical::shiftStepLowDefault
	set vertical::shiftStepBLow $vertical::shiftStepLowDefault
	return
    }

    #Channel A High Range Step Size
    set address [expr {$address+16}]
    set temp [cal::readParameter $address]
    if {[string is double $temp]} {
	set vertical::shiftStepAHigh $temp
    } else {
	puts "Invalid calibration value detected (shiftStepAHigh): $temp"
	set vertical::shiftStepAHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepBHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepALow $vertical::shiftStepLowDefault
	set vertical::shiftStepBLow $vertical::shiftStepLowDefault
	return
    }

    #Channel A Low Range Step Size
    set address [expr {$address+16}]
    set temp [cal::readParameter $address]
    if {[string is double $temp]} {
	set vertical::shiftStepALow $temp
    } else {
	puts "Invalid calibration value detected (shiftStepALow): $temp"
	set vertical::shiftStepAHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepBHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepALow $vertical::shiftStepLowDefault
	set vertical::shiftStepBLow $vertical::shiftStepLowDefault
	return
    }

    #Channel B High Range Step Size
    set address [expr {$address+16}]
    set temp [cal::readParameter $address]
    if {[string is double $temp]} {
	set vertical::shiftStepBHigh $temp
    } else {
	puts "Invalid calibration value detected (shiftStepBHigh): $temp"
	set vertical::shiftStepAHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepBHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepALow $vertical::shiftStepLowDefault
	set vertical::shiftStepBLow $vertical::shiftStepLowDefault
	return
    }

    #Channel B Low Range Step Size
    set address [expr {$address+16}]
    set temp [cal::readParameter $address]
    if {[string is double $temp]} {
	set vertical::shiftStepBLow $temp
    } else {
	puts "Invalid calibration value detected (shiftStepBLow): $temp"
	set vertical::shiftStepAHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepBHigh $vertical::shiftStepHighDefault
	set vertical::shiftStepALow $vertical::shiftStepLowDefault
	set vertical::shiftStepBLow $vertical::shiftStepLowDefault
	return
    }
}
# scope::autoOffsetCabliration
#
# Iterates through all available sampling rates and calibrates the offset for each input channel and gain setting.
proc scope::autoOffsetCalibration {} {

    set answer [tk_messageBox	\
		    -default no	\
		    -icon warning	\
		    -message "WARNING: Auto-Calibrate will replace all scope offset values.\nWould you like to continue?"	\
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
	-maximum 4	\
	-variable scope::autoOffsetProgress

    grid .autoOffset.status -row 0 -column 0
    grid .autoOffset.progress -row 1 -column 0

    raise .autoOffset
    focus .autoOffset
    grab .autoOffset

    #Use single-shot trigger during auto-calibration
    #set trigger::triggerMode "Single-Shot"
    #trigger::selectTriggerMode
    #after 50
    #update
    #trigger::manualTrigger
    #after 100
    #update

    #Flag to indicate that we are calibrating the offsets
    set scope::scopeOffsetCalibrationInProgress 1

    #Select High Range for both channels
    set scope::autoOffsetStatus "Range: 1.0 - 5.0V"
    set vertical::verticalIndexA 6
    set vertical::verticalIndexB 6
    #vertical::updateIndicator .scope.verticalA A
    #vertical::updateIndicator .scope.verticalB B
    vertical::adjustVertical .scope.verticalA A update
    vertical::adjustVertical .scope.verticalB B update

    #Zero the offsets
    puts "===Zeroing A High"
    scope::zeroOffset A
    incr scope::autoOffsetProgress
    update
    puts "===Zeroing B High"
    scope::zeroOffset B
    incr scope::autoOffsetProgress
    update

    #Select Low Range for both channels
    set scope::autoOffsetStatus "Range: 20mV - 500mV"
    set vertical::verticalIndexA 2
    set vertical::verticalIndexB 2
    #vertical::updateIndicator .scope.verticalA A
    #vertical::updateIndicator .scope.verticalB B
    #vertical::updateVertical
    vertical::adjustVertical .scope.verticalA A update
    vertical::adjustVertical .scope.verticalB B update

    vwait scope::scopeOffsetData
    vwait scope::scopeOffsetData
    vwait scope::scopeOffsetData

    #Zero the offsets
    puts "===Zeroing A Low"
    scope::zeroOffset A
    incr scope::autoOffsetProgress
    update
    puts "===Zeroing B Low"
    scope::zeroOffset B
    incr scope::autoOffsetProgress
    update

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
	    if {$vertical::verticalIndexA > 5} {
		.offset.aHighScale set $testOffset
	    } else {
		.offset.aLowScale set $testOffset
	    }
	} else {
	    if {$vertical::verticalIndexB > 5} {
		.offset.bHighScale set $testOffset
	    } else {
		.offset.bLowScale set $testOffset
	    }
	}

	set measuredOffset [scope::calculateAverage $channel]
	puts "Measured $measuredOffset"

	if {$measuredOffset == 511} {
	    break
	}

	if {$measuredOffset > 511} {
	    set minValue $testOffset
	} else {
	    set maxValue $testOffset
	}
	update
    }

}

proc scope::calculateAverage {channel} {

    for {set i 0} {$i < 2} {incr i} {
	#Capture one waveform
	#trigger::singleShotReset
	#after 100
	#update
	#trigger::manualTrigger
	#update
	#Wait for the data to arrive from the scope
	vwait scope::scopeOffsetData
    }

    if {$channel == "A"} {
	set data [lindex $scope::scopeData 0]
    } else {
	set data [lindex $scope::scopeData 1]
    }

    set average 0
    for {set i 0} {$i < 4096} {incr i} {
	set average [expr {$average+[lindex $data $i]}]
    }
    set average [expr {round($average/4096.0)}]

    return $average

}

proc vertical::autoVerticalCalibration {range} {

    set answer [tk_messageBox	\
		    -default no	\
		    -icon warning	\
		    -message "WARNING: Auto-Calibrate will replace all scope vertical calibration values.\nWould you like to continue?"	\
		    -parent .calibrate	\
		    -title "Auto-Calibrate Warning"	\
		    -type yesno]

    if {$answer=="no"} {return}

    if {$range=="high"} {
	set vRef "2.5V"
    } else {
	set vRef "250mV"
    }
    tk_messageBox	\
	-default ok	\
	-icon warning	\
	-message "Connect a $vRef voltage reference to both channels and click OK to proceed"	\
	-parent .calibrate	\
	-title "Connect Calibration Sources"		\
	-type ok

    #Create a window to display the automatic offset calibration progress bar
    toplevel .autoCalibration
    wm title .autoCalibration "Automatic Calibration"
    wm iconname .autoCalibration "Auto Cal"
    wm resizable .autoCalibration 0 0

    #Create a label to display the auto-calibration status
    label .autoCalibration.status	\
	-text "Calibrating..."

    #Create a progress bar
    set scope::autoCalibrationProgress 0
    ttk::progressbar .autoCalibration.progress	\
	-orient horizontal	\
	-length 200	\
	-mode determinate	\
	-maximum 50	\
	-variable scope::autoCalibrationProgress

    grid .autoCalibration.status -row 0 -column 0
    grid .autoCalibration.progress -row 1 -column 0

    update
    raise .autoCalibration
    focus .autoCalibration
    grab .autoCalibration
    update

    #Select Range
    if {$range == "high"} {
	#Select High Range for both channels
	.autoCalibration.status	configure -text "Range: 1.0 - 5.0V"
	update
	set vertical::verticalIndexA 6
	set vertical::verticalIndexB 6
	vertical::adjustVertical .scope.verticalA A update
	vertical::adjustVertical .scope.verticalB B update
	vertical::calibrate A 2.5
	set scope::autoCalibrationProgress 25
	vertical::calibrate B 2.5
	set scope::autoCalibrationProgress 50
    } else {
	#Select Low Range for both channels
	.autoCalibration.status	configure -text "Range: 20mV - 500mV"
	update
	set vertical::verticalIndexA 3
	set vertical::verticalIndexB 3
	vertical::adjustVertical .scope.verticalA A update
	vertical::adjustVertical .scope.verticalB B update
	vertical::calibrate A 0.250
	set scope::autoCalibrationProgress 25
	vertical::calibrate B 0.250
	set scope::autoCalibrationProgress 50
    }

    destroy .autoCalibration
    update
}

proc vertical::calibrate {channel voltage} {

    if {$voltage >= 1.0} {
	set minValue 0.01
	set maxValue 0.07
    } else {
	set minValue 0.001
	set maxValue 0.007
    }

    automeasure::showMeasurements

    #Hunt down the correct step voltage
    for {set i 0} {$i <25} {incr i} {

	puts "Iteration $i"
	puts "Max $maxValue Min $minValue"

	set testValue [expr {($maxValue-$minValue)/2+$minValue}]
	puts "Testing value $testValue"
	if {$channel == "A"} {
	    if {$voltage >= 1.0} {
		.calibrate.a.high set $testValue
		vwait automeasure::autoAverageA
		vwait automeasure::autoAverageA
		set measuredAverage [string range $automeasure::autoAverageA 0 end-2]
	    } else {
		.calibrate.a.low set $testValue
		vwait automeasure::autoAverageA
		vwait automeasure::autoAverageA
		set measuredAverage [string range $automeasure::autoAverageA 0 end-3]
		set measuredAverage [expr {$measuredAverage/1000.0}]
	    }

	} else {
	    if {$voltage >= 1.0} {
		.calibrate.b.high set $testValue
		vwait automeasure::autoAverageB
		vwait automeasure::autoAverageB
		set measuredAverage [string range $automeasure::autoAverageB 0 end-2]
	    } else {
		.calibrate.b.low set $testValue
		vwait automeasure::autoAverageB
		vwait automeasure::autoAverageB
		set measuredAverage [string range $automeasure::autoAverageB 0 end-3]
		set measuredAverage [expr {$measuredAverage/1000.0}]
	    }

	}

	puts "Measured average: $measuredAverage"

	if {$measuredAverage == $voltage} {
	    break;
	}

	if {$measuredAverage > $voltage} {
	    set maxValue $testValue
	} else {
	    set minValue $testValue
	}
	incr scope::autoCalibrationProgress

	update
    }

}

proc vertical::autoShiftCalibration {} {

    set answer [tk_messageBox	\
		    -default no	\
		    -icon warning	\
		    -message "WARNING: Auto-Calibrate will replace all scope vertical shift calibration values.\nThis calibration should only be performed after calibrating the scope offsets and vertical scale.\nWould you like to continue?"	\
		    -parent .shift	\
		    -title "Auto-Calibrate Warning"	\
		    -type yesno]

    tk_messageBox	\
	-default ok	\
	-icon warning	\
	-message "Disconnect all signals from both channels and click OK to proceed"	\
	-parent .shift	\
	-title "Connect Calibration Sources"		\
	-type ok

    #Create a window to display the automatic offset calibration progress bar
    toplevel .autoShift
    wm title .autoShift "Automatic Calibration"
    wm iconname .autoShift "Auto Cal"
    wm resizable .autoShift 0 0

    #Create a label to display the auto-calibration status
    label .autoShift.status	\
	-text "Calibrating..."

    #Create a progress bar
    set scope::autoCalibrationProgress 0
    ttk::progressbar .autoShift.progress	\
	-orient horizontal	\
	-length 200	\
	-mode determinate	\
	-maximum 100	\
	-variable scope::autoCalibrationProgress

    grid .autoShift.status -row 0 -column 0
    grid .autoShift.progress -row 1 -column 0

    update
    raise .autoShift
    focus .autoShift
    grab .autoShift
    update

    #A High Range
    .autoShift.status configure -text "Channel A Range: 1.0 - 5.0V"
    update
    set vertical::verticalIndexA 8
    vertical::adjustVertical .scope.verticalA A update
    vertical::calibrateShift A high
    set scope::autoCalibrationProgress 25

    #B High Range
    .autoShift.status configure -text "Channel B Range: 1.0 - 5.0V"
    update
    set vertical::verticalIndexB 8
    vertical::adjustVertical .scope.verticalB B update
    vertical::calibrateShift B high
    set scope::autoCalibrationProgress 50

    #A Low Range
    .autoShift.status configure -text "Channel A Range: 20mV - 500mV"
    update
    set vertical::verticalIndexA 5
    vertical::adjustVertical .scope.verticalA A update
    vertical::calibrateShift A low
    set scope::autoCalibrationProgress 75

    #B High Range
    .autoShift.status configure -text "Channel B Range: 20mV - 500mV"
    update
    set vertical::verticalIndexB 5
    vertical::adjustVertical .scope.verticalB B update
    vertical::calibrateShift B low
    set scope::autoCalibrationProgress 100

    destroy .autoShift
    update
}

proc vertical::calibrateShift {channel range} {

    if {$range == "high"} {
	set minValue 30
	set maxValue 90
	set voltage 20
    } else {
	set minValue 300
	set maxValue 900
	set voltage 2
    }

    automeasure::showMeasurements

    cursor::moveChAGnd 52
    cursor::moveChBGnd 52

    #Hunt down the correct step voltage
    for {set i 0} {$i <25} {incr i} {

	puts "Iteration $i"
	puts "Max $maxValue Min $minValue"

	set testValue [expr {($maxValue-$minValue)/2.0+$minValue}]
	puts "Testing value $testValue"

	if {$channel == "A"} {
	    if {$range == "high"} {
		.shift.aHighScale set $testValue
		vwait automeasure::autoAverageA
		vwait automeasure::autoAverageA
		set measuredAverage [string range $automeasure::autoAverageA 0 end-2]
	    } else {
		.shift.aLowScale set $testValue
		vwait automeasure::autoAverageA
		vwait automeasure::autoAverageA
		set measuredAverage [string range $automeasure::autoAverageA 0 end-2]
	    }

	} else {
	    if {$range == "high"} {
		.shift.bHighScale set $testValue
		vwait automeasure::autoAverageB
		vwait automeasure::autoAverageB
		set measuredAverage [string range $automeasure::autoAverageB 0 end-2]
	    } else {
		.shift.bLowScale set $testValue
		vwait automeasure::autoAverageB
		vwait automeasure::autoAverageB
		set measuredAverage [string range $automeasure::autoAverageB 0 end-2]
	    }

	}

	puts "Measured average: $measuredAverage"

	if {$measuredAverage == $voltage} {
	    break;
	}

	if {$measuredAverage > $voltage} {
	    set maxValue $testValue
	} else {
	    set minValue $testValue
	}
	incr scope::autoCalibrationProgress

	update
    }

}

namespace eval mk2 {

    set fpgaProgress 0

}

#proc mk2::device2Write {} {
#
#	set pageAddress 0
#	set byteAddress 0
#
#	firmware::addLog "Writing to Device 2..."
#
#	firmware::addChar "0%"
#
#	set endPage [expr {ceil($firmware::device2FlashEnd/256.0)}]
#
#	for {set pageAddress 0} {$pageAddress < $endPage} {incr pageAddress} {
#		#Fill the buffer
#		set firmware::status writingBuffer
#		firmware::sendByte "w"
#		firmware::sendByte [format "%c" [expr {($pageAddress>>8) & 0xFF}]]
#		firmware::sendByte [format "%c" [expr {($pageAddress & 0xFF)}]]
#		for {set byteAddress 0} {$byteAddress < 256} {incr byteAddress} {
#			firmware::sendByte [format "%c" [lindex $firmware::device2Data [expr {$pageAddress*256+$byteAddress}]]]
#		}
#		set firmware::afterHandle [after 5000 {set firmware::status timeout}]
#		vwait firmware::status
#		after cancel $firmware::afterHandle
#		if { $firmware::status != "WOK"} {
#			firmware::addLog ""
#			firmware::addLog "Device 2 flash write failed at address $pageAddress"
#			return 0
#		}
#
#		.firmware.log delete "insert linestart" "insert lineend"
#		firmware::addChar "[expr {round($pageAddress*1.0/$endPage*100)}]%"
#
#	}
#
#	.firmware.log delete "insert linestart" "insert lineend"
#	firmware::addLog "100%"
#	firmware::addLog "Writing to Device 2 complete."
#
#	return 1
#
#}

#Show Firmware GUI
#----------------------
#This procedure builds the firmware upgrade dialog box or
#restores it if it has already been created.
proc mk2::showFpgaUpgrade {} {

    if {$firmware::fpgaIsCurrent} {
	tk_messageBox	\
	    -message "Your FPGA image is current.  No firmware update required.\n"	\
	    -parent .	\
	    -title "Firmware Info"	\
	    -type ok
	return
    }

    if {![winfo exists .fpga]} {

	toplevel .fpga
	wm title .fpga "FPGA Upgrade"

	frame .fpga.manual	\
	    -relief groove	\
	    -borderwidth 2

	label .fpga.manual.warning	\
	    -text 	"FPGA IMAGE UPGRADE:\n\nThis process will ERASE and upgrade the firmware on your device.\n\nDo not disconnect your device or interrupt the software during this process.\n\nDistrupting this process can damage your device."	\
	    -anchor center

	button .fpga.manual.start	\
	    -text "Start upgrade"	\
	    -command {.fpga.manual.start configure -state disabled; .fpga.manual.cancel configure -state disabled; mk2::fpgaUpgrade}

	button .fpga.manual.cancel	\
	    -text "Exit"	\
	    -command {destroy .fpga}

	grid .fpga.manual.warning -row 0 -column 0 -pady 5 -columnspan 2
	grid .fpga.manual.start -row 1 -column 0 -pady 5 -padx 5
	grid .fpga.manual.cancel -row 1 -column 1 -pady 5 -padx 5

	#Progress bar for saving values to the hardware
	set mk2::fpgaProgress 0

	ttk::progressbar .fpga.progressBar	\
	    -orient horizontal	\
	    -length 300	\
	    -mode determinate	\
	    -maximum 100	\
	    -variable mk2::fpgaProgress

	text  .fpga.log	\
	    -width 55		\
	    -height 15		\
	    -undo 1

	grid .fpga.manual -row 0 -stick we
	grid .fpga.progressBar -row 1 -pady 5
	grid .fpga.log -row 2

	wm iconify .
	wm iconify .wave
	wm iconify .digio
	raise .fpga
	focus .fpga
	grab .fpga

	wm protocol .fpga WM_DELETE_WINDOW {
	    destroy .fpga
	    update
	    destroy .
	}

    } else {
	wm deiconify .fpga
	raise .fpga
	focus .fpga
    }
}

proc mk2::addLog {logText} {

    .fpga.log insert end "$logText\n"
    .fpga.log yview moveto 1
}

proc mk2::addChar {char} {

    .fpga.log insert end $char
    .fpga.log yview moveto 1
}

proc mk2::fpgaUpgrade {} {

    #Kill any on-going scope captures
    sendCommand k

    set answer [tk_messageBox	\
		    -default no	\
		    -message "WARNING: The firmware update process can take several minutes.\nDo not unplug the device or interrupt the process.\nWould you like to continue?"	\
		    -parent .fpga	\
		    -title "Firmware Warning"	\
		    -type yesno
	       ]

    if {$answer != "yes"} {
	wm deiconify .wave
	wm deiconify .digio
	wm deiconify .
	raise .
	focus .
	destroy .fpga
	return
    }

    if {$firmware::fpgaRev=="0x01"} {
	mk2::addLog ""
	mk2::addLog "Production Rev 1 FPGA Image Detected!"
	mk2::addLog "Performing full FPGA image replacement."
	mk2::addLog "DO NOT INTERRUPT THIS PROCESS OR YOUR DEVICE WILL"
	mk2::addLog "NO LONGER FUNCTION."
	mk2::addLog ""
    } else {
	mk2::addLog ""
	mk2::addLog "Production Rev 2+ FPGA Image Detected!"
	mk2::addLog "Performing selective FPGA upgrade"
	mk2::addLog "DO NOT INTERRUPT THIS PROCESS OR YOUR DEVICE WILL"
	mk2::addLog "NO LONGER FUNCTION."
	mk2::addLog ""
    }

    #Put the device into FPGA programming mode
    after 1000
    sendCommand !
    update
    after 1000
    update

    #Open the hex file
    mk2::addLog "Opening FPGA image file..."
    if {![mk2::openDevice2File "./Firmware/MK2/Device2.hex"]} {
	#Restore the device from FPGA programming mode
	usbSerial::sendByte !
	update
	return
    }
    mk2::addLog "Reading file complete"
    set mk2::fpgaProgress 10
    update

    #Erase the device
    mk2::addLog "Erasing Device 2..."
    if {![mk2::device2Erase]} {
	mk2::addLog "Erase Failed."
	#Restore the device from FPGA programming mode
	usbSerial::sendByte !
	update
	return
    }
    mk2::addLog "Erase complete."
    set mk2::fpgaProgress 40
    update

    #Program and verify the device
    mk2::addLog "Programming device #2..."
    if {![mk2::device2Write]} {
	mk2::addLog "Programming failed."
	#Restore the device from FPGA programming mode
	usbSerial::sendByte !
	update
	return
    }
    mk2::addLog "Programming Complete."
    set mk2::fpgaProgress 70
    update

    #Restore the device from FPGA programming mode
    usbSerial::sendByte !
    update

    tk_messageBox	\
	-message "Firmware upgrade complete.\nPlease unplug the CircuitGear and\npress OK to continue..."	\
	-default ok	\
	-type ok

    set mk2::fpgaProgress 80
    update

    tk_messageBox	\
	-message "Please reconnect the CircuitGear and press OK to continue..."	\
	-default ok	\
	-type ok

    set mk2::fpgaProgress 100
    update

    wm deiconify .wave
    wm deiconify .digio
    wm deiconify .
    raise .
    focus .
    destroy .fpga

    update

    usbSerial::openSerialPort

}

proc mk2::openDevice2File {hexFile} {

    if {[catch {set ltotal [firmware::linecount $hexFile]} result]} {
	mk2::addLog "Unable to read hex file: $hexFile"
	puts "$result"
	return 0
    }

    if {[catch {set fileHandle [open $hexFile r]} result]} {
	mk2::addLog "Unable to open hex file: $hexFile"
	return 0
    } else {
	mk2::addLog "Open firmware file...complete."
	update
    }

    set firmware::device2Data {}
    for {set i 0} {$i < $firmware::device2FlashSize} {incr i} {
	lappend firmware::device2Data 255
    }

    set baseAddress 0
    set start $firmware::flashSize
    set end 0

    mk2::addLog "Reading firmware file..."
    mk2::addChar "0%"
    update

    set lcount 0

    set nextUpdate 5

    while {[gets $fileHandle line] >= 0} {

	set record [firmware::processRecord $line]
	if {$record==-1} {
	    mk2::addLog "Failed to process hex file."
	    close $fileHandle
	    return 0
	}

	#Process record according to type
	switch [lindex $record 2] {
	    0 {
		set offset [lindex $record 1]
		set length [lindex $record 0]
		set data [lindex $record 3]
		if {[expr {$baseAddress + $offset + $length}] > $firmware::device2FlashSize} {
		    mk2::addLog "HEX file defines data outside of buffer limits!"
		    mk2::addLog "Offset was $offset"
		    close $fileHandle
		    return 0
		}
		#Copy the data into our main data buffer
		for {set dataPos 0} {$dataPos < $length} {incr dataPos} {
		    lset firmware::device2Data [expr {$baseAddress+$offset+$dataPos}] [lindex $data $dataPos]
		}
		#Update byte usage
		if {[expr {$baseAddress+$offset}]<$start} {
		    set start [expr {$baseAddress+$offset}]
		}
		if {[expr {$baseAddress+$offset+$length-1}] > $end} {
		    set end [expr {$baseAddress+$offset+$length-1}]
		}
	    } 1 {
		mk2::addLog "\nReading firmware file...complete."
		close $fileHandle
		#Figure out the last sector in the flash file
		set lastByte $firmware::device2FlashSize
		for {set i 0} {$i < $firmware::device2FlashSize} {incr i} {
		    if {[lindex $firmware::device2Data $i] != 255} {
			set lastByte $i
		    }
		}
		puts "Last data byte: $lastByte"
		set firmware::device2LastSector [expr {floor($lastByte/65536-8.0)}]
		puts "Last sector: $firmware::device2LastSector"
		return 1
	    } 4 {
		set data [lindex $record 3]
		set MSB [lindex $data 0]
		set LSB [lindex $data 1]
		set baseAddress [expr {($MSB<<24)+($LSB<<16)}]
		puts "New base address $baseAddress"
	    }
	}

	set currentProgress [expr {round($lcount*1.0/$ltotal*100)}]
	if {$currentProgress >= $nextUpdate} {
	    .fpga.log delete "insert linestart" "insert lineend"
	    mk2::addChar "$currentProgress%"
	    set nextUpdate [expr {$nextUpdate+5}]
	    update
	}

	incr lcount

    }

    #We should never reach here
    mk2:addLog "ERROR: Premature end of file encountered!"
    return 0

}

proc mk2::device2Erase {} {

    update

    for {set i 0} {$i <= $firmware::device2LastSector} {incr i} {

	mk2::addLog "Erasing Sector $i"
	update

	#Start the erase cycle
	usbSerial::sendByte "X"
	usbSerial::sendByte [format "%c" $i]

	set firmware::eraseStatus starting

	while {($firmware::eraseStatus!="X")} {
	    update
	    set firmware::afterHandle [after 5000 {set firmware::status timeout}]
	    vwait firmware::eraseStatus
	    after cancel $firmware::afterHandle
	    update
	    if { $firmware::eraseStatus == "f"} {
		mk2::addLog ""
		mk2::addLog "Device 2 flash erase failed."
		return 0
	    }
	    if {$firmware::eraseStatus=="i"} {
		mk2::addChar "."
		update
	    }
	    if {$firmware::eraseStatus == "timeout"} {
		mk2::addLog ""
		mk2::addLog "Device 2 flash erase failed.  Timeout."
		return 0
	    }
	}

	mk2::addLog "Sector $i Erased"

    }

    mk2::addLog ""
    mk2::addLog "Device 2 flash erase complete."
    return 1

}

proc mk2::device2Write {} {

    set pageAddress 0
    set byteAddress 0

    mk2::addLog "Writing to Device 2..."

    mk2::addChar "0%"

    set endPage [expr {ceil(($firmware::device2LastSector+1)*256.0)}]

    for {set pageAddress 0} {$pageAddress <= $endPage} {incr pageAddress} {
	#Fill the buffer
	set firmware::status writingBuffer
	usbSerial::sendByte "w"
	usbSerial::sendByte [format "%c" [expr {($pageAddress>>8) & 0xFF}]]
	usbSerial::sendByte [format "%c" [expr {($pageAddress & 0xFF)}]]
	for {set byteAddress 0} {$byteAddress < 256} {incr byteAddress} {
	    usbSerial::sendByte [format "%c" [lindex $firmware::device2Data [expr {($pageAddress+2048)*256+$byteAddress}]]]
	}
	set firmware::afterHandle [after 8000 {set firmware::status timeout}]
	vwait firmware::status
	after cancel $firmware::afterHandle
	if { $firmware::status != "WOK"} {
	    mk2::addLog ""
	    mk2::addLog "Device 2 flash write failed at address $pageAddress"
	    set pageAddress [expr {$pageAddress - 1}]
	    return 0
	}

	.fpga.log delete "insert linestart" "insert lineend"
	mk2::addChar "[expr {round(($pageAddress*1.0/$endPage)*100)}]%"

    }

    .fpga.log delete "insert linestart" "insert lineend"
    mk2::addLog "100%"
    mk2::addLog "Writing to Device 2 complete."

    return 1

}

#Additional tone burst controls
set wavePath [wave::getWavePath]

if {![winfo exists $wavePath.trigger]} {

    frame $wavePath.trigger	\
	-relief groove	\
	-borderwidth 2

    frame $wavePath.trigger.waveMode	\
	-relief groove	\
	-borderwidth 1

    label $wavePath.trigger.waveMode.title	\
	-text "Waveform Generator\nTrigger Mode:"	\
	-font {-weight bold -size -12}

    radiobutton $wavePath.trigger.waveMode.normal	\
	-text "Free-Running"	\
	-value normal	\
	-variable wave::waveTriggerMode	\
	-command wave::selectWaveTriggerMode

    radiobutton $wavePath.trigger.waveMode.triggered	\
	-text "Triggered"	\
	-value triggered	\
	-variable wave::waveTriggerMode	\
	-command wave::selectWaveTriggerMode

    grid $wavePath.trigger.waveMode.title -row 0 -sticky w
    grid $wavePath.trigger.waveMode.normal -row 1 -sticky w
    grid $wavePath.trigger.waveMode.triggered -row 2 -sticky w

    #Frame for waveform generator output mode controls
    frame $wavePath.trigger.outMode	\
	-relief groove	\
	-borderwidth 1

    label $wavePath.trigger.outMode.title	\
	-text "Waveform Generator\nOutput Mode:"	\
	-font {-weight bold -size -12}

    radiobutton $wavePath.trigger.outMode.normal	\
	-text "Continuous"	\
	-value continuous	\
	-variable wave::waveOutputMode	\
	-command wave::selectWaveOutputMode

    radiobutton $wavePath.trigger.outMode.toneBurst	\
	-text "Tone Burst"	\
	-value toneBurst		\
	-variable wave::waveOutputMode	\
	-command wave::selectWaveOutputMode

    grid $wavePath.trigger.outMode.title -row 0 -sticky w
    grid $wavePath.trigger.outMode.normal -row 1 -sticky w
    grid $wavePath.trigger.outMode.toneBurst -row 2 -sticky w

    #Frame for trigger source selectors
    frame $wavePath.trigger.source	\
	-relief groove	\
	-borderwidth 1

    label $wavePath.trigger.source.title	\
	-text "Trigger Source:"	\
	-font {-weight bold -size -12}

    radiobutton $wavePath.trigger.source.external	\
	-text "External"	\
	-value external	\
	-variable wave::triggerSource	\
	-command wave::selectTriggerSource

    radiobutton $wavePath.trigger.source.manual	\
	-text "Manual"	\
	-value manual	\
	-variable wave::triggerSource	\
	-command wave::selectTriggerSource

    grid $wavePath.trigger.source.title -row 0 -sticky w
    grid $wavePath.trigger.source.external -row 1 -sticky w
    grid $wavePath.trigger.source.manual -row 2 -sticky w

    frame $wavePath.trigger.cycles	\
	-relief groove	\
	-borderwidth 1

    label $wavePath.trigger.cycles.title	\
	-text "Trigger Cycles"	\
	-font {-weight bold -size -12}

    label $wavePath.trigger.cycles.onLabel	\
	-text "On:"	\
	-width 8

    button $wavePath.trigger.cycles.onCycles	\
	-textvariable wave::onCycles	\
	-command wave::modifyOnCycles	\
	-width 7

    label $wavePath.trigger.cycles.offLabel	\
	-text "Off:"	\
	-width 8

    button $wavePath.trigger.cycles.offCycles	\
	-textvariable wave::offCycles	\
	-command wave::modifyOffCycles		\
	-width 7

    label $wavePath.trigger.cycles.repeatLabel	\
	-text "Repeat:"	\
	-width 8

    button $wavePath.trigger.cycles.repeatCycles	\
	-textvariable wave::repeatCycles	\
	-command wave::modifyRepeatCycles	\
	-width 7

    grid $wavePath.trigger.cycles.title -row 0 -columnspan 2
    grid $wavePath.trigger.cycles.onLabel -row 1 -column 0
    grid $wavePath.trigger.cycles.onCycles -row 1 -column 1
    grid $wavePath.trigger.cycles.offLabel -row 2 -column 0
    grid $wavePath.trigger.cycles.offCycles -row 2 -column 1
    grid $wavePath.trigger.cycles.repeatLabel -row 3 -column 0
    grid $wavePath.trigger.cycles.repeatCycles -row 3 -column 1

    button $wavePath.trigger.manualTrigger	\
	-text "Manual Trigger"	\
	-command {sendCommand WT}

    grid $wavePath.trigger.waveMode -row 1 -column 0 -sticky news -columnspan 2
    grid $wavePath.trigger.outMode -row 2 -column 0 -sticky news -columnspan 2
    grid $wavePath.trigger.source -row 3 -column 0 -sticky news -columnspan 2
    grid $wavePath.trigger.cycles -row 4 -column 0 -sticky news -columnspan 2
    grid $wavePath.trigger.manualTrigger -row 5 -column 0 -sticky news -columnspan 2 -pady 10

    grid $wavePath.trigger -row 0 -column 4 -sticky n -padx 5
}

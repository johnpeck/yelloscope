#File: calibration.tcl
#Syscomp USB Oscilloscope GUI
#Scope Vertical Calibration Procedures

#JG
#Copyright 2013 Syscomp Electronic Design
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

namespace eval cal {

variable scaleAHigh
variable scaleALow
variable scaleBHigh
variable scaleBLow

set miniHighStepMax 0.040
set miniHighStepMin 0.010
set miniLowStepMax 0.004
set miniLowStepMin 0.001

set mk2HighStepMax 0.07
set mk2HighStepMin 0.01
set mk2LowStepMax 0.007
set mk2LowStepMin 0.001

}

#Calibration GUI
#------------------
#Thi procedure creates the calibration window and sets up all the widgets
#associate with calibrating the vertical scales.
proc cal::calibration {} {

	#Create a new window for the calibration controls
	if {[winfo exists .calibrate]} {
		raise .calibrate
		return
	}
	toplevel .calibrate
	wm title .calibrate "Scope Vertical Calibration"

	#Limits for sliders
	if {($::deviceType=="mini")||($::deviceType=="sig")} {
		set highStepMax $cal::miniHighStepMax
		set highStepMin $cal::miniHighStepMin
		set lowStepMax $cal::miniLowStepMax
		set lowStepMin $cal::miniLowStepMin
	} else {
		set highStepMax $cal::mk2HighStepMax
		set highStepMin $cal::mk2HighStepMin
		set lowStepMax $cal::mk2LowStepMax
		set lowStepMin $cal::mk2LowStepMin
	}
	
	#Create a frame for each channel
	frame .calibrate.a -relief groove -borderwidth 3
	frame .calibrate.b -relief groove -borderwidth 3
	
	#Channel A Calibration Controls
	label .calibrate.chanA	\
		-text "Channel A"
	
	label .calibrate.a.highLabel	\
		-text "High Range (500mV-5V/div)\nA/D Step \[V/step\]"
	scale .calibrate.a.high	\
		-from $highStepMax	\
		-to $highStepMin	\
		-variable cal::scaleAHigh	\
		-orient vertical	\
		-tickinterval 0	\
		-resolution 0.0001	\
		-length 200		\
		-command {cal::calibrateVertical a high}
		
	label .calibrate.a.lowLabel	\
		-text "Low Range (10mV-200mV/div)\nA/D Step \[V/step\]"
	scale .calibrate.a.low	\
		-from $lowStepMax	\
		-to $lowStepMin	\
		-variable cal::scaleALow	\
		-orient vertical	\
		-tickinterval 0	\
		-resolution 0.00001	\
		-length 200	\
		-command {cal::calibrateVertical a low}
	
	grid .calibrate.a.highLabel -row 0 -column 0
	grid .calibrate.a.high -row 1 -column 0
	grid .calibrate.a.lowLabel -row 0 -column 1
	grid .calibrate.a.low -row 1 -column 1

	#Channel B Calibration Controls
	label .calibrate.chanB	\
		-text "Channel B"
	
	#Channel B Calibration Controls
	label .calibrate.b.highLabel	\
		-text "High Range (500mV-5V/div)\nA/D Step \[V/step\]"
	scale .calibrate.b.high	\
		-from $highStepMax	\
		-to $highStepMin	\
		-variable cal::scaleBHigh	\
		-orient vertical	\
		-tickinterval 0	\
		-resolution 0.0001	\
		-length 200		\
		-command {cal::calibrateVertical b high}
		
	label .calibrate.b.lowLabel	\
		-text "Low Range (10mV-200mV/div)\nA/D Step \[V/step\]"
	scale .calibrate.b.low	\
		-from $lowStepMax	\
		-to $lowStepMin	\
		-variable cal::scaleBLow	\
		-orient vertical	\
		-tickinterval 0	\
		-resolution 0.00001	\
		-length 200	\
		-command {cal::calibrateVertical b low}
	
	grid .calibrate.b.highLabel -row 0 -column 0
	grid .calibrate.b.high -row 1 -column 0
	grid .calibrate.b.lowLabel -row 0 -column 1
	grid .calibrate.b.low -row 1 -column 1
		
	button .calibrate.restoreDefaults	\
		-text "Restore Defaults"	\
		-command {cal::restoreDefaults}
	
	button .calibrate.calibrateHigh	\
		-text "Calibrate High Scale"	\
		-command {vertical::autoVerticalCalibration high}
	
	button .calibrate.calibrateLow	\
		-text "Calibrate Low Scale"	\
		-command {vertical::autoVerticalCalibration low}
	
	button .calibrate.saveCalibration	\
		-text "Save Calibration Values"	\
		-command {cal::saveCalibration}
	
	grid .calibrate.chanA -row 0 -column 0 -sticky w
	grid .calibrate.a -row 1 -column 0
	grid .calibrate.chanB -row 0 -column 1 -sticky w
	grid .calibrate.b -row 1 -column 1 -sticky w
	if {$::deviceType=="mk2"} {
		grid .calibrate.calibrateHigh -row 2 -column 0 -columnspan 2
		grid .calibrate.calibrateLow -row 3 -column 0 -columnspan 2
	}
	grid .calibrate.restoreDefaults -row 4 -column 0 -columnspan 2
	grid .calibrate.saveCalibration -row 5 -column 0 -columnspan 2
}

#Calibrate Vertical Scale
#---------------------------
#This procedure is the service routine called by each of the calibration sliders.
#It performs the necessary conversion calculations and updates the global arrays
#which hold the vertical constants for scaling the vertical axes.
proc cal::calibrateVertical {chan scale sliderValue} {
	
	if {$chan=="a"} {
		if {$scale=="high"} {
			set vertical::stepSizeAHigh $cal::scaleAHigh
		} elseif {$scale=="low"} {
			set vertical::stepSizeALow $cal::scaleALow
		}
	} elseif {$chan=="b"} {
		if {$scale=="high"} {
			set vertical::stepSizeBHigh $cal::scaleBHigh
		} elseif {$scale=="low"} {
			set vertical::stepSizeBLow $cal::scaleBLow
		}
	}

	vertical::updateVertical
	
}

#Restore Defaults
#-------------------
#This procedure restores all of the vertical scale settings to their defaults
proc cal::restoreDefaults {} {
	
	set vertical::stepSizeAHigh $vertical::stepSizeHighDefault
	set vertical::stepSizeALow  $vertical::stepSizeLowDefault
	set vertical::stepSizeBHigh $vertical::stepSizeHighDefault
	set vertical::stepSizeBLow $vertical::stepSizeLowDefault
	
	set cal::scaleAHigh $vertical::stepSizeHighDefault
	set cal::scaleALow $vertical::stepSizeLowDefault
	set cal::scaleBHigh $vertical::stepSizeHighDefault
	set cal::scaleBLow $vertical::stepSizeLowDefault
	
	vertical::updateVertical
}

#Save Calibration
#-------------------
#This procedure saves the current calibration values into a text configuration
#file that is used to configure the vertical scaling each time the program
#is started.
proc cal::saveCalibration {} {
	
	#Save Channel A High Range Step Size
	set address [expr {$::nvmAddressVertical+16}]
	set vertical::stepSizeAHigh [format "%.13f" $vertical::stepSizeAHigh]
	cal::saveParameter $vertical::stepSizeAHigh $address
	#Save Channel A Low Range Step Size
	set address [expr {$address+16}]
	set vertical::stepSizeALow [format "%.13f" $vertical::stepSizeALow]
	cal::saveParameter $vertical::stepSizeALow $address
	#Save Channel B High Range Step Size
	set address [expr {$address+16}]
	set vertical::stepSizeBHigh [format "%.13f" $vertical::stepSizeBHigh]
	cal::saveParameter $vertical::stepSizeBHigh $address
	#Save Channel B Low Range Step Size
	set address [expr {$address+16}]
	set vertical::stepSizeBLow [format "%.13f" $vertical::stepSizeBLow]
	cal::saveParameter $vertical::stepSizeBLow $address
	
	#Write custom calibration identifier
	cal::saveParameter 1 $::nvmAddressVertical
	
	tk_messageBox	\
		-message "Configuration values saved."	\
		-type ok	
	
}

proc cal::readConfig {} {

	set address $::nvmAddressVertical

	set verticalCalibrated [cal::readParameter $address]
	
	if {$verticalCalibrated=="1"} {
		puts "Custom vertical calibration detected, loading from device"
	} else {
		puts "No custom vertical calibration stored in device, using defaults"
		set cal::scaleAHigh $vertical::stepSizeAHigh
		set cal::scaleALow $vertical::stepSizeALow
		set cal::scaleBHigh $vertical::stepSizeBHigh
		set cal::scaleBLow $vertical::stepSizeBLow
	}
	
	#Channel A High Range Step Size
	set address [expr {$address+16}]
	set cal::scaleAHigh [cal::readParameter $address]
	if {[string is double $cal::scaleAHigh]} {
		set vertical::stepSizeAHigh $cal::scaleAHigh
	} else {
		puts "Invalid calibration value detect (scaleAHigh): $cal::scaleAHigh"
		set cal::scaleAHigh $vertical::stepSizeAHigh
		set cal::scaleALow $vertical::stepSizeALow
		set cal::scaleBHigh $vertical::stepSizeBHigh
		set cal::scaleBLow $vertical::stepSizeBLow
		return
	}
	
	#Channel A Low Range Step Size
	set address [expr {$address+16}]
	set cal::scaleALow [cal::readParameter $address]
	if {[string is double $cal::scaleALow]} {
		set vertical::stepSizeALow $cal::scaleALow
	} else {
		puts "Invalid calibration value detect (scaleALow): $cal::scaleALow"
		set cal::scaleAHigh $vertical::stepSizeAHigh
		set cal::scaleALow $vertical::stepSizeALow
		set cal::scaleBHigh $vertical::stepSizeBHigh
		set cal::scaleBLow $vertical::stepSizeBLow
		return
	}
	
	#Channel B High Range Step Size
	set address [expr {$address+16}]
	set cal::scaleBHigh [cal::readParameter $address]
	if {[string is double $cal::scaleBHigh]} {
		set vertical::stepSizeBHigh $cal::scaleBHigh
	} else {
		puts "Invalid calibration value detect (scaleBHigh): $cal::scaleBHigh"
		set cal::scaleAHigh $vertical::stepSizeAHigh
		set cal::scaleALow $vertical::stepSizeALow
		set cal::scaleBHigh $vertical::stepSizeBHigh
		set cal::scaleBLow $vertical::stepSizeBLow
		return
	}
	
	#Channel B Low Range Step Size
	set address [expr {$address+16}]
	set cal::scaleBLow [cal::readParameter $address]
	if {[string is double $cal::scaleBLow]} {
		set vertical::stepSizeBLow $cal::scaleBLow
	} else {
		puts "Invalid calibration value detect (scaleBLow): $cal::scaleBLow"
		set cal::scaleAHigh $vertical::stepSizeAHigh
		set cal::scaleALow $vertical::stepSizeALow
		set cal::scaleBHigh $vertical::stepSizeBHigh
		set cal::scaleBLow $vertical::stepSizeBLow
		return
	}
}

proc cal::saveParameter {value address} {

	set length [string length $value]

	if { $length > 15} {
		puts "Parameter is too long! $value"
		return
	}

	if {$address > 1000} {
		puts "Address out of range"
		return
	}
	
	for {set i 0} {$i < 16} {incr i} {
		#Get the character
		if {$i < $length} {
			set char [scan [string range $value $i $i] "%c"]
		} else {
			set char "0"
		}
		set charAddress [expr {$i + $address}]
		#Write the character
		sendCommand "E $charAddress $char"
		after 5
		update
	}
}

proc cal::readParameter {address} {

	set param ""
	
	for {set i 0} {$i < 16} {incr i} {
		set charAddress [expr {$address+$i}]
		sendCommand "e $charAddress"
		vwait usbSerial::eepromData
		if {$usbSerial::eepromData != 0} {
			append param [format "%c" $usbSerial::eepromData]
		}
	}
	
	return $param

}

.menubar.tools.toolsMenu add command	\
	-label "Calibrate Scope Vertical Scale"	\
	-command cal::calibration
.menubar.tools.toolsMenu add separator
#File: usb_serial.tcl
#USB Serial Port Interface Procedures

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

#======================================

package provide usbSerial 1.0
set portHandle stdout

namespace eval usbSerial {

    #---=== USB-Serial Global Variables ===---
    set serialPort "\\\\.\\COM27"
    set comNum "?"
    set serialStatus "Disconnected"
    set baudRate 115200
    set receivedData {}
    set eepromData {}
    set responseType "?"
    set validPorts {}

    set firmwareIdent "Unknown"

    set usbWarnImage [image create photo -file $::images/USB-Warn.png]

    set answer ""

    set portShow showAvailable

    #Create a cache for converting signed integers to
    #unsigned ones.  Suggested in comp.lang.tcl in
    #April 11, 2005
    set cvt {}
    for {set i 0} {$i <256} {incr i} {
	lappend cvt $i
    }

    #---=== Export Public Procedures
    namespace export serialSettings
    namespace export sendCommand

    #Work around for newer Windows permissions
    if {$::osType == "windows"} {
	if {$::tcl_platform(osVersion) >= 6.1} {
	    #Windows 8+ - Make sure we have a directory to store the port.cfg file
	    if {![file exists [file join $env(APPDATA) "Syscomp"]]} {
		file mkdir [file join $env(APPDATA) "Syscomp"]
	    }
	    if {![file exists [file join $env(APPDATA) "Syscomp" "CGR201"]]} {
		file mkdir [file join $env(APPDATA) "Syscomp" "CGR201"]
	    }
	    set portCfgLocation [file join $env(APPDATA) "Syscomp" "CGR201" "port.cfg"]
	} else {
	    #Windows 7 and earlier
	    set portCfgLocation "port.cfg"
	}
    } else {
	#Mac and Linux
	set portCfgLocation "port.cfg"
    }

}

#Serial Settings
#---------------
#When invoked, this procedure creates a new window which allows
#the user to adjust the serial port settings.  The settings are read
#from, and stored to, a file called port.cfg.
proc ::usbSerial::serialSettings {} {
    global osType	\
	otherPort

    #Create a new window
    toplevel .serial
    wm title .serial "Port Settings"
    wm iconname .serial "Port Settings"
    grab .serial
    focus .serial

    #Create a frame to hold the port selection widgets
    frame .serial.ports 	\
	-relief sunken	\
	-borderwidth 2

    label .serial.serialTitle	\
	-text "Port Settings"	\
	-font {-weight bold}

    grid .serial.serialTitle -row 0 -column 0 -columnspan 2 -sticky w
    grid .serial.ports -row 1 -column 0 -columnspan 2 -sticky we
    grid columnconfigure .serial 0 -weight 1
    grid columnconfigure .serial.ports 0 -weight 1

    label .serial.ports.title	\
	-text "Please Select A COM Port:"	\
	-font {-weight bold -size -12}

    frame .serial.ports.top

    radiobutton .serial.ports.top.showAvailable	\
	-text "Show Available Ports"	\
	-value showAvailable	\
	-variable usbSerial::portShow	\
	-command "usbSerial::updateValidPorts 1"

    radiobutton .serial.ports.top.showAll	\
	-text "Show All Ports"	\
	-value showAll	\
	-variable usbSerial::portShow	\
	-command "usbSerial::updateValidPorts 0"

    button .serial.ports.top.refresh	\
	-text "Refresh"	\
	-command "usbSerial::updateValidPorts 1"

    grid .serial.ports.top.showAvailable -row 0 -column 0 -padx 30
    grid .serial.ports.top.showAll -row 0 -column 1 -padx 30
    grid .serial.ports.top.refresh -row 0 -column 2 -padx 60 -pady 5

    ttk::treeview .serial.ports.portList	\
	-yscrollcommand {.serial.ports.portScroll set}	\
	-columns {"SerialNum" "Device"}	\
	-selectmode browse
    .serial.ports.portList heading #0 -text "Port"
    .serial.ports.portList column #0 -width 110 -anchor center
    .serial.ports.portList heading SerialNum -text "Serial Number"
    .serial.ports.portList column SerialNum -width 200 -anchor center
    .serial.ports.portList heading Device -text "Device" -anchor w
    .serial.ports.portList column Device -width 400 -anchor w

    scrollbar .serial.ports.portScroll	\
	-orient vertical	\
	-command {.serial.ports.portList yview}

    button .serial.connect	\
	-text "Connect"	\
	-command {
	    destroy .serial
	    if {[usbSerial::openSerialPort]==1} {
		set fileId [open $usbSerial::portCfgLocation w]
		puts $fileId $usbSerial::comNum
		close $fileId
	    }
	}

    grid .serial.ports.title -row 0 -column 0 -sticky w -columnspan 3
    grid .serial.ports.top -row 1 -column 0 -columnspan 3 -sticky we
    grid .serial.ports.portList -row 2 -column 0 -columnspan 3 -sticky we
    grid .serial.ports.portScroll -row 2 -column 3 -sticky ns
    grid .serial.connect -row 3 -column 0 -columnspan 3

    #Center the serial port settings window over the parent
    #See http://wiki.tcl.tk/534
    update
    set w [winfo width .]
    set h [winfo height .]
    set x [winfo rootx .]
    set y [winfo rooty .]
    set xpos "+[ expr {$x+($w-[winfo width .serial])/2}]"
    set ypos "+[ expr {$y+($h-[winfo height .serial])/2}]"
    wm geometry .serial "$xpos$ypos"
    raise .serial
    update

    if {$usbSerial::portShow == "showAvailable"} {
	usbSerial::updateValidPorts 1
    } else {
	usbSerial::updateValidPorts 0
    }

}

proc usbSerial::deviceQuery {serialPort} {
    global portHandle
    global serialCheck

    #Attempt to open the serial port
    if { [catch {set portHandle [open $serialPort r+]} result] } {

	puts "Unable to open port: $result"

	#Close the port, in case it is already open
	usbSerial::closeSerialPort

	return [list 0 "Unable to open port"]
    }

    if {$::osType!="Darwin"} {
	if {[catch {fconfigure $portHandle -mode $usbSerial::baudRate,n,8,1 -blocking 0	-buffering line -encoding binary} result]} {

	    ::usbSerial::closeSerialPort

	    #showConnectOptions
	    serialSettings

	    return [list 0 "Unable to configure port"]
	}
    } else {
	exec stty -f $usbSerial::serialPort $usbSerial::baudRate cs8 -parenb -cstopb crtscts
	fconfigure $portHandle	\
	    -blocking 0		\
	    -buffering line	\
	    -handshake rtscts	\
	    -encoding binary	\
	    -translation {binary lf}
    }

    # We are now going to query the device.  We set up and
    # intermediate fileevent handler to deal with identification data
    # received from the instrument
    fileevent $portHandle readable {
	set incomingData [gets $portHandle]
	# puts "incomingData: $incomingData"
	if { ([lsearch $incomingData "Mini"] !=-1) || ([lsearch $incomingData "MKII"] !=-1) || ([lsearch $incomingData "Signature"] != -1) } {
	    #Poke the serialCheck variable
	    set serialCheck found
	    #Global variable to store firmware information
	    set usbSerial::firmwareIdent $incomingData
	} elseif {[string match "*CGM101BOOT*" $incomingData]==1} {
	    set serialCheck firmwareOnly
	    set usbSerial::firmwareIdent $incomingData
	} elseif {[string match "*CGR201BOOT*" $incomingData]==1} {
	    set serialCheck firmwareOnly
	    set usbSerial::firmwareIdent $incomingData
	} elseif {[string match "*SIG101BOOT" $incomingData]==1} {
	    set serialCheck firmwareOnly
	    set usbSerial::firmwareIdent $incomingData
	} else {
	    puts "No match"
	}
    }

    puts "Querying device..."
    #Query the device.
    sendCommand ""
    sendCommand ""
    flush $portHandle
    after 500
    set junk [read $portHandle]
    sendCommand i

    #Wait for a response from the device
    set serialCheck waiting
    set timeoutID [after 1500 {set serialCheck timeout}]
    vwait serialCheck
    after cancel $timeoutID
    usbSerial::closeSerialPort

    #Check to see if we found the device...
    if { $serialCheck == "found" } {
	puts "Connected."

	#Enable handshaking
	#fconfigure $portHandle -handshake rtscts -translation {binary lf}

	return [list 1 $usbSerial::firmwareIdent]

    } elseif {$serialCheck == "firmwareOnly"} {
	puts "Connected - firmware upgrade only"

	return [list 1 $usbSerial::firmwareIdent]

    } else {
	puts "Failed."

	return [list 0 "Not a Syscomp Device"]
    }

}

proc usbSerial::updateValidPorts {detectPorts} {
    variable validPorts

    #Clear the current list of valid com ports
    set validPorts {}
    .serial.ports.portList delete [.serial.ports.portList children {}]

    #Disable the refresh button while we work
    .serial.ports.top.refresh configure -text "Refreshing" -state disabled
    update

    if {$::osType == "windows"} {

	#Get a list of the current ports on the system
	set portList [usbSerial::winDetectPorts]

	if {$detectPorts} {
	    #Make sure ports were detected
	    if {$portList == -1} {
		set usbSerial::portShow showAll
	    }
	}

	#See if we need to detect the ports or just create a big list
	if {$detectPorts && ($portList != -1)} {
	    #Limit the list to the ports available on the system
	    set validPorts $portList
	} else {
	    for {set i 1} {$i < 100} {incr i} {
		set comString "COM$i"
		foreach port $portList {
		    if {[lsearch -glob $port $comString] >= 0} {
			set description [lindex $port 1]
			break
		    } else {
			set description "<Not Present>"
		    }
		}
		lappend validPorts [list $comString $description]
	    }
	}

	puts "Valid ports $validPorts"

	foreach port $validPorts {
	    set portId [lindex $port 0]
	    puts "portId $portId"
	    set portPath [string range $portId 3 end]
	    if {$portPath < 10} {
		set portPath "COM$portPath"
	    } else {
		set portPath "\\\\.\\COM$portPath"
	    }

	    puts "portPath $portPath"

	    #Identify Syscomp devices by their serial numbers
	    set temp [list [lindex $port 1]]
	    if {([string first "ftdi-CM" [lindex $temp 0]] >= 0) || ([string first "ftdi-C2" [lindex $temp 0]] >= 0) || ([string first "ftdi-SG" [lindex $temp 0]] >= 0)} {
		set color "Dark Green"
		set deviceInfo [lindex [deviceQuery $portPath] 1]
	    } else {
		set color "Orange"
		set deviceInfo "Unknown Device"
	    }

	    #Build the treeview
	    .serial.ports.portList insert {} end -id $portId -text $portId  -values [list $temp $deviceInfo] -tags $portId
	    .serial.ports.portList tag configure $portId -foreground $color
	    .serial.ports.portList tag bind $portId <<TreeviewSelect>> {
		update
		set temp [.serial.ports.portList focus]
		puts $temp
		set usbSerial::comNum [string range $temp 3 end]
		if {$usbSerial::comNum < 10} {
		    set usbSerial::serialPort "COM$usbSerial::comNum"
		} else {
		    set usbSerial::serialPort "\\\\.\\COM$usbSerial::comNum"
		}
	    }
	}
    } elseif {$::osType == "unix"} {

	if {$detectPorts} {
	    #Get a list of the current ports on the system
	    set portList [usbSerial::linDetectPorts]
	    #Make sure ports were detected
	    if {$portList == -1} {
		#.serial.ports.showAll invoke
		#return
		set usbSerial::portShow showAll
	    }
	}

	#See if we need to detect the ports or just create a big list
	if {$detectPorts && ($portList != -1)} {
	    #Limit the list to the ports available on the system
	    set validPorts $portList
	} else {
	    for {set i 1} {$i < 100} {incr i} {
		set comString "/dev/ttyUSB$i"
		foreach port $portList {
		    if {[lsearch -glob $port $comString] >= 0} {
			set description [lindex $port 1]
			break
		    } else {
			set description "<Not Present>"
		    }
		}
		lappend validPorts [list $comString $description]
	    }

	    #for {set i 0} {$i < 100} {incr i} {
	    #	set comString "/dev/ttyUSB$i"
	    #	set description ""
	    #	lappend validPorts [list $comString $description]
	    #}
	}

	#puts "Valid ports $validPorts"

	foreach port $validPorts {
	    set temp [list [lindex $port 1]]
	    set color black

	    set portId [lindex $port 0]
	    .serial.ports.portList insert {} end -id $portId -text $portId  -values "$temp" -tags $portId
	    .serial.ports.portList tag configure $portId -foreground $color
	    .serial.ports.portList tag bind $portId <<TreeviewSelect>> {
		update
		set temp [.serial.ports.portList focus]
		set usbSerial::comNum $temp
		set usbSerial::serialPort $temp
	    }
	}

    }  elseif {$::osType == "Darwin"} {

	if {$detectPorts} {
	    #Get a list of the current ports on the system
	    set portList [usbSerial::macDetectPorts]
	    #Make sure ports were detected
	    if {$portList == -1} {
		#.serial.ports.showAll invoke
		#return
		set usbSerial::portShow showAll
	    }
	}

	#See if we need to detect the ports or just create a big list
	if {$detectPorts && ($portList != -1)} {
	    #Limit the list to the ports available on the system
	    set validPorts $portList
	} else {
	    lappend validPorts [list /dev/cu.usbSerial ""]
	    for {set i 0} {$i < 100} {incr i} {
		set comString "/dev/ttyUSB$i"
		set description ""
		lappend validPorts [list $comString $description]
	    }
	}

	foreach port $validPorts {
	    set temp [list [lindex $port 1]]
	    set color black

	    set portId [lindex $port 0]
	    .serial.ports.portList insert {} end -id $portId -text $portId  -values "$temp" -tags $portId
	    .serial.ports.portList tag configure $portId -foreground $color
	    .serial.ports.portList tag bind $portId <<TreeviewSelect>> {
		update
		set temp [.serial.ports.portList focus]
		set usbSerial::comNum $temp
		set usbSerial::serialPort $temp
	    }
	}

    }

    #Enable the refresh button
    .serial.ports.top.refresh configure -text "Refresh" -state normal
}

proc usbSerial::openSerialPort {} {
    global portHandle
    global serialCheck

    #Attempt to open the serial port
    if { [catch {set portHandle [open $usbSerial::serialPort r+]} result] } {

	if {$usbSerial::serialPort!="?"} {
	    tk_messageBox	\
		-title "Communication Error"	\
		-default ok		\
		-message "Port COM$usbSerial::comNum can not be opened.  Already in use?"	\
		-type ok			\
		-icon warning
	}

	#Close the port, in case it is already open
	usbSerial::closeSerialPort

	serialSettings

	return 0

    } else {
	if {$::osType!="Darwin"} {
	    if {[catch {fconfigure $portHandle -mode $usbSerial::baudRate,n,8,1	-blocking 0	-buffering line -encoding binary} result]} {
		#Display "Disconnected" status on the menubar
		set usbSerial::serialStatus "Disconnected"
		.menubar.serialPortStatus configure \
		    -background red
		tk_messageBox	\
		    -title "Communication Error"	\
		    -default ok		\
		    -message "Device on COM$usbSerial::comNum can not be configured."	\
		    -type ok			\
		    -icon warning

		::usbSerial::closeSerialPort

		serialSettings

		return 0
	    }
	} else {
	    exec stty -f $usbSerial::serialPort $usbSerial::baudRate cs8 -parenb -cstopb crtscts
	    fconfigure $portHandle	\
		-blocking 0		\
		-buffering line	\
		-handshake rtscts	\
		-encoding binary	\
		-translation {binary lf}
	}

	#We are now going to query the device.
	#We set up  and intermediate fileevent handler to deal with
	#identification data received from the instrument
	fileevent $portHandle readable {
	    set incomingData [gets $portHandle]
	    puts "incomingData: $incomingData"
	    if { [lsearch $incomingData "Mini"] !=-1 } {
		set ::deviceType mini
		source [file join $program_directory CGRMINI.tcl]
		#Global variable to store firmware information
		set usbSerial::firmwareIdent $incomingData
		#Poke the serialCheck variable
		set serialCheck found
	    } elseif {[lsearch $incomingData "MKII"] !=-1 } {
		${log}::info "Found a CGR-201"
		set ::deviceType mk2
		source [file join $program_directory CGRMK2.tcl]
		update
		update idletasks
		#Global variable to store firmware information
		set usbSerial::firmwareIdent $incomingData
		#Poke the serialCheck variable
		set serialCheck found
	    } elseif {[lsearch $incomingData "Signature"] !=-1} {
		set ::deviceType sig
		source [file join $program_directory SIG101.tcl]
		#Global variable to store firmware information
		set usbSerial::firmwareIdent $incomingData
		#Poke the serialCheck variable
		set serialCheck found
	    } elseif {[string match "*CGM101BOOT*" $incomingData]==1} {
		set ::deviceType mini
		set serialCheck firmwareOnly
		set usbSerial::firmwareIdent $incomingData
		set firmware::firmwareIsCurrent 0
	    } elseif {[string match "*CGR201BOOT*" $incomingData]==1} {
		set ::deviceType mk2
		set serialCheck firmwareOnly
		set usbSerial::firmwareIdent $incomingData
		set firmware::firmwareIsCurrent 0
		set firmware::fpgaIsCurrent 1
	    } elseif {[string match "*SIG101BOOT*" $incomingData]==1} {
		set ::deviceType sig
		set serialCheck firmwareOnly
		set usbSerial::firmwareIdent $incomingData
		set firmware::firmwareIsCurrent 0
	    } else {
		puts "No match"
	    }
	}
	puts "Querying device..."
	#Query the device.
	sendCommand ""
	if {$::deviceType == "MKII"} {
	    #Kill any on-going captures
	    sendCommand "k"
	}
	sendCommand ""
	flush $portHandle
	after 500
	set junk [read $portHandle]
	sendCommand i

	#Wait for a response from the device
	set serialCheck waiting
	set timeoutID [after 1500 {set serialCheck timeout}]
	vwait serialCheck
	after cancel $timeoutID

	#Check to see if we found the device...
	if { $serialCheck == "found" } {
	    puts "Connected."

	    #Enable handshaking
	    fconfigure $portHandle -handshake rtscts -translation {binary lf}

	    #Display "Connected" status on menu bar
	    set usbSerial::serialStatus "Connected"
	    .menubar.serialPortStatus configure -background green
	    usbSerial::setupFileevent
	    #Connect was successful
	    bind . Destroy {usbSerial::closeSerialPort; destroy .}

	    if {[firmware::checkFirmware]} {
		#The firmware is up to date, carry on
		initializeCGR
	    } else {

		set updateString "A firmware update is available.\nThis update is required to use this software version.\n"

		if {$::deviceType == "mk2"} {

		    if {(!$firmware::firmwareIsCurrent) && (!$firmware::fpgaIsCurrent)} {
			append updateString "This is a two stage update.\nThe microprocessor firmware will be upgraded first.\n"
			append updateString "You will then be prompted to reboot the CGR-201 and then update the FPGA firmware."
		    } elseif {!$firmware::fpgaIsCurrent} {
			append updateString "Click OK to upgrade the FPGA firmware."
		    } else {
			append updateString "Click OK to upgrade the firwmare."
		    }

		}

		#The firmware is not current
		tk_messageBox	\
		    -icon question	\
		    -message $updateString	\
		    -parent .	\
		    -title "Firmware Upgrade"	\
		    -type ok

		#Update the main firmware
		if {!$firmware::firmwareIsCurrent} {
		    firmware::showFirmware 0
		} else {
		    #Check the FPGA for MKII devices
		    if {$::deviceType == "mk2"} {
			if {!$firmware::fpgaIsCurrent} {
			    puts "FPGA image is not current."
			    if {$firmware::fpgaRev=="0x01"} {
				#The P0 FPGA image is replaced entirely in the bootloader
				set firmware::firmwareIsCurrent 0
			    } else {
				#All other FPGA image upgrades are done through the main firmware
				mk2::showFpgaUpgrade
			    }
			}
		    }
		}

	    }

	    return 1

	} elseif {$serialCheck == "firmwareOnly"} {
	    puts "Connected - firmware upgrade only"

	    set answer [tk_messageBox	\
			    -default no	\
			    -icon question	\
			    -message "Instrument is blank.\nWould you like to perform a firmware upgrade?"	\
			    -parent .	\
			    -title "Firmware Error"	\
			    -type yesno]

	    if {$answer == "yes"} {
		firmware::showFirmware 0
		return 1
	    } else {
		usbSerial::closeSerialPort
		return 0
	    }

	} else {
	    puts "Failed."

	    #Display "Disconnected" status on the menubar
	    set usbSerial::serialStatus "Disconnected"
	    .menubar.serialPortStatus configure \
		-background red
	    tk_messageBox	\
		-title "Communication Error"	\
		-default ok		\
		-message "Device on COM$usbSerial::comNum did not respond."	\
		-type ok			\
		-icon warning

	    usbSerial::closeSerialPort

	    #showConnectOptions
	    serialSettings

	    return 0

	}
    }

}

#Set Up Fileevent
#-----------------
#This procedure is called to initialize the fileevent handler
#for data received from the instrument.
proc ::usbSerial::setupFileevent {} {
    global portHandle

    #Read in any left over data (such as line ends) from the
    #autodetection routines.
    set junk [read $portHandle]

    fileevent $portHandle readable {
	::usbSerial::processResponse
    }
}

#Close Serial Port
#-----------------
#This procedure closes any USB serial port currently open as
#"portHandle".
proc ::usbSerial::closeSerialPort {} {
    global portHandle
    variable serialStatus

    if {$portHandle != "stdout"} {
	catch { [close $portHandle]}
    }
    set serialStatus "Disconnected"
    .menubar.serialPortStatus configure -background red
    set portHandle stdout
}

#Send Command to Hardware
#------------------------------
# This procedure takes the argument "command" and sends it
# to the serial port.  The argument is also printed to stdout.
proc ::usbSerial::sendCommand {command} {
    global osType portHandle

    puts $portHandle $command
    if {$osType == "Darwin"} {flush $portHandle}
    if $::debugLevel { puts $command }
}

#Send a Single Byte to the Hardware
#----------------------------------
proc usbSerial::sendByte {byteData} {
    global osType portHandle

    puts -nonewline $portHandle $byteData
    if {$osType == "Darwin"} {flush $portHandle}
    if $::debugLevel { puts $byteData }
    flush $portHandle
}

#Based on www2.tcl.tk/1838
proc usbSerial::winDetectPorts {} {

    set result {}
    set ccs {HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet}

    #Search for the FT232R and the FT240X
    foreach {type prefix match} {
	Serenum  ftdi {^FTDIBUS.*_6001.(\w+)}
	Serenum  ftdi {^FTDIBUS.*_6015.(\w+)}
    } {
	# ignore registry access errors
	catch {
	    set enum "$ccs\\Services\\$type\\Enum"
	    set n [registry get $enum Count]
	    for {set i 0} {$i < $n} {incr i} {
		set desc [registry get $enum $i]
		if {[regexp $match $desc - serial]} {
		    set p [registry get "$ccs\\Enum\\$desc\\Device Parameters" PortName]
		    #lappend result $prefix-$serial $p $desc
		    lappend result [list "$p" "$prefix-$serial"]
		}
	    }
	}
    }

    #See if there are any com ports present
    if {![llength $result]} {
	tk_messageBox	\
	    -message "No Com Ports Detected"	\
	    -default ok	\
	    -parent .	\
	    -title "Serial Detection"	\
	    -type ok
	return -1
    }

    return $result
}

proc usbSerial::linDetectPorts {} {

    #See if there are any usb-serial ports available in the dev directory
    if {[catch {set devList [glob -directory /dev/ ttyUSB*]} result]} {
	set devList ""
    }

    #We did not find any ports
    if {$devList == ""} {
	update
	tk_messageBox	\
	    -message "No Com Ports Detected"	\
	    -default ok	\
	    -parent .serial	\
	    -title "Serial Detection"	\
	    -type ok
	return -1
    }

    set comList {}
    foreach dev $devList {
	set description [exec ls -al $dev]
	lappend comList [list $dev $description]
    }

    return $comList

}

proc usbSerial::macDetectPorts {} {

    #See if there are any usb-serial ports available in the dev directory
    if {[catch {set devList [glob -directory /dev/ cu.usbserial*]} result]} {
	set devList ""
    }

    #We did not find any ports
    if {$devList == ""} {
	update
	tk_messageBox	\
	    -message "No Com Ports Detected"	\
	    -default ok	\
	    -parent .serial	\
	    -title "Serial Detection"	\
	    -type ok
	return -1
    }

    set comList {}
    foreach dev $devList {
	set description [exec ls -al $dev]
	lappend comList [list $dev $description]
    }

    return $comList

}

proc usbSerial::getStoredPort {} {

    if [catch {open $usbSerial::portCfgLocation r+} fileId] {
	return 0
    } else {
	if {$::osType == "windows"} {
	    if { [gets $fileId line] >= 0} {
		set usbSerial::comNum $line
		if {$usbSerial::comNum < 10} {
		    set usbSerial::serialPort "COM$usbSerial::comNum"
		} else {
		    set usbSerial::serialPort "\\\\.\\COM$usbSerial::comNum"
		}
		close $fileId
		return 1
	    } else {
		close $fileId
		return 0
	    }
	} else {
	    if {[gets $fileId line] >= 0} {
		set usbSerial::serialPort $line
		close $fileId
		return 1
	    } else {
		close $fileId
		return 0
	    }
	}
    }

}


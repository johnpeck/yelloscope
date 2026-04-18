#File: average.tcl
#Syscomp USB Oscilloscope GUI
#Scope Display Persistence Averaging Package

#MG
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

package provide average 1.0

namespace eval average {

	variable chA [list]
	variable chB [list]
	variable averageDataA [list]
	variable averageDataB [list]
	variable levelsOfAverage Off

	#used to hold off restarting the averaging after clearing to flush stale data
	variable averageStale 0

	variable averagePlotDataA [list]
	variable averagePlotDataB [list]

}

proc average::updateAverage {plotDataA plotDataB} {

    if {$average::levelsOfAverage == "Off" || $average::averageStale} {
	set plotA $plotDataA
	set plotB $plotDataB

	set average::chA {}
	set average::averageDataA [list]

	set average::chB {}
	set average::averageDataB [list]

	set average::averageStale 0

    } else {
	set plotA [list]
	set plotB [list]

	## Channel A processing
	if {$vertical::enableA} {

	    set averageLength [llength $plotDataA]
	    set numPoints [llength $average::chA]
	    # puts "averageLength $averageLength numPoints $numPoints"

	    #for each data point, add the new value and subtract the old
	    if {[llength $average::averageDataA] == 0} {
		#reset condition with no average history
		for {set i 1} {$i < $averageLength} {incr i 2} {
		    lappend average::averageDataA [lindex $plotDataA [expr {$i-1}]]
		    lappend plotA [lindex $average::averageDataA end]
		    lappend average::averageDataA [expr {[lindex $plotDataA $i]/$average::levelsOfAverage}]
		    lappend plotA [expr {[lindex $average::averageDataA end]*$average::levelsOfAverage/($numPoints+1)}]
		}
	    } elseif { [llength $average::chA] >= $average::levelsOfAverage } {
		# add the new value and remove the old one
		set tmpAvg [list]
		set tmpRmv [lindex $average::chA 0]
		for {set i 1} {$i < $averageLength} {incr i 2} {
		    lappend tmpAvg [lindex $plotDataA [expr {$i-1}]]
		    lappend tmpAvg [expr {[lindex $average::averageDataA $i] + ([lindex $plotDataA $i] - [lindex $tmpRmv $i])/$average::levelsOfAverage}]
		}
		set average::averageDataA $tmpAvg
		set plotA $tmpAvg
	    } else {
		# transient start condition adding new values and removing none
		set tmpAvg [list]
		for {set i 1} {$i < $averageLength} {incr i 2} {
		    lappend tmpAvg [lindex $plotDataA [expr {$i-1}]]
		    lappend plotA [lindex $tmpAvg end]
		    lappend tmpAvg [expr {[lindex $average::averageDataA $i] + [lindex $plotDataA $i]/$average::levelsOfAverage}]
		    lappend plotA [expr {[lindex $tmpAvg end]*$average::levelsOfAverage/($numPoints+1)}]
		}
		set average::averageDataA $tmpAvg
	    }
	    if { [llength $average::chA] >= $average::levelsOfAverage } {
		set average::chA [lreplace $average::chA 0 0]
	    }
	    set average::chA [linsert $average::chA end $plotDataA]
	} else {
	    set average::chA {}
	    set average::averageDataA [list]
	}

	## Channel B processing
	# if {$vertical::enableB} {}
	if {true} {
	    set averageLength [llength $plotDataB]
	    set numPoints [llength $average::chB]

	    #for each data point, add the new value and subtract the old
	    if {[llength $average::averageDataB] == 0} {
		#reset condition with no average history
		for {set i 1} {$i < $averageLength} {incr i 2} {
		    lappend average::averageDataB [lindex $plotDataB [expr {$i-1}]]
		    lappend plotB [lindex $average::averageDataB end]
		    lappend average::averageDataB [expr {[lindex $plotDataB $i]/$average::levelsOfAverage}]
		    lappend plotB [expr {[lindex $average::averageDataB end]*$average::levelsOfAverage/($numPoints+1)}]
		}

	    } elseif { [llength $average::chB] >= $average::levelsOfAverage } {
		# add the new value and remove the old one
		set tmpAvg [list]
		set tmpRmv [lindex $average::chB 0]
		for {set i 1} {$i < $averageLength} {incr i 2} {
		    lappend tmpAvg [lindex $plotDataB [expr {$i-1}]]
		    lappend tmpAvg [expr {[lindex $average::averageDataB $i] + ([lindex $plotDataB $i] - [lindex $tmpRmv $i])/$average::levelsOfAverage}]
		}
		set average::averageDataB $tmpAvg
		set plotB $tmpAvg
	    } else {
		# transient start condition adding new values and removing none
		set tmpAvg [list]
		for {set i 1} {$i < $averageLength} {incr i 2} {
		    lappend tmpAvg [lindex $plotDataB [expr {$i-1}]]
		    lappend plotB [lindex $tmpAvg end]
		    lappend tmpAvg [expr {[lindex $average::averageDataB $i] + [lindex $plotDataB $i]/$average::levelsOfAverage}]
		    lappend plotB [expr {[lindex $tmpAvg end]*$average::levelsOfAverage/($numPoints+1)}]
		}
		set average::averageDataB $tmpAvg
	    }

	    if { [llength $average::chB] >= $average::levelsOfAverage } {
		set average::chB [lreplace $average::chB 0 0]
	    }
	    set average::chB [linsert $average::chB end $plotDataB]
	} else {
	    set average::chB {}
	    set average::averageDataB [list]
	}
    }

    average::plotAverage $plotA $plotB

    set average::averagePlotDataA $plotA
    set average::averagePlotDataB $plotB
}

proc average::plotAverage {averageDataA averageDataB} {

	set scopePath [display::getDisplayPath]

	if {$persist::levelsOfPersistence != "infinite"} {
		$scopePath.display delete waveDataA
		$scopePath.display delete waveDataB
	}

	if {$vertical::enableA} {
	    $scopePath.display create line	\
		$averageDataA	\
		-tag waveDataA	\
		-fill $display::channelAColor
	}

	if {$vertical::enableB} {
	    $scopePath.display create line	\
		$averageDataB	\
		-tag waveDataB	\
		-fill $display::channelBColor
	}

}

proc average::changeLevelsA {} {

	set scopePath [display::getDisplayPath]
	$scopePath.display delete waveDataA

	#set average::chA {}
	#set average::averageDataA [list]

}

proc average::changeLevelsB {} {

	set scopePath [display::getDisplayPath]
	$scopePath.display delete waveDataB
	#set average::chB {}
	#set average::averageDataB [list]

}

proc average::changeLevels {} {

	set average::averageStale 1
	average::changeLevelsA
	average::changeLevelsB

}

.menubar.scopeView.viewMenu add separator

menu .menubar.scopeView.average -tearoff 0
.menubar.scopeView.average add check	\
	-label "Off"	\
	-variable average::levelsOfAverage	\
	-onvalue "Off"	\
	-command average::changeLevels
.menubar.scopeView.average add check	\
	-label "4"	\
	-variable average::levelsOfAverage	\
	-onvalue "4"	\
	-command average::changeLevels
.menubar.scopeView.average add check	\
	-label "16"	\
	-variable average::levelsOfAverage	\
	-onvalue "16"	\
	-command average::changeLevels
.menubar.scopeView.average add check	\
	-label "64"	\
	-variable average::levelsOfAverage	\
	-onvalue "64"	\
	-command average::changeLevels
.menubar.scopeView.average add check	\
	-label "256"	\
	-variable average::levelsOfAverage	\
	-onvalue "256"	\
	-command average::changeLevels
.menubar.scopeView.average add command	\
	-label "Reset"	\
	-command average::changeLevels

.menubar.scopeView.viewMenu add cascade	\
	-menu .menubar.scopeView.average		\
	-label "Digital Average"

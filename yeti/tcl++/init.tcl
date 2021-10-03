#
# Sensus Consulting Ltd (C) 1997-1998
# Matt Newman <matt@sensus.org>
#
namespace eval tcl++ {
	variable library [file dirname [info script]]
}
lappend ::auto_path ${tcl++::library}

source ${tcl++::library}/tcl++.tcl
source ${tcl++::library}/array.tcl
source ${tcl++::library}/lists.tcl

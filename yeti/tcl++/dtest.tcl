#!/usr/bin/env tclsh
##############################################################################
#
#  Author        : Dr. Detlef Groth
#  Created By    : Dr. Detlef Groth
#  Created       : Sat Oct 2 08:41:47 2021
#  Last Modified : <211002.0846>
#
#  Description	
#
#  Notes
#
#  History
#	
##############################################################################
#
#  Copyright (c) 2021 Dr. Detlef Groth.
# 
#  License:      MIT
# 
##############################################################################

lappend auto_path [file dirname [info script]]
package require tcl++
namespace import -force ::itcl::*

class Test {
    constructor {args} {
        puts $args
        
    }
    method hello {} {
        puts "Hello!"
    }
}

set t [Test #auto]
$t hello
rename $t ""
puts end

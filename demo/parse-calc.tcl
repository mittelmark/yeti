#! /bin/sh
# \
exec tclsh8.3 "$0" ${1+"$@"}

#
# calculator that supports basic arithmetic and brackets
#

lappend auto_path [file join [file dirname [info script]] .. ..]
package require ylex
package require yeti

package provide parse-calc-demo 0.1
#
# Use ylex to generate a new scanner
#

set sg [yeti::ylex #auto -name MathScanner]

$sg add {
    [0-9]+		{ return [list NUMBER $yytext] }
    {\+}		{ return PLUS }
    {-}			{ return MINUS }
    {\*}		{ return MULTIPLY }
    {/}			{ return DIVIDE }
    {\(}		{ return OPEN }
    {\)}		{ return CLOSE }
}

set scannercode [$sg dump]

# for debug
# set f [open "foo.tcl" w]
# puts $f $scannercode
# close $f

eval $scannercode
rename $sg ""

#
# Use yeti to generate a new parser
#

set pg [yeti::yeti #auto -name MathParser]

$pg add {
    start {addition} {}

    addition {addition PLUS multiplication} {
	return [expr $1+$3]
    }

    addition {addition MINUS multiplication} {
	return [expr $1-$3]
    }

    addition {multiplication} {}

    multiplication {multiplication MULTIPLY number} {
	return [expr $1*$3]
    }

    multiplication {multiplication DIVIDE number} {
	return [expr $1/$3]
    }

    multiplication {number} {}

    number {NUMBER} {}

    number {MINUS NUMBER} {
	return [expr -$2]
    }

    number {OPEN addition CLOSE} {
	return $2
    }
}

#
# Create the new parser
#

set parsercode [$pg dump]
eval $parsercode
rename $pg ""

if {[info exists argv0] && $argv0 eq [info script]} {
    if {[llength $argv] == 0 || ([llength $argv] > 0 && [lindex $argv 0] eq "--help")} {
        puts "Usage: [info script] options code|filename"
        puts "valid options are:"
        puts "    --help          - displays this help page"
        puts "    --version       - displays package version"
        puts "    --demo  expr    - evaluates mathematical expressions"
        puts "    --write outfile - write parser into outfile"
    } elseif {[llength $argv] > 0 && [lindex $argv 0] eq "--version"} {
        puts [package provide parse-calc-demo]
    } elseif {[llength $argv] > 0 && [lindex $argv 0] eq "--demo"} { 
        #
        # Instantiate a new parser
        #
        set argv [lrange $argv 1 end]
        set scanner [MathScanner #auto]
        set mp [MathParser #auto -scanner $scanner]
        
        if {[llength $argv] == 0} {
            set argv [list "2*3+4*2" "1+(2+(3))*8+1"]
        }
        foreach arg $argv {
            if {$arg == "-v"} {
                $scanner configure -verbose [expr [$scanner cget -verbose] + 1]
                $mp configure -verbose [expr [$mp cget -verbose] + 1]
                continue
            }
            
            $scanner start $arg
            $mp reset
            
            puts "Result is [$mp parse]"
        }
        rename $mp ""
    } elseif {[llength $argv] > 0 && [lindex $argv 0] eq "--write"} { 
        # for debug
        if {[llength $argv] == 1} {
            set outfile [regsub {.tcl$} [info script] "-out.tcl"]
        } else {
            set outfile [lindex $argv 1]
        }
        set f [open $outfile w]
        puts $f $scannercode
        puts $f $parsercode
        close $f
    }
}




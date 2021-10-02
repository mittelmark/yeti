#! /bin/sh
# \
exec tclsh8.3 "$0" ${1+"$@"}

#
# simple scanner that counts lines, words and characters: wc equivalent
#

lappend auto_path [file join [file dirname [info script]] ..]
package require ylex

#
# initialize scanner generator
#

set scannergenerator [yeti::ylex #auto -name wc]

$scannergenerator code public {
    variable lines 0
    variable words 0
    variable chars 0
}

$scannergenerator code reset {
    set lines 0
    set words 0
    set chars 0
}

$scannergenerator add {[[:alnum:][:punct:][:graph:]]+} {
    incr words
    incr chars [string length $yytext]
}

$scannergenerator add {\n} {
    incr lines
    incr chars
}

$scannergenerator add {.} {
    incr chars
}

#
# Generate new Scanner
#

set scannertext [$scannergenerator dump]

if {0} {
    set f [open "foo.tcl" w]
    puts $f $scannertext
    close $f
}

eval $scannertext
delete object $scannergenerator

#
# Create instance of scanner
#

set scanner [wc #auto]

#
# process file from command line, or myself
#

if {[llength $argv] == 0} {
    lappend argv [info script]
}

set totlines 0
set totwords 0
set totchars 0

foreach filename $argv {
    if {[catch {set file [open $filename]} res]} {
	puts "cannot open $filename: $res"
	continue
    }
    if {[catch {set text [read $file]} res]} {
	puts "cannot read from $filename: $res"
	close $file
	continue
    }
    close $file

    #
    # run the scanner on this file
    #

    $scanner start $text
    $scanner run

    set lines [$scanner cget -lines]
    set words [$scanner cget -words]
    set chars [$scanner cget -chars]

    puts [format "%7d %7d %7d %s" $lines $words $chars $filename]

    incr totlines $lines
    incr totwords $words
    incr totchars $chars
    $scanner reset
}

if {[llength $argv] > 1} {
    puts [format "%7d %7d %7d %s" $totlines $totwords $totchars total]
}

delete object $scanner


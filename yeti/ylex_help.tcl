#!/usr/bin/env tclsh

set filename [file join [file dirname [info script]] ylex.md]
set manpage [file join [file dirname [info script]] ylex.n]

if {[auto_execok man] ne ""} {
    set res [exec man $manpage]
    puts $res
    exit 0
}

if [catch {open $filename r} infh] {
    puts stderr "Cannot open $filename: $infh"
    exit
} else {
    while {[gets $infh line] >= 0} {
        if {![regexp {^#} $line]} {
            puts "  $line"
        } else {
            puts $line
        }
    }
    close $infh
}


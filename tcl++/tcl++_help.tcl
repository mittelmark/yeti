#!/usr/bin/env tclsh

set filename [file join [file dirname [info script]] README.txt]

if [catch {open $filename r} infh] {
    puts stderr "Cannot open $filename: $infh"
    exit
} else {
    while {[gets $infh line] >= 0} {
        puts "$line"
    }
    close $infh
}


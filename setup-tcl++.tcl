# setup file for tclinstall
# tclmain -m tclinstall path-to/lib/setup-tcl++.tcl
array set setup {
   name tcl++   
   version 2.3
   url https://github.com/mittelmark/yeti
   author {Detlef Groth}
   license {Sensus Consulting Ltd, Copyright (c) 1997-1998, Matt Newmann}
   include {
       tcl++/array.tcl 
       tcl++/init.tcl 
       tcl++/lists.tcl
       tcl++/tcl++.tcl 
       tcl++/tcl++_help.tcl        
       tcl++/pkgIndex.tcl
       tcl++/README*
       tcl++/COPYRIGHT
   }
}


if {$::argv0 eq [info script]} {
    package require tclinstall
    set ::argv0 tclinstall
    tclinstall::install [info script]
}

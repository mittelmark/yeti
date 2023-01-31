# setup file for tclinstall
# tclmain -m tclinstall path-to/lib/setup-yeti.tcl
array set setup {
   name yeti   
   version 0.4.2
   url https://github.com/mittelmark/yeti
   author {Detlef Groth}
   license {BSD 2.0}
   include {
       yeti/*.tcl 
       yeti/*.md 
       yeti/*.n
       yeti/CHANGES 
       yeti/README*
       yeti/LICENSE
   }
}


if {$::argv0 eq [info script]} {
    package require tclinstall
    set ::argv0 tclinstall
    tclinstall::install [info script]
}

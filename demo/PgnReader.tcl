##############################################################################
#
#  System        : 
#  Module        : 
#  Object Name   : $RCSfile$
#  Revision      : $Revision$
#  Date          : $Date$
#  Author        : $Author$
#  Created By    : Dr. Detlef Groth
#  Created       : Sat Sep 28 07:48:08 2019
#  Last Modified : <211003.1820>
#
#  Description	
#
#  Notes
#
#  History
#	
##############################################################################
#
#  Copyright (c) 2019 Dr. Detlef Groth.
# 
#  All Rights Reserved.
# 
##############################################################################
#' # PgnReader 0.1 - read chess pgn files
#' 
#' ## Name 
#' 
#' PgnReader - read chess pgn files.
#' 
#' ## <a name='toc'></a>Table Of Contents
#' 
#'  - [Table Of Contents](#toc)
#'  - [Synopsis](#synopsis)
#'  - [Class Command](#command)
#'  - [PgnReader Commands](#commands)
#'  - [Todo's](#todo)
#'  - [Bugs, Ideas, Feedback](#bugs)
#'  - [Authors](#authors)
#'  - [Copyright](#copyright)
#' 
#' ## <a name='synopsis'></a>Synopsis
#' 
#' ```
#' package require PgnReader 0.1
#' set scanner [PgnReader #auto]
#' set pgn [$scanner getGame sample.pgn 4]
#' puts $pgn
#' $scanner scanPGNText $pgn
#' puts [$scanner moves]
#' puts [$scanner header White]
#' puts [$scanner header Black]
#' ```
#' 
#' ## <a name='command'></a> Class Command
#' **PgnReader** *cmdname ?options?*
#' 
#' Create a new PgnReader object with the given options.
#'  
#' ## <a name='commands'></a> Class Methods
#' 
lappend auto_path /home/groth/workspace/github/yeti
::tcl::tm::path add [file dirname [info script]]
                    
package require ylex
set version 0.1

set scannergenerator [yeti::ylex #auto -name PgnReader]

$scannergenerator code private {
    variable nesting 0
    variable headers 
    variable moves
    variable comments
    variable ccomm ;# current comment
    variable PGN
    variable HM 0

}
$scannergenerator add {\[[A-Za-z]+[^\]]+\]\+?} {
regexp {\[([A-Za-z]+).+?"(.+)"} $yytext -> header value
          #puts $yytext
    #puts "$header: $value"
    set headers($header) $value
}

$scannergenerator add {[^0-9]1\.} {
    set yystate GAME
    set moves [list]
    set HM 0
}

$scannergenerator add -state GAME {[-0-2/]{3,}} {
    #puts "result: $yytext"
    set yystate ""
}

$scannergenerator add -state GAME {[0ORNBQKa-h][-Oa-h0-8x\+]+} {
    #puts "move $yytext"
    lappend moves $yytext 
    incr HM 1
}


$scannergenerator add -state GAME {[\{]} {
    incr nesting
    set ccomm ""
    set yystate COMMENT
}
$scannergenerator add -state COMMENT {[\}]} {
    incr nesting -1
    if {$nesting == 0} {
        dict set comments $HM $ccomm
        set ccomm ""
        set yystate GAME
    }

}
$scannergenerator add -state COMMENT {[^\}]} {
    append ccomm $yytext
}
$scannergenerator code constructor {{args} {
    eval $this configure $args
    array set headers [list]
    set comments [dict create 0 None]
}}

#$scannergenerator code public {method hello {} {
#        puts "Hello World!"
#}}
        

#' 
#' *cmdName* **comment** *number* *?color?*
#' 
#' > Return a comment for a given move and turn color. Color can be on of *b,*, *black*, *Black*, *w*, *white*, *White* only the first letter is important.
#'   If the color is not given move is assumed to be a halfmove.
#' 
$scannergenerator code public {method comment {number {color ""}} {
   if {$color ne ""} {
       set col [string tolower [string range $color 0 0]]
       set hm [expr {($number -1)*2}]
       incr hm 1
       if {$col eq "b"} {
           incr hm 1
       }
   } else {
       set hm $number
   }
   if {[dict exists $comments $hm]} {
       return [dict get $comments $hm]
   } else {
       return ""
   }
}}

#' 
#' *cmdName* **comments** 
#' 
#' > return all comments for the scanned game.
#' 
$scannergenerator code public {method comments {} {
   return $comments
}}

#' 
#' *cmdName* **getGame** *filename* *gameNumber*
#' 
#' > *filename* PGN filename
#'
#' > *gameNumber* number of the game, first game is 1
#' 
#' > returns: PGN code for the game
#' 

$scannergenerator code public {method getGame {filename n} {
   set pgn ""     
   if [catch {open $filename r} infh] {
       puts stderr "Cannot open $filename: $infh"
       exit
   } else {
       set x 0
       while {[gets $infh line] >= 0} {
           if {[regexp {^\[Event } $line]} {
                incr x
                if {$x == $n} {
                    set pgn "$line\n"
                } elseif {$x > $n} {
                    break
                }
            } elseif {$x == $n} {
                append pgn "$line\n"
            }
       }
       close $infh
       return $pgn
   }
}}


#' 
#' *cmdName* **header** *key*
#' 
#' > return the given header entry for key. If no such entry exists returns \*
#' 
$scannergenerator code public {method header {htype} {
    if {[info exists headers($htype)]} {
         return $headers($htype)
    } else {
         return "*"
    }
}}

#' 
#' *cmdName* **move** *number* *?color?*
#' 
#' > Return for the given move number and turn color. Color can be on of *b,*, *black*, *Black*, *w*, *white*, *White* only the first letter is important. 
#'   If the color is not given move is assumed to be a halfmove.
#' 
$scannergenerator code public {method move {number {color ""}} {
   set hm [expr {$number*2-2}]
   if {$color eq ""} {
       set color w
   }
   set col [string tolower [string range $color 0 0]]
   if {$col eq "b"} {
       incr hm 1       
   } 
   return [lindex $moves $hm]
}}

#' 
#' *cmdName* **moves** 
#' 
#' > return all moves for the scanned game.
#' 
$scannergenerator code public {method moves {} {
   return $moves
}}


#' 
#' *cmdName* **scanPGNFile** *filename* *gameNumber*
#' 
#' > *filename* PGN filename
#'
#' > *gameNumber* number of the game, first game is 1, defaults to 1
#' 
#' > returns: number of half moves for scanned game.
#' 

$scannergenerator code public {method scanPGNFile {filename {n 1}} {
    set pgn [$this getGame $filename $n]
    set PGN $pgn
    array set headers [list]
    set moves [list]
    set nesting 0
    $this start $pgn
    $this run
    return [llength moves]
}}

#' 
#' *cmdName* **scanPGNText** *pgntext*
#' 
#' > *pgntext* PGN text string for single game
#'
#' > returns: number of half moves for scanned game.
#' 

$scannergenerator code public {method scanPGNText {pgntext} {
    set PGN $pgntext
    array set headers [list]
    set moves [list]
    set nesting 0
    $this start $pgntext
    $this run
    return [llength moves]
}}

set scannertext [$scannergenerator dump]
eval $scannertext

if {1} {
    set f [open "PgnReader-${version}.tm" w]
    puts $f $scannertext
    close $f
}

if {[info exists argv0] && $argv0 eq [info script]} {
    set scanner [PgnReader #auto]
    #$scanner hello
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
        puts "Moves: [$scanner moves]"
        puts "Comments: [$scanner comments]"
        puts "Comment 3 Black: [$scanner comment 3 b]"
        puts "Comment 6 Halfmove: [$scanner comment 6]"
    }
    itcl::delete object $scanner
}

#'
#' ## EXAMPLE
#' 
#' Let's first demonstrate the retrieval of a specific game from a PGN file:
#' 
#' ```{.tcl}
#' source [file join [file dirname [info script]] PgnReader-0.1.tm]
#' set pgnfile [file join [file dirname [info script]] sample.pgn]
#' set scanner [PgnReader #auto]
#' set pgn [$scanner getGame $pgnfile 4]
#' puts $pgn
#' ```
#' 
#' The real scanner works on single games. It is executed on the PGN text using the method _scanPGNText_.
#' Let's display the moves and who is white and black:
#' 
#' ```{.tcl}
#' $scanner scanPGNText $pgn
#' puts [$scanner moves]
#' puts [$scanner header White]
#' puts [$scanner header Black]
#' ```
#' 
#' As an alternative to the start and run cycle you can as well use the `scanPGNText` method, see below.
#' What was the second move of black?
#' 
#' ```{.tcl}
#' puts [$scanner move 1 White]
#' puts [$scanner move 1 Black]
#' puts [$scanner move 2 w]
#' puts [$scanner move 2 b]
#' puts [$scanner move 3 w]
#' ```
#' 
#' Let's now load an another game, there is scan:
#' 
#' ```{.tcl}
#' set pgn [$scanner getGame sample.pgn 1]
#' $scanner scanPGNText $pgn
#' puts [$scanner header White]
#' puts [$scanner header Black]
#' ```
#' 
#' Other meta information about the currently scanned PGN game can can be as well retrieved via the _header_ method.
#' 
#' ```{.tcl}
#' puts [$scanner header Date]
#' puts [$scanner header Result]
#' ```
#' 
#' ## SESSION
#' 
#' ```{.tcl}
#' puts "Tcl: [package present Tcl]"
#' puts "Itcl: [package versions Itcl]"
#' puts "tcl++: [package versions tcl++]"
#' ```
#'
#' ## INSTALLATION
#' 
#' - You need the yeti package to create the Scanner.
#' - You need the package Itcl or it's replacement tcl++ to run the generated scanner. A minmal version of the tcl++ package which is largely compatible with Itcl 3.0 can be retrieved from: 
#' 
#' 

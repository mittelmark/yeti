#
# ======================================================================
#
# YLEX -- Scanner for the Yeti Package
#
# A (f)lex-like parser for Tcl
#
# Copyright (c) Frank Pilhofer, yeti@fpx.de
#
# ======================================================================
#
# CVS Version Tag: $Id: ylex.tcl,v 1.8 2004/07/05 23:46:49 fp Exp $
#

package require Tcl 8.0
package require Itcl
package provide ylex 0.4.2

#
# ----------------------------------------------------------------------
# The Yeti Lexer
# ----------------------------------------------------------------------
#

namespace eval yeti {
    namespace import -force ::itcl::*
    class ylex {
	#
        # nocase:     whether we want -nocase on all regexps
	#

        public variable case
        public variable verbose
	public variable verbout
	public variable start

	#
	# ruleno:   integer for rule numbering
	# rules:    list of all active rules
	# regexs:   map rule# -> regular expression
	# igncase:  map rule# -> 1 if case should be ignored
	# codes:    map rule# -> user code to execute upon match
	# states:   map name -> list of active rules
	# macros:   map name  -> regular expression
	#

	private variable ruleno
	private variable rules
	private variable regexs
	private variable igncase
	private variable codes
	private variable states
	private variable macros

	#
	# user code to be dumped
	#

	public variable name
	private variable usercode
	private variable userconstrcode
	private variable userdestrcode
	private variable usererrorcode
	private variable userresetcode

	#
	# ============================================================
	# Constructor
	# ============================================================
	#

	constructor {args} {
	    set ruleno 0
	    set case 1
	    set verbose 0
	    set verbout stderr
	    set name "unnamed"
	    set start "INITIAL"
	    eval $this configure $args
	}

	#
	# ============================================================
	# Macro handling
	# ============================================================
	#

	private method substitute_macros {regex} {
	    #
	    # try to find {name} in regex
	    #

	    set hasmacro [regexp -indices {<[[:alnum:]_]+>} $regex found]

	    while {$hasmacro} {
		set begin [lindex $found 0]
		set end [lindex $found 1]
		set macroname [string range $regex \
			[expr {$begin + 1}] [expr {$end - 1}]]
		if {![info exists macros($macroname)]} {
		    error "undefined macro: $macroname"
		}

		#
		# substitute this macro
		#

		set regex [string replace $regex \
			$begin $end \
			"(?:$macros($macroname))"]

		#
		# repeat
		#

		set hasmacro [regexp -indices {<[[:alnum:]_]+>} $regex found]
	    }

	    return $regex
	}

	public method macro {args} {
	    #
	    # There may be a single list of names and regexs
	    #

	    if {[llength $args] == 1} {
		set args [lindex $args 0]
	    }

	    #
	    # Number of args must be positive and even
	    #

	    if {[llength $args] == 0 || ([llength $args] % 2) != 0} {
		error "usage: $this macro name regex ?name regex ...?"
	    }

	    foreach {macroname regex} $args {
		set macros($macroname) [substitute_macros $regex]

		if {$verbose > 1} {
		    puts $verbout "ylex: macro `$macroname' expands to `$macros($macroname)'"
		}
	    }
	}

	#
	# ============================================================
	# Rule handling
	# ============================================================
	#

	public method add {args} {
	    set doigncase 0

	    for {set i 0} {$i < [llength $args]} {incr i} {
		set arg [lindex $args $i]
		switch -glob -- $arg {
		    -nocase {
			set doigncase 1
		    }
		    -state {
			lappend thestates [lindex $args [incr i]]
		    }
		    -states {
			foreach thestate [lindex $args [incr i]] {
			    lappend thestates $thestate
			}
		    }
		    -- {
			incr i
			break
		    }
		    -* {
			error "illegal option: $arg"
		    }
		    default {
			break
		    }
		}
	    }

	    #
	    # One remaining argument can be a list of regexs and codes
	    #

	    if {$i+1 == [llength $args]} {
		set args [lindex $args $i]
		set i 0
	    }

	    #
	    # There must be an even, positive number of remaining args
	    #

	    if {$i >= [llength $args] || (([llength $args] - $i) % 2) != 0} {
		error "usage: $this add ?options? regex script ?regex script ...?"
	    }

	    for {} {$i < [llength $args]} {incr i} {
		set orig_regex [lindex $args $i]
		set code [lindex $args [incr i]]

		set regex [substitute_macros $orig_regex]

		#
		# check if regular expression is valid
		#

		if {[catch {regexp -- $regex "Hello World"}]} {
		    error "syntax error in regular expression `$regex'"
		}

		#
		# sanity check: the regular expression must not match the
		# empty string.
		#

		if {[regexp -- $regex ""]} {
		    error "regular expression `$regex' matches empty string"
		}

		#
		# check that there are no unbalanced unquoted braces
		#

		set quoted 0
		set brlevel 0

		for {set j 0} {$j < [string length $regex]} {incr j} {
		    set c [string index $regex $j]
		    if {$quoted} {
			set quoted 0
			continue
		    } elseif {[string equal $c "\\"]} {
			set quoted 1
			continue
		    } elseif {[string equal $c \{]} {
			incr brlevel
		    } elseif {[string equal $c \}]} {
			if {[incr brlevel -1] < 0} {
			    error "extra characters after close-brace in regular expression `$regex'"
			}
		    }
		}

		if {$brlevel != 0} {
		    error "missing close brace in regular expression `$regex'"
		}

		#
		# add to rule set
		#

		lappend rules [incr ruleno]
		set regexs($ruleno) $regex
		set igncase($ruleno) $doigncase

		if {[info exists thestates]} {
		    foreach thestate $thestates {
			lappend states($thestate) $ruleno
		    }
		} else {
		    lappend states(__all__) $ruleno
		}

		if {$code != "" && $code != "-"} {
		    set codes($ruleno) $code
		}

		if {$verbose > 1} {
		    puts $verbout "ylex: rule $ruleno `$orig_regex' expands to `$regex'"
		}
	    }

	    return $ruleno
	}

	#
	# ============================================================
	# Code handling
	# ============================================================
	#

	public method code {type thecode} {
	    switch -- $type {
		public -
		private -
		protected {
		    lappend usercode $type $thecode
		}
		constructor {
		    set userconstrcode $thecode
		}
		destructor {
		    set userdestrcode $thecode
		}
		error {
		    set usererrorcode $thecode
		}
		reset {
		    set userresetcode $thecode
		}
	    }
	}

	#
	# ============================================================
	# Dump generated Scanner
	# ============================================================
	#

	public method dump {} {
	    #
	    # Create scanner code
	    #

	    append data "itcl::class $name {\n"
	    append data "    public variable case $case\n"
	    append data "    public variable verbose 0\n"
	    append data "    public variable verbout stderr\n"
	    append data "    private variable yyistcl83 -1\n"
	    append data "\n"
	    append data "    public variable yydata \"\"\n"
	    append data "    public variable yyindex 0\n"
	    append data "    private variable yymatches\n"
	    append data "\n"
	    append data "    public variable yystate \"$start\"\n"
	    append data "    public variable yytext\n"
	    append data "    public variable yystart\n"
	    append data "    public variable yyend\n"
	    append data "\n"
	    append data "    private common yyregexs\n"
	    append data "    private common yyigncase\n"
	    append data "    private common yystates\n"
	    append data "\n"

	    #
	    # yyregexs:   map rule# -> regular expression
	    #

	    append data "    array set yyregexs {\n"

	    foreach ruleno [lsort -integer [array names regexs]] {
		append data "        $ruleno {$regexs($ruleno)}\n"
	    }

	    append data "    }\n"
	    append data "\n"

	    #
	    # yyigncase:  map rule# -> 1 if case should be ignored
	    #

	    append data "    array set yyigncase {\n"

	    foreach ruleno [lsort -integer [array names regexs]] {
		if {[info exists igncase($ruleno)]} {
		    append data "        $ruleno $igncase($ruleno)\n"
		} else {
		    append data "        $ruleno 0\n"
		}
	    }

	    append data "    }\n"
	    append data "\n"

	    #
	    # yystates: map name -> list of active rules
	    #

	    append data "    array set yystates {\n"

	    set hadall 0
	    foreach statename [lsort [array names states]] {
		append data "        $statename {\n"
		foreach ruleno $states($statename) {
		    append data "            $ruleno\n"
		}
		append data "        }\n"
		if {$statename == "__all__"} {
		    set hadall 1
		}
	    }

	    if {!$hadall} {
		append data "        __all__ {\n"
		append data "        }\n"
	    }

	    append data "    }\n"
	    append data "\n"

	    #
	    # user code
	    #

	    if {[info exists usercode]} {
		foreach {type thecode} $usercode {
		    append data "    $type {\n"
		    append data $thecode "\n"
		    append data "    }\n"
		    append data "\n"
		}
	    }

	    #
	    # constructor
	    #

	    if {[info exists userconstrcode]} {
		append data "    constructor " $userconstrcode "\n"
	    } else {
		append data "    constructor {args} {\n"
		append data "        eval \$this configure \$args\n"
		append data "    }\n"
		append data "    \n"
	    }

	    #
	    # destructor
	    #

	    if {[info exists userdestrcode]} {
		append data "    destructor " $userdestrcode "\n"
	    }

	    #
	    # reset
	    #

	    append data "    public method reset {} {\n"
	    append data "        if {\$verbose} {\n"
	    append data "            puts \$verbout \"$name: reset, entering state INITIAL\"\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        set yyindex 0\n"
	    append data "        set yystate \"$start\"\n"
	    append data "        catch {unset yymatches}\n"

	    if {[info exists userresetcode]} {
		append data "\n" $userresetcode "\n"
	    }

	    append data "    }\n"
	    append data "    \n"

	    #
	    # start
	    #

	    append data "    public method start {yynewstr} {\n"
	    append data "        reset\n"
	    append data "        set yydata \$yynewstr\n"
	    append data "    }\n"
	    append data "    \n"

	    #
	    # yyerror: overloadable error handling
	    #

	    append data "    protected method yyerror {yyerrmsg} {\n"

	    if {[info exists usererrorcode]} {
		append data $usererrorcode "\n"
	    } else {
		append data "        puts \$verbout \"$name: \$yyerrmsg\"\n"
	    }

	    append data "    }\n"
	    append data "    \n"

	    #
	    # yyupdate: check all regexps for the next match
	    #           returns rule for next best match
	    #

	    append data "    private method yyupdate {} {\n"
	    append data "        if {\$yyistcl83 == -1} {\n"
	    append data "            if {\[package vcompare \[info tclversion\] 8.3\] >= 0} {\n"
	    append data "                set yyistcl83 1\n"
	    append data "            } else {\n"
	    append data "                set yyistcl83 0\n"
	    append data "            }\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        set yybestmatch -1\n"
	    append data "        set yybestbegin \[string length \$yydata\]\n"
	    append data "        set yybestend   \$yybestbegin\n"
	    append data "        \n"
	    append data "        if {\$verbose >= 2} {\n"
	    append data "            set yycurdata \[string range \$yydata \$yyindex \[expr {\$yyindex + 16}\]\]\n"
	    append data "            set yycurout \[string map {\\r \\\\r \\n \\\\n} \$yycurdata\]\n"
	    append data "            if {\$yyindex + 16 < \[string length \$yydata\]} {\n"
	    append data "                append yycurout \"...\"\n"
	    append data "            }\n"
	    append data "            puts \$verbout \"$name: looking for match at position \$yyindex: `\$yycurout'\"\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        if {\[info exists yystates(\$yystate)\]} {\n"
	    append data "            set yyruleset \[concat \$yystates(\$yystate) \$yystates(__all__)\]\n"
	    append data "        } else {\n"
	    append data "            set yyruleset \$yystates(__all__)\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        if {\[llength \$yyruleset\] == 0} {\n"
	    append data "            if {\$verbose} {\n"
	    append data "                puts \$verbout \"$name: no active rules in state \$yystate\"\n"
	    append data "            }\n"
	    append data "        }\n"
	    set updatecode {

        foreach yyruleno $yyruleset {
            #
            # if the last match is in the past, rerun regexp
            #

            if {![info exists yymatches($yyruleno)] || \
                    [lindex [lindex $yymatches($yyruleno) 0] 0] < $yyindex} {
                if {$yyistcl83} {
                    if {!$case || $yyigncase($yyruleno)} {
                        set yyfound [regexp -nocase -start $yyindex \
                                -inline -indices -- \
                                $yyregexs($yyruleno) $yydata]
                    } else {
                        set yyfound [regexp -start $yyindex \
                                -inline -indices -- \
                                $yyregexs($yyruleno) $yydata]
                    }
                } else {
                    if {!$case || $yyigncase($yyruleno)} {
                        set yyres [regexp -nocase -start $yyindex \
                                -indices -- $yyregexs($yyruleno) \
                                $yydata yyfound]
                    } else {
                        set yyres [regexp -start $yyindex \
                                -indices -- $yyregexs($yyruleno) \
                                $yydata yyfound]
                    }

                    if {!$yyres} {
                        set yyfound [list]
                    } else {
                        set yyfound [list $yyfound]
                    }
                }

                if {[llength $yyfound] > 0} {
                    set yymatches($yyruleno) $yyfound
                } else {
                    set yymatches($yyruleno) [list \
                        [string length $yydata] \
                        [string length $yydata]]
                }

                if {$verbose >= 3 && [llength $yymatches($yyruleno)] > 0} {
                    set yymatchbegin [lindex [lindex $yymatches($yyruleno) 0] 0]
                    set yymatchend [lindex [lindex $yymatches($yyruleno) 0] 1]
                    if {$yymatchbegin != [string length $yydata]} {
                        set yymatchdata [string range $yydata $yymatchbegin $yymatchend]
			set yymatchout [string map {\r "\\r" \n "\\n"} $yymatchdata]
			if {[string length $yymatchout] > 20} {
			    set yymatchout [string range $yymatchout 0 16]
			    append yymatchout "..."
			}
                        puts $verbout "%name%: next match for rule $yyruleno is $yymatchbegin-$yymatchend: `$yymatchout'"
                    } else {
                        puts $verbout "%name%: rule $yyruleno does not match anwhere in remaining text"
		    }
                }
            }

            #
            # see if the match is better than the one we already have
            #

            set yymatchbegin [lindex [lindex $yymatches($yyruleno) 0] 0]
            set yymatchend [lindex [lindex $yymatches($yyruleno) 0] 1]

            if {($yymatchbegin < $yybestbegin) || \
                    ($yymatchbegin == $yybestbegin && $yymatchend > $yybestend)} {
                set yybestmatch $yyruleno
                set yybestbegin $yymatchbegin
                set yybestend   $yymatchend

                if {$verbose >= 2} {
                    set yybestdata [string range $yydata $yybestbegin $yybestend]
		    set yymatchout [string map {\r "\\r" \n "\\n"} $yybestdata]
		    if {[string length $yymatchout] > 20} {
			set yymatchout [string range $yymatchout 0 16]
			append yymatchout "..."
		    }
                    puts $verbout "%name%: new best match rule $yyruleno, $yybestbegin-$yybestend: `$yymatchout'"
                }
            }
        }
            }

	    append data [string map [list %name% $name] $updatecode]

	    append data "        \n"
	    append data "        return \$yybestmatch\n"
	    append data "    }\n"
	    append data "    \n"

	    #
	    # step
	    #

	    append data "    public method step {} {\n"
	    append data "        if {\$yyindex >= \[string length \$yydata\]} {\n"
	    append data "            if {\$verbose} {\n"
	    append data "                puts \$verbout \"$name: scanner at EOF\"\n"
	    append data "            }\n"
	    append data "            return \[list -1 1 \"\"\]\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        set yyruleno \[yyupdate\]\n"
	    append data "        \n"
	    append data "        if {\$yyruleno == -1} {\n"
	    append data "            if {\$verbose} {\n"
	    append data "                puts \$verbout \"$name: no further match until EOF\"\n"
	    append data "            }\n"
	    append data "            set yyindex \[string length \$yydata\]\n"
	    append data "            return \[list -1 1 \"\"\]\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        set yymatch \$yymatches(\$yyruleno)\n"
	    append data "        set yyindices \[lindex \$yymatch 0\]\n"
	    append data "        set yystart \[lindex \$yyindices 0\]\n"
	    append data "        set yyend \[lindex \$yyindices 1\]\n"
	    append data "        set yytext \[string range \$yydata \$yystart \$yyend\]\n"
	    append data "        \n"
	    append data "        if {\$verbose} {\n"
	    append data "            set yymatchout \[string map {\\r \\\\r \\n \\\\n} \$yytext\]\n"
	    append data "            if {\[string length \$yymatchout] > 20} {\n"
	    append data "                set yymatchout \[string range \$yymatchout 0 16\]\n"
	    append data "                append yymatchout \"...\"\n"
	    append data "            }\n"
	    append data "            puts \$verbout \"$name: best match at \$yyindex using rule \$yyruleno, \$yystart-\$yyend: `\$yymatchout'\"\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        set yyindex \[expr {\$yyend + 1}\]\n"
	    append data "        \n"

	    #
	    # Set $1, $2 ... to the submatches. We start at index
	    # zero, because the first list element is the complete
	    # match.
	    #

	    append data "        for {set yyi 0} {\$yyi < \[llength \$yymatch\]} {incr yyi} {\n"
	    append data "            set yysubidxs  \[lindex \$yymatch \$yyi\]\n"
	    append data "            set yysubbegin \[lindex \$yysubidxs 0\]\n"
	    append data "            set yysubend   \[lindex \$yysubidxs 1\]\n"
	    append data "            set \$yyi \[string range \$yydata \$yysubbegin \$yysubend\]\n"
	    append data "        }\n"
	    append data "        \n"

	    #
	    # exec user code
	    #

	    append data "        set yyoldstate \$yystate\n"
	    append data "        set yyretcode \[catch {\n"
	    append data "            switch -- \$yyruleno {\n"
	    foreach ruleno [lsort -integer [array names codes]] {
		append data "                $ruleno {\n"
		append data $codes($ruleno) "\n"
		append data "                }\n"
	    }
	    append data "            }\n"
	    append data "        } yyretdata\]\n"
	    append data "        \n"

	    #
	    # enter new state
	    #

	    append data "        if {\$verbose} {\n"
	    append data "            if {!\[string match \$yyoldstate \$yystate\]} {\n"
	    append data "                puts \$verbout \"$name: leaving state \$yyoldstate, entering \$yystate\"\n"
	    append data "            }\n"
	    append data "        }\n"
	    append data "        \n"

	    #
	    # did the user code throw an error?
	    #

	    append data "        if {\$yyretcode == 1} {\n"
	    append data "            global errorInfo\n"
	    append data "            set yyerrmsg \"script for rule # \$yyruleno failed: \$yyretdata\"\n"
	    append data "            yyerror \$yyerrmsg\n"
	    append data "            append errorInfo \"\\n    while executing script for rule # \$yyruleno\"\n"
	    append data "            error \$yyerrmsg \$errorInfo\n"
	    append data "        }\n"
	    append data "        \n"

	    #
	    # did the user code execute a return?
	    #

	    append data "        if {\$yyretcode == 2} {\n"
	    append data "            return \[list \$yyruleno 1 \$yyretdata\]\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        return \[list \$yyruleno 0 \"\"\]\n"
	    append data "    }\n"
	    append data "    \n"

	    #
	    # next
	    #

	    append data "    public method next {} {\n"
	    append data "        while {42} {\n"
	    append data "            set yysd \[step\]\n"
	    append data "            if {\[lindex \$yysd 1\] == 1} {\n"
	    append data "                return \[lindex \$yysd 2\]\n"
	    append data "            }\n"
	    append data "        }\n"
	    append data "    }\n"
	    append data "    \n"

	    #
	    # run
	    #

	    append data "    public method run {} {\n"
	    append data "        set yyresult \[list\]\n"
	    append data "        set yysd \[next\]\n"
	    append data "        while {\$yysd != \"\"} {\n"
	    append data "            lappend yyresult \$yysd\n"
	    append data "            set yysd \[next\]\n"
	    append data "        }\n"
	    append data "        return \$yyresult\n"
	    append data "    }\n"

	    #
	    # end of class
	    #

	    append data "}\n"
	    append data "\n"
	}
    }
}


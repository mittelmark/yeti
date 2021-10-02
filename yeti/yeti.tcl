#
# ======================================================================
#
# YETI -- Yet anothEr Tcl Interpreter
#
# A yacc/bison like parser for Tcl
#
# Copyright 2004-2014 (c) Frank Pilhofer, yeti (at) fpx (dot) de
# Copyright 2021      (c) Detlef Groth,   detlef(at) dgroth (dot) de
# 
# ======================================================================
#
# CVS Version Tag: $Id: yeti.tcl,v 1.28 2004/07/06 00:11:03 fp Exp $
#

package require Tcl 8.0
package require struct 2.0
#package require tcl++
#namespace import -force ::itcl::*
#
# Can work with Itcl 3.0 or Tcl++ 2.3. We prefer the former, but don't
# complain if the latter is already available.
#
if {false} {
    if {[catch {package present tcl++ 2.3}]} {
        if {[catch {package require Itcl 3.0}]} {
            if {[catch {package require tcl++ 2.3}]} {
                error "Oops in YETI initialization: neither \[incr Tcl\] nor tcl++ available"
            }
        } else {
            namespace import -force ::itcl::*
        }
    }
}
 
package provide yeti 0.5.0
package require Itcl

#
# ----------------------------------------------------------------------
# The Yeti parser
# ----------------------------------------------------------------------
#

namespace eval yeti {

    itcl::class yeti {
	public variable verbose
	public variable verbout

	#
	# production rules
	#

	public variable start
	private variable productions
	private variable rules
	private variable codes
	private variable ruleno

	#
	# NFSM data
	#

	private variable nfsm
	private variable nfsminitstate
	private variable nfsmendstate
	private variable nfsmstateno

	#
	# DFSM data
	#

	private variable dfsm
	private variable dfsminitstate
	private variable dfsmendstate
	private variable dfsmstateno

	#
	# Mapping bettween the three
	#

	private variable nfsmstatetont
	private variable nfsmstatetodfsmstate
	private variable dfsmstatetonfsmstate

	#
	# We store the terminals that may follow a non-terminal. This
	# knowledge is useful to solve reduce/reduce conflicts by
	# looking at the lookahead.
	#

	private variable ntpostterminals

	#
	# cache
	#

	private variable equivalentstates
	private variable canntbeempty

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
	# Constructor and Destructor
	# ============================================================
	#
	
	constructor {args} {
	    set verbose 0
	    set ruleno 1
	    set dfsm ""
	    set nfsm ""
	    set verbout stderr
	    set name "unnamed"
	    set start "start"
	    eval $this configure $args
	}

	destructor {
	    if {$nfsm != ""} {
		catch {$nfsm destroy}
	    }
	    if {$dfsm != ""} {
		catch {$dfsm destroy}
	    }
	}

	public method add {args} {
	    if {[llength $args] == 1} {
		set args [lindex $args 0]
	    }

	    if {([llength $args] == 1) || \
		    ([llength $args] != 2 && ([llength $args] % 3) != 0)} {
		error "usage: $this add lhs rhs ?script?"
	    }

	    if {[llength $args] == 2} {
		set lhs [lindex $args 0]
		set rhs [lindex $args 1]
		lappend productions($lhs) [incr ruleno]
		set rules($ruleno) [list $lhs $rhs]
		return $ruleno
	    }

	    set lastlhs ""

	    foreach {lhs rhs code} $args {
		if {$lhs == "|"} {
		    set lhs $lastlhs
		}

		lappend productions($lhs) [incr ruleno]
		set rules($ruleno) [list $lhs $rhs]

		if {$code != "" && $code != "-"} {
		    set codes($ruleno) $code
		}

		set lastlhs $lhs
	    }

	    return $ruleno
	}

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
	# Build a Non-deterministic Finite State Machine from rules
	# ============================================================
	#

	private method BuildNFSM {} {
	    if {$nfsm != ""} {
		catch {$nfsm destroy}
		catch {unset equivalentstates}
		catch {unset canntbeempty}
		catch {unset nfsmstatetont}
	    }

	    set nfsm [::struct::graph nfsm$this]

	    #
	    # initially, assign state# to each non-terminal
	    #

	    set nfsmstateno 0

	    foreach nt [array names productions] {
		set ntstate($nt) [incr nfsmstateno]
		set nfsmstatetont($nfsmstateno) $nt

		$nfsm node insert $nfsmstateno
		$nfsm node set $nfsmstateno info [list]
		$nfsm node set $nfsmstateno reductions [list]
	    }

	    set nfsminitstate $ntstate(__init__)

	    #
	    # traverse all rules
	    #

	    foreach ruleno [array names rules] {
		set lhs [lindex $rules($ruleno) 0]
		set rhs [lindex $rules($ruleno) 1]

		#
		# create new state, make epsilon transition from
		# the non-terminal's state# to new state
		#

		$nfsm node insert [incr nfsmstateno]
		$nfsm node set $nfsmstateno info [list [list $ruleno 0]]
		$nfsm node set $nfsmstateno reductions [list]

		set arc [$nfsm arc insert $ntstate($lhs) $nfsmstateno]
		$nfsm arc set $arc token ""

		set laststate $nfsmstateno

		#
		# create new state for each step of RHS
		#

		for {set i 0} {$i < [llength $rhs]} {incr i} {
		    set token [lindex $rhs $i]

		    $nfsm node insert [incr nfsmstateno]
		    $nfsm node set $nfsmstateno info \
			    [list [list $ruleno [expr {$i+1}]]]
		    $nfsm node set $nfsmstateno reductions [list]

		    set arc [$nfsm arc insert $laststate $nfsmstateno]
		    $nfsm arc set $arc token $token

		    #
		    # If token is a non-terminal, make epsilon transition
		    # to non-terminal's state# so that this non-terminal
		    # can be read.
		    #
		    # However, don't do that if we're at index 0 and the
		    # non-terminal is our LHS. In that case, we're in the
		    # right state for reading this non-terminal already
		    # (via other rules). Adding a transition would cause
		    # a circle (via epsilon transitions).
		    #

		    if {($i != 0 || $token != $lhs) && \
			    [info exists productions($token)]} {
			set arc [$nfsm arc insert $laststate $ntstate($token)]
			$nfsm arc set $arc token ""
		    }

		    set laststate $nfsmstateno
		}

		#
		# mark the last state as a reduction state
		#

		$nfsm node set $laststate reductions [list $ruleno]

		#
		# if lhs is __init__, then this is our final state
		#

		if {$lhs == "__init__"} {
		    set nfsmendstate $laststate
		}
	    }
	}

	#
	# ============================================================
	# State Machine Helpers
	# ============================================================
	#

	#
	# Determine if the non-terminal can produce the empty string
	#

	private method CanNTBeEmpty {nt} {
	    if {[info exists canntbeempty($nt)]} {
		return $canntbeempty($nt)
	    }

	    if {![info exists productions($nt)]} {
		return 0
	    }

	    set canbeempty 0
	    set canntbeempty($nt) 1 ;# protection against infinite recursion

	    foreach rule $productions($nt) {
		set lhs [lindex $rules(rule) 0]
		set rhs [lindex $rules(rule) 1]

		for {set i 0} {$i < [llength $rhs]} {incr i} {
		    set token [lindex $rhs $i]

		    #
		    # if token is a terminal, this rule cannot be empty
		    #

		    if {![info exists productions($token)]} {
			break
		    }

		    #
		    # if token is the lhs, then ignore
		    #

		    if {$token == $lhs} {
			continue
		    }

		    if {![CanNTBeEmpty $token]} {
			break
		    }
		}

		#
		# if we could traverse the rule without finding a terminal,
		# then this rule can indeed produce the empty string
		#

		if {$i >= [llength $rhs]} {
		    set canbeempty 1
		    break
		}
	    }

	    set canntbeempty($nt) $canbeempty
	    return $canbeempty
	}

	#
	# Determine which states are reachable by epsilon transitions,
	# taking into account non-terminals that can produce an empty
	# string.
	#

	private method NFSMEpsilonTransitions {state {beenthere {}}} {
	    if {[info exists equivalentstates($state)]} {
		return $equivalentstates($state)
	    }

	    if {[lsearch -exact $beenthere $state] != -1} {
		error "error: infinite loop detected for NFSM state $state"
	    }

	    lappend beenthere $state
	    set resstates [list $state]

	    foreach arc [$nfsm arcs -out $state] {
		set token [$nfsm arc get $arc token]

		if {$token != ""} {
		    if {[info exists productions($token)]} {
			continue
		    }

		    if {![CanNTBeEmpty $token]} {
			continue
		    }
		}

		set newstate [$nfsm arc target $arc]
		lappend resstates $newstate

		foreach addstate [NFSMEpsilonTransitions $newstate $beenthere] {
		    lappend resstates $addstate
		}
	    }

	    set equivalentstates($state) [lsort -unique $resstates]
	    return $equivalentstates($state)
	}

	#
	# Collect terminals that can follow a non-terminal. This info
	# can be used to resolve reduce/reduce conflicts.
	#

	private method CollectPostTerminalsRek {nt {beenthere {}}} {
	    upvar ntpostfollows ntpostfollows
	    upvar temppostterminals temppostterminals

	    if {[info exists ntpostterminals($nt)]} {
		return $ntpostterminals($nt)
	    }

	    if {[lsearch -exact $beenthere $nt] != -1} {
		return [list]
	    }

	    lappend beenthere $nt

	    if {[info exists temppostterminals($nt)]} {
		set res $temppostterminals($nt)
	    } else {
		set res [list]
	    }

	    if {[info exists ntpostfollows($nt)]} {
		foreach follows $ntpostfollows($nt) {
		    foreach token [CollectPostTerminalsRek $follows $beenthere] {
			lappend res $token
		    }
		}
	    }

	    set ntpostterminals($nt) [lsort -unique $res]
	    return $res
	}

	private method CollectPostTerminals {} {
	    catch {unset ntpostterminals}

	    #
	    # Look at each arc in the graph, and see if it is marked with
	    # a non-terminal. If so, then see which terminals can be read
	    # in the target state.
	    #

	    foreach arc [$nfsm arcs] {
		set nt [$nfsm arc get $arc token]

		if {$nt == ""} {
		    continue
		}

		if {![info exists productions($nt)]} {
		    # terminal
		    continue
		}

		set ntstate [$nfsm arc target $arc]
		set ntstates [NFSMEpsilonTransitions $ntstate]

		foreach state $ntstates {
		    foreach arc [$nfsm arcs -out $state] {
			set token [$nfsm arc get $arc token]

			if {$token == ""} {
			    continue
			}

			if {[info exists productions($token)]} {
			    # non-terminal
			    continue
			}

			lappend temppostterminals($nt) $token
		    }

		    #
		    # If there is a reduction possible, then everything
		    # that can follow the LHS of the rule that is being
		    # reduced can also follow this nt.
		    #

		    foreach redux [$nfsm node get $state reductions] {
			set lhs [lindex $rules($redux) 0]
			lappend ntpostfollows($nt) $lhs
		    }
		}
	    }

	    lappend temppostterminals(__init__) "" ;# EOF

	    foreach nt [array names productions] {
		CollectPostTerminalsRek $nt
	    }

	    if {$verbose >= 4} {
		puts $verbout "CollectPostTerminals: lookahead terminals for reductions"

		foreach nt [array names productions] {
		    puts -nonewline $verbout "  lookaheads for reducing $nt:"
		    if {[llength $ntpostterminals($nt)] == 0} {
			puts $verbout " (none)"
		    } else {
			foreach lookahead $ntpostterminals($nt) {
			    if {$lookahead == ""} {
				puts -nonewline $verbout " (EOF)"
			    } else {
				puts -nonewline $verbout " $lookahead"
			    }
			}
			puts $verbout ""
		    }
		}

		puts $verbout ""
	    }
	}

	#
	# ============================================================
	# Build a Deterministic Finite State Machine from NFSM
	# ============================================================
	#

	#
	# Build up deterministic state dfsmstate from all of nfsmstates
	# by simulating all transitions from these states in parallel
	#

	private method BuildDFSMTransition {dfsmstate nfsmstates} {
	    #
	    # fill in state information for this dfsmstate from all of
	    # the nfsmstates
	    #

	    set dfsminfo [list]
	    set dfsmredux [list]

	    foreach nfsmstate $nfsmstates {
		foreach info [$nfsm node get $nfsmstate info] {
		    lappend dfsminfo $info
		}
		foreach redux [$nfsm node get $nfsmstate reductions] {
		    lappend dfsmredux $redux
		}
	    }

	    #
	    # initialize dfsmstate info
	    #

	    $dfsm node set $dfsmstate info $dfsminfo
	    $dfsm node set $dfsmstate reductions $dfsmredux

	    #
	    # map nfsmstates to dfsmstate
	    #

	    set nfsmstates [lsort -unique -integer $nfsmstates]
	    set dfsmstatetonfsmstate($dfsmstate) $nfsmstates
	    set nfsmstatetodfsmstate([join $nfsmstates ,]) $dfsmstate

	    foreach nfsmstate $nfsmstates {
		set nfsmstatetodfsmstate($nfsmstate) $dfsmstate
	    }

	    #
	    # collect all tokens that can be read in any of these states,
	    # and the states that we can enter by reading them
	    #
	    # allnfsmtokens: map(token) : list of nextstate
	    #

	    foreach arc [eval $nfsm arcs -out $nfsmstates] {
		set token [$nfsm arc get $arc token]

		if {$token == ""} {
		    continue
		}

		set newstate [$nfsm arc target $arc]
		set newstates [NFSMEpsilonTransitions $newstate]

		foreach nstate $newstates {
		    lappend allnfsmtokens($token) $nstate
		}
	    }

	    #
	    # create transitions for each of these tokens
	    #

	    foreach token [array names allnfsmtokens] {
		#
		# See if we already have a DFSM state that is equivalent to
		# all the NFSM states reachable by reading $token. If yes,
		# link to it, otherwise create a new one.
		#

		set allnfsmtokens($token) \
			[lsort -unique -integer $allnfsmtokens($token)]
		set allnfsmindex [join $allnfsmtokens($token) ,]

		if {[info exists nfsmstatetodfsmstate($allnfsmindex)]} {
		    set equivalentstate $nfsmstatetodfsmstate($allnfsmindex)
		} else {
		    set equivalentstate -1
		}

		if {$equivalentstate >= 0} {
		    #
		    # create transition to that state
		    #
		    set arc [$dfsm arc insert $dfsmstate $equivalentstate]
		    $dfsm arc set $arc token $token
		} else {
		    #
		    # else, create a new state, and simulate that state
		    #
		    $dfsm node insert [incr dfsmstateno]
		    set arc [$dfsm arc insert $dfsmstate $dfsmstateno]
		    $dfsm arc set $arc token $token
		    BuildDFSMTransition $dfsmstateno $allnfsmtokens($token)
		}
	    }
	}

	private method BuildDFSM {} {
	    #
	    # initialize DFSM building process
	    #

	    if {$dfsm != ""} {
		catch {$dfsm destroy}
		catch {unset nfsmstatetodfsmstate}
		catch {unset dfsmstatetonfsmstate}
	    }

	    set dfsm [::struct::graph dfsm$this]

	    set dfsmstateno 1
	    set dfsminitstate 1
	    $dfsm node insert 1

	    #
	    # Start DFSM building process by creating an initial state #1
	    # that represents all nodes that are reachable by epsilon
	    # transitions from the NFSM's initial state.
	    #
	    
	    BuildDFSMTransition 1 [NFSMEpsilonTransitions $nfsminitstate]

	    #
	    # Check which DFSM state the NFSM's end state has been mapped to
	    #

	    if {![info exists nfsmstatetodfsmstate($nfsmendstate)]} {
		error "assertion failure: no dfsm state for end state $nfsmendstate"
	    }

	    set dfsmendstate $nfsmstatetodfsmstate($nfsmendstate)
	}

	#
	# ============================================================
	# Check for conflicts
	# ============================================================
	#

	#
	# check for reduce/reduce conflicts
	#

	private method CheckReduceReduce {} {
	    foreach state [$dfsm nodes] {
		set reductions [$dfsm node get $state reductions]

		if {[llength $reductions] <= 1} {
		    continue
		}

		#
		# multiple reductions possible here, check if their set
		# of lookaheads is disjunct
		#

		catch {unset testlookaheads}

		foreach redux $reductions {
		    set lhs [lindex $rules($redux) 0]
		    if {![info exists ntpostterminals($lhs)]} {
			continue
		    }
		    foreach lookahead $ntpostterminals($lhs) {
			if {[info exists testlookaheads($lookahead)]} {
			    if {$verbose} {
				puts $verbout "yeti: warning: reduce/reduce conflict in state $state ($lookahead)"
				DumpState $dfsm $state
			    }
			} else {
			    set testlookaheads($lookahead) 1
			}
		    }
		}

		catch {unset testlookaheads}
	    }
	}

	private method CheckShiftReduce {} {
	    foreach state [$dfsm nodes] {
		#
		# We have computed the reduction lookaheads (which
		# terminals could follow a non-terminal) in the
		# ntpostterminals array.
		#
		# Make sure that this state, where the reduction
		# may occur, does not offer an out arc that also
		# reads this token
		#

		catch {unset testlookaheads}

		set reductions [$dfsm node get $state reductions]

		foreach redux $reductions {
		    set lhs [lindex $rules($redux) 0]

		    if {![info exists ntpostterminals($lhs)]} {
			continue
		    }

		    foreach terminal $ntpostterminals($lhs) {
			set testlookaheads($terminal) $lhs
		    }
		}

		foreach arc [$dfsm arcs -out $state] {
		    set token [$dfsm arc get $arc token]

		    if {[info exists testlookaheads($token)]} {
			if {$verbose} {
			    puts $verbout "yeti: warning: shift/reduce conflict in state $state (shift $token, reduce $testlookaheads($token))"
			    DumpState $dfsm $state
			}
		    }
		}
	    }
	}

	private method CheckDFSM {} {
	    CheckReduceReduce
	    CheckShiftReduce
	}

	#
	# ============================================================
	# Debug: dump the state machines
	# ============================================================
	#

	private method DumpState {sm state} {
	    foreach info [$sm node get $state info] {
		set index [lindex $info 1]
		set ruleno [lindex $info 0]
		set rule $rules($ruleno)
		set lhs [lindex $rule 0]
		set rhs [lindex $rule 1]
		puts -nonewline $verbout "  $lhs -->"
		for {set i 0} {$i < $index} {incr i} {
		    puts -nonewline $verbout " "
		    puts -nonewline $verbout [lindex $rhs $i]
		}
		puts -nonewline $verbout " ."
		for {} {$i < [llength $rhs]} {incr i} {
		    puts -nonewline $verbout " "
		    puts -nonewline $verbout [lindex $rhs $i]
		}
		puts $verbout ""
	    }

	    if {[llength [$sm node get $state info]] > 0} {
		puts $verbout ""
	    }
	    
	    foreach arc [$sm arcs -out $state] {
		set token [$sm arc get $arc token]
		if {$token == ""} {
		    puts -nonewline $verbout "  (epsilon): go to state"
		} else {
		    puts -nonewline $verbout "  $token: go to state"
		}
		set ts [$sm arc target $arc]
		puts -nonewline $verbout " "
		puts -nonewline $verbout $ts
		puts $verbout "."
	    }

	    if {[llength [$sm arcs -out $state]] > 0} {
		puts $verbout ""
	    }

	    set reductions [$sm node get $state reductions]

	    if {[llength $reductions] > 1} {
		foreach redux $reductions {
		    set lhs [lindex $rules($redux) 0]
		    if {[info exists ntpostterminals($lhs)]} {
			set lookaheads $ntpostterminals($lhs)
		    } else {
			set lookaheads [list "(default)"]
		    }
		    foreach lookahead $lookaheads {
			if {$lookahead == ""} {
			    set lookahead "(EOF)"
			}
			puts $verbout "  $lookahead: reduce using rule# $redux ($lhs)"
		    }
		}
	    } elseif {[llength $reductions] == 1} {
		set redux [lindex $reductions 0]
		set lhs [lindex $rules($redux) 0]
		puts $verbout "  (default): reduce using rule# $redux ($lhs)"
	    }
	    
	    if {[llength $reductions] > 0} {
		puts $verbout ""
	    }
	}

	public method DumpNFSM {} {
	    puts -nonewline $verbout "NFSM: initial state $nfsminitstate, "
	    puts $verbout "final state $nfsmendstate"
	    foreach state [lsort -integer [$nfsm nodes]] {
		puts $verbout "NFSM State # $state:"
		if {[info exists nfsmstatetont($state)]} {
		    puts $verbout "  represents token $nfsmstatetont($state)"
		}
		DumpState $nfsm $state
	    }
	}

	public method DumpDFSM {} {
	    puts -nonewline $verbout "DFSM: initial state $dfsminitstate, "
	    puts $verbout "final state $dfsmendstate"
	    foreach state [lsort -integer [$dfsm nodes]] {
		puts $verbout "DFSM State # $state:"
		puts $verbout "  represents NFSM states $dfsmstatetonfsmstate($state)"
		puts $verbout ""
		DumpState $dfsm $state
	    }
	}

	#
	# ============================================================
	# Build State Machines
	# ============================================================
	#

	public method BuildSMS {} {
	    #
	    # Add initial rule __init__ -> $start
	    #

	    if {![info exists rules(0)]} {
		lappend productions(__init__) 0
		set rules(0) [list __init__ [list $start]]
	    }

	    #
	    # Build Non-deterministic Finite State Machine from rules
	    #

	    if {$nfsm == ""} {
		BuildNFSM
	    }

	    #
	    # Build Deterministic Finite State Machine from NFSM
	    #

	    CollectPostTerminals

	    if {$dfsm == ""} {
		BuildDFSM
	    }

	    #
	    # Check DFSM for conflicts
	    #

	    CheckDFSM

	    #
	    # Debug output
	    #

	    if {$verbose >= 3} {
		puts $verbout "-----"
		puts $verbout "NFSM:"
		puts $verbout "-----"
		DumpNFSM
	    }

	    if {$verbose >= 2} {
		puts $verbout "-----"
		puts $verbout "DFSM:"
		puts $verbout "-----"
		DumpDFSM
	    }
	}

	#
	# ============================================================
	# Dump generated Parser
	# ============================================================
	#

	public method dump {} {
	    #
	    # First, build DFSM if necessary
	    #
	    
	    if {$dfsm == ""} {
		BuildSMS
	    }

	    #
	    # Create parser code
	    #
            append data "package require Itcl\n"
	    append data "itcl::class $name {\n"
	    append data "    public variable scanner \"\"\n"
	    append data "    public variable verbose 0\n"
	    append data "    public variable verbout stderr\n"
	    append data "    private variable yystate $dfsminitstate\n"
	    append data "    private variable yysstack {$dfsminitstate}\n"
	    append data "    private variable yydstack {}\n"
	    append data "    private variable yyreadnext 1\n"
	    append data "    private variable yylookahead\n"
	    append data "    private variable yyfinished 0\n"
	    append data "    private common yytrans\n"
	    append data "    private common yyredux\n"
	    append data "    private common yyrules\n"
	    append data "\n"
	    
	    #
	    # yytrans: array($state,$token) -> newstate
	    #

	    append data "    array set yytrans {\n"

	    foreach state [lsort -integer [$dfsm nodes]] {
		foreach arc [$dfsm arcs -out $state] {
		    set token [$dfsm arc get $arc token]
		    set ts [$dfsm arc target $arc]
		    append data "        $state,$token $ts\n"
		}
	    }

	    append data "    }\n"
	    append data "\n"

	    #
	    # yyredux: array($state,$token) -> ruleno
	    #          array($state)        -> ruleno
	    #

	    append data "    array set yyredux {\n"

	    foreach state [lsort -integer [$dfsm nodes]] {
		set reductions [$dfsm node get $state reductions]

		foreach redux $reductions {
		    set lhs [lindex $rules($redux) 0]
		    set count [expr {[llength $rules($redux)] - 1}]

		    if {[info exists ntpostterminals($lhs)] && \
			    [llength $reductions] > 1} {
			foreach lookahead $ntpostterminals($lhs) {
			    append data "        $state,$lookahead $redux\n"
			}
		    } else {
			append data "        $state $redux\n"
		    }
		}
	    }

	    append data "    }\n"
	    append data "\n"

	    #
	    # yyrules: array($ruleno) -> [list lhs rhs]
	    #

	    append data "    array set yyrules {\n"

	    foreach ruleno [lsort -integer [array names rules]] {
		set rule $rules($ruleno)
		set lhs [lindex $rule 0]
		set rhs [lindex $rule 1]
		append data "        $ruleno {$lhs {$rhs}}\n"
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
	    append data "            puts \$verbout \"$name: reset, entering state $dfsminitstate\"\n"
	    append data "        }\n"
	    append data "        set yystate $dfsminitstate\n"
	    append data "        set yysstack \[list \$yystate\]\n"
	    append data "        set yydstack \[list\]\n"
	    append data "        set yyreadnext 1\n"
	    append data "        set yyfinished 0\n"

	    if {[info exists userresetcode]} {
		append data "\n" $userresetcode "\n"
	    }

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
	    # yyshift: shift token and data
	    #

	    append data "    private method yyshift {yytoken yydata} {\n"
	    append data "        set yynewstate \$yytrans(\$yystate,\$yytoken)\n"
	    append data "        lappend yysstack \$yynewstate\n"
	    append data "        lappend yydstack \$yydata\n"
	    append data "        \n"
	    append data "        if {\$verbose} {\n"
	    append data "            puts \$verbout \"$name: shifting token \$yytoken, entering state \$yynewstate\"\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        set yystate \$yynewstate\n"
	    append data "    }\n"
	    append data "\n"

	    #
	    # yyreduce: execute a rule
	    #

	    append data "    private method yyreduce {yyruleno} {\n"
	    append data "        set yylhs \[lindex \$yyrules(\$yyruleno) 0\]\n"
	    append data "        set yyrhs \[lindex \$yyrules(\$yyruleno) 1\]\n"
	    append data "        set yycount \[llength \$yyrhs\]\n"
	    append data "        set yyssdepth \[llength \$yysstack\]\n"
	    append data "        set yydsdepth \[llength \$yydstack\]\n"
	    append data "        \n"
	    append data "        if {\$verbose} {\n"
	    append data "            puts -nonewline \$verbout \"$name: reducing rule # \$yyruleno: \$yylhs -->\"\n"
	    append data "            foreach yytoken \$yyrhs {\n"
	    append data "                puts -nonewline \$verbout \" \"\n"
	    append data "                puts -nonewline \$verbout \$yytoken\n"
	    append data "            }\n"
	    append data "            puts \$verbout \"\"\n"
	    append data "        }\n"
	    append data "\n"
	    append data "        for {set yyi 0} {\$yyi < \$yycount} {incr yyi} {\n"
	    append data "            set yyvarname \[expr {\$yyi + 1}\]\n"
	    append data "            set yyvarval  \[lindex \$yydstack \[expr {\$yydsdepth-\$yycount+\$yyi}\]\]\n"
	    append data "            set \$yyvarname \$yyvarval\n"
	    append data "        }\n"
	    append data "        \n"
	    if {[llength [array names codes]] > 0} {
		append data "        set yyretcode \[catch {\n"
		append data "            switch -- \$yyruleno {\n"
		foreach ruleno [lsort -integer [array names codes]] {
		    append data "                $ruleno {\n"
		    append data $codes($ruleno) "\n"
		    append data "                }\n"
		}
		append data "            }\n"
		append data "        } yyretdata\]\n"
	    } else {
		#
		# Tcl doesn't like empty switch statements
		#
		append data "        set yyretcode 0"
	    }
	    append data "        \n"
	    append data "        if {\$yyretcode == 0} {\n"
	    append data "            if {\$yycount} {\n"
	    append data "                set yyretdata \$1\n"
	    append data "            } else {\n"
	    append data "                set yyretdata \"\"\n"
	    append data "            }\n"
	    append data "        } elseif {\$yyretcode == 1} {\n"
	    append data "            global errorInfo\n"
	    append data "            set yyerrmsg \"script for rule # \$yyruleno (\$yylhs --> \$yyrhs) failed: \$yyretdata\"\n"
	    append data "            yyerror \$yyerrmsg\n"
	    append data "            append errorInfo \"\\n    while executing script for rule # \$yyruleno (\$yylhs --> \$yyrhs)\"\n"
	    append data "            error \$yyerrmsg \$errorInfo\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        set yysstack \[lrange \$yysstack 0 \[expr {\$yyssdepth-\$yycount-1}\]\]\n"
	    append data "        set yydstack \[lrange \$yydstack 0 \[expr {\$yydsdepth-\$yycount-1}\]\]\n"
	    append data "        set yystate \[lindex \$yysstack end\]\n"
	    append data "        \n"
	    append data "        if {\$verbose} {\n"
	    append data "            puts \$verbout \"$name: entering state \$yystate\"\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        return \$yyretdata\n"
	    append data "    }\n"
	    append data "    \n"

	    #
	    # Single step
	    #

	    append data "    public method step {} {\n"
	    append data "        if {\$yyfinished} {\n"
	    append data "           error \"step beyond end of parse\"\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        if {\$yyreadnext} {\n"
	    append data "            set yylookahead \[\$scanner next\]\n"
	    append data "            set yyreadnext 0\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        set yyterm \[lindex \$yylookahead 0\]\n"
	    append data "        set yydata \[lindex \$yylookahead 1\]\n"
	    append data "        \n"
	    append data "        if {\[info exists yytrans(\$yystate,\$yyterm)\]} {\n"
	    append data "            yyshift \$yyterm \$yydata\n"
	    append data "            set yyreadnext 1\n"
	    append data "            return \[list \$yyterm \$yydata\]\n"
	    append data "        } elseif {\[info exists yyredux(\$yystate)\] || \\\n"
	    append data "                \[info exists yyredux(\$yystate,\$yyterm)\]} {\n"
	    append data "            if {\[info exists yyredux(\$yystate)\]} {\n"
	    append data "                set yyruleno \$yyredux(\$yystate)\n"
	    append data "            } else {\n"
	    append data "                set yyruleno \$yyredux(\$yystate,\$yyterm)\n"
	    append data "            }\n"
	    append data "            \n"
	    append data "            set yyreduxlhs \[lindex \$yyrules(\$yyruleno) 0\]\n"
	    append data "            set yyreduxdata \[yyreduce \$yyruleno\]\n"
	    append data "            \n"
	    append data "            if {\$yyreduxlhs == \"__init__\"} {\n"
	    append data "                set yyfinished 1\n"
	    append data "            } else {\n"
	    append data "                yyshift \$yyreduxlhs \$yyreduxdata\n"
	    append data "            }\n"
	    append data "            return \[list \$yyreduxlhs \$yyreduxdata\]\n"
	    append data "        } else {\n"
	    append data "            global errorInfo\n"
	    append data "            set yyerrmsg \"parse error reading \\\"\$yyterm\\\" in state \$yystate\"\n"
	    append data "            set errorInfo \$yyerrmsg\n"
	    append data "            append errorInfo \"\\n    expecting one of:\"\n"
	    append data "            foreach yylaname \[array names yytrans \$yystate,*\] {\n"
	    append data "                append errorInfo \"\\n        \" \[lindex \[split \$yylaname ,\] 1\]\n"
	    append data "            }\n"
	    append data "            yyerror \$yyerrmsg\n"
	    append data "            error \$yyerrmsg \$errorInfo\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        error \"oops: unreachable code\"\n"
	    append data "    }\n"
	    append data "    \n"

	    #
	    # Main parse method
	    #

	    append data "    public method parse {} {\n"
	    append data "        if {\$scanner == \"\"} {\n"
	    append data "            global errorInfo\n"
	    append data "            set yyerrmsg \"cannot start parsing without a scanner\"\n"
	    append data "            set errorInfo \$yyerrmsg\n"
	    append data "            yyerror \$yyerrmsg\n"
	    append data "            error \$yyerrmsg \$errorInfo\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        while {!\$yyfinished} {\n"
	    append data "            set yydata \[step\]\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        if {\[lindex \$yylookahead 0\] != \"\"} {\n"
	    append data "            global errorInfo\n"
	    append data "            set yyerrmsg \"parser finished, but not at EOF (lookahead: \[lindex \$yylookahead 0\])\"\n"
	    append data "            set errorInfo \$yyerrmsg\n"
	    append data "            yyerror \$yyerrmsg\n"
	    append data "            error \$yyerrmsg\n"
	    append data "        }\n"
	    append data "        \n"
	    append data "        return \[lindex \$yydata 1\]\n"
	    append data "    }\n"

	    #
	    # End of newly generated class
	    #

	    append data "}\n"
	    append data "\n"
	}
    }
}

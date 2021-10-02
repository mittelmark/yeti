#
# Sensus Consulting Ltd (C) 1997-1998
# Matt Newman <matt@sensus.org>
#
# All the p* routines have C equivilents. So these
# are provided just in case you don't have the C
# extension.
#
# They work on "paired" lists, i.e. the format used by
# Tcl's array set & get. This is different from the
# "keyed" lists used by TclX.
#
# One not-so-know fact about Tcl is that you can give a list
# of variables to the foreach command. SO to iterate over a plist
# you can do:
#
# foreach {fld val} $plist {
#	...
# }
#
proc psort {list} {
	array set a $list
	set ret {}
	foreach key [lsort [array names a]] {
		lappend ret $key $a($key)
	}
	return $ret
}
#
# I need these bogus INDEX entries because
# Tcl 8's auto_mkindex doesn't pick up the
# definintions inside the if statements!
#INDEX\
proc pget {} {}
#INDEX\
proc pset {} {}
#INDEX\
proc pkeys {} {}
#INDEX\
proc pdel {} {}
if {[info comm pget]==""} {
	#
	# These are normally done in C for speed.
	#
	proc pget {list fld {def "_NULL_"}} {
		array set a $list
		if {[info exists a($fld)]} {
			return $a($fld)
		} elseif {$def != "_NULL_"} {
			return $def
		} else {
			error "\"$fld\" not found in list"
		}
	}
	proc pset {list args} {
		array set a $list
		array set a $args
		return [array get a]
	}
	proc pkeys {list} {
		array set a $list
		return [array names a]
	}
	proc pdel {list args} {
		array set a $list
		foreach arg $args {
			unset a($arg)
		}
		return [array get a]
	}
}
#INDEX\
proc lmatch {} {}
#INDEX\
proc lassign {} {}
#INDEX\
proc lcontain {} {}
#INDEX\
proc lempty {} {}
#INDEX\
proc lvarcat {} {}
#INDEX\
proc lvarpop {} {}
#INDEX\
proc lvarpush {} {}
if {[info comm lvarcat]==""} {
	#
	# TclX list routines, in case you don't have TclX
	#
	proc lmatch {list pat} {
		set ret {}
		foreach val $list {
			if [string match $pat $val] {
				lappend ret $val
			}
		}
		return $ret
	}
	proc lassign {list args} {
		set argc [llength $args]
		for {set i 0} {$i < $argc} {incr i} {
			uplevel 1 [list set [lindex $args $i] [lindex $list $i]]
		}
	}
	proc lcontain {list element} {
		return [expr {[lsearch -exact $list $element]!=-1}]
	}
	proc lempty {list} {
		return [expr {[llength $list]==0}]
	}
	proc lvarcat {lvar args} {
		upvar 1 $lvar list
		foreach arg $args {
			lappend list $arg
		}
	}
	proc lvarpop {lvar {idx 0} {str <undefined>}} {
		upvar 1 $lvar list
		set end [llength $list]
		if {$end != 0} {set end [expr {$end - 1}]}
		regsub end $idx $end idx
		set idx [expr $idx]
		set ret [lindex $list $idx]
		if {$str == "<undefined>"} {
			if {$idx > $end} {return ""}
			set list [lreplace $list $idx $idx]
		} else {
			set list [lreplace $list $idx $idx $str]
		}
		return $ret
	}
	proc lvarpush {lvar str {idx 0}} {
		upvar 1 $lvar list
		set end [llength $list]
		if {$end != 0} {set end [expr {$end - 1}]}
		regsub end $idx $end idx
		set idx [expr $idx]
		set ret [lindex $list $idx]
		set list [linsert $list $idx $str]
		return 
	}
}
proc lreverse {list} {
	set ret {}
	for {set idx [expr [llength $list] -1]} {$idx >= 0} {incr idx -1} {
		lappend ret [lindex $list $idx]
	}
	return $ret
}
proc lunique {list} {
	foreach val $list {
		set a($val) 1
	}
	return [array names a]
}


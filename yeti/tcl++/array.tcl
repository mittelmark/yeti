#
# Sensus Consulting Ltd, Copyright 1997-1998
#
# Matt Newman <matt@sensus.org>
#

# Tcl core enhancements
proc ainit {arr} {
	upvar $arr a
	set a(?) ?
	unset a(?)
}
# aset - as array set, but allows prefix & suffix for key to be set.
proc aset {arr list {pfx ""} {sfx ""}} {
	upvar $arr a
	set len [llength $list]
	for {set i 0} {$i < $len} {incr i 2} {
		set key [lindex $list $i]
		set val [lindex $list [expr $i + 1]]
		set a(${pfx}$key${sfx}) $val
	}
}
# aget - as array get, but allows prefix & suffix for key to be specified.
# inverse of aset
proc aget {arr {pfx ""} {sfx ""}} {
	upvar $arr a
	set plen	[string length $pfx]
	set slen	[string length $sfx]
	set ret		{}
	foreach key [lsort [array names a ${pfx}*${sfx}]] {
		set klen [string length $key]
		set name [string range $key $plen [expr $klen - $slen - 1]]
		lappend ret $name $a($key)
	}
	return $ret
}
# adel - allows prefix & suffix for key to be specified. And deletes
# all matching keys
proc adel {arr {pfx ""} {sfx ""}} {
	upvar $arr a
	foreach key [array names a ${pfx}*${sfx}] {
		unset a($key)
	}
}
proc asort {arr {order -increasing}} {
	upvar $arr a
	if {![info exists a]} {return {}}
	return [lsort -command [list _asort a] $order [array names a]]
}
proc _asort {arr k1 k2} {
	upvar $arr a
	return [string compare $a($k1) $a($k2)]
}

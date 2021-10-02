#
# Sensus Consulting Ltd, Copyright (c) 1997-1998
# Matt Newman <matt@sensus.org>
#
# With help from:
#	John Reekie <johnr@eecs.berkeley.edu>
#	Bret A. Schuhmacher <bas@healthcare.com>
#	+ many others
#
# Implements an 100% [incr Tcl] compatible framework in pure Tcl.
#
# The semantics are identical except for:
# 1) all objects that do not inherit from a super class are made to
#	inherit from ::Object 
# 2) during class construction, i.e. inside class X {...} common variables
# inherited from parent classes are not accessible, so you have to use
# fully-qualified names, i.e. ::A::foo. (BUG)
#
# Data structures:
#
# Each class is implemented as a namespace, and contains a private array
# called _info, indexed by $type,$name
#
# variable,$name	- $scope $class $name $init $config
# common,$name		- $scope $class $name $init
# method,$name		- $scope $class $name $arglist $body ?$init?
# proc,$name		- $scope $class $name $arglist $body
#
package require Tcl 8.0

package provide tcl++ 2.3

proc uid {{pfx _tcl++_}} {
    variable _uid
    if ![info exists _uid($pfx)] {
        return $pfx[set _uid($pfx) 0]
    }
    return $pfx[incr _uid($pfx)]
}
#if {[catch {package require Itcl}]==0} {
#	# Can't have Itcl & tcl++, You still get the other goodies in
#	# tcl++, but not the [incr Tcl] clone support.
#	return
#}
#
# Fake up itcl support
#
namespace eval itcl {
	variable library ${tcl++::library}
	namespace import -force ::tcl++::class
}
#package provide Itcl 2.2

# Not needed, but some things are faster if you have TclX.
catch {package require TclX}
# Not needed, but some things are *even* faster if you have sentcl.
catch {package require sentcl}

namespace eval tcl++ {
	variable library [file dirname [info script]]
	variable classes
	variable objects

	set classes(_) 1
	unset classes(_)
	set objects(_) 1
	unset objects(_)

	namespace export class body configbody new info \
			global local code delete scope @scope \
			uid public protected import \
			fqns rns
}
namespace eval tcl++::parser {
	namespace export -clear inherit constructor destructor method proc \
				common variable public protected private
	::proc parseClass {name body} {
		#tclLog "parseClass $name ([namespace current])"
		catch {namespace delete $name}
		namespace eval $name [format {
			#
			# The patten-match on imports doesn't work right under
			# Tcl 8.1
			set guests [namespace eval ::tcl++::parser {namespace export}]
			foreach guest $guests {
				namespace import -force ::tcl++::parser::$guest
				#tclLog [list namespace import -force ::tcl++::parser::$guest]
			}
			::variable _info
			set _info(class) %s
			set _info(body)	%s
			#error
			#tclLog "namespace import DONE"
			#
			# Parser defaults
			#
			set _info(scope) default
			if {$_info(class) != "::Object"} {
				set _info(inherit) ::Object
			} else {
				set _info(inherit) {}
			}
			set _info(method,constructor) [list private $_info(class) constructor "" "" ""]
			set _info(method,destructor) [list private $_info(class) destructor "" ""]

			eval $_info(body)
			#
			# Forget invited guests to namespace party
			#
			eval namespace forget $guests
			unset guests guest
		} [list $name] [list $body]]
	}
	::proc inherit {args} {
		upvar 1 _info _info
		set _info(inherit) {}
		foreach super $args {
			if {![string match ::* $super]} {set super ::$super}
			lappend _info(inherit) $super
		}
	}
	::proc constructor {args} {
		upvar 1 _info _info
		set argc [llength $args]
		if {$argc == 2} {
			set init {}
			set body [lindex $args 1]
		} elseif {$argc == 3} {
			set init [lindex $args 1]
			set body [lindex $args 2]
		} else {
			error "wrong # args: should be \"constructor args ?init? body\""
 		}
		set arglist [lindex $args 0]

 		set _info(method,constructor) [list private $_info(class) constructor $arglist $body $init]
	}
	::proc destructor {{body ""}} {
		upvar 1 _info _info
		set _info(method,destructor) [list private $_info(class) destructor {} $body]
	}
	::proc method {name {arglist <undefined>} {body <undefined>}} {
		upvar 1 _info _info
		set scope $_info(scope)
		if {$scope == "default"} {set scope public}
		set _info(method,$name) [list $scope $_info(class) $name $arglist $body]
	}
	::proc proc {name {arglist <undefined>} {body <undefined>}} {
		upvar 1 _info _info
		set scope $_info(scope)
		if {$scope == "default"} {set scope public}
		set _info(proc,$name) [list $scope $_info(class) $name $arglist $body]
	}
	::proc variable {name {init <undefined>} {config ""}} {
		upvar 1 _info _info
		#tclLog [list variable $name $init $config]
		set scope $_info(scope)
		if {$scope == "default"} {set scope protected}
		if {$config != "" && $scope != "public"} {
			error "wrong # args: should be \"variable name ?init?\""
		}
		if {$name == "this" || \
		    $name == "class"} {
		    error "bad variable \"$name\": reserved name"
		}
		set _info(variable,$name) [list $scope $_info(class) $name $init $config]
	}
	::proc common {name {init <undefined>}} {
		upvar 1 _info _info
		set scope $_info(scope)
		if {$scope == "default"} {set scope protected}
		set _info(common,$name) [list $scope $_info(class) $name $init]
		if {$init == "<undefined>"} {
			namespace eval $_info(class) [list ::variable $name]
		} else {
			namespace eval $_info(class) [list ::variable $name $init]
		}
	}
	#
	# Scoping constructs
	#
	::proc public {command args} {
		upvar 1 _info _info
		set old $_info(scope)
		set _info(scope)	public
		if {[llength $args]==0} {
			namespace eval $_info(class) $command
		} else {
			namespace eval $_info(class) [concat $command $args]
		}
		set _info(scope)	$old
	}
	::proc private {command args} {
		upvar 1 _info _info
		set old $_info(scope)
		set _info(scope)	private
		if {[llength $args]==0} {
			namespace eval $_info(class) $command
		} else {
			namespace eval $_info(class) [concat $command $args]
		}
		set _info(scope)	$old
	}
	::proc protected {command args} {
		upvar 1 _info _info
		set old $_info(scope)
		set _info(scope)	protected
		if {[llength $args]==0} {
			namespace eval $_info(class) $command
		} else {
			namespace eval $_info(class) [concat $command $args]
		}
		set _info(scope)	$old
	}
}
catch {rename auto_import auto_import-}
#
# PUBLIC Procedures (i.e. ones imported into Global namespace)
#
proc tcl++::class {class body} {
	set ns [uplevel 1 namespace current]
	set class [fqns $ns $class]

	if {[_info exists ::tcl++::classes($class)]} {
		error "class \"[rns $ns $class]\" already exists"
	}
	parser::parseClass $class $body
	#
	# Initialization
	#
	upvar ${class}::_info info
	set ::tcl++::classes($class) 1
	set info(heritage)	$class
	set info(derived)	{}
	set info(uid)		-1
	#
	# INHERIT - Prepare namespace, pull in inherited defs
	#
	if {$info(inherit) != ""} {
		set tmp {}
		foreach super $info(inherit) {
			lappend tmp [inherit $class [fqns $ns $super]]
		}
		set info(inherit) $tmp
	}
	#
	# Now build the class from it's parsed definition.
	#
	# CLASS PROCS
	#
	foreach {key data} [array get info proc,*] {
		set name [string range $key 5 end]

		if {[lindex $data 4] == "<undefined>"} {
			continue
		}
		if {[lindex $data 1] == ${class}} {
			# define procedure
			eval compile proc $data
		}
		# export if not private
		if {[lindex $data 0] != "private"} {
			namespace eval $class [list namespace export $name]
		}
	}
	#
	# CLASS METHODS
	#
	foreach {key data} [array get info method,*] {
		set name [string range $key 7 end]

		if {[lindex $data 4] == "<undefined>"} {
			continue
		}
		if {[lindex $data 1] == ${class}} {
			eval compile method $data
		}
		# export if not private
		if {[lindex $data 0] != "private"} {
			namespace eval $class [list namespace export $name _tcl++_$name]
		}
	}
	#
	# CLASS VARIABLES
	#
	foreach {key data} [array get info variable,*] {
		set name [string range $key 9 end]

		if {[lindex $data 0] == "public" && [lindex $data 1] == ${class}} {
			set info(config,$name) [lindex $data 4]
		}
	}
	#
	# CLASS COMMON
	#
	foreach {key data} [array get info common,*] {
		set name [string range $key 7 end]

		# Skip, if inherited
		if {[lindex $data 1] != ${class}} continue

		# Nothing to do - just a place holder
	}
	#
	# OPTION method CACHE (to help us determine quickly whether what
	# we can callout, wether we are in-context, or out-of-context).
	#
	set info(public,$class) {}
	set info(private,$class) {}
	foreach name [lsort [array names info method,*]] {
		set name [string range $name 7 end]

		if {[lindex $info(method,$name) 0] == "public"}	{
			lappend info(public,$class) $name
		}
		lappend info(private,$class) $name
	}
	#
	# CLASS EVAL - a hook to execute within correct context
	#
	compile method private $class _eval {body} {eval $body}
	#
	# CLASS FACTORY
	#
	proc $class {this args} [format {::uplevel 1 ::tcl++::new %s $this $args} $class]
	#
	# At last! We're outahere :-)
	#
	return ""
}
namespace import -force ::tcl++::class

proc tcl++::uid {{pfx _tcl++_}} {
    variable uid
    if ![_info exists uid($pfx)] {
        return $pfx[set uid($pfx) 0]
    }
    return $pfx[incr uid($pfx)]
}
namespace import -force ::tcl++::uid
#
# Instansiate an instance of class $class
#
proc tcl++::new {class this args} {
	set ns [uplevel 1 namespace current]
	if {$this == "::"} {
		error [format {syntax "class :: proc" is an anachronism
[incr Tcl] no longer supports this syntax.
Instead, remove the spaces from your procedure invocations:
  %s::%s ?args?} [rns $ns $class] [lindex $args 0]]
  	}
	set class [fqns $ns $class]
	set this [fqns $ns $this]
	set uid [uid]
	switch -glob -- $this {
	*#auto*	{
		set cls [namespace tail $class]
		set cls [string tolower [string range $cls 0 0]][string range $cls 1 end]
		while {1} {
			regsub {#auto} $this $cls[incr ${class}::_info(uid)] nthis
			if {[_info commands $nthis] == ""} {
				set this $nthis
				break
			}
		}
	}
	};#sw
	if {[_info command $this] != ""} {
		if {[set tmp [namespace qualifiers $this]] == ""} {set tmp ::}
		error [format {command "%s" already exists in namespace "%s"} [namespace tail $this] $tmp]
	}
	upvar #0 ${this}_clientdata_ __v__
	if {[_info exists __v__]} {unset __v__}
	set __v__(__class) $class
	set __v__(__heritage) {}
	set __v__(__objectID) [uid]
	set __v__(__refcount) 0
	set __v__(__rip) 0
	#
	set ::tcl++::objects($class,$this) $__v__(__objectID)

	compile accessor $class $this

	if [catch {eval ${class}::constructor $args} err] {
		global errorInfo
		set el [split $errorInfo \n]
		set idx [expr [llength $el] - 3]
		set el [lrange $el 0 $idx]
		catch {delete object $this}
		return -code error -errorinfo [join $el \n] $err
	}
	# HACK - make sure all widgets are imported in global namespace
	set xthis [namespace tail $this]
	set xns [namespace qualifiers $this]
	if {$xns != "" && [string match .* $xthis]} {
		namespace eval $xns [list namespace export $xthis]
		namespace eval :: [list namespace import -force $this]
	}
	return [rns $ns $this]
}
namespace import -force ::tcl++::new
#
# COMPAT - w/ [incr Tcl] delete
#
proc tcl++::delete {option args} {
	upvar 1 this pthis
	set ns [uplevel 1 namespace current]
	switch -- $option {
	object	{
		foreach this $args {
			set this [fqns $ns $this]
			upvar #0 ${this}_clientdata_ __v__

			if {![_info exists __v__]} {
				# Were fucked, someone probably deleted the namespace
				catch {::rename $this ""}
				return
			}
			if {$__v__(__rip) == 2} {
				error "can't delete an object while it is being destructed"
			}
			if {[_info exists pthis] && [fqns $ns $pthis] == $this} {
				# Deleting myself!
				set pthis {}
			}
			if {$__v__(__refcount) == 0} {
				set __v__(__rip) 2
				if {[catch {
					foreach class [set $__v__(__class)::_info(heritage)] {
						${class}::destructor
					}
				} err]} {
					set __v__(__rip) 0
					error $err
				}
				foreach class [set $__v__(__class)::_info(heritage)] {
					upvar #0 ${class}::$__v__(__objectID) __p__
					if {[_info exists __p__]} {unset __p__}
				}
				unset tcl++::objects($__v__(__class),$this)
				unset __v__
				catch {::rename $this ""}
			} elseif {$__v__(__rip) == 0} {
				set __v__(__rip) 1
			}
		}
	}
	namespace -
	class	{
		foreach class $args {
			set class [fqns $ns $class]
			if {![_info exists ::tcl++::classes($class)]} {
				error "no such class \"$class\""
			}
			#
			# First destroy all derived classes
			#
			foreach derived [set ${class}::_info(derived)] {
				delete class $derived
			}
			#
			# Now delete all instances of this class
			#
			foreach key [array names ::tcl++::objects $class,*] {
				set inst [string range $key [string length $class,] end]
				delete object $inst
			}
			#
			# Clear up class dependancies
			#
			foreach super [set ${class}::_info(inherit)] {
				set derived [set ${super}::_info(derived)]
				set idx [lsearch $derived $class]
				set ${super}::_info(derived) [lreplace $derived $idx $idx]
			}
			#
			# Delete class factory
			#
			catch {
				rename $class ""
			}
			#
			# And finally remove namespace
			#
			namespace delete $class
			unset ::tcl++::classes($class)
		}
	}
	default	{
		error "bad option \"$option\": must be one of class, or object"
	}
	};#switch
	return ""
}
namespace import -force ::tcl++::delete
#
proc tcl++::body {name args} {
	set ns [uplevel 1 namespace current]
	set name [fqns $ns $name]

	set class [namespace qualifiers $name]
	upvar ${class}::_info info
	set name [namespace tail $name]
	set argc [llength $args]

	if {[string compare $name constructor]==0} {
		if {$argc == 2} {
			set init [lindex $info(method,constructor) 5]
			set body [lindex $args 1]
		} elseif {$argc == 3} {
			set init [lindex $args 1]
			set body [lindex $args 2]
		} else {
			error "wrong # of args: should be \"body ${class}::constructor args ?init? body"
		}
		set arglist [lindex $args 0]
		set scope [lindex $info(method,constructor) 0]
		set ${class}::_info(method,constructor) [list $scope $class constructor $arglist $body $init]

		compile method $scope ${class} $name $arglist $body $init
	} elseif {[string compare $name destructor]==0} {
		if {$argc != 2} {
			error "wrong # args: should be \"body ${class}::destructor body"
		}
		set body [lindex $args 1]
		set scope [lindex $info(method,destructor) 0]
		set ${class}::_info(method,destructor) [list $scope $class destructor {} $body]

		compile method $scope ${class} $name {} $body
	} else {
		if {$argc != 2} {
			error "wrong # args: should be \"body class::func arglist body\""
		}
		set arglist	[lindex $args 0]
		set body	[lindex $args 1]
		if {[_info exists info(method,$name)] && \
			[lindex $info(method,$name) 1] == $class} {
			set type method
		} elseif {[_info exists info(proc,$name)] && \
			[lindex $info(proc,$name) 1] == $class} {
			set type proc
		} else {
			error "function \"$name\" is not defined in class \"$class\""
		}
		set scope [lindex $info($type,$name) 0]
		set Oarglist [lindex $info($type,$name) 3]
		set Obody [lindex $info($type,$name) 4]
		if {$Oarglist == "<undefined>"} {
			set ${class}::_info($type,$name) [list $scope $class $name <undefined> $body]
		} elseif {$arglist != $arglist} {
			# should be $arglist != $Oarglist, was the simplest way I could comment out the code.
			error "argument list changed for function \"[rns $ns ${class}::$name]\": should be \"$Oarglist\""
		} else {
			set ${class}::_info($type,$name) [list $scope $class $name $arglist $body]
		}
		compile $type $scope ${class} $name $arglist $body
		if {[lindex $info($type,$name) 0] != "private"} {
			if {$Obody == "<undefined>"} {
				namespace eval $class [list namespace export $name]
				if {$type == "method"} {
					namespace eval $class [list namespace export _tcl++_$name]
				}
			}
			foreach dclass $info(derived) {
				set dinfo [set ${dclass}::_info($type,$name)]
				# Skip, if not imported into derived class
				if {[lindex $dinfo 1] != $class} continue

				namespace eval $dclass [list namespace import -force ${class}::$name]
				if {$type == "method"} {
					namespace eval $dclass [list namespace import -force ${class}::_tcl++_$name]
				}
			}
		}
	}
	return ""
}
namespace import -force ::tcl++::body

proc tcl++::configbody {args} {
	if {[llength $args] != 2} {
		error {wrong # args: should be "configbody class::option body"}
	}
	set ns [uplevel 1 namespace current]
	set name [fqns $ns [lindex $args 0]]
	set body [lindex $args 1]

	set class [namespace qualifiers $name]
	set name [namespace tail $name]

	upvar ${class}::_info info
	if {[_info exists info(config,$name)]} {
		set info(config,$name) $body
	} elseif {[_info exists info(variable,$name)] && \
		[lindex $info(variable,$name) 1] == ${class} } {
		error "option \"[rns $ns ${class}::$name]\" is not a public configuration option"
	} else {
		error "option \"$name\" is not defined in class \"$class\""
	}
	return ""
}
namespace import -force ::tcl++::configbody
#
# This section renames some built-in commands
# You have to be VERY careful here - the semantics
# are different between Tcl 8.0 & Tcl 8.1(a2)
# If you redefine a proc that is imported to somewhere, running the
# command in the NS that previously has the command imported
# generates an error in Tcl 8.0, but invokes the unknown proc
# in Tcl 8.1(a2).
#
# Change at your own risk!
#
if {[info commands ::_global] == ""} {
	#tclLog "global: overriding"
	rename ::global ::_global
}
proc tcl++::global {args} {
	#tclLog [concat GLOBAL $args]
	set class [uplevel 1 namespace current]
	foreach var $args {
		if {[_info exists ${class}::_info(common,$var)]} {
			continue
		} elseif {[_info exists ${class}::$var]} {
			uplevel 1 [list ::variable $var]
		} else {
			uplevel 1 [list ::_global $var]
		}
	}
}
namespace import -force ::tcl++::global
#
# Provide a backwards(ish) compatibile equiv of [incrTcl] info command
#
if {[info commands ::_info] == ""} {
	#tclLog "info: overriding"
	rename ::info ::_info
}
proc tcl++::info {option args} {
	#tclLog [concat INFO $option $args]
	set argc [llength $args]
	switch -- $option {
	context		{return [uplevel 1 namespace current]}
	which		{return [uplevel 1 namespace which $args]}
	xvars		{
			if {$argc == 0} {
				set glob *
			} elseif {$argc == 1} {
				set glob [lindex $args 1]
			} else {
				error "wrong # args: should be \"info vars ?pattern?"
			}
			set ret {}
			foreach var [uplevel 1 _info local $glob] {
				switch -- $var {
				this	{}
				default	{lappend ret $var}
				}
			}
			return $ret
	}
	namespace	{
		set ns [uplevel 1 namespace current]
		switch -- [lindex $args 0] {
		all {
			if {$argc == 1} {
				set glob *
			} elseif {$argc == 2} {
				set glob [lindex $args 1]
			} else {
				error "wrong # args: should be \"info namespace all ?pattern?"
			}
			set ret {}
			foreach cns [namespace children $ns] {
				set cns [namespace tail $cns]
				if {[string match $glob $cns]} {
					lappend ret $cns
				}
			}
			return $ret
		}
		children {
			if {$argc == 2} {
				set ns [lindex $args 1]
			} elseif {$argc != 1} {
				error "wrong # args: should be \"info namespace children ?name?"
			}
			return [namespace children $ns]
		}
		parent {
			if {$argc == 2} {
				set ns [lindex $args 1]
			} elseif {$argc != 1} {
				error "wrong # args: should be \"info namespace parent ?name?"
			}
			return [namespace parent $ns]
		}
		qualifiers {
			if {$argc != 2} {
				error "wrong # args: should be \"info namespace qualifiers string"
			}
			set name [lindex $args 1]
			return [namespace qualifiers $name]
		}
		tail {
			if {$argc != 2} {
				error "wrong # args: should be \"info namespace tail string"
			}
			set name [lindex $args 1]
			return [namespace tail $name]
		}
		default	{
			error "bad option \"[lindex $args 0]\": must be one of all, children, parent, qualifiers, or tail"
		}
		};#switch (namespace)
	}
	classes		{
		if {$argc == 0} {
			set glob *
		} elseif {$argc == 1} {
			set glob [lindex $args 0]
		} else {
			error "wrong # args: should be \"info classes ?pattern?"
		}
		set ns [uplevel 1 namespace current]
		if {![string match ::* $glob]} {set glob ::$glob}
		set ret {}
		foreach cls [lsort [array names ::tcl++::classes $glob]] {
			set cls [rns $ns $cls]
			# Skip nested child classes
			if {![regexp {^[^:].*::.*} $cls]} {
				lappend ret $cls
			}
		}
		return $ret
	}
	objects		{
		set ns [uplevel 1 namespace current]
		set glob ""
		set isa ""
		set class ""
		while {[llength $args]>0} {
			set arg [lindex $args 0]
			if {[string compare $arg -class]==0 && $class == ""} {
				set class [lindex $args 1]
				set args [lrange $args 2 end]
			} elseif {[string compare $arg -isa]==0 && $isa == ""} {
				set isa [lindex $args 1]
				set args [lrange $args 2 end]
			} elseif {[string match -* $arg] || $glob != ""} {
				error "wrong # args: should be \"info objects ?-class className? ?-isa className? ?pattern?"
			} else {
				set glob $arg
				set args [lrange $args 1 end]
			}
		}
		if {$glob == ""} {set glob *}
		if {$isa == ""} {set isa *}
		if {$class == ""} {set class *}
		set glob [fqns :: $glob]
		set class [fqns :: $class]
		set isa [fqns :: $isa]
		set ret {}
		foreach obj [array names ::tcl++::objects $class,$glob] {
			set tmp [split $obj ,]
			set cls [lindex $tmp 0]
			set obj [lindex $tmp 1]
			if {[string match $class $cls]==0}	continue
			if {$isa != "::*"  && \
				[lsearch [set ${cls}::_info(heritage)] $isa]==-1}	continue
			lappend ret [rns $ns $obj]
		}
		return $ret
	}
	protection	{
		error "info protection is unsupported in Tcl 8.x"
	}
	globals	{
		set ns [uplevel 1 namespace current]
		if {$ns == "::"} {
			return [eval _info globals $args]
		}
		set all [namespace eval $ns [concat _info vars $args]]
		set ret {}
		foreach var $all {
			set real [uplevel 1 namespace which -variable $var]
			if {[namespace qualifiers $real] == $ns && ![string match _* $var]} {
				lappend ret [rns $ns $var]
			}
		}
		return $ret
	}
	default		{return [uplevel 1 _info $option $args]}
	}
}
namespace import -force ::tcl++::info

proc tcl++::code {args} {
	set ns [uplevel 1 namespace current]
	if {[lindex $args 0] == "-namespace"} {
		set ns [fqns $ns [lindex $args 1]]
		set args [lrange $args 2 end]
	}
	return [list @scope $ns $args]
}
namespace import -force ::tcl++::code

proc tcl++::scope {name} {
	if {$name == ""} {
		return ""
	}
	set ns [uplevel 1 namespace current]
	return [fqns $ns $name]
}
namespace import -force ::tcl++::scope

proc tcl++::@scope {ns cmd args} {
	set cmd [list namespace eval $ns [concat $cmd $args]]
	set retCode [catch $cmd ret]
	switch -- $retCode {
	0	{#TCL_OK
		return $ret
		}
	2	{#TCL_RETURN
		return -code return $ret
		}
	3	{#TCL_BREAK
		::return -code break
		}
	4	{#TCL_CONTINUE
		::return -code continue
		}
	1	-
	default	{#TCL_ERROR
		::global errorInfo errorCode
		::return -code $retCode \
			-errorinfo $errorInfo \
			-errorcode $errorCode $ret
		}
	}
}
namespace import -force ::tcl++::@scope

proc tcl++::local {class args} {
	set obj [uplevel 1 $class $args]
	set ns [uplevel 1 namespace current]
	uplevel 1 [list set itcl-local-$obj 1]
	uplevel 1 [list trace variable itcl-local-$obj u [list ::tcl++::local_trace [fqns ${ns} $obj]]]
}
namespace import -force ::tcl++::local

proc tcl++::local_trace {obj v1 v2 op} {
	catch {delete object $obj}
}
proc tcl++::import {args} {
	error "import is not supported in Tcl 8.x"
}
namespace import -force ::tcl++::import

#
# protection of variables is not supported with namespaces in Tcl 8.x
#
proc tcl++::public {args} {
	return [uplevel 1 $args]
}
namespace import -force ::tcl++::public

proc tcl++::protected {args} {
	return [uplevel 1 $args]
}
namespace import -force ::tcl++::protected
#
# Format name as FQNS (Fully qualified namespace), e.g.
#
# fqns :: a -> ::a
# fqns ::a ::b -> ::b
proc tcl++::fqns {ns name} {
	if {$ns == "::"} {set ns ""}
	if {[string match ::* $name]} {
		return $name
	} else {
		return ${ns}::$name
	}
}
namespace import -force ::tcl++::fqns
#
# Format fqns names relative to a given namespace, E.g.
#
# rns :: ::a -> a
# rns ::a ::b -> ::b
proc tcl++::rns {ns name} {
	if {$ns == "::"} {set ns ""}
	if {[string match ${ns}::* $name]} {
		return [string range $name [string length ${ns}::] end]
	} else {
		return $name
	}
}
namespace import -force ::tcl++::rns
#
# Private procedures
#
#
# Join two namespaces together
#
proc tcl++::jns {ns1 ns2} {
	if {$ns1 == "::"} {set ns1 ""}
	if {$ns2 == "::"} {
		set ns2 ""
	} elseif {![string match ::* ${ns2}]} {
		set ns2 ::$ns2
	}
	return "$ns1$ns2"
}
proc tcl++::inherit {class super} {
	upvar ${class}::_info info
	#
	# Force a load & parse of super class.
	# WARNING: this makes us re-entrant!
	#
	if {[_info commands ${super}::constructor]==""} {
		if {![auto_load $super]} {
			error "cannot inherit from \"$super\" (unknown class)"
		}
	}
	upvar ${super}::_info super_info
	#
	# Update derived classes
	#
	if {[lsearch $super_info(derived) $class]==-1} {
		lappend super_info(derived) $class
	}
	if {$super_info(heritage) != "::Object"} {
		set info(heritage)	[concat $info(heritage) $super_info(heritage)]
	}
	#
	# INHERIT CACHE for method callout.
	#
	array set info [array get super_info private,*]
	#
	# INHERIT PROCS
	#
	foreach {key data} [array get super_info proc,*] {
		set name [string range $key 5 end]
		# Skip, if defined in this class
		if {[_info exists info($key)]}	continue

		# Skip, if private
		if {[lindex $data 0] == "private"}	continue
		# Import
		if {[lindex $data 4] != "<undefined>"} {
			namespace eval $class [list namespace import -force ${super}::$name]
		}
		# Link info
		#namespace eval $class [list upvar $info(super)::_info(proc,$name) info(proc,$name)]
		set info($key) $data
		trace variable ${super}::_info($key) w [list ::tcl++::ripple $class]

		#tclLog "$class: importing proc ${super}::$name"
	}
	#
	# INHERIT METHODS
	#
	foreach {key data} [array get super_info method,*] {
		set name [string range $key 7 end]
		# Skip, if defined in this class
		if {[_info exists info($key)]}	continue

		# Skip, if private
		if {[lindex $data 0] == "private"}	continue

		# Import
		if {[lindex $data 4] != "<undefined>"} {
			namespace eval $class [list namespace import -force ${super}::$name]
			namespace eval $class [list namespace import -force ${super}::_tcl++_$name]
		}
		# Link info
		#namespace eval $class [list upvar $info(super)::_info(method,$name) info(method,$name)]
		set info($key) $data
		trace variable ${super}::_info($key) w [list ::tcl++::ripple $class]

		#tclLog "$class: importing method ${super}::$name"
	}
	#
	# INHERIT VARIABLES
	#
	foreach {key data}  [array get super_info variable,*] {
		set name [string range $key 9 end]
		# Skip, if defined in this class
		if {[_info exists info($key)]}	continue

		# Skip, if private
		if {[lindex $data 0] == "private"}	continue

		# Link info - (Well this is what I wanted to do, but
		# Tcl doesn't support intra-ns upvars on array elements - :-(
		#namespace eval $class [list upvar $info(super)::_info(variable,$name) info(variable,$name)]
		set info($key) $data
		trace variable ${super}::_info($key) w [list ::tcl++::ripple $class]

		#tclLog "$class: importing variable $info(super)::$name"
	}
	#
	# INHERIT COMMON
	#
	foreach {key data} [array get super_info common,*] {
		set name [string range $key 7 end]
		# Skip, if defined in this class
		if {[_info exists info($key)]}	continue

		# Skip, if private
		if {[lindex $data 0] == "private"}	continue

		# Link info
		#namespace eval $class [list upvar $info(super)::_info(common,$name) info(common,$name)]
		set info($key) $data
		trace variable ${super}::_info($key) w [list ::tcl++::ripple $class]
		# Link variable
		namespace eval $class [list upvar ${super}::$name $name]

		#tclLog "$class: importing common ${super}::$name"
	}
	return $super
}
#
# "Compile" a method, we actually generate two copies
# One which will be called from external to the object
# and one which is called within the class.
#
# The reason for this is PURELY speed.
#
# internal nop method consumes ~236us of overhead
# external nop method consumes ~200us of overhead
#
# With virtual method hooks the execution times go up to:
# qualified access: 380us
# unqualified access to method which is declared in outamost
#			class:	415us
# virtual dispatch:	895us
#
proc tcl++::compile {type args} {
	if {$type == "method"} {
		eval compileMethod $args
	} elseif {$type == "proc"} {
		eval compileProc $args
	} elseif {$type == "accessor"} {
		eval compileAccessor $args
	} else {
		error "unknown type \"$type\": must be one of accessor, method, or proc"
	}
}
proc tcl++::compileMethod {scope class method args body {init ""}} {
	#
	# Build virtual callout.
	#
	set virtual {[list}
	set sawArgs 0
	foreach arg $args {
		set arg [lindex $arg 0]
		set _args($arg) 1
		if {$arg == "args"} {
			append virtual {] $args}
			set sawArgs 1
		} else {
			append virtual [format { ${%s}} $arg]
		}
	}
	if {$sawArgs == 0} {
		append virtual {]}
	}
	#
	# Method headers
	#
	set headerInt [format {
		# CLASS %s
		# METHOD %s
		::upvar 1 this this
		# Public & Protected vars
		::upvar #0 ${this}_clientdata_ __v__
	} $class $method ]
	if {$scope != "private"} {
		append headerInt [format {
		#SPEEDUP - if you want methods to be virtual by default
		# uncomment out the if statement, but be warned it is slower.
		if {![::string match *::* [::lindex [::_info level 0] 0]]} {
			# dispatch virtual method
			return [::uplevel 1 [info class]::_tcl++_%s $this %s]
		}
		#END SPEEDUP
		} $method $virtual]
	}
	set headerExt [format {
		# CLASS %s
		# METHOD %s
		# Public & Protected vars
		::upvar #0 ${this}_clientdata_ __v__
	} $class $method]
	#
	# Prolog for all methods.
	#
	set prolog [format {
		# Private vars
		::upvar %s::$__v__(__objectID) __p__
	} $class]

	if {$method == "constructor"} {
		append prolog [format {
		# Record list of constructors called so far.
		::lappend __v__(__heritage) %s
		# INIT code
		%s
		# Force super class constructors to be called.
		::tcl++::init
		} $class $init]
	}
	#
	# Map in any arrays
	#
	set code {}
	foreach {name data} [array get ${class}::_info variable,*] {
		set name [string range $name 9 end]

		if {[_info exists _args($name)]} {
			# Avoid clashes
			continue
		}
		if {[lindex $data 3] == "<undefined>" && [lindex $data 0] != "public"} {
			# Assume it is an array.
			# If you realy meant you wanted an uninitialized
			# variable, declare its init to "<undefined>"
			set rcls [lindex $data 1]
			append code "${rcls}::\$__v__(__objectID)_$name $name "
		} else {
			#
			# SPEEDUP: This if statement provides *full* variable access compatibility
			# w/ [incr Tcl]. But... at a cost in terms of speed for all method
			# invocations (internal & external).
			#
			if {[lindex $data 0] == "private"} {
				append code "__p__($name) $name "
			} else {
				append code "__v__($name) $name "
			}
		}
	}
	# SPEEDUP
	# This brings common vars into scope within a method.
	# If you comment this out you can acheive the same by
	# inserting "variable <name>" in your code, which would be
	# cheaper since you need only do it in the methods that
	# actually use the variable.
	foreach {name data} [array get ${class}::_info common,*] {
		set name [string range $name 7 end]

		if {[_info exists _args($name)]} {
			# Avoid clashes
			continue
		}
		append code "${class}::$name $name "
	}
	if {[llength $code]>0} {
		append prolog "\n\t\t::upvar 0 $code\n"
	}
	#
	# Build internal method
	#
	proc ${class}::$method $args "$headerInt$prolog\n$body"
	#
	# Build external method
	#
	if {$method != "constructor" && $method != "destructor"} {
		proc ${class}::_tcl++_$method [linsert $args 0 this] "$headerExt$prolog\n$body"
	}
	return ${class}::$method
}
proc tcl++::compileProc {scope class proc args body} {
	set prolog {}
	set code {}
	foreach arg $args {
		set _args([lindex $arg 0]) 1
	}
	# SPEEDUP
	# This brings common vars into scope within a method.
	# If you comment this out you can acheive the same by
	# inserting "variable <name>" in your code, which would be
	# cheaper since you need only do it in the methods that
	# actually use the variable.
	foreach {name data} [array get ${class}::_info common,*] {
		set name [string range $name 7 end]

		if {[_info exists _args($name)]} {
			# Avoid clashes
			continue
		}
		append code "${class}::$name $name "
	}
	if {[llength $code]>0} {
		append prolog "::upvar 0 $code\n"
	}
	#
	# Build proc
	#
	proc ${class}::$proc $args "$prolog\n$body"

	return ${class}::$proc
}
proc tcl++::compileAccessor {class this} {
	proc $this {option args} [format {
		::set this %s
		::set class %s
		::upvar #0 ${this}_clientdata_ __v__
		if {$option == "info"} {
			return [eval ${class}::info $args]
		}
		#SPEEDUP: UNCOMMENT next line, and comment subsequent line
		# to enable option checking, timings are:
		# 1075us vs 1935us "you pays your money an' makes your choices"
		::set option [::tcl++::checkOption $class $this $option [uplevel 1 namespace current]]
		#::set option ${class}::_tcl++_${option}
		#END SPEEDUP
		::set body [::concat $option $this $args]
		::upvar 1 _error_ ret
		::incr __v__(__refcount)
		::set retCode [::uplevel 1 [::list catch $body _error_]]
		if {[incr __v__(__refcount) -1] == 0 && $__v__(__rip) == 1} {
			::delete object $this
		}
		::switch -- $retCode {
		0	{#TCL_OK
			::return $ret
			}
		2	{#TCL_RETURN
			::return -code return $ret
			}
		3	{#TCL_BREAK
			::return -code break
			}
		4	{#TCL_CONTINUE
			::return -code continue
			}
		1	-
		default	{#TCL_ERROR
			::global errorInfo errorCode
			::return -code $retCode \
				-errorinfo $errorInfo \
				-errorcode $errorCode $ret
			}
		}
	} $this $class]
}
proc tcl++::checkOption {class this option {context ::}} {
	upvar #0 ${class}::_info info
	set q [namespace qualifiers $option]
	if {$q != ""} {
		if {![string match ::* $q]} {set q ::$q}
		set class $q
		set option [namespace tail $option]
		upvar #0 ${class}::_info info
	}
	# faster if exact! :-)
	if {[_info exists info(method,$option)]} {
		# Check context
		if {[lindex $info(method,$option) 0]=="public"} {
			return ${class}::_tcl++_$option
		}
		if {[_info exists info(private,$context)]} {
			return ${context}::_tcl++_$option
		}
	}
	if {[_info exists info(private,$context)]} {
		set options $info(private,$context)
		set class $context
	} else {
		set options $info(public,$class)
	}
	set match [lmatch $options ${option}*]
	if {[llength $match]!=1} {
		set options [lreplace $options end end "or [lindex $options end]"]
		if {[llength $match]==0} {
			error "bad option \"$option\": must be one of [join $options ", "]"
		} else {
			error "ambiguous option \"$option\": must be one of [join $options ", "]"
		}
	}
	set option [lindex $match 0]
	return ${class}::_tcl++_$option
}
#
# Invoke any constructors that have not already been invoked.
#
proc tcl++::init {} {
	set class [uplevel 1 namespace current]
	upvar 1 this this
	upvar #0 ${class}::_info info
	upvar #0 ${this}_clientdata_ __v__
	upvar #0 ${class}::$__v__(__objectID) __p__

	ainit __p__

	foreach super [lreverse $info(inherit)] {
		if {[lsearch -exact $__v__(__heritage) $super]==-1} {
			${super}::constructor
		}
	}
	#
	# Initialize instance variables
	#
	foreach {name data} [array get info variable,*] {
		set name [string range $name 9 end]
		# Skip, if not declared in this class
		if {[lindex $data 1] != ${class}} continue

		set scope [lindex $data 0]
		set init [lindex $data 3]
		if {$scope == "private"} {
			set arr __p__
		} else {
			set arr __v__
		}
		if {$init == "<undefined>"} {
			if {$scope != "public"} {
				# Might be an array so lets use a "real"
				# variable
				set ${arr}($name) ${class}::$__v__(__objectID)_$name
			}
		} else {
			set ${arr}($name) $init
		}
	}
}
#
# I *really* wanted to use upvar to link elements of
# the info array in a nice chain thur the namespaces
# but it only works on entire arrays, not individual
# indices. :-(
#
proc tcl++::ripple {targetNS arr idx op} {
	catch {set ${targetNS}::_info($idx) [set ${arr}($idx)]}
}
#
# Base class for tcl++ classes
#
catch {delete class Object}
class Object {
	public {
		method cget {option} 
		method configure {args}
		method isa {class}

		proc info {option args} 
		proc chain {args} 
	}
	protected {
		method self {}
		method super {args}
		method virtual {args} 
	}
}
body Object::cget {option} {
	upvar 0 $__v__(__class)::_info info

	if {![string match -* $option]} {
		error "improper usage: should be \"object cget -option\""
	}
	set option [string range $option 1 end]
	if {![_info exists info(variable,$option)] || \
		[lindex $info(variable,$option) 0] != "public"} {
		error "unknown option \"$option\""
	}
	if [_info exists __v__($option)] {
		return $__v__($option)
	} else {
		return <undefined>
	}
}
body Object::configure {args} {
	upvar 0 $__v__(__class)::_info info

	switch -- [llength $args] {
	0	{
		set ret {}
		foreach {option data} [array get info variable,*] {
			set option [string range $option 9 end]

			if {[lindex $data 0] != "public"} continue

			set rec [list -$option [lindex $data 3]]
			if [_info exists __v__($option)] {
				lappend rec $__v__($option)
			} else {
				lappend rec <undefined>
			}
			lappend ret $rec
		}
		return $ret
	}
	1	{
		set option [lindex $args 0]

		if {![string match -* $option]} {
			error "improper usage: should be \"object configure ?-option? ?-value -option -value...?\""
		}
		set option [string range $option 1 end]
		if {![_info exists info(variable,$option)] || \
			[lindex $info(variable,$option) 0] != "public"} {
			error "unknown option \"$option\""
		}
		set rec [list -$option [lindex $info(variable,$option) 3]]
		if [_info exists __v__($option)] {
			lappend rec $__v__($option)
		} else {
			lappend rec <undefined>
		}
		return $rec
	}
	default {
		foreach {option val} $args {
			if {![string match -* $option]} {
				error "unknown option \"$option\""
			}
			set option [string range $option 1 end]
			if {![_info exists info(variable,$option)] || \
				[lindex $info(variable,$option) 0] != "public"} {
				error "unknown option \"-$option\""
			}
			if {[_info exists __v__($option)]} {
				set old $__v__($option)
			} else {
				set old <undefined>
			}
			set __v__($option) $val

			set class [lindex $info(variable,$option) 1]
			set config [set ${class}::_info(config,$option)]
			#
			# Force code to be executed in correct namespace
			#
			if {$config != ""} {
				if [catch {uplevel 1 [list namespace eval ${class} [list _tcl++__eval $this $config]]} err] {
					if {$old != "<undefined>"} {
						set __v__($option) $old
					}
					return -code error -errorinfo $err $err
				}
			}
		}
	}
	};# switch
}
body Object::isa {class} {
	set ns [uplevel 1 namespace current]
	set class [fqns $ns $class]
	if {[lsearch $__v__(__heritage) $class]==-1} {
		return 0
	} else {
		return 1
	}
}
	
body Object::self {} {
	return [uplevel 1 namespace current]
}
body Object::super {args} {
	set ns [uplevel 1 namespace current]
	set super [set ${ns}::_info(inherit)]
	if {[llength $args]==0} {
		return $super
	} else {
		set func [lindex $args 0]
		return [uplevel 1 ${super}::$func [lrange $args 1 end]]
	}
}
body Object::virtual {args} {
	if {[llength $args]==0} {
		return $__v__(__class)
	} else {
		set func [lindex $args 0]
		return [uplevel 1 $__v__(__class)::$func [lrange $args 1 end]]
	}
}
body Object::info {option args} {
	#
	# Need to determine several calling convertions
	# 1. called from accessor - i.e. $obj info heritage
	# 2. called within class/namespace
	# 3. called within object context
	set proc [lindex [_info level 0] 0]
	set class [namespace qualifiers $proc]
	if {$class == ""} {
		# Called normally
		set lvl 1
		set ns [uplevel 1 namespace current]
		set class $ns
	} else {
		# Called from Accessor
		set lvl 2
		set ns [uplevel 2 namespace current]
	}
	#tclLog "info: class=$class, ns=$ns"
	upvar 1 this this
	upvar 0 ${class}::_info info

	set argc [llength $args]
	switch -- $option {
	args	-
	body	{
		if {$argc != 1} {
			error "wrong # args: should be \"info $option procname\""
		}
		if {$option == "args"} {
			set idx 3
		} else {
			set idx 4
		}
		set name [lindex $args 0]
		if {[_info exists info(method,$name)]} {
			return [lindex $info(method,$name) $idx]
		} elseif {[_info exists info(proc,$name)]} {
			return [lindex $info(proc,$name) $idx]
		} else {
			error "$name isn't a procedure"
		}
	}
	class	{
		if {$argc != 0} {
			error "wrong # args: should be \"info class\""
		}
		if {[_info exists this]} {
			set class [set ${this}_clientdata_(__class)]
		}
		return [rns $ns $class]
	}
	inherit	{
		if {$argc != 0} {
			error "wrong # args: should be \"info inherit\""
		}
		set ret {}
		foreach class $info(inherit) {
			lappend ret [rns $ns $class]
		}
		return $ret
	}
	heritage {
		if {$argc != 0} {
			error "wrong # args: should be \"info heritage\""
		}
		set ret {}
		foreach class $info(heritage) {
			lappend ret [rns $ns $class]
		}
		return $ret
	}
	function {
		#
		# You know, option processing must rate pretty high on the
		# all-time most painful things to code.
		#
		if {$argc == 0} {
			set ret {}
			foreach {name data} [array get info method,*] {
				set name [string range $name 7 end]
				set cls [lindex $data 1]
				lappend ret [rns $ns ${cls}::$name]
			}
			foreach {name data} [array get info proc,*] {
				set name [string range $name 5 end]
				set cls [lindex $data 1]
				lappend ret [rns $ns ${cls}::$name]
			}
			return [lsort $ret]
		}
		set cls [namespace qualifiers [lindex $args 0]]
		set name [namespace tail [lindex $args 0]]
		if {$cls != ""} {set class $cls}
		if {[_info exists ${class}::_info(method,$name)]} {
			lassign [set ${class}::_info(method,$name)] scope xclass xname xargs xbody
			set ret [list $scope method [rns $ns ${xclass}::$name] $xargs $xbody]
		} elseif {[_info exists ${class}::_info(proc,$name)]} {
			lassign [set ${class}::_info(proc,$name)] scope xclass xname xargs xbody
			set ret [list $scope proc [rns $ns ${xclass}::$name] $xargs $xbody]
		} else {
			return ""
		}
		if {[llength $args] == 1} {
			return $ret
		}
		set rret {}
		foreach arg [lrange $args 1 end] {
			switch -- $arg {
			-args	{lappend rret [lindex $ret 3]}
			-name	{lappend rret [lindex $ret 2]}
			-protection	{lappend rret [lindex $ret 0]}
			-type	{lappend rret [lindex $ret 1]}
			-body	{lappend rret [lindex $ret 4]}
			default	{
				error "bad option \"$arg\": should be -args, -body, -name, -protection, or -type"
			}
			};#sw
		}
		if {[llength $rret] == 1} {
			return [lindex $rret 0]
		} else {
			return $rret
		}
	}
	variable {
		#
		# You know, option processing must rate pretty high on the
		# all-time most painful things to code.
		#
		if {$argc == 0} {
			set ret [rns $ns ${class}::this]
			foreach {name data} [array get info variable,*] {
				set name [string range $name 9 end]
				set cls [lindex $data 1]
				lappend ret [rns $ns ${cls}::$name]
			}
			foreach {name data} [array get info common,*] {
				set name [string range $name 7 end]
				set cls [lindex $data 1]
				lappend ret [rns $ns ${cls}::$name]
			}
			return [lsort $ret]
		}
		set cls [namespace qualifiers [lindex $args 0]]
		set name [namespace tail [lindex $args 0]]
		if {$cls != ""} {set class $cls}
		if {$name == "this"} {
			if {![_info exists this]} {
				error {cannot access object-specific info without an object context}
			}
			set ret [list protected variable [rns $ns ${class}::$name] $this $this]
		} elseif {[_info exists ${class}::_info(variable,$name)]} {
			if {![_info exists this]} {
				error {cannot access object-specific info without an object context}
			}
			# Make variables accessible
			upvar #0 ${this}_clientdata_ __v__
			upvar #0 ${class}::$__v__(__objectID) __p__

			# scope type ns::name def ?config? cur
			lassign [set ${class}::_info(variable,$name)] scope xclass xname xinit
			set ret [list $scope variable [rns $ns ${xclass}::$name] $xinit]
			if {$scope == "public"} {
				lappend ret [set ${xclass}::_info(config,$name)]
				set var __v__($xname)
			} elseif {$xinit == "<undefined>"} {
				set var ${xclass}::$__v__(__objectID)_$name
			} elseif {$scope == "protected"} {
				set var __v__($xname)
			} else {
				set var __p__($xname)
			}
			if {[_info exists $var] && ![array exists $var]} {
				lappend ret [set $var]
			} else {
				lappend ret <undefined>
			}
		} elseif {[_info exists ${class}::_info(common,$name)]} {
			# scope type ns::name def cur
			lassign [set ${class}::_info(common,$name)] scope xclass xname xinit
			set ret [list $scope common [rns $ns ${xclass}::$name] $xinit]
			if {[_info exists ${xclass}::$name] && ![array exists ${xclass}::$name]} {
				lappend ret [set ${xclass}::$name]
			} else {
				lappend ret "<undefined>"
			}
		} else {
			return ""
		}
		if {[llength $args] == 1} {
			return $ret
		}
		set rret {}
		foreach arg [lrange $args 1 end] {
			switch -- $arg {
			-config	{
				if {[lindex $ret 0] == "public" && [lindex $ret 1] == "variable"} {
					lappend rret [lindex $ret 4]
				} else {
					lappend rret ""
				}
			}
			-init	{lappend rret [lindex $ret 3]}
			-name	{lappend rret [lindex $ret 2]}
			-protection	{lappend rret [lindex $ret 0]}
			-type	{lappend rret [lindex $ret 1]}
			-value	{lappend rret [lindex $ret end]}
			default	{
				error "bad option \"$arg\": should be -config, -init, -name, -protection, -type, or -value"
			}
			};#sw
		}
		if {[llength $rret] == 1} {
			return [lindex $rret 0]
		} else {
			return $rret
		}
	}
	default		{return [uplevel $lvl ::info $option $args]}
	}
}
#
# Needs to work for methods or procs!
#
body Object::chain {args} {
	upvar 1 this this
	set name [lindex [_info level -1] 0]
	set ns [uplevel 2 namespace current]
	set class [tcl++::fqns $ns [namespace qualifiers $name]]
	set name [namespace tail $name]
	regsub {^_tcl\+\+_} $name {} name
	if {$class == ""} {
		set class [uplevel 1 namespace current]
	}
	#
	# Make sure this wasn't inherited - if so that is the class starting
	# point.
	foreach type {method proc} {
		if {[_info exists ${class}::_info($type,$name)]} {
			set class [lindex [set ${class}::_info($type,$name)] 1]
			break
		}
	}
	if {[_info exists this]} {
		upvar #0 ${this}_clientdata_ __v__
		set heritage [set $__v__(__class)::_info(heritage)]
	} else {
		set heritage [set ${class}::_info(heritage)]
	}
	set idx [lsearch -exact $heritage $class]
	if {$idx == -1} {
		#tclLog "CHAIN: $class not in $heritage"
		return ""
	}
	#tclLog "CHAIN: name=$name, class=$class, heritage=$heritage"
	foreach super [lrange $heritage [expr $idx + 1] end] {
		foreach type {method proc} {
			if {[_info exists ${super}::_info($type,$name)]} {
				set super [lindex [set ${super}::_info($type,$name)] 1]
				#tclLog "CHAIN: found ${super}::$name ($type)"
				return [uplevel 1 ${super}::$name $args]
			}
		}
	}
	#tclLog "CHAIN: not found"
	return ""
}
#
# Sensus Consulting Ltd (C) 1998
# Matt Newman <matt@sensus.org>
#
# ensemble - ala [incr Tcl]
#

namespace eval tcl++ {
	namespace export ensemble

	namespace eval ensemble {
		variable _options
	}
	namespace eval ensemble-parser {
		variable _ns_

		namespace export ensemble parse

		proc option {name argv body} {
			::variable _ns_
			upvar ${_ns_}::_options options

			set options($name) ${_ns_}::$name

			proc ${_ns_}::$name $argv $body
		}
		proc ensemble {name body} {
			::variable _ns_
			upvar ${_ns_}::_options options

			set options($name) ${_ns_}::$name

			proc ${_ns_}::$name {option args} [format {
				upvar %s::_options options
				if {[info exists options($option)]} {
					return [uplevel 1 $options($option) $args]
				}
				set opt [array names options ${option}*]
				if {[llength $opt]==1} {
					return [uplevel 1 $options($opt) $args]
				} elseif {[llength $opt]>1} {
					set opts [lsort [array names options ${option}*]]
					set opts [lreplace $opts end end "or [lindex $opts end]"]
					error "ambiguous option \"$option\": must be one of [join $opts ", "]"
				}
				if {[info exists options(@error)]} {
					return [uplevel 1 $options(@error) $option $args]
				} else {
					set opts [lsort [array names options]]
					set opts [lreplace $opts end end "or [lindex $opts end]"]
					error "bad option \"$option\": must be one of [join $opts ", "]"
				}
			} ${_ns_}::$name]
			# parse nested-ensemble
			set _ns_ [tcl++::jns $_ns_ $name]
			namespace eval ${_ns_} {variable _options}
			namespace eval ::tcl++::ensemble-parser $body
			set _ns_ [namespace parent $_ns_]
		}
	}
}
proc tcl++::ensemble {name body} {
	set ns [uplevel 1 namespace current]
	set name [fqns $ns $name]
	set ns [namespace qualifiers $name]
	set name [namespace tail $name]
	if {$ns == ""} {set ns ::}
	#
	# Initialize nested stack
	set ensemble-parser::_ns_ [jns ::tcl++::ensemble $ns]
	#
	# Initialize namespace for ensemble commands
	namespace eval ${ensemble-parser::_ns_} [list namespace export $name]
	#
	# Kick off the recursive parser
	ensemble-parser::ensemble $name $body
	#
	# Import into parent namespace
	namespace eval $ns [list namespace import -force [jns ${ensemble-parser::_ns_} $name]]
}
namespace import -force tcl++::ensemble
catch {rename auto_import- auto_import}

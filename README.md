# yeti
Yeti - parser and scanner generator for Tcl

This is a fork of the yeti package of Frank Pilhofer. The package has vanished from the internet. See the [Tcl Wiki](https://wiki.tcl-lang.org/page/Yeti) for more details. I added a few bugfixes, removed the tcl++ support and bumpbed the package version to 0.5 to distinguish it clearly from the Frank Pilhofer's version. The Copyright stays at it is, a BSD License.

The direct support for tcl++ will be added later if I upload tcl++ version 2.3 and have checked if it still works with Tcl 8.6 and Tcl 8.7.

The cutdown version of tcl++ can be already used as alternative to Itcl in the generated
scanner or parser if the following lines are used to replace the `package require Itcl` call on top:

```
if {[catch {package require Itcl}]} {
    lappend auto_path [file dirname [info script]]
    package require tcl++
    interp alias {} itcl::class {} tcl++::class
} 
```

You just have to place the tcl++ folder directly below of your scanner/parser.
The scanner should then run even when Itcl is not not available.

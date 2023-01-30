# Yeti - parser and scanner generator for Tcl


This is a fork of the yeti package of Frank Pilhofer. The package has vanished
from the internet. See the [Tcl Wiki](https://wiki.tcl-lang.org/page/Yeti) for
more details. I added a few bugfixes, removed the tcl++ support and bumpbed
the package version to 0.5 to distinguish it clearly from the Frank Pilhofer's
version. The Copyright stays at it is, a BSD License. Then the code was backported
using a version from Steve Havelka which fixed an issue in yeti.tcl and who removed
tcl++ support. So the version is now 0.4.2 - the same which is available in LUCK.

The tools _yeti_ and _ylex_ do not work, in contrast to their counterparts [taccle](https://github.com/devnull42/taccle)  and
[fickle](https://github.com/devnull42/fickle), on straight text files as inputs but on procedure calls,
and that it requires Itcl or tcl++ to be present. The advantgage of yeti and
ylex is that they can create lexers and parsers on the fly without the need to
have this text file processing. Furthermore, yeti and ylex read as input just strings and not file handles.


2021-10-02 - The direct support for tcl++ will be added later if I upload tcl++ version 2.3
and have checked if it still works with Tcl 8.6 and Tcl 8.7.

2021-10-03 - The cutdown version of tcl++ can be already used as alternative to Itcl in the generated
scanner or parser if the following lines are used to replace the `package require Itcl` call on top:

```
if {[catch {package require Itcl}]} {
    lappend auto_path [file dirname [info script]]
    package require tcl++
    interp alias {} itcl::class {} tcl++::class
    package provide Itcl 3.0
} 
```

You just have to place the tcl++ folder directly below of your scanner/parser.
The scanner should then run even when Itcl is not not available.

## Manual pages

* [yeti.html](https://htmlpreview.github.io/?https://github.com/mittelmark/yeti/blob/master/yeti/yeti.html)
* [ylex.html](https://htmlpreview.github.io/?https://github.com/mittelmark/yeti/blob/master/yeti/ylex.html)

## Demos

* [PgnReader demo](https://github.com/mittelmark/yeti/blob/main/demo/PgnReader.tcl)
* [PgnReader output](https://github.com/mittelmark/yeti/blob/main/demo/PgnReader-0.1.tm)
* [PgnReader HTML manual](https://htmlpreview.github.io/?https://github.com/mittelmark/yeti/blob/master/demo/PgnReader.html)
* [sample.pgn - sample games for PgnReader demo](https://github.com/mittelmark/yeti/blob/main/demo/sample.pgn)
* [cscanner demo](https://github.com/mittelmark/yeti/blob/main/demo/cscanner.tcl)
* [cparser demo](https://github.com/mittelmark/yeti/blob/main/demo/cparser.tcl)

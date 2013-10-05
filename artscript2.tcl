#!/usr/bin/wish
#
#----------------:::: ArtscriptTk ::::----------------------
# Version: 2.0-alpha
# Author:IvanYossi / http://colorathis.wordpress.com ghevan@gmail.com
# Script inspired by David Revoy artscript / www.davidrevoy.com info@davidrevoy.com
# License: GPLv3 
#-----------------------------------------------------------
# Goal : Batch convert any image file supported by imagemagick, calligra & Inkscape.
# Dependencies: >=imagemagick-6.7.5, tk 8.5 zip
# Optional deps: calligraconverter, inkscape, gimp
#
# __Customize:__
#   You can modify any variable between "#--=====" markers
#   Or (recomended) make a config file (rename presets.config.presets to presets.config)
#   File must be in the same directory as the script.
#
#--====User variables
#Extension, define what file tipes artscript should read.
package require Tk
ttk::style theme use clam

# Create the namespace
namespace eval ::img { }

set ::ext ".ai .bmp .dng .exr .gif .jpeg .jpg .kra .miff .ora .png .psd .svg .tga .tiff .xcf .xpm"
#set date values
#Get a different number each run
set ::raninter [clock seconds]
set ::now [split [clock format $raninter -format %Y/%m/%d/%u] "/"]
set ::year [lindex $now 0]
set ::month [lindex $now 1]
set ::day [lindex $now 2]
set ::date [join [list $year $month $day] "-"]
#set autor name
set ::autor "Autor"
#Initialize variables for presets

#Watermark options
set ::wmtxt {}
set ::watermarks [list \
	"Copyright (c) $autor" \
	"Copyright (c) $autor / $date" \
	"http://www.yourwebsite.com" \
	"Artwork: $autor" \
	"$date" \
]
set ::wmsize 10
set ::wmcol "#000000"
set ::wmcolswatch [list "red" "#f00" "blue" "#00f" "green" "#0f0" "black" "#000" "white" "#fff" ]
set ::wmop 80
set ::wmpos "BottomRight"
set ::wmpositions [list "TopLeft" "Top" "TopRight" "Left" "Center" "Right" "BottomLeft" "Bottom" "BottomRight"]
#Place image watermark URL. /home/user/image
set ::wmimsrc ""
set ::iwatermarks [dict create \
	"Logo" "/path/to/logo" \
	"Client Watermark" "/path/to/watermarkimg" \
]
set ::wmimpos "Center"
set ::wmimsize "0"
set ::wmimcomp "Over"
set ::wmimop 100

set ::watsel 0
set ::watseltxt 0
set ::watselimg 0


#Sizes
set ::sizes [list \
	"1920x1920" \
	"1650x1650" \
	"1280x1280" \
	"1024x1024" \
	"720x720" \
	"50%" \
]
set ::sizesel 0

set ::prefixsel 0
#Extension & output
set ::outext "jpg"
set ::iquality 92

#--=====
#Don't modify below this line
set ::version "v2.0-alpha"
set ::lstmsg ""
# TODO remove this list of global tcl vars. set all user vars in a pair list value, or array.
set ::gvars {tcl_rcFileName|tcl_version|argv0|argv|tcl_interactive|tk_library|tk_version|auto_path|errorCode|tk_strictMotif|errorInfo|auto_index|env|tcl_pkgPath|tcl_patchLevel|argc|tk_patchLevel|tcl_library|tcl_platform}
#Function to send message boxes
proc alert {type icon title msg} {
		tk_messageBox -type $type -icon $icon -title $title \
		-message $msg
}

# TODO: look for binary paths using global $env variable
proc validate {program} {
	expr { ![catch {exec which $program}] ? [return 1] : [return 0] }
}
#Gimp path
set hasgimp [validate "gimp"]
#Inkscape path, if true converts using inkscape to /tmp/*.png
set hasinkscape [validate "inkscape"]
#calligraconvert path, if true converts using calligra to /tmp/*.png
set hascalligra [validate "calligraconverter"]

# Global dictionaries, files values, files who process
set inputfiles [dict create]
set handlers [dict create]
# Checks the files listed in args to be valid files supported	
proc listValidate { ltoval {counter 1}} {
	global ext hasinkscape hascalligra hasgimp
	global identify ops
	
	proc setDictEntries { id fpath size ext h} {
		global inputfiles handlers

		set iname [file tail $fpath]
		set apath [file normalize $fpath]
		set ext [string trim $ext {.}]
		
		dict set inputfiles $id name $iname
		dict set inputfiles $id oname $iname
		dict set inputfiles $id size $size
		dict set inputfiles $id ext $ext
		dict set inputfiles $id path $apath
		dict set inputfiles $id deleted 0
		dict set handlers $iname $h
	}
	# Keep $fc adding up if proc is called a second time. TODO (perhaps make global)
	set fc $counter
	
	# TODO make functions work with a single identify format { identify -quiet -format "%wx%h:%m:%M " }
	# Last returns a list of (n) nunber of layers the image has
	set identify "identify -quiet -format %wx%h\|%m\|%M\|"
	# Variable to store option arguments:ex :p xx.preset
	set ops [dict create]
	set options true
	set lops 1
	#We validate sort arguments into options and filelists
	foreach i $ltoval {
		# TODO inset while to avoid evaluating this when options is set to false
		incr c
		if { [string index $i 0] == ":" && $options} {
			dict set ops $i [lindex $argv $c]
			set lops [expr {[llength $ops]+1}]
			continue
		} elseif { $options && $lops == $c } {
			set options false
		}
		# from here vars are not options but files
		# Call itself with directory contents if arg is dir
		if {[file isdirectory $i]} {
			listValidate [glob -nocomplain -directory $i -type f *] $fc
			continue
		}
		set filext [string tolower [file extension $i] ]
		set iname [file tail $i]

		if {[lsearch $ext $filext ] >= 0 } {
			if { [regexp {.xcf|.psd} $filext ] && $hasgimp } {

				set size [lindex [exec identify -format "%wx%h " $i ] 0]

				setDictEntries $fc $i $size $filext "g"
				incr fc
				continue

			} elseif { [regexp {.svg|.ai} $filext ] && $hasinkscape } {

				if { [catch { exec inkscape -S $i | head -n 1 } msg] } {
					append lstmsg "EE: $i discarted\n"
					puts $msg
					continue
				}
				
				# TODO get rid of head cmd
				set svgcon [exec inkscape -S $i | head -n 1]
				# Get the last elements of first line == w x h
				set svgvals [lrange [split $svgcon {,}] end-1 end]
				# Make float to int. TODO check if format "%.0f" works best here
				set size [expr {round([lindex $svgvals 0])}]
				append size "x" [expr {round([lindex $svgvals 1])}]

				setDictEntries $fc $i $size $filext "i"
				incr fc
				continue

			} elseif { [regexp {.kra|.ora|.xcf|.psd} $filext ] && $hascalligra } {
				set size "N/A"
				# TODO Simplify
				# Get contents from file and parse them into Size values.
				if { $filext == ".ora" } {
					if { [catch { set zipcon [exec unzip -p $i stack.xml | grep image | head -n 1] } msg] } {
						continue
					}
					set zipcon [exec unzip -p $i stack.xml | grep image | head -n 1]
					set zipkey [lreverse [ string trim $zipcon "image<> " ] ]
					set size [string trim [lindex [split [lindex $zipkey 0] {=}] 1] "\""]x[string trim [lindex [split [lindex $zipkey 1] "="] 1] {"\""}]
					unset zipcon zipkey

				} elseif { $filext == ".kra" } {
					if { [catch { set zipcon [exec unzip -p $i maindoc.xml | grep -i IMAGE | head -n1] } msg] } {
						continue
					}
						set zipcon [exec unzip -p $i maindoc.xml | grep -i IMAGE | head -n1]
						set zipkey [lsearch -inline -regexp -all $zipcon {^(width|height)} ]
						set size [string trim [lindex [split [lindex $zipkey 0] {=}] 1] "\""]x[string trim [lindex [split [lindex $zipkey 1] "="] 1] {"\""}]
						unset zipcon zipkey
				}

				setDictEntries $fc $i $size $filext "k"
				incr fc
				continue

			# Catch magick errors. Some files have the extension but are not valid types
			} else {
				if { [catch {set finfo [exec {*}[split $identify " "] $i ] } msg ] } {
					puts $msg
					append ::lstmsg "EE: $i discarted\n"
					continue
				} else {
					set size [lindex [split [string trim $finfo "|"] "|"] 0]
				}

				setDictEntries $fc $i $size $filext "m"
				incr fc
			}
		
		# When no extension we still check if file is valid image file, this can't tell
		# if image type is openraster, krita or gimp valid. Need to work with mimes.
		} elseif { [string is boolean [file extension $i]] && !$options } {
			if { [catch { set f [exec {*}[split $identify " "] $i ] } msg ] } {
				puts $msg
			} else {
				if { [catch {set finfo [exec {*}[split $identify " "] $i ] } msg ] } {
					puts $msg
					append ::lstmsg "EE: $i discarted\n"
					continue
				}

				set iminfo [split [string trim $finfo "|"] "|"]
				set size [lindex $iminfo 0]
				set filext [string tolower [lindex $iminfo 1]]

				setDictEntries $fc $i $size $filext "m"
				incr fc
			}
		}
	}
}
# Validate input filetypes
listValidate $argv

# Returns total of files in dict except for flagged as deleted.
# TODO all boolean is reversed.
proc getFilesTotal { { all 0} } {
	global inputfiles

	if { $all == 1 } {
		dict for {id datas} $inputfiles {
 	 		dict with datas {
				if { $deleted == 0 } {
					lappend count $id
				}
 	 		}
		}
	} else {
		set count [dict keys $inputfiles]
	}
	return [llength $count]
}

proc updateWinTitle {} {
	wm title . "Artscript $::version -- [getFilesTotal 1] Files selected"
}

# Returns a list with all keys that match value == c
proc putsHandlers {c} {
	global handlers
	set ${c}fdict [dict filter $handlers script {k v} {expr {$v eq $c}}]
	puts [dict keys [set ${c}fdict]]
	#or puts [dict keys [subst $${c}fdict]]
}
putsHandlers "g"
putsHandlers "i"
putsHandlers "k"
putsHandlers "m"

#--- Window options
wm title . "Artscript $version -- [getFilesTotal] Files selected"

# We test if icon exist before addin it to the wm
set wmiconpath [file join [file dirname [info script]] "atk-logo.gif"]
if {![catch {set wmicon [image create photo -file $wmiconpath  ]} msg ]} {
	wm iconphoto . -default $wmicon
}

proc openFiles {} {
	global inputfiles
	set exts [list $::ext]
	set types " \
	 	\"{Suported Images}  $exts \"
	{{KRA, ORA}      {.ora .kra}  } \
	{{SVG, AI}       {.svg .ai}   } \
	{{XCF, PSD}      {.xcf .psd}  } \
	{{PNG}           {.png}       } \
	{{JPG, JPEG}     {.jpg .jpeg} } \
	"
	set files [tk_getOpenFile -filetypes $types -initialdir $::env(HOME) -multiple 1]
	
	listValidate $files [expr {[getFilesTotal]+1}] ; # Add 1 to keep global counter id in sync
	# TODO Instead of using global inputfiles we could create a trasition dict and append to it.
	addTreevalues .f2.fb.flist $inputfiles 
	updateWinTitle
}

# ----=== Gui proc events ===----

# Checks checkbox state, turns on if off and returns value.
# TODO Make versatile to any checkbox
proc bindsetAction { args } {
	foreach i $args {
		incr n
		set $n $i
	}
	setGValue $1 $2
	optionOn $3 $4
}
proc setGValue {gvar value} {
	if {$gvar != 0} {
		upvar #0 $gvar var
		set var $value
		puts $var
	}
}
proc optionOn {gvar args} {
	if {$gvar != 0} {
		upvar #0 $gvar var
		foreach check {*}$args {
			set vari [$check cget -variable]
			upvar #0 $vari wmcbst
			if { !$var || !$wmcbst} {
				$check invoke
			}
		}
	}
}
# Sets a custom value to any key of all members o the dict
# TODO complete the function. recieves widget, inputdict, key to alter, script
proc changeval {} {
	global inputfiles
	foreach arg [dict keys $inputfiles] {
		global imgid$arg
		set setval [.m2.ac.conv.size.sizes item [.m2.ac.conv.size.sizes selection] -text]
		set oname "[dict get $inputfiles $arg name]_$setval"
		dict set inputfiles $arg oname $oname
		.m1.flist set [set imgid$arg] output $oname
	}
}
# Get nested dict values and place them in the tree $w
proc addTreevalues { w fdict } {
	# .f2.fb.flist
	#puts [dict keys [set ${c}fdict]]
	#or puts [dict keys [subst $${c}fdict]]
	dict for {id datas} $fdict {
		#check to see if id exists to avoid duplication
		if { [info exists ::img::imgid$id] || [dict get $fdict $id deleted] } {
			continue
		}
 	  dict with datas {
				set values [list $id $name $ext $size $oname]
				set ::img::imgid$id [$w insert {} end -values $values]
 	  }
	}
}

# Deletes the keys from tree(w), and sets deletes value to 1
# TODO Remove all entries of file type. (filtering)
proc removeTreeItem { w i } {
	global inputfiles

	foreach item $i {
		set id [$w set $item id]
		# TODO undo last delete
		dict set inputfiles $id deleted 1
		unset ::img::imgid$id
	}
	# remove keys from tree
	$w delete $i
	updateWinTitle
}

# from http://wiki.tcl.tk/20930
proc treeSort {tree col direction} {
	# Build something we can sort
    set data {}
    foreach row [$tree children {}] {
        lappend data [list [$tree set $row $col] $row]
    }

    set dir [expr {$direction ? "-decreasing" : "-increasing"}]
    set r -1

    # Now reshuffle the rows into the sorted order
    foreach info [lsort -dictionary -index 0 $dir $data] {
        $tree move [lindex $info 1] {} [incr r]
    }

    # Switch the heading so that it will sort in the opposite direction
    set cmd [list treeSort $tree $col [expr {!$direction}]]
    $tree heading $col -command $cmd
}

# Attempts to load a thumbnail from thumbnails folder if exists.
# Creates a thumbnail for files missing Large thumbnail
proc showPreview { w f {tryprev 1}} {

	# First define subprocesses
	# TODO, set a rename proc "" to delete process and make it trully local (or lambas?)
	# makeThumb creates a thumbnail based on path (file type) makes requested sizes.
	proc makeThumb { path tsize } {
		set cmd [dict create]
		dict set cmd .ora {Thumbnails/thumbnail.png}
		dict set cmd .kra {preview.png}

		set filext [string tolower [file extension $path] ]

		if { [regexp {.ora|.kra} $filext ] } {
			set container [dict get $cmd $filext]
			#unzip to location tmp$container
			catch {exec unzip $path $container -d /tmp/}
			set tmpfile "/tmp/$container"
			set path $tmpfile

		# Remove gimp and psd thumnail if we cannot figure it out how to keep GUI responsive
		# Or: force use of tmp file from convert (faster) instead of savind a preview.
		} elseif {[regexp {.xcf|.psd} $filext ]} {
			set tmpfile "atk-gimpprev.png"
			set cmd "(let* ( (image (car (gimp-file-load 1 \"$path\" \"$path\"))) (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE))) ) (gimp-file-save 1 image drawable \"/tmp/$tmpfile\" \"/tmp/$tmpfile\") )(gimp-quit 0)"
			#run gimp command, it depends on file extension to do transforms.
			catch { exec gimp -i -b $cmd } msg
			set tmpfile "/tmp/$tmpfile"
			set path $tmpfile
		}
		foreach {size dest} $tsize {
			catch {exec convert $path -thumbnail [append size x $size] -flatten PNG32:$dest} msg
		}
		catch {file delete $tmpfile}
	}

	global inputfiles env

	# Do not process if selection is multiple
	if {[llength $f] > 1} {
		return -code 3
	}
	# TODO, get value with no lindex: .t set $f id
	set id [lindex [.f2.fb.flist item $f -values] 0]
	set path [dict get $inputfiles $id path]
	# Creates md5 checksum from text string: TODO avoid using echo
	# exec md5sum << "string" and string trim $hash {- }
	set thumbname [lindex [exec echo -n "file://$path" \| md5sum] 0]
	set thumbdir "$env(HOME)/.thumbnails"
	set lthumb "${thumbdir}/large/$thumbname.png"
	set nthumb "${thumbdir}/normal/$thumbname.png"

	# Displays preview in widget, Make proc of this.
	if { [file exists $lthumb ] } {
		global img oldimg
		set prevgif {/tmp/atkpreview.gif}
		
		exec convert $lthumb GIF:$prevgif
		catch {set oldimg $img}
		set img [image create photo -file /tmp/atkpreview.gif ]

		.f2.fb.lprev.im configure -image $img
		catch {image delete $oldimg}

		catch {file delete $prevgif}
		return ; # Exits parent proc
		# As a proc it has to return true false

	} elseif { [file exists $nthumb] } {
		puts "$path has normal thumb"
		makeThumb $path [list 256 $lthumb]
	} else {
		puts "$path has no thumb"
		makeThumb $path [list 128 $nthumb 256 $lthumb]
	}

	if {$tryprev} {
		showPreview w $f 0
	}
}

# Scroll trough tabs on a notebook. (dir = direction)
proc scrollTabs { w i {dir 1} } {
		set tlist [llength [$w tabs]]
		# Defines if we add or res
		expr { $dir ? [set op ""] : [set op "-"] }
		incr i [append ${op} 1]
		if { $i < 0 } {
			$w select [expr {$tlist-1}]
		} elseif { $i == $tlist } {
			$w select 0
		} else {
			$w select $i
		}
}

# Defines a combobox editable with right click
proc comboBoxEditEvents { w {script {optionOn watsel} }} {
	bind $w <<ComboboxSelected>> $script
	bind $w <Button-3> { %W configure -state normal }
	bind $w <KeyRelease> $script
	bind $w <FocusOut> { %W configure -state readonly }
}


# ----=== Gui Construct ===----
# TODO Make every frame a procedure to ease movement of the parts
# Top menu panel
pack [ttk::frame .f1] -side top -expand 0 -fill x
ttk::label .f1.title -text "Artscript 2.0alpha"
ttk::button .f1.add -text "Add files" -command { puts [openFiles] }
pack .f1.title .f1.add -side left


# Paned views, File manager and options
ttk::panedwindow .f2 -orient vertical
ttk::frame .f2.fb
ttk::panedwindow .f2.ac -orient horizontal
.f2 add .f2.fb
.f2 add .f2.ac

# --== File manager treeview start ==
set fileheaders { id input ext size oname }
ttk::treeview .f2.fb.flist -columns $fileheaders -show headings -yscrollcommand ".f2.fb.sscrl set"
foreach col $fileheaders {
	set name [string totitle $col]
	.f2.fb.flist heading $col -text $name -command [list treeSort .f2.fb.flist $col 0 ]
}
.f2.fb.flist column id -width 48 -stretch 0
.f2.fb.flist column ext -width 48 -stretch 0
.f2.fb.flist column size -width 86 -stretch 0

#Populate tree
addTreevalues .f2.fb.flist $inputfiles

bind .f2.fb.flist <<TreeviewSelect>> { showPreview .m2.lprev.im [%W selection] }
bind .f2.fb.flist <Key-Delete> { removeTreeItem %W [%W selection] }
ttk::scrollbar .f2.fb.sscrl -orient vertical -command { .f2.fb.flist yview }

# --== Thumbnail
ttk::labelframe .f2.fb.lprev -width 276 -height 292 -padding 6 -labelanchor n -text "Thumbnail"
# -labelwidget .f2.ac.checkwm
ttk::label .f2.fb.lprev.im -anchor center -text "No preview"


pack .f2.fb.flist -side left -expand 1 -fill both
pack .f2.fb.sscrl .f2.fb.lprev -side left -expand 0 -fill both
pack propagate .f2.fb.lprev 0
pack .f2.fb.lprev.im -expand 1 -fill both

# --== Option tabs
ttk::notebook .f2.ac.n
ttk::notebook::enableTraversal .f2.ac.n
bind .f2.ac.n <ButtonPress-4> { scrollTabs %W [%W index current] 1 }
bind .f2.ac.n <ButtonPress-5> { scrollTabs %W [%W index current] 0 }

# Set a var to ease modularization. TODO: procs
set wt {.f2.ac.n.wm}
ttk::frame $wt -padding 6

ttk::label $wt.lsel -text "Selection*"
ttk::label $wt.lsize -text "Size" -width 4
ttk::label $wt.lpos -text "Position" -width 10
ttk::label $wt.lop -text "Opacity" -width 10

proc  turnOffParentCB { parent args } {
	set varpar [$parent cget -variable]
	upvar #0 $varpar pbvar
	foreach cb $args {
		set varcb [$cb cget -variable]
		upvar #0 $varcb cbvar
		lappend total $cbvar
	}
	set total [expr [join $total +]]
	if { ($total > 0 && !$pbvar) || ($total == 0 && $pbvar) } {
		$parent invoke
	}
}

# Text watermark ops
ttk::checkbutton $wt.cbtx -onvalue 1 -offvalue 0 -variable watseltxt -command { turnOffParentCB .f3.rev.checkwm $wt.cbtx $wt.cbim}
ttk::label $wt.ltext -text "Text"
ttk::combobox $wt.watermarks -state readonly -textvariable wmtxt -values $watermarks -width 28
$wt.watermarks set [lindex $watermarks 0]
comboBoxEditEvents $wt.watermarks {bindsetAction 0 0 watsel ".f3.rev.checkwm $wt.cbtx"}

# font size spinbox
set fontsizes [list 8 10 11 12 13 14 16 18 20 22 24 28 32 36 40 48 56 64 72 144]
ttk::spinbox $wt.fontsize -width 4 -values $fontsizes -validate key \
	-validatecommand { string is integer %P }
$wt.fontsize set $wmsize
bind $wt.fontsize <ButtonRelease> {bindsetAction wmsize [%W get] watsel ".f3.rev.checkwm $wt.cbtx"}
bind $wt.fontsize <KeyRelease> { bindsetAction wmsize [%W get] watsel ".f3.rev.checkwm $wt.cbtx" }

# Text position box
ttk::combobox $wt.position -state readonly -textvariable wmpossel -values $wmpositions -width 10
$wt.position set $wmpos
bind $wt.position <<ComboboxSelected>> { bindsetAction 0 0 watsel ".f3.rev.checkwm $wt.cbtx" }

# Image watermark ops
ttk::checkbutton $wt.cbim -onvalue 1 -offvalue 0 -variable watselimg -command {turnOffParentCB .f3.rev.checkwm $wt.cbtx $wt.cbim}
ttk::label $wt.limg -text "Image"
# dict get $dic key
# Get only the name for image list.
set iwatermarksk [dict keys $iwatermarks]
ttk::combobox $wt.iwatermarks -state readonly -textvariable wmimsrc -values $iwatermarksk
$wt.iwatermarks set [lindex $iwatermarksk 0]
bind $wt.iwatermarks <<ComboboxSelected>> { bindsetAction 0 0 watsel ".f3.rev.checkwm $wt.cbim" }

# Image size box \%
ttk::spinbox $wt.imgsize -width 4 -from 0 -to 100 -increment 10 -validate key \
	-validatecommand { string is integer %P }
$wt.imgsize set $wmimsize
bind $wt.imgsize <ButtonRelease> { bindsetAction wmimsize [%W get] watsel .f3.rev.checkwm }
bind $wt.imgsize <KeyRelease> { bindsetAction wmimsize [%W get] watsel ".f3.rev.checkwm $wt.cbim"] }

# Image position
ttk::combobox $wt.iposition -state readonly -textvariable wmimpos -values $wmpositions -width 10
$wt.position set $wmpos
bind $wt.iposition <<ComboboxSelected>> { bindsetAction 0 0 watsel ".f3.rev.checkwm $wt.cbim" }

# Opacity scales
# Set a given float as integer, TODO uplevel to set local context variable an not global namespace
proc progressBarSet { gvar cvar wt cb ft fl } {
	bindsetAction $gvar [format $ft $fl] $cvar ".f3.rev.checkwm $wt.$cb"
}

ttk::scale $wt.txop -from 10 -to 100 -variable wmop -value $wmop -orient horizontal -command { progressBarSet wmop watsel $wt cbtx "%.0f" }
ttk::label $wt.tolab -width 3 -textvariable wmop

ttk::scale $wt.imop -from 10 -to 100 -variable wmimop -value $wmimop -orient horizontal -command { progressBarSet wmimop watsel $wt cbim "%.0f" }
ttk::label $wt.iolab -width 3 -textvariable wmimop

# Style options
ttk::frame $wt.st
ttk::label $wt.st.txcol -text "Text Color"
ttk::label $wt.st.imstyle -text "Image Blending"
ttk::separator $wt.st.sep -orient vertical

#Convert RGB to HSV, to calculate contrast colors
proc rgbtohsv { r g b } {
	set r1 [expr {$r/255.0}]
	set g1 [expr {$g/255.0}]
	set b1 [expr {$b/255.0}]
	set max [expr {max($r1,$g1,$b1)}]
	set min [expr {min($r1,$g1,$b1)}]
	set delta [expr {$max-$min}]
	set h -1
	set s {}
	set v $max
	set l $v
	set luma $l

	if {$delta != 0} {
		set l [expr { ($max + $min) / 2 } ]
		set s [expr { $delta/$v }]
		set luma [expr { (0.2126 * $r1) + (0.7152 * $g1) + (0.0722 * $b1) }]
		if { $max == $r1 } {
			set h [expr { ($g1-$b1) / $delta }]
		} elseif { $max == $g1 } {
			set h [expr { 2 + ($b1-$r1) / $delta }]
		} else {
			set h [expr { 4 + ($r1-$g1) / $delta }]
		}
		set h [expr {round(60 * $h)}]
		if { $h < 0 } { incr h 360 }
	} else {
		set s 0
	}
	return [list $h [format "%0.2f" $s] [format "%0.2f" $v] [format "%0.2f" $l] [format "%0.2f" $luma]]
}

proc setColor { w var item col {direct 1} { title "Choose color"} } {
	upvar 1 $var txtcol ; # review if txtcol can be deleted
	set col [lindex $col end]

	#Call color chooser and store value to set canvas color and get rgb values
	if { $direct } {
		set col [tk_chooseColor -title $title -initialcolor $col -parent .]
	}
	# User selected a color and not cancel then
	if { [expr {$col ne "" ? 1 : 0}] } {
		$w itemconfigure $item -fill $col
		$w itemconfigure $::c(main) -outline [getContrastColor $col]
	}
	return $col
}
proc getContrastColor { color } {
	set rgbs [winfo rgb . $color]
	set luma [lindex [rgbtohsv {*}$rgbs ] 4]
	return [expr { $luma >= 165 ? "black" : "white" }]
}

proc drawSwatch { w args } {
	set args {*}$args
	set chal [expr {([llength $args]/2)+1}] ; # Half swatch list

	set gap 10
	set height 26
	set width [expr {$height+($chal*13)+$gap}]
	set cw 13
	set ch 13
	set x [expr {26+$gap}]
	set y 1
	
	$w configure -width $width

	foreach swatch $args {
		incr i
		set ::c($i) [$w create rectangle $x $y [expr {$x+$cw}] [expr {$y+$ch-1}] -fill $swatch -width 1 -outline {gray26} -tags {swatch}]
		set col [lindex [$w itemconfigure $::c($i) -fill] end]
		$w bind $::c($i) <Button-1> [list setColor $w wmcol $::c(main) $col 0 ]
		if { $i == $chal } {
			incr y $ch
			set x [expr {$x-($cw*$i)}]
		}
		incr x 13
	}
}

# from http://wiki.tcl.tk/534
proc dec2rgb {r {g 0} {b UNSET} {clip 0}} {
	if {![string compare $b "UNSET"]} {
		set clip $g
		if {[regexp {^-?(0-9)+$} $r]} {
			foreach {r g b} $r {break}
		} else {
			foreach {r g b} [winfo rgb . $r] {break}
		}
	}
	set max 255
	set len 2
	if {($r > 255) || ($g > 255) || ($b > 255)} {
		if {$clip} {
		set r [expr {$r>>8}]; set g [expr {$g>>8}]; set b [expr {$b>>8}]
		} else {
			set max 65535
			set len 4
		}
	}
	return [format "#%.${len}X%.${len}X%.${len}X" \
	  [expr {($r>$max)?$max:(($r<0)?0:$r)}] \
	  [expr {($g>$max)?$max:(($g<0)?0:$g)}] \
	  [expr {($b>$max)?$max:(($b<0)?0:$b)}]]
}

proc getswatches { {colist 0} {sortby 1}} {
	# Set a default palette, colors have to be in rgb
	set swcol { Black {0 0 0} English-red {208 0 0} {Dark crimson} {120 4 34} Orange {254 139 0} Sand {193 177 127} Sienna {183 65 0} {Yellow ochre} {215 152 11} {Cobalt blue} {0 70 170} Blue {30 116 253} {Bright steel blue} {170 199 254} Mint {118 197 120} Aquamarine {192 254 233} {Forest green} {0 67 32} {Sea green} {64 155 104} Green-yellow {188 245 28} Purple {137 22 136} Violet {77 38 137} {Rose pink} {254 101 203} Pink {254 202 218} {CMYK Cyan} {0 254 254} {CMYK Yellow} {254 254 0} White {255 255 255} }
	
	if { [llength $colist] > 1 } {
		set swcol [list]
		# Convert hex list from user to rgb 257 vals
		foreach {ncol el} $colist {
			set rgb6 [winfo rgb . $el]
			set rgb6 [list [expr {[lindex $rgb6 0]/257}] [expr {[lindex $rgb6 1]/257}] [expr {[lindex $rgb6 2]/257}] ]
			lappend swcol $ncol $rgb6
		}
	}

	set swdict [dict create {*}$swcol]
	set swhex [dict create]
	set swfinal [dict create]

	dict for {key value} $swdict {
		lappend swluma [list $key [lindex [rgbtohsv {*}$value] $sortby]]
		dict set swhex $key [dec2rgb {*}$value]
	}

	foreach pair [lsort -index 1 $swluma] {
		set swname [lindex $pair 0]
		dict set swfinal $swname [dict get $swhex $swname]
	}
	return [dict values $swfinal]
}




canvas $wt.st.chos  -width 62 -height 26
set c(main) [$wt.st.chos create rectangle 2 2 26 26 -fill $::wmcol -width 2 -outline [getContrastColor $::wmcol] -tags {main}]
$wt.st.chos bind main <Button-1> { setColor %W wmcol $c(main) [%W itemconfigure $c(main) -fill] }

set wmswatch [getswatches $::wmcolswatch]
drawSwatch $wt.st.chos $wmswatch

set iblendmodes [list "Bumpmap" "Burn" "Color_Burn" "Color_Dodge" "Colorize" "Copy_Black" "Copy_Blue" "Copy_Cyan" "Copy_Green" "Copy_Magenta" "Copy_Opacity" "Copy_Red" "Copy_Yellow" "Darken" "DarkenIntensity" "Difference" "Divide" "Dodge" "Exclusion" "Hard_Light" "Hue" "Light" "Lighten" "LightenIntensity" "Linear_Burn" "Linear_Dodge" "Linear_Light" "Luminize" "Minus" "ModulusAdd" "ModulusSubtract" "Multiply" "Overlay" "Pegtop_Light" "Pin_Light" "Plus" "Saturate" "Screen" "Soft_Light" "Vivid_Light"]
ttk::combobox $wt.st.iblend -state readonly -textvariable wmimcomp -values $iblendmodes -width 12
$wt.st.iblend set $wmimcomp
bind $wt.st.iblend <<ComboboxSelected>> { bindsetAction wmimcomp [%W get] watsel ".f3.rev.checkwm $wt.cbim" }

set wtp 2 ; # Padding value

grid $wt.lsize $wt.lpos $wt.lop -row 1 -sticky ws
grid $wt.cbtx $wt.ltext $wt.watermarks $wt.fontsize $wt.position $wt.txop $wt.tolab -row 2 -sticky we -padx $wtp -pady $wtp
grid $wt.cbim $wt.limg $wt.iwatermarks $wt.imgsize $wt.iposition $wt.imop $wt.iolab -row 3 -sticky we -padx $wtp -pady $wtp
grid $wt.cbtx $wt.cbim -column 1 -padx 0 -ipadx 0
grid $wt.ltext $wt.limg -column 2
grid $wt.watermarks $wt.iwatermarks -column 3
grid $wt.lsize $wt.fontsize $wt.imgsize -column 4
grid $wt.lpos $wt.position $wt.iposition -column 5
grid $wt.lop $wt.txop $wt.imop -column 6
grid $wt.tolab $wt.iolab -column 7
grid $wt.st -row 4 -column 3 -columnspan 4 -sticky we -pady 4
grid columnconfigure $wt {3} -weight 1

pack $wt.st.txcol $wt.st.chos $wt.st.sep $wt.st.imstyle $wt.st.iblend -expand 1 -side left -fill x
pack configure $wt.st.txcol $wt.st.chos $wt.st.imstyle -expand 0

# --== Size options
proc tabResize {st} {
	global wList hList
	foreach size $::sizes {
		if { [string index $size end] == {%} } {
			lappend pList $size
		} else {
			set size [split $size {x}]
			lappend wList [lindex $size 0]
			lappend hList [lindex $size 0]
		}
	}
	lappend wList $pList 
	
	ttk::frame $st -padding 6
	
	ttk::frame $st.lef
	ttk::labelframe $st.rgt -text "Options"
	
	grid $st.lef -column 1 -row 1 -sticky nesw
	grid $st.rgt -column 2 -row 1 -sticky nesw
	grid columnconfigure $st 1 -weight 1 -minsize 250
	grid columnconfigure $st 2 -weight 2 -minsize 250
	grid rowconfigure $st 1 -weight 1 
	
	ttk::label $st.rgt.ins -text ""
	pack $st.rgt.ins -side left
	
	ttk::style layout small.TButton {
		Button.border -sticky nswe -border 1 -children {
			Button.focus -sticky nswe -children {
				Button.spacing -sticky nswe -children {Button.label -sticky nswe}
				}
			}
		}
	# ttk::style configure small.TButton -background color
	
	# grid $st.ins -column 0 -row 1 -columnspan 5 -sticky we
	ttk::label $st.lef.ann -text "   No Selection" -font "-size 14"
	ttk::button $st.lef.add -text "+" -width 2 -style small.TButton -command [list addSizecol $st.lef 1 1]
	grid $st.lef.ann -column 1 -row 1 -columnspan 4 -sticky nwse
	grid $st.lef.add -column 0 -row 1 -sticky w
	grid rowconfigure $st.lef 1 -minsize 28

	proc getSizesSel { w } {
		set cols [grid slaves $w -column 2]	
		set gsels {}
		set widx [expr {[string length $w]+4}]
		foreach el $cols {
			set idl [string range $el $widx end]
			set wid [$w.wid$idl get]
			set hei [$w.hei$idl get]
			lappend gsels "$wid $hei"
		}

		return $gsels
	}
	
	proc eventSize { w wc } {
		set sizesels [getSizesSel $w]
		if { [llength $sizesels] > 1 } {
			# treeAlterVal .f2.fb.flist oname {lindex [getOutputName $value $::outext $::oupreffix $::ousuffix] 0}
		} elseif { [llength $sizesels] == 1 } {
			bindsetAction 0 0 sizesel .f3.rev.checksz
		} elseif { [llength $sizesels] == 0 } {
			.f3.rev.checksz invoke
		}
		
		# set fname [getOutputName $f $::outext $::ouprefix $::ousuffix]
		# puts $fname
	}
	
	proc addSizecol {st id row {state normal}} {
		global wList hList
		
		grid forget $st.ann
		ttk::combobox $st.wid$id -state readonly -width 8 -justify right -values $wList
		$st.wid$id set [lindex $wList 0]
		ttk::combobox $st.hei$id -state readonly -width 8 -values $hList
		$st.hei$id set [lindex $hList 0]
		comboBoxEditEvents $st.wid$id "eventSize $st %W"
		comboBoxEditEvents $st.hei$id "eventSize $st %W"
		# ttk::separator $st.sep -orient vertical -padding
		ttk::label $st.xmu$id -text "x" -font "-size 18"	
		ttk::button $st.del$id -text "-" -width 2 -style small.TButton -command [list delSizecol $st $id]
		
		grid $st.del$id $st.wid$id $st.xmu$id $st.hei$id -row $row
		grid $st.del$id -column 1
		grid $st.wid$id -column 2 -sticky we
		grid $st.xmu$id -column 3 
		grid $st.hei$id -column 4 -sticky we
		grid columnconfigure $st {3} -pad 18
		
		incr id
		incr row
		$st.add configure -command [list addSizecol $st $id $row]
		
		eventSize $st 0
		
	}
	proc delSizecol { st id } {
		# grid forget $st.del$id $st.wid$id $st.xmul$id $st.hei$id
		destroy $st.del$id $st.wid$id $st.xmu$id $st.hei$id
		set szgrid [llength [getSizesSel $st]]
		
		eventSize $st 0
		if {[llength [grid slaves $st -row 1]] <= 1 } {
			set i 1
			set sboxl [lsort [grid slaves $st -column 2]]
			set widx [expr {[string length $st]+4}]
			foreach el $sboxl {
				set idl [string range $el $widx end]
				grid $st.del$idl $st.wid$idl $st.xmu$idl $st.hei$idl -row $i
				incr i
			}
		}
		if { [llength [grid slaves $st -column 2]] == 0 } {
			$st.add configure -command [list addSizecol $st $id 1]
			grid $st.ann -column 1 -row 1 -columnspan 4 -sticky nwse
		}
		return $szgrid
	}
}

tabResize .f2.ac.n.sz

# Add frames to tabs in notebook
.f2.ac.n add $wt -text "Watermark" -underline 0
.f2.ac.n add .f2.ac.n.sz -text "Resize" -underline 0

# --== Suffix and prefix ops
set ou .f2.ac.onam
ttk::frame $ou
ttk::checkbutton $ou.cbpre -onvalue true -offvalue false -variable prefixsel -text "Suffix and Prefix"
ttk::labelframe $ou.efix -text "Suffix and Prefix" -labelwidget $ou.cbpre -padding 6

ttk::label $ou.lpre -text "Prefix"
ttk::label $ou.lsuf -text "Suffix"

set ::suffixes [list \
	"net" \
	"archive" \
	"by-[string map -nocase {{ } -} $autor]" \
	"$date" \
]
lappend ::suffixes {} ; # Appends an empty value to allow easy deselect
foreach suf $::suffixes {
	lappend suflw [string length $suf]
}
set suflw [lindex [lsort -integer -decreasing $suflw] 0]
set suflw [expr {int($suflw+($suflw*.2))}]
expr { $suflw > 16 ? [set suflw 16] : [set suflw] }

ttk::combobox $ou.efix.pre -width $suflw -state readonly -textvariable ::ouprefix -values $suffixes
$ou.efix.pre set [lindex $suffixes 0]
comboBoxEditEvents $ou.efix.pre {printOutname [.f2.fb.flist set [.f2.fb.flist selection] input]}
ttk::combobox $ou.efix.suf -width $suflw -state readonly -textvariable ::ousuffix -values $suffixes
$ou.efix.suf set [lindex $suffixes end-1]
comboBoxEditEvents $ou.efix.suf {printOutname [.f2.fb.flist set [.f2.fb.flist selection] input]}

# Sets a custom value to any key of all members o the dict
# TODO complete the function. recieves widget, inputdict, key to alter, script
proc treeAlterVal { w column {script {puts $value}} } {
	global inputfiles
	
	foreach id [dict keys $inputfiles] {

		set value [dict get $inputfiles $id $column]
		set newvalue [uplevel 0 $script]
		
		$w set [set ::img::imgid$id] $column $newvalue
	}
}

proc printOutname { f } {
	treeAlterVal .f2.fb.flist oname {lindex [getOutputName $value $::outext $::ouprefix $::ousuffix] 0}
	bindsetAction 0 0 prefixsel .f2.ac.onam.cbpre
	set fname [getOutputName $f $::outext $::ouprefix $::ousuffix]
	puts $fname
}

# --== Output frame

ttk::labelframe $ou.f -text "Output & Quality" -padding 8

set formats [list PNG JPG GIF] ; # TODO ora and keep
ttk::label $ou.f.lbl -text "Format:"
ttk::combobox $ou.f.fmt -state readonly -width 6 -textvariable outext -values $formats
$ou.f.fmt set [lindex $formats 0]
bind $ou.f.fmt <<ComboboxSelected>> { puts [%W get] }

ttk::label $ou.f.qtb -text "Quality:"
ttk::scale $ou.f.qal -from 10 -to 100 -variable iquality -value $::iquality -orient horizontal -command { progressBarSet iquality 0 0 0 "%.0f" }

ttk::label $ou.f.qlb -width 4 -textvariable iquality

ttk::separator $ou.sep -orient horizontal

pack $ou.efix $ou.sep $ou.f -side top -fill both -expand 1 -padx $wtp
pack configure $ou.sep -padx 24 -pady 6 -expand 0
pack configure $ou.efix -fill x -expand 0

pack $ou.efix.pre $ou.efix.suf -padx $wtp -side left -fill x -expand 1

ttk::separator $ou.f.sep -orient vertical

grid $ou.f.qtb $ou.f.qlb $ou.f.qal -row 1
grid configure $ou.f.qtb -column 1
grid configure $ou.f.qal -column 2 -columnspan 2 -sticky we
grid configure $ou.f.qlb -column 4 -sticky w
grid $ou.f.lbl $ou.f.fmt -row 2
grid configure $ou.f.lbl -column 2
grid configure $ou.f.fmt -column 3
grid configure $ou.f.fmt $ou.f.qlb -sticky we
grid configure $ou.f.qtb $ou.f.lbl -sticky e

grid columnconfigure $ou.f {2} -weight 12 -pad 4 
grid columnconfigure $ou.f {1} -weight 2 -pad 4
grid rowconfigure $ou.f {0 1 2 3} -weight 1 -pad 4


# Add frame notebook to pane left.
.f2.ac add .f2.ac.n
.f2.ac add .f2.ac.onam
.f2.ac pane .f2.ac.n -weight 6
.f2.ac pane .f2.ac.onam -weight 2

#pack panned window
pack .f2 -side top -expand 1 -fill both

# ----==== Status bar
pack [ttk::frame .f3] -side top -expand 0 -fill x
ttk::frame .f3.rev
ttk::frame .f3.do

# A master checkbox unset all of the submitted childs
# All variables must be declared for it to work.
# proc master child1 var1 ?child2 ?var2 ...
proc turnOffChildCB { w args } {
	upvar #0 $w father
	set checkbs [list {*}$args]

	if {!$father} {
		dict for {c var} $checkbs {
			upvar #0 $var mn
			if {$mn} {
				$c invoke
			}
		}
	}
}

ttk::checkbutton .f3.rev.checkwm -text "Watermark" -onvalue 1 -offvalue 0 -variable watsel -command { turnOffChildCB watsel "$wt.cbim" watselimg "$wt.cbtx" watseltxt }
ttk::checkbutton .f3.rev.checksz -text "Resize" -onvalue 1 -offvalue 0 -variable sizesel

pack .f3.rev.checkwm .f3.rev.checksz -side left
pack .f3.rev -side left

# Positions list correspond to $::watemarkpos, but names as imagemagick needs
set magickpos [list "NorthWest" "North" "NorthEast" "West" "Center" "East" "SouthWest" "South" "SouthEast"]


# TODO adapt all below to new code.
#Resize: returns the validated entry as wxh or ready true as "-resize wxh\>"
proc getSizeSel { {collage false} {ready false}} {
	if { [string is list $::sizext] } {
		set sizeval [lindex $::sizext 0]
	} else {
		set sizeval [string trim $::sizext]
	}
	#We check if user wants resize and $sizeval not empty
	if {$collage} {
		#We have to substract the margin from the tile value, in this way the user gets
		# the results is expecting (200px tile 2x2 = 400px)
		if { $sizeval == "x" } {
			#turns concat mode on
			return "{} 0 0"
		} elseif {![string match -nocase {*[0-9]\%} $sizeval] && ![string is boolean $sizeval] } {
			set mgap [expr {($::mborder + $::mspace)*2} ]
			set xpos [string last "x" $sizeval]
			set sizelast [expr {[string range $sizeval $xpos+1 end]-$mgap}]
			set sizefirst [expr {[string range $sizeval 0 $xpos-1]-$mgap}]
			set sizeval "$sizefirst\x$sizelast\\>"
			return [lappend sizeval $sizefirst $sizelast]
		} else {
			set tmpl ""
			return [lappend tmpl [string trim $sizeval "\%"] "0" "0"]
		}
	} else {
		if {!$::sizesel || [string is boolean $sizeval] || $sizeval == "x" } {
			set sizeval ""
		}
		if {$ready && ![string is boolean $sizeval] } {
			set sizeval "-resize $sizeval\\>"
		}
	}
		return $sizeval
}



#Preproces functions
#watermark
proc watermark {} {

# ::wmtxt ::watermarks wmsize wmcol wmop wmpos wmpositions  wmimsrc iwatermarks ::wmimpos ::wmimsize ::wmimcomp ::wmimop ::watsel watseltxt watselimg

# convert -size ${width}x${height} xc:transparent -pointsize $::wmsize -gravity Center           -stroke $::wmcol -strokewidth 1 -annotate 0 $::wmtxt -blur 80x2   -background none +repage           -stroke none -fill $wmcolinv -annotate 0 $::wmtxt -trim $wmtmp
# wmtmp = /tmp/artk-watermark.png
# color in hex, no rgb mod necessary
# add wmtmp to delete list
# width and height: calculate length, multiply by 10x20

#inide convert function, after resize
# { -gravity $::wmpos $wmtmp -compose dissolve -define compose:args=$::wmop -composite } Can be repeated

	global watxt watsel wmsize wmpos wmcol opacity wmimsel

	set rgbout [setRGBColor $wmcol $opacity]
	set watval ""
	#Watermarks, we check if checkbox selected to add characters to string
	if {$watsel} {
		set watval "-pointsize $wmsize -fill $rgbout -draw \"gravity $wmpos text 10,10 \'$watxt\'\""
	}
	#we check image watermark checkbox to add image wm
	if { $wmimsel } {
			if { [file exists $::wmimsrc] } {
				set watval [concat $watval "-gravity $::wmimpos -draw \"image $::wmimcomp 10,10 0,0 '$::wmimsrc' \""]
			}
		}
	return $watval
}

#Prepares output name adding Suffix or Prefix
#Checks if destination file exists and adds a standard suffix
proc getOutputName { iname outext { prefix "" } { suffix {} } {tmprun false} {orloc 0} } {
	
	# if {$tmprun} { set suffix "" } else { set tmpsuffix $::suffix }
	
	if {$orloc != 0 } {
		set iname $orloc
	}
	set dir [file normalize [file dirname $iname]]
	set name [file rootname [file tail $iname]]

	set lname [concat $prefix [list $name] $suffix ] ; # Name in brackets to protect white space

	append outname [join $lname "_"] "." $outext
	
	#Add a counter if filename exists
	while { [file exists [file join $dir "$outname"] ] } {
		incr s
		set safe "_$s"
		set outname [join [list [string trimright $outname ".$outext"] $safe ".$outext"] {} ]
	}
	
	set olist [list]
	return [lappend olist $outname $dir]
}

#gimp process
proc processGimp { olist } {
	set ifiles ""
	if [llength $olist] {
		foreach i $olist {
			#Sends file input for processing, stripping input directory
			set io [setOutputName $i "png" 0 0 0 1]
			set outname [lindex $io 0]
			set origin [lindex $io 1]
			#Make png to feed convert
			#We set the command outside for later unfolding or it won't work.
			set cmd "(let* ( (image (car (gimp-file-load 1 \"$i\" \"$i\"))) (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE))) ) (gimp-file-save 1 image drawable \"/tmp/$outname\" \"/tmp/$outname\") )(gimp-quit 0)"
			#run gimp command, it depends on file extension to do transforms.
			catch { exec gimp -i -b $cmd } msg
			#udpate progressbar
			progressUpdate

			set errc $::errorCode;
			set erri $::errorInfo
			puts "errc: $errc \n\n"
			#puts "erri: $erri"
			if {$errc != "NONE"} {
				append ::lstmsg "EE: $i discarted\n"
				puts $msg
				continue
			}
			#Add png to argv file list on /tmp dir and originalpath to dict
			dict set ifiles [file join "/" "tmp" "$outname"] [file join $origin $i]
		}
	}
	return $ifiles
}

#Inkscape converter
proc processInkscape { {outdir "/tmp"} olist } {
	set ifiles ""
	set sizeval [getSizeSel]
	if [llength $olist] {
		foreach i $olist {
			set inksize "-d 90"
			if {$::sizesel || $::tilesel } {
				if {![string match -nocase {*[0-9]\%} $sizeval]} {
					set inksize [string range $sizeval 0 [string last "x" $sizeval]-1]
					set inksize "-w $inksize"
				} else {
					set inksize [string range $sizeval 0 [string last "%" $sizeval]-1]
					set inksize [expr {90 * ($inksize / 100.0)} ]
					set inksize "-d $inksize"
				}
			}
			#Sends file input for processing, stripping input directory
			set io [setOutputName $i "png" 0 0 0 1]
			set outname [file join $outdir [lindex $io 0]]
			set origin [lindex $io 1]
			#Make png to feed convert
			#Inkscape error handling works ok in most situations. errorCode is always reported as NONE so it isn't reliable.
			if { [catch { exec inkscape $i -z -C $inksize -e $outname } msg] } {
				append lstmsg "EE: $i discarted\n"
				puts $msg
				continue
			}
			#udpate progressbar
			progressUpdate
			#Add png to argv file list on /tmp dir and originalpath to dict
			dict set ifiles $outname [file join $origin $i]
		}
	}
	return $ifiles
}

#general unsharp value
# -unsharp 0x6+0.5+0
#extra quality x3 smashing


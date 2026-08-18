onerror {quit -code 1}
onbreak {quit -code 1}

if {![info exists env(MES50HP_TEMPLATE_ROOT)] || [string trim $env(MES50HP_TEMPLATE_ROOT)] eq ""} {
    error "MES50HP_TEMPLATE_ROOT is not set."
}
set repo_root [file normalize $env(MES50HP_TEMPLATE_ROOT)]
source [file join $repo_root config.tcl]

proc collect_files {dir patterns} {
    set result {}
    foreach pattern $patterns {
        set result [concat $result [glob -nocomplain -types f -directory $dir $pattern]]
    }
    foreach child [glob -nocomplain -types d -directory $dir *] {
        if {[file tail $child] ne "work"} {
            set result [concat $result [collect_files $child $patterns]]
        }
    }
    return [lsort -unique $result]
}

proc configured_files {root config_name fallback_dir patterns} {
    global template_config
    if {[info exists template_config($config_name)] && [llength $template_config($config_name)] > 0} {
        set result {}
        foreach path $template_config($config_name) {
            if {[file pathtype $path] ne "absolute"} {
                set path [file join $root $path]
            }
            set path [file normalize $path]
            if {![file isfile $path]} {error "Configured source does not exist: $path"}
            lappend result $path
        }
        return $result
    }
    return [collect_files [file join $root $fallback_dir] $patterns]
}

set work_dir [file join $repo_root sim work]
if {[file exists $work_dir]} {vdel -lib $work_dir -all}
vlib $work_dir
vmap work $work_dir

set rtl_files [configured_files $repo_root rtl_sources rtl {*.v *.sv *.vhd *.vhdl}]
set sim_files [configured_files $repo_root sim_sources sim {*.v *.sv *.vhd *.vhdl}]
if {[llength $rtl_files] == 0} {error "No RTL files found under rtl/."}
if {[llength $sim_files] == 0} {error "No simulation files found under sim/."}

set vlog_options [list -sv]
foreach dir $template_config(include_dirs) {
    if {[file pathtype $dir] ne "absolute"} {set dir [file join $repo_root $dir]}
    lappend vlog_options "+incdir+[file normalize $dir]"
}

foreach file [concat $rtl_files $sim_files] {
    set ext [string tolower [file extension $file]]
    if {$ext eq ".vhd" || $ext eq ".vhdl"} {
        vcom -2008 $file
    } else {
        eval vlog $vlog_options [list $file]
    }
}

vsim -c -voptargs=+acc work.$template_config(default_tb)
eval $template_config(default_sim_time)
quit -code 0

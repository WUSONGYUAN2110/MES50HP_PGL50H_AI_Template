if {[info exists env(MES50HP_TEMPLATE_ROOT)] && [string trim $env(MES50HP_TEMPLATE_ROOT)] ne ""} {
    set repo_root [file normalize $env(MES50HP_TEMPLATE_ROOT)]
} else {
    set script_dir [file dirname [file normalize [info script]]]
    set repo_root  [file dirname $script_dir]
}
source [file join $repo_root config.tcl]

proc cfg {name} {
    global template_config
    if {![info exists template_config($name)]} {
        error "Missing template_config($name) in config.tcl"
    }
    return $template_config($name)
}

set_arch -family [cfg family] -device [cfg device] -speedgrade [cfg speedgrade] -package [cfg package]
synthesize -ads -help

proc discover_files {root patterns} {
    set result {}
    foreach pattern $patterns {
        foreach path [glob -nocomplain -types f -directory $root $pattern] {
            lappend result [file normalize $path]
        }
    }
    foreach child [glob -nocomplain -types d -directory $root *] {
        set result [concat $result [discover_files $child $patterns]]
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
            if {![file isfile $path]} {
                error "Configured source does not exist: $path"
            }
            lappend result $path
        }
        return $result
    }
    return [discover_files [file join $root $fallback_dir] $patterns]
}

proc enabled_group {name} {
    return [expr {[lsearch -exact [cfg enabled_pin_groups] $name] >= 0}]
}

proc generate_active_constraint {repo_root} {
    set csv_path [file join $repo_root doc mes50hp_pinout.csv]
    set out_dir  [file join $repo_root prj generated]
    set out_path [file join $out_dir mes50hp_active.fdc]
    file mkdir $out_dir

    set input [open $csv_path r]
    set output [open $out_path w]
    fconfigure $input  -encoding utf-8
    fconfigure $output -encoding utf-8
    puts $output "# Generated from doc/mes50hp_pinout.csv. Do not edit."
    puts $output "# Enabled groups: [cfg enabled_pin_groups]"

    set first 1
    set count 0
    set used_pins [dict create]
    while {[gets $input line] >= 0} {
        if {$first} {
            set first 0
            continue
        }
        if {[string trim $line] eq "" || [string match "#*" [string trim $line]]} {
            continue
        }
        set fields [split $line ,]
        if {[llength $fields] != 11} {
            close $input
            close $output
            error "Invalid pin database row with [llength $fields] fields: $line"
        }
        lassign $fields group port pin direction vccio standard drive clock_period mode description manual_table
        if {![enabled_group $group]} {
            continue
        }
        if {$mode ne "gpio"} {
            close $input
            close $output
            error "Pin group '$group' requires vendor IP/configuration handling and cannot be emitted as GPIO constraints."
        }
        if {[dict exists $used_pins $pin]} {
            set previous [dict get $used_pins $pin]
            close $input
            close $output
            error "Enabled pin groups conflict on package pin $pin: $previous and $port"
        }
        dict set used_pins $pin $port

        if {$clock_period ne ""} {
            set half [expr {double($clock_period) / 2.0}]
            puts $output "create_clock -name {$port} \[get_ports {$port}\] -period {$clock_period} -waveform {0 $half}"
        }
        puts $output "define_attribute {p:$port} {PAP_IO_DIRECTION} {$direction}"
        puts $output "define_attribute {p:$port} {PAP_IO_LOC} {$pin}"
        if {$vccio ne ""} {
            puts $output "define_attribute {p:$port} {PAP_IO_VCCIO} {$vccio}"
        }
        if {$standard ne ""} {
            puts $output "define_attribute {p:$port} {PAP_IO_STANDARD} {$standard}"
        }
        if {$drive ne "" && $direction eq "Output"} {
            puts $output "define_attribute {p:$port} {PAP_IO_DRIVE} {$drive}"
        }
        puts $output ""
        incr count
    }
    close $input
    close $output
    if {$count == 0} {
        error "No GPIO constraints were generated; check enabled_pin_groups in config.tcl."
    }
    puts "CONSTRAINT: generated=$out_path ports=$count"
    return $out_path
}

proc add_project_inputs {repo_root} {
    set rtl_files [configured_files $repo_root rtl_sources rtl {*.v *.sv *.vhd *.vhdl}]
    if {[llength $rtl_files] == 0} {
        error "No design files found under rtl/."
    }
    foreach path $rtl_files {
        add_design $path
    }
    set constraint [generate_active_constraint $repo_root]
    add_constraint $constraint
    set sim_files [configured_files $repo_root sim_sources sim {*.v *.sv *.vhd *.vhdl}]
    foreach path $sim_files {
        add_simulation $path
    }
    puts "INPUTS: rtl=[llength $rtl_files] sim=[llength $sim_files] constraint=$constraint"
}

proc run_compile {} {
    compile -force_to_run -top_module [cfg top_name] -system_verilog
    puts "MILESTONE: compile_complete"
}

proc run_synth {} {
    run_compile
    synthesize -force_to_run -ads -frequency [cfg synth_frequency]
    puts "MILESTONE: synthesis_complete"
}

proc run_pnr {} {
    run_synth
    dev_map -force_to_run -detail
    puts "MILESTONE: device_map_complete"
    pnr -force_to_run -report_timing
    puts "MILESTONE: pnr_complete"
}

proc run_timing {} {
    run_pnr
    report_timing -force_to_run -delay_type max -nworst 5 -max_path 50 -report_io_datasheet
    puts "MILESTONE: timing_complete"
}

proc run_bitstream {} {
    run_timing
    gen_netlist -force_to_run -sdf_annotate TRUE
    puts "MILESTONE: netlist_complete"
    gen_bit_stream -force_to_run -create_bit_file TRUE -create_bin_file -compress_bitstream [cfg compress_bitstream] -optimize_compress [cfg optimize_compress] -master_configuration_clock_frequency [cfg master_configuration_clock_frequency]
    puts "MILESTONE: bitstream_complete"
}

proc main {} {
    global repo_root env
    set step "all"
    if {[info exists env(PDS_STEP)] && [string trim $env(PDS_STEP)] ne ""} {
        set step [string tolower [string trim $env(PDS_STEP)]]
    }
    puts "FLOW: step=$step project=[cfg project_name] part=[cfg family]/[cfg device]/[cfg speedgrade]/[cfg package]"

    add_project_inputs $repo_root

    switch -- $step {
        check { }
        compile { run_compile }
        synth { run_synth }
        pnr { run_pnr }
        timing { run_timing }
        all { run_bitstream }
        default { error "Unknown PDS step '$step'." }
    }
    puts "SUCCESS: PDS step '$step' completed."
    exit 0
}

if {[catch {main} message options]} {
    puts stderr "ERROR: $message"
    if {[dict exists $options -errorinfo]} {
        puts stderr "DETAIL: [dict get $options -errorinfo]"
    }
    exit 1
}

if {![info exists env(MES50HP_TEMPLATE_ROOT)] || [string trim $env(MES50HP_TEMPLATE_ROOT)] eq ""} {
    error "MES50HP_TEMPLATE_ROOT is not set."
}
set repo_root [file normalize $env(MES50HP_TEMPLATE_ROOT)]
source [file join $repo_root config.tcl]
set_arch -family $template_config(family) -device $template_config(device) -speedgrade $template_config(speedgrade) -package $template_config(package)
puts "SUCCESS: PDS project bootstrap completed."

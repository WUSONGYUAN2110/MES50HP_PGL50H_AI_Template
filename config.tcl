set template_config(project_name) "AAA_Template"
set template_config(top_name)     "TOP_MODULE"
set template_config(default_tb)  "TESTBENCH_MODULE"
set template_config(default_sim_time) "run -all"
set template_config(family)      "Logos"
set template_config(device)      "PGL50H"
set template_config(speedgrade)  "-6"
set template_config(package)     "FBG484"
set template_config(synth_frequency) 50
set template_config(compress_bitstream) TRUE
set template_config(optimize_compress) TRUE
set template_config(master_configuration_clock_frequency) "25M"
set template_config(enabled_pin_groups) {clock_50m keys leds}
set template_config(rtl_sources) {}
set template_config(sim_sources) {}
set template_config(include_dirs) {rtl}
set template_config(allowed_unconstrained_ports) {
    user_key[0] user_key[1] user_key[2] user_key[3]
    user_key[4] user_key[5] user_key[6] user_key[7]
    user_led[0] user_led[1] user_led[2] user_led[3]
    user_led[4] user_led[5] user_led[6] user_led[7]
}
set template_config(flash_boot_wait_ms) 2000

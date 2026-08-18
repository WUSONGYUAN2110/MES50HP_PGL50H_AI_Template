set connected 0
if {[catch {
    set flashfile [file normalize $env(FLASH_FILE)]
    cfg_connect -ip $env(JTAG_IP) -port $env(JTAG_PORT)
    set connected 1
    cfg_set_cable_property -index 0 -freq 1MHz
    cfg_scan_chain
    cfg_jtag_flash_scan_device -device_index $env(DEVICE_INDEX)
    cfg_jtag_flash_assign_file -file $flashfile -device_index $env(DEVICE_INDEX)
    cfg_jtag_flash_erase -device_index $env(DEVICE_INDEX)
    cfg_jtag_flash_program -device_index $env(DEVICE_INDEX)
    cfg_jtag_flash_verify -device_index $env(DEVICE_INDEX)
    puts "BOOT_CHECK_BEGIN"
    cfg_reset_fpga -device_index $env(DEVICE_INDEX)
    after $env(BOOT_WAIT_MS)
    cfg_scan_chain
    puts "BOOT_CHECK_END"
    cfg_disconnect
    set connected 0
    puts "SUCCESS: $flashfile"
} message]} {
    if {$connected} { catch {cfg_disconnect} }
    puts stderr "ERROR: $message"
    exit 1
}
exit 0

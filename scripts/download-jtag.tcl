set connected 0
if {[catch {
    set bitfile [file normalize $env(SBIT_FILE)]
    cfg_connect -ip $env(JTAG_IP) -port $env(JTAG_PORT)
    set connected 1
    cfg_scan_chain
    cfg_assign_file -file $bitfile -device_index $env(DEVICE_INDEX)
    cfg_program -device_index $env(DEVICE_INDEX)
    cfg_disconnect
    set connected 0
    puts "SUCCESS: $bitfile"
} message]} {
    if {$connected} { catch {cfg_disconnect} }
    puts stderr "ERROR: $message"
    exit 1
}
exit 0

# tb_top_control_lock 스냅샷의 실제 신호를 VCD로 내보낸다.
# XSim 실행 디렉터리는 verify_step11.py가 출력한 결과 디렉터리를 사용한다.
set output_path [file join [pwd] control_lock_full.vcd]
if {[info exists ::env(LOCK_VCD_PATH)]} {
    set output_path [file normalize $::env(LOCK_VCD_PATH)]
}
set signal_names {
    /tb_top_control_lock/clk
    /tb_top_control_lock/lock_switch
    /tb_top_control_lock/buttons
    /tb_top_control_lock/dut/locked
    /tb_top_control_lock/dut/u_lock/r_was_locked
    /tb_top_control_lock/dut/button_pulse
    /tb_top_control_lock/dut/control_buttons
    /tb_top_control_lock/dut/cook_state
    /tb_top_control_lock/motor_pwm
}
set objects {}
foreach name $signal_names {
    set object [get_objects $name]
    if {[llength $object] != 1} {error "Required waveform signal missing: $name"}
    lappend objects {*}$object
}
open_vcd $output_path
log_vcd $objects
run all
close_vcd
puts "Waveform VCD: $output_path"
quit

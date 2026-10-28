# 원본 XPR의 소스 등록과 선택된 Top을 읽기 전용으로 검사한다.
set repo_root [file normalize [file join [file dirname [info script]] ..]]
if {[info exists ::env(VIVADO_BOARD_REPO)]} {
    set_param board.repoPaths [list [file normalize $::env(VIVADO_BOARD_REPO)]]
}
open_project -read_only [file join $repo_root fpga-microwave-oven.xpr]
if {[get_property PART [current_project]] ne "xc7a35tcpg236-1"} {
    error "Unexpected FPGA part"
}
foreach {fileset required_names} {
    sources_1 {reset_synchronizer tick_generator btn_debouncer rotary_decoder input_frontend microwave_controller fnd_scanner display_controller sound_controller servo_controller door_controller motor_controller top_microwave_oven}
    sim_1 {tb_input_frontend tb_timebase tb_microwave_controller tb_input_controller tb_display_controller tb_controller_display tb_sound_controller tb_display_sound tb_servo_controller tb_door_controller tb_door_control tb_motor_controller tb_motor_control tb_top_microwave_oven}
} {
    if {[get_property TOP [get_filesets $fileset]] ni $required_names} {
        error "Top is not one of the registered STEP 4..10 modules for $fileset"
    }
    set source_files [get_files -of_objects [get_filesets $fileset] -filter {FILE_TYPE == Verilog}]
    foreach name $required_names {
        set matching [get_files -quiet -of_objects [get_filesets $fileset] */${name}.v]
        if {[llength $matching] != 1} {
            error "Required file missing or duplicated: ${name}.v"
        }
    }
    foreach source_file $source_files {
        if {![file exists [get_property NAME $source_file]]} {
            error "Missing file: $source_file"
        }
    }
}
close_project
puts "PASS: read-only XPR registration check (13 RTL, 14 TB; board Top registered)"

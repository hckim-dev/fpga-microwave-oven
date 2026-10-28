# 저장소 상대 경로로 보드 프로젝트를 재생성한다.
set repo_root [file normalize [file join [file dirname [info script]] ..]]
set output_dir [file join $repo_root build vivado_step11]
# 기존 생성 프로젝트를 덮어쓰지 않는다.
if {[file exists [file join $output_dir microwave_step11.xpr]]} {
    error "Project already exists: $output_dir. Open it or choose another output directory."
}
create_project microwave_step11 $output_dir -part xc7a35tcpg236-1
set rtl_dir [file join $repo_root fpga-microwave-oven.srcs sources_1 new]
foreach name {reset_synchronizer tick_generator btn_debouncer rotary_decoder input_frontend microwave_controller fnd_scanner display_controller sound_controller servo_controller door_controller motor_controller control_lock top_microwave_oven} {
    add_files -fileset sources_1 -norecurse [file join $rtl_dir ${name}.v]
}
set test_dir [file join $repo_root fpga-microwave-oven.srcs sim_1 new]
foreach name {tb_input_frontend tb_timebase tb_microwave_controller tb_input_controller tb_display_controller tb_controller_display tb_sound_controller tb_display_sound tb_servo_controller tb_door_controller tb_door_control tb_motor_controller tb_motor_control tb_top_microwave_oven tb_control_lock tb_top_control_lock} {
    add_files -fileset sim_1 -norecurse [file join $test_dir ${name}.v]
}
set_property target_language Verilog [current_project]
add_files -fileset constrs_1 -norecurse [file join $repo_root fpga-microwave-oven.srcs constrs_1 new microwave_basys3.xdc]
set_property top top_microwave_oven [get_filesets sources_1]
set_property top tb_top_control_lock [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PASS: created STEP 11 board project: $output_dir"

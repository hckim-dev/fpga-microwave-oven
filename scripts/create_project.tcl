# Recreate the current STEP 9 simulation project without local machine paths.
set repo_root [file normalize [file join [file dirname [info script]] ..]]
set output_dir [file join $repo_root build vivado_step9]
# Do not overwrite an existing generated project.
if {[file exists [file join $output_dir microwave_step9.xpr]]} {
    error "Project already exists: $output_dir. Open it or choose another output directory."
}
create_project microwave_step9 $output_dir -part xc7a35tcpg236-1
set rtl_dir [file join $repo_root fpga-microwave-oven.srcs sources_1 new]
foreach name {reset_synchronizer tick_generator btn_debouncer rotary_decoder input_frontend microwave_controller fnd_scanner display_controller sound_controller servo_controller door_controller motor_controller} {
    add_files -fileset sources_1 -norecurse [file join $rtl_dir ${name}.v]
}
set test_dir [file join $repo_root fpga-microwave-oven.srcs sim_1 new]
foreach name {tb_input_frontend tb_timebase tb_microwave_controller tb_input_controller tb_display_controller tb_controller_display tb_sound_controller tb_display_sound tb_servo_controller tb_door_controller tb_door_control tb_motor_controller tb_motor_control} {
    add_files -fileset sim_1 -norecurse [file join $test_dir ${name}.v]
}
set_property target_language Verilog [current_project]
set_property top motor_controller [get_filesets sources_1]
set_property top tb_motor_control [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PASS: created STEP 9 simulation project: $output_dir"

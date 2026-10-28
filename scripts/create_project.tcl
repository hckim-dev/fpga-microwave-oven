# Recreate the current STEP 4 simulation project without local machine paths.
set repo_root [file normalize [file join [file dirname [info script]] ..]]
set output_dir [file join $repo_root build vivado_step4]
# Do not overwrite an existing generated project.
if {[file exists [file join $output_dir microwave_step4.xpr]]} {
    error "Project already exists: $output_dir. Open it or choose another output directory."
}
create_project microwave_step4 $output_dir -part xc7a35tcpg236-1
set rtl_dir [file join $repo_root fpga-microwave-oven.srcs sources_1 new]
foreach name {reset_synchronizer tick_generator btn_debouncer rotary_decoder input_frontend} {
    add_files -fileset sources_1 -norecurse [file join $rtl_dir ${name}.v]
}
set test_dir [file join $repo_root fpga-microwave-oven.srcs sim_1 new]
foreach name {tb_input_frontend tb_timebase} {
    add_files -fileset sim_1 -norecurse [file join $test_dir ${name}.v]
}
set_property target_language Verilog [current_project]
set_property top input_frontend [get_filesets sources_1]
set_property top tb_input_frontend [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PASS: created STEP 4 simulation project: $output_dir"

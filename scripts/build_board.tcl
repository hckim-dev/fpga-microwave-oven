# Run with: vivado -mode batch -source scripts/build_board.tcl
# Isolated non-project build; does not modify the user's XPR or program hardware.
set repo_root [file normalize [file join [file dirname [info script]] ..]]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set output_dir [file join $repo_root build board ${stamp}_[pid]]
file mkdir $output_dir
# Keep ancillary Vivado files (for example clockInfo.txt) inside this build too.
cd $output_dir
puts "Board build output: $output_dir"
puts "Tool: [version -short]"
set rtl_dir [file join $repo_root fpga-microwave-oven.srcs sources_1 new]
read_verilog [lsort [glob [file join $rtl_dir *.v]]]
read_xdc [file join $repo_root fpga-microwave-oven.srcs constrs_1 new microwave_basys3.xdc]
synth_design -top top_microwave_oven -part xc7a35tcpg236-1
report_utilization -file [file join $output_dir utilization_synth.rpt]
report_cdc -details -file [file join $output_dir cdc.rpt]
opt_design
place_design
phys_opt_design
route_design
report_route_status -file [file join $output_dir route_status.rpt]
report_utilization -file [file join $output_dir utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output_dir timing_summary.rpt]
report_drc -file [file join $output_dir drc.rpt]
report_methodology -file [file join $output_dir methodology.rpt]
report_exceptions -file [file join $output_dir exceptions.rpt]
write_checkpoint [file join $output_dir microwave_routed.dcp]
set setup_path [get_timing_paths -delay_type max -max_paths 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1]
if {[llength $setup_path] == 0 || [llength $hold_path] == 0} {
    error "Timing paths absent"
}
set setup_slack [get_property SLACK $setup_path]
set hold_slack [get_property SLACK $hold_path]
if {$setup_slack < 0 || $hold_slack < 0} {
    error "Internal timing failed: setup=$setup_slack ns, hold=$hold_slack ns; inspect $output_dir"
}
write_bitstream [file join $output_dir microwave.bit]
set summary [open [file join $output_dir summary.txt] w]
puts $summary "Vivado [version -short]; xc7a35tcpg236-1; 100 MHz"
puts $summary "Internal setup slack: $setup_slack ns; hold slack: $hold_slack ns"
puts $summary "Asynchronous board input arrival paths excepted; external output timing unspecified."
puts $summary "Reports must be reviewed; no board programming or physical confirmation."
close $summary
puts "PASS: board build; internal setup=$setup_slack ns hold=$hold_slack ns; reports/bitstream: $output_dir"

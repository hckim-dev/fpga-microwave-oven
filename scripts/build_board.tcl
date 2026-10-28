# 실행: vivado -mode batch -source scripts/build_board.tcl
# 원본 XPR 수정이나 보드 기록 없이 별도 디렉터리에서 빌드한다.
set repo_root [file normalize [file join [file dirname [info script]] ..]]
set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set output_dir [file join $repo_root build board ${stamp}_[pid]]
file mkdir $output_dir
# clockInfo.txt 등 Vivado 부수 산출물도 빌드 디렉터리에 저장한다.
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
set timing_checks [check_timing -return_string]
set check_file [open [file join $output_dir check_timing.rpt] w]
puts $check_file $timing_checks
close $check_file
# 외부 I/O delay 경고와 내부 제약 누락을 구분한다.
foreach name {no_clock constant_clock unconstrained_internal_endpoints multiple_clock loops latch_loops} {
    set pattern [format {checking %s \(([0-9]+)\)} $name]
    if {![regexp $pattern $timing_checks -> count]} {
        error "Timing check result missing: $name"
    }
    if {$count != 0} {error "Timing check failed: $name=$count; inspect $output_dir"}
}
set pulse_report [report_pulse_width -return_string]
set pulse_file [open [file join $output_dir pulse_width.rpt] w]
puts $pulse_file $pulse_report
close $pulse_file
set pulse_slack ""
foreach line [split $pulse_report \n] {
    if {[regexp {^(Min Period|Low Pulse Width|High Pulse Width)\s} [string trim $line]]} {
        set slack [lindex [regexp -all -inline {\S+} $line] end-2]
        if {![string is double -strict $slack]} {error "Unrecognized pulse width result: $line"}
        if {$pulse_slack eq "" || $slack < $pulse_slack} {set pulse_slack $slack}
    }
}
if {$pulse_slack eq "" || $pulse_slack < 0} {
    error "Pulse width check failed: slack=$pulse_slack ns; inspect $output_dir"
}
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
puts $summary "Minimum clock pulse/period slack: $pulse_slack ns; internal constraint checks passed"
puts $summary "Asynchronous board input arrival paths excepted; external output timing unspecified."
puts $summary "Reports must be reviewed; no board programming or physical confirmation."
close $summary
puts "PASS: board build; internal setup=$setup_slack ns hold=$hold_slack ns; reports/bitstream: $output_dir"

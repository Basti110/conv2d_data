# Config
set processor [lindex [::iss::processors] 0]
set appdir "/home/basti/data/hdd/test/cnn_asip/core/apps/benchmark_conv2d/runs/ssd_test/resnet18_l1_b0_conv1"
set appname "benchmark_conv2d"
set program "Release/$appname"
set mem_file "chess_reports/$appname.mem"
# In case no RTL-simulation is planned, RCD-dumping is not neccessary
set generate_rcd 0
set rcd_file "/scratch/ssd_test____resnet18_l1_b0_conv1.iss.rcd"

# Create ISS
::iss::create $processor iss

# Load program 
iss program load $program \
    -do_not_set_entry_pc 1\
    -dwarf2 \
    -cycle_count_breakpoints \
    -disassemble \
    -sourcepath {.}

# Map application data directly into DM_Glob
source "data/conv2d_iss_init.tcl"

# Set outputs for verification
if { $generate_rcd == 1 } {
    iss fileoutput go -file $rcd_file
}
iss fileoutput chess_report set -file $mem_file

# Turn on all the profiling options
iss profile set -control source
iss profile set_active 1
iss profile storages_set_active 1
iss profile reset
iss profile storages_reset

# Simulate until first chess_stop()
set rtval [catch { iss step -1 } msg]
puts $msg

# Read out cycle-count for DRAM power simulation
set cycle_count [ lindex [iss info count -cycle] 0 ]
puts "Comp cycle count : $cycle_count"
set cf [open "$program.comp_cycle_count" w]
puts $cf $cycle_count
close $cf

# Run until end of application
set rtval [catch { iss step -1 } msg]
puts $msg

# Print cycle count
set cycle_count [ lindex [iss info count -cycle] 0 ]
puts "Total cycle count : $cycle_count"
set cf [open "$program.cycle_count" w]
puts $cf $cycle_count
close $cf

# Generate reports:
#   Readable reports
::iss profile save "profile_results/instruction_report.txt" -type function_details -user_cycle_count Off -source_refs Off -asm_width 50 -asm_remove_white_space On -hide_instruction_bits Off -xml 0
::iss profile save "profile_results/functional_unit_report.txt" -type functional_units -xml Off -function_details Off
::iss profile storage_access_save -file "profile_results/storage_report.txt" -function_details Off -field_details Off -function_summary Off -data "" -cycle_count 0 -instruction_count 0 -hide_instruction_bits Off
::iss profile save "profile_results/primitive_reports.txt" -type primitive_operations -xml Off -function_details Off

#   XML reports
::iss profile save "profile_results/instruction_report.xml" -type function_details -user_cycle_count Off -source_refs Off -asm_width 50 -asm_remove_white_space On -hide_instruction_bits Off -xml 1
::iss profile save "profile_results/functional_unit_report.xml" -type functional_units -xml On -function_details Off
::iss profile storage_access_save -file "profile_results/storage_report.xml" -function_details Off -field_details Off -function_summary On -data "" -cycle_count 0 -instruction_count 0 -hide_instruction_bits Off -xml 1
::iss profile save "profile_results/primitive_report.xml" -type primitive_operations -xml On -function_details Off

iss close

exit
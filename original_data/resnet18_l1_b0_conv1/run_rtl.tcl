set hdlprx tmicro_vlog
# read hdlprx from HDLPRX env variable, if exists
catch { set hdlprx $env(HDLPRX) }

set appdir "."
# read appdir from APPDIR env variable, if exists
catch { set appdir $env(APPDIR) }

set gen_rtl_dump   0
set rtl_dump_scope ""
set rtl_dump_file  "dump.fsdb"
catch { set gen_rtl_dump   $env(GEN_RTL_DUMP) }
catch { set rtl_dump_scope $env(RTL_DUMP_SCOPE) }
catch { set rtl_dump_file  $env(RTL_DUMP_FILE) }

set rcd_filename "/scratch/ssd_test____resnet18_l1_b0_conv1.rtl.rcd"

set appname "data"
# read appname from APP env variable, if exists
catch { set appname $env(APP) }
puts "** Info: Using hdlprx='$hdlprx', appdir='$appdir', appname='$appname'"

# generate appname.cfg
set f_appname [open "appname.cfg" w]
puts $f_appname "$appdir/$appname"
close $f_appname

# generate rcdname.cfg
set f_rcdname [open "rcdname.cfg" w]
puts $f_rcdname $rcd_filename
close $f_rcdname
# delete potential existing rcd file
file delete $rcd_filename

# now read the cycle count
set num_cycles 0
if {![file exists "$appdir/$appname.cycle_count"]} {
    puts "** Error: File '$appdir/$appname.cycle_count' not found!"
    finish
}
puts "** Info: Reading cycle_count from file '$appdir/$appname.comp_cycle_count'"
set f_cycle_count [open "$appdir/$appname.comp_cycle_count" r]
gets $f_cycle_count line
close $f_cycle_count
set num_cycles [expr $line]

# set stop conditions
force /test_bench/inst_tmicro/inst_regfile_others/inst_reg_PC/max_cycles $num_cycles

if {[info exists env(GEN_RTL_SAIF)]} {
    puts "Tracing switching activity information..."
    power -gate_level rtl_on mda
    power  /test_bench/inst_tmicro
    power -enable
}

if { $gen_rtl_dump == 1 } {
    set dump_fid [dump -file $rtl_dump_file -type FSDB]
    dump -deltaCycle off
    dump -enable
    dump -glitch on

    if { $rtl_dump_scope == "all" } {
        puts "** Info: Dumping all activity into file $rtl_dump_file ..."
        dump -add test_bench.inst_tmicro -fid $dump_fid -aggregates -depth 0

    } else {
        puts "** Info: Dumping only OPCode relevant activity into file $rtl_dump_file ..."
        dump -add test_bench.inst_tmicro.clock -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.reset -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.io_eDM_chip_select_p1_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.io_eDM_chip_select_p2_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.io_eDM_write_enable_p1_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.io_eDM_write_enable_p2_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_core_mem_DM.inst_io_eDM.io_eDM_chip_select_p1_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_core_mem_DM.inst_io_eDM.io_eDM_chip_select_p2_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_core_mem_DM.inst_io_eDM.io_eDM_write_enable_p1_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_core_mem_DM.inst_io_eDM.io_eDM_write_enable_p2_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.edmvg_st_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.edmvg_ld_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_0.inst_vector_lane_0_decoder.vector_lane_0_decoder_E4_enabling_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_1.inst_vector_lane_1_decoder.vector_lane_1_decoder_E4_enabling_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_2.inst_vector_lane_2_decoder.vector_lane_2_decoder_E4_enabling_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_3.inst_vector_lane_3_decoder.vector_lane_3_decoder_E4_enabling_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_0.inst_vector_lane_0_decoder.vector_lane_0_decoder_E6_enabling_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_1.inst_vector_lane_1_decoder.vector_lane_1_decoder_E6_enabling_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_2.inst_vector_lane_2_decoder.vector_lane_2_decoder_E6_enabling_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_3.inst_vector_lane_3_decoder.vector_lane_3_decoder_E6_enabling_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_0.inst_vector_lane_0_pipes.inst_pipe_vlane0_e3_vgrd_pipe.vlane0_e3_vgrd_pipe_r_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_1.inst_vector_lane_1_pipes.inst_pipe_vlane1_e3_vgrd_pipe.vlane1_e3_vgrd_pipe_r_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_2.inst_vector_lane_2_pipes.inst_pipe_vlane2_e3_vgrd_pipe.vlane2_e3_vgrd_pipe_r_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_3.inst_vector_lane_3_pipes.inst_pipe_vlane3_e3_vgrd_pipe.vlane3_e3_vgrd_pipe_r_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_0.inst_vector_lane_0_pipes.inst_pipe_vlane0_e5_vgrd_pipe.vlane0_e5_vgrd_pipe_r_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_1.inst_vector_lane_1_pipes.inst_pipe_vlane1_e5_vgrd_pipe.vlane1_e5_vgrd_pipe_r_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_2.inst_vector_lane_2_pipes.inst_pipe_vlane2_e5_vgrd_pipe.vlane2_e5_vgrd_pipe_r_out -fid $dump_fid -depth 1
        dump -add test_bench.inst_tmicro.inst_vector_lane_3.inst_vector_lane_3_pipes.inst_pipe_vlane3_e5_vgrd_pipe.vlane3_e5_vgrd_pipe_r_out -fid $dump_fid -depth 1
    }
}

# and run:
puts "** Info: Simulating $num_cycles cycles."
run

# run one additional ps to log changes of other regs:
run 1 ps

if { $gen_rtl_dump == 1 } {
    dump -disable -fid $dump_fid
    dump -flush $dump_fid
    dump -close
}

if {[info exists env(GEN_RTL_SAIF)]} {
    power -disable
    power -report $env(RTL_SAIF_FILE) 1e-12 inst_tmicro
}

# cleanup
file delete "appname.cfg"
file delete "rcdname.cfg"

finish
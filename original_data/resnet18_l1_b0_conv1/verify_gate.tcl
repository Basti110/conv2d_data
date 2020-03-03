source "$::env(PROJDIR)/gatesim/verify_gate_helpers.tcl"

# Note: We expect the range to be dumped for verification to
#       be specified as an environment variable.
catch { set TCL_VERIFY_INIT_SCRIPT $::env(TCL_VERIFY_INIT_SCRIPT) }
catch { set EXPECTED_RESULTS_FILE $::env(EXPECTED_RESULTS_FILE) }
catch { set RCD_DIR $::env(RCD_DIR) }
catch { set TIMING $::env(TIMING) }

# Here the start and end of the dump-range is set
source "$TCL_VERIFY_INIT_SCRIPT"

if {![info exists env(LEVEL)]} {
    puts "Simulation level (LEVEL) not specified! Exiting..."
    exit
} else {
    set LEVEL $::env(LEVEL)
}

if { $LEVEL == "layout" } {
    if {![info exists env(DENSITY)]} {
        puts "Layout density (DENSITY) not specified! Exiting..."
        exit
    } else {
        set DENSITY $::env(DENSITY)
    }

    set gatefile   "$RCD_DIR/netlist_sim.layout.c${TIMING}0_d${DENSITY}0.mem"
    set outfile    "$RCD_DIR/netlist_sim.layout.c${TIMING}0_d${DENSITY}0.diff"
} else {
    set gatefile   "$RCD_DIR/netlist_sim.gate.c${TIMING}0.mem"
    set outfile    "$RCD_DIR/netlist_sim.gate.c${TIMING}0.diff"
}

#puts [format "verify_gate $nativefile $gatefile $outfile 16336 %d" [expr 16336+3*16]]
verify_chess_report_vs_memory "DM_Glob" $EXPECTED_RESULTS_FILE $gatefile $outfile $DUMP_RANGE_START $DUMP_RANGE_END

finish
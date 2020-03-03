#!/bin/bash
#$ -cwd
#$ -o /home/basti/data/hdd/test/cnn_asip/core/apps/benchmark_conv2d/sge_logs/ssd_test____resnet18_l1_b0_conv1.log
#$ -j y
#$ -l h_vmem=8G
#$ -l num_proc=1
#$ -l vcs_mx=1
#$ -l h=belarus|bitbus|claus|druckguss|gonzalus|ionicus|kalyptus|kleinbus|linienbus|quintus|ritus|schampus|tetanus|ryzinus
#$ -R y
#$ -M basti@ice.rwth-aachen.de
#$ -N ssd_test____resnet18_l1_b0_conv1
#$ -m beas
#$ -b y


#############################################################
# Template parameters
#############################################################

projdir="/home/basti/data/hdd/test/cnn_asip/core"
sim_prefix=""
sim_model="tmicro_fpga"
do_rtlsim=0
do_netlistsim=0
do_rtl_pwrest=0
do_netlist_pwrest=0
rtl_pwrest_dumpstyle=SAIF
rtl_trace_opcodes=0
do_dramsim_power_est=1
dramsim_page_policy=open
dramsim_address_mapping_scheme=4
level="layout"
timing=1.80
density=0.70
clock=1.90
appdir="/home/basti/data/hdd/test/cnn_asip/core/apps/benchmark_conv2d/runs/ssd_test/resnet18_l1_b0_conv1"
technode="tsmc28"
syn_prefix=""
compile_params=""
regen_inputs=False
run_name="ssd_test____resnet18_l1_b0_conv1"
vsize="16"
vlanes="16"
keep_rtl_saif=0
keep_rtl_dump=0
keep_netlist_saif=0


#############################################################
# General config/setup
#############################################################

abspath=$(dirname $(readlink -f ${BASH_SOURCE[0]}))

appname="benchmark_conv2d"
tmpdir="/scratch"
dm_glob_logfile="${tmpdir}/${run_name}.log.eDMv_Glob"
dm_logfile="${tmpdir}/${run_name}.log.io_eDM_eM"
rtl_dump_file="${tmpdir}/${run_name}.fsdb"
rtl_saif_file="$tmpdir/${run_name}_rtl.saif"
netlist_saif_file=$tmpdir/${run_name}_${technode}_${level}_c${timing}.saif

# 100000 KByte/s = 100 MByte/s limit
rsync_max_bw=100000

# Source setup-script to load modules and get infos like e.g. memory-config
# Note: The setup.sh sets some environment variables based on the defined technode
#       and resets VSIZE and VLANES!
export TECHNODE=${technode}
source ${projdir}/setup.sh
export VSIZE=${vsize}
export VLANES=${vlanes}


# For some reason, PrimeTime likes to have trouble with the NFS, not finding the synthesis libraries and stuff
# As a quick fix, we just restart PrimeTime in case it threw errors and hope the NFS is ok by then.
# Here the maximal number of re-tries and the delay between retries can be specified.
pt_max_tries=5
retry_delay=600


#############################################################
# Helper functions
#############################################################

# Arguments:
# 1: Appdir
# 2: Config-Name
# 3: Exit-Code
function cleanup_and_exit {
    if [ $# -lt 3 ]; then
        echo "ERROR: cleanup_and_exit called with less than 3 arguments!"
    fi

    appdir=$1
    cfgname=$2
    exitcode=$3

    # Remove RCD files
    rm -f $tmpdir/${cfgname}*.rcd >& /dev/null

    # Compress logs, chess-reports and rcds
    gzip -f $appdir/logs/*.log >& /dev/null
    gzip -f $appdir/chess_reports/* >& /dev/null

    # Move memory-log for external memory to NFS
    # in case the simulation was successul
    if [ $exitcode == 0 ]; then
        gzip ${dm_glob_logfile}
        rsync -at --bwlimit=${rsync_max_bw} ${dm_glob_logfile}.gz $appdir/rcd/${appname}.log.eDMv_Glob.gz
        rm -f ${dm_glob_logfile}.gz

        gzip ${dm_logfile}
        rsync -at --bwlimit=${rsync_max_bw} ${dm_logfile}.gz $appdir/rcd/${appname}.log.io_eDM_eM.gz
        rm -f ${dm_logfile}.gz
    else
        rm -f ${dm_glob_logfile} ${dm_logfile}
    fi

    # Compress and copy SAIF files
    if [ "$keep_rtl_saif" == "1" ]; then
        gzip -f $tmpdir/${run_name}_rtl.saif
        rsync -at --bwlimit=${rsync_max_bw} $tmpdir/${run_name}_rtl.saif.gz $appdir/rcd/${run_name}_rtl.saif.gz
        rm -f $tmpdir/${run_name}_rtl.saif.gz
    fi

    if [ "$do_netlistsim" == "1" ] && [ "$keep_netlist_saif" == "1" ]; then
        gzip -f $netlist_saif_file
        rsync -at --bwlimit=${rsync_max_bw} ${netlist_saif_file}.gz $appdir/rcd/${run_name}_netlist.saif.gz
        rm -f ${netlist_saif_file}.gz
    fi

    # Remove all remaining SAIF, FSDB, VPD & VCD files
    rm -f $tmpdir/${run_name}*.saif $tmpdir/${run_name}*.fsdb $tmpdir/${run_name}*.vpd $tmpdir/${run_name}*.vcd >& /dev/null

    exit $exitcode
}


#############################################################
# Variable checks
#############################################################

if [ ${clock} == -1 ] ; then
    clock=$timing
fi

if [ "$sim_prefix" != "" ]; then
    sim_prefix="${sim_prefix}_"
fi

density_suffix=""
if [ "$level" == "layout" ]; then
    density_suffix="_d${density}"
fi

# Check if there´s enough disk-space in /scratch
diskspace_avail=`df -h $tmpdir | grep -oP '/dev/[a-z0-9]+( +)([0-9]+G)( +)([0-9]+G)( +)\K([0-9]+)'`
echo "NOTE: Available disk-space on ${tmpdir}: ${diskspace_avail} GB"

if [ "$diskspace_avail" -lt "50" ]; then
    echo "WARNING: There is less than 50GB of disk-space left on ${tmpdir} !"
fi


#############################################################
# RTL/Netlist Simulation Setup
#############################################################

if ! [ "$sim_model" == "fpga_board" ]; then
    rtlsim_cmd="${projdir}/hdl/$sim_model/simv +warn=noSTASKW_CO -ucli -do ${appdir}/run_rtl.tcl -licqueue +appname=Release/$appname +dm_glob_logfile=${dm_glob_logfile} +dm_logfile=${dm_logfile}"
fi

if [ $level == "gate" ] ; then
    gatesim_cmd="${projdir}/gatesim/${sim_prefix}vsize${vsize}_vlane${vlanes}_${technode}_c${timing}_clk${clock}/simv +warn=noSTASKW_CO -ucli -do ${projdir}/gatesim/run_sim_gate.tcl -licqueue +appname=Release/$appname"
else
    gatesim_cmd="${projdir}/layoutsim/${sim_prefix}vsize${vsize}_vlane${vlanes}_${technode}_c${timing}_clk${clock}_d${density}/simv +warn=noSTASKW_CO -ucli -do ${projdir}/layoutsim/run_sim_layout.tcl -licqueue +appname=Release/$appname"
fi

dram_power_rpt_dir="${appdir}/power_results/dramsim_power"
power_rpt_dir="${appdir}/power_results/${technode}_${level}_c${timing}_clk${clock}${density_suffix}"
power_rpt_dir_rtl="${appdir}/power_results/${technode}_${level}_c${timing}_clk${clock}${density_suffix}_rtl"


##################################################################

pushd $abspath >& /dev/null
set -eu


##################################################################
# Create required folders
##################################################################

if [ ! -d "chess_reports" ]; then
    mkdir chess_reports
fi

if [ ! -d "data" ]; then
    mkdir data
fi

if [ ! -d "logs" ]; then
    mkdir logs
fi

if [ ! -d "rcd" ]; then
    mkdir rcd
fi

if [ ! -d "${power_rpt_dir}" ]; then
    mkdir -p ${power_rpt_dir}
fi

if [ ! -d "${power_rpt_dir_rtl}" ]; then
    mkdir -p ${power_rpt_dir_rtl}
fi

if [ ! -d "profile_results" ]; then
    mkdir profile_results
fi


##################################################################
# Generate golden reference data
##################################################################
if [ ! -f data/conv2d_config.h ] || [ "$regen_inputs" == "true" ] || [ "$regen_inputs" == "True" ]; then
    echo "INFO: Generating input data..."

    python /home/basti/data/hdd/test/cnn_asip/core/apps/benchmark_conv2d/golden_ref/conv2d_ref.py \
        --outpath ${appdir}/data --configfile ${appdir}/config.yaml >& logs/gen_golden_ref.log

    # Check if Python vs TF was OK
    if grep -i "Verification SUCCEEDED" logs/gen_golden_ref.log &> /dev/null ; then
        echo "SUCCESS: Python vs. PyTorch matches."
    else
        echo "ERROR: Mismatches between python golden-reference and PyTorch"
        rm -f data/conv2d_config.h
        cleanup_and_exit $appdir $run_name 1
    fi

    # Check for possible warnings/errors given in python-output
    grep_res=$(true || egrep '(WARNING|ERROR)' logs/gen_golden_ref.log)
    if [ "$grep_res" != "" ]; then
        echo "$grep_res"
    fi
else
    echo "INFO: Using already existing input-data..."
fi


##################################################################
# Build & run & verify native execution
##################################################################

echo "INFO: Compiling and running native..."

if ! chessmk -C Native -D VERIFICATION_MODE_ON ${compile_params} $appname.prx >& logs/build_native.log ; then
    echo "ERROR: Building native failed!"
    cleanup_and_exit $appdir $run_name 1
fi

if ! chessmk -C Native -D VERIFICATION_MODE_ON ${compile_params} -S $appname.prx >& logs/run_native.log ; then
    echo "ERROR: Running native failed!"
    cleanup_and_exit $appdir $run_name 1
fi

if ! grep -i "Verification SUCCEEDED" logs/run_native.log &>/dev/null ; then
    echo "ERROR: Native execution has mismatches!"
    cleanup_and_exit $appdir $run_name 1
else
    echo "SUCCESS: Native execution matches expected values."
fi


##################################################################
# Build & run on ISS (+profiling)
##################################################################

echo "INFO: Compiling and running on Simulator (Cfg: Release)..."

if ! chessmk -C Release -D VERIFICATION_MODE_ON ${compile_params} $appname.prx >& logs/build_release.log ; then
    echo "ERROR: Building for ISS (Cfg: Release) failed!"
    cleanup_and_exit $appdir $run_name 1
fi


if ! chessmk -S -D VERIFICATION_MODE_ON ${compile_params} $appname.prx >& logs/run_release.log ; then
    echo "ERROR: Running on ISS failed!"
    cleanup_and_exit $appdir $run_name 1
else
    echo "SUCCESS: Running on ISS succeded."
fi

tclsh compare_chess_reports.tcl >& logs/run_chess_compare.log

if grep -i "diff" chess_reports/$appname.diff &>/dev/null ; then
    echo "ERROR: ISS vs Native has mismatches"
    cleanup_and_exit $appdir $run_name 1
else
    echo "SUCCESS: ISS vs Native matches"
fi


##################################################################
# Run & Verify RTL-level design
##################################################################

if [ ${do_rtlsim} == 0 ] ; then
    echo "INFO: Skipping RTL-level simulation due to do_rtlsim=${do_rtlsim}..."

else
    echo "INFO: Starting RTL-level simulation..."

    if ! chessmk +H -D VERIFICATION_MODE_ON ${compile_params} $appname.prx >& logs/gen_rtl_input.log ; then
        echo "ERROR: Generating RTL input failed!"
    fi

    # Copy the data file with data for the global memory (DDR=DM_Glob) to
    # the Release folder of the project
    cp -f data/conv2d.eDMv_Glob Release/$appname.esysDM

    # Note: The following exported variables are required by the RTL simulator
    export APP="$appname"
    export APPDIR="$appdir/Release"

    # Dump the entire hierarchy for later power estimation
    if [ "${do_rtl_pwrest}" == "1" ] && [ "$rtl_pwrest_dumpstyle" == "FSDB" ]; then
        export GEN_RTL_DUMP=1
        export RTL_DUMP_SCOPE="all"
        export RTL_DUMP_FILE=$rtl_dump_file

    # Generate a dump of only the relevant OPCode data to save disk-space
    elif [ "$rtl_trace_opcodes" == "1" ]; then
        export GEN_RTL_DUMP=1
        export RTL_DUMP_SCOPE="opcodes"
        export RTL_DUMP_FILE=$rtl_dump_file
    else
        export GEN_RTL_DUMP=0
    fi

    # Generate a SAIF file either for power-estimation or to keep it e.g. for synthesis
    if [ "$keep_rtl_saif" == "1" ] || ( [ "${do_rtl_pwrest}" == "1" ] && [ "$rtl_pwrest_dumpstyle" == "SAIF" ] ); then
        export GEN_RTL_SAIF=1
        export RTL_SAIF_FILE=$rtl_saif_file
    fi

    if ! ${rtlsim_cmd} &> logs/run_rtl.log ; then
        echo "ERROR: Running RTL failed!"
        cleanup_and_exit $appdir $run_name 1
    else
        echo "SUCCESS: Running RTL succeeded."
    fi

    # DRAMSim power estimation
    if [ ${do_dramsim_power_est} == 1 ] ; then
        echo "INFO: Starting DRAMSIM power estimation..."
        mkdir -p ${dram_power_rpt_dir}
        dram_max_cycle_count=$(cat Release/$appname.comp_cycle_count)
        python ${PROJDIR}/power_est/dram_power_est/dramsim_power_estimation_cnn_asip_app.py -c ${clock} \
                                                                                            -i $dm_glob_logfile \
                                                                                            -o ${dram_power_rpt_dir} \
                                                                                            -p ${dramsim_page_policy} \
                                                                                            -s ${dramsim_address_mapping_scheme} \
                                                                                            -m ${dram_max_cycle_count}
        gzip -f ${dram_power_rpt_dir}/mase_application_dramsim.trc &> /dev/null
        grep -hi 'Average Power' ${dram_power_rpt_dir}/dramsim_estimation_result.txt
    fi

    # Postprocessing of memory dumps
    python $projdir/bin/iss_memdump_postproc.py -i $tmpdir/$run_name.iss.rcd -o $tmpdir/$run_name.iss.postproc.rcd &> logs/iss_mem_postprocess.log
    python $projdir/bin/rtl_memdump_postproc.py -i $tmpdir/$run_name.rtl.rcd -o $tmpdir/$run_name.rtl.postproc.rcd &> logs/rtl_mem_postprocess.log

    # Delete un-processed logs so we dont waste more memory than required
    if [ -f $tmpdir/$run_name.iss.postproc.rcd ]; then
        rm -f $tmpdir/$run_name.iss.rcd
    fi
    if [ -f $tmpdir/$run_name.rtl.postproc.rcd ]; then
        rm -f $tmpdir/$run_name.rtl.rcd
    fi

    comp_cycle_count=$(cat Release/$appname.comp_cycle_count)
    if ! rcd_compare -c $comp_cycle_count $tmpdir/$run_name.iss.postproc.rcd $tmpdir/$run_name.rtl.postproc.rcd >& $tmpdir/${run_name}_compare_rtl.log ; then
        rtl_nr_mismatches=`grep -oP 'Total number of differences: \K([0-9]+)' $tmpdir/${run_name}_compare_rtl.log`
        echo "ERROR: RTL vs. ISS has ${rtl_nr_mismatches} mismatches"

        # Keep compressed compare-log for debugging
        gzip -f $tmpdir/${run_name}_compare_rtl.log
        rsync -at --bwlimit=${rsync_max_bw} $tmpdir/${run_name}_compare_rtl.log.gz rcd/compare_rtl.log.gz
        rm -f $tmpdir/${run_name}_compare_rtl.log

        cleanup_and_exit $appdir $run_name 1
    else
        echo "SUCCESS: RTL vs. ISS matches"

        # Delete compare-Log because it easily gets very large (>100MByte)
        rm $tmpdir/${run_name}_compare_rtl.log >& /dev/null
    fi

    if [ "${GEN_RTL_DUMP}" == "1" ]; then
        echo "INFO: Size of RTL dump-file is $(du -sh $rtl_dump_file)"

        if [ "$keep_rtl_dump" == "1" ]; then
            echo "INFO: Saving RTL dump-file"
            rsync -at --bwlimit=${rsync_max_bw} $rtl_dump_file $appdir/rcd/${run_name}.fsdb
        fi
    fi

    if [ "$rtl_trace_opcodes" == "1" ]; then
        echo "INFO: Starting FSDB to VCD conversion for OPCode traces..."

        rtl_simtime_ps=$(grep -oP '(?<=Time\: )([0-9]+)(?= ps)' logs/run_rtl.log)
        # The last 1ps is only to trigger the remaining reg-log tasks, but the simulation
        # is already stopped, thereby creating 'X'-values which are a problem for the
        # power model extraction processs
        rtl_simtime_ps=$(expr $rtl_simtime_ps - 1)

        # Convert FSDB to VCD and GZip the result
        fsdb2vcd $rtl_dump_file -o ${tmpdir}/${run_name}_opcodes.vcd -f $appdir/fsdb_extract_opcodes.tcl -et "${rtl_simtime_ps}ps" &> logs/fsdb2vcd.log
        gzip -f ${tmpdir}/${run_name}_opcodes.vcd
        

        echo "INFO: Starting Opcode trace extraction from VCD file"
        python ${projdir}/apps/power_model_calibration/extract_powerdata.py --vcd ${tmpdir}/${run_name}_opcodes.vcd.gz \
                                                                            --out $appdir/rcd/${appname}_opcode_trace.pkl \
                                                                            --instpath 'test_bench' \
                                                                            --vsize $vsize --vlanes $vlanes &> logs/extract_powerdata.log

        # Move compressed VCD from tmpdir to final storage
        rsync -at --bwlimit=${rsync_max_bw} ${tmpdir}/${run_name}_opcodes.vcd.gz $appdir/rcd/${appname}_opcodes.vcd.gz
        rm -f ${tmpdir}/${run_name}_opcodes.vcd.gz
    fi


    ##################################################################
    # RTL-Level Power Estimation
    ##################################################################

    if [ ${do_rtl_pwrest} == 0 ] ; then
        echo "INFO: Skipping RTL-level power estimation due to do_rtl_pwrest=${do_rtl_pwrest}..."
    else
        echo "INFO: Starting RTL-level power estimation..."

        export PT_PWREST_RTL=true
        export SYN_PREFIX=${syn_prefix}
        export REPORTS_DIR="${power_rpt_dir_rtl}"
        export TIMING=$timing
        export CLOCK=$clock
        export LEVEL=${level}
        export DENSITY=${density}
        if [ "$rtl_pwrest_dumpstyle" == "SAIF" ]; then
            export RTL_ACTIVITY_TYPE="saif"
            export ACTIVITY_FILE=$rtl_saif_file
        else
            export RTL_ACTIVITY_TYPE="fsdb"
            export ACTIVITY_FILE=$rtl_dump_file
        fi

        counter=1
        while [ "$counter" -le "$pt_max_tries" ]; do
            if ! pt_shell -file $projdir/power_est/rm_pt_scripts/pt.tcl &> logs/run_primetime_rtl.log ; then
                echo "ERROR: Power estimation for RTL-level failed!"
                cleanup_and_exit $appdir $run_name 1
            else
                if ! egrep -i '^error' logs/run_primetime_rtl.log &>/dev/null ; then
                    echo "SUCCESS: Power estimation for RTL succeeded."
                    break
                else
                    if [ "$counter" -lt "$pt_max_tries" ] && egrep -i 'Error: Cannot read .+ file' logs/run_primetime_rtl.log &>/dev/null ; then
                        echo "WARNING: Power estimation has trouble opening some files on NFS (see report-file: $appdir/logs/run_primetime_rtl.log)"
                        echo "         The script will retry power-estimation after a $retry_delay second delay..."
                        sleep $retry_delay
                    else
                        echo "ERROR: Power estimation has errors in report-file: $appdir/logs/run_primetime_rtl.log"
                        echo "### Start: First 10 errors ###"
                        egrep -m10 -i '^error' $appdir/logs/run_primetime_rtl.log
                        echo "### End: Errors ###"
                        cleanup_and_exit $appdir $run_name 1
                    fi
                fi
            fi

            let counter = counter + 1
        done

        export PT_PWREST_RTL=false

        # Compress the power-report files
        gzip -f $power_rpt_dir_rtl/*.* &>/dev/null

    fi # do_rtl_pwrest
fi # do_rtlsim


##################################################################
# Verify gate/layout-level design and measure power
##################################################################

if [ ${do_netlistsim} == 0 ] ; then
    echo "INFO: Exiting here due to do_netlistsim=${do_netlistsim}..."
    cleanup_and_exit $appdir $run_name 0
else
    echo "INFO: Starting verification and SAIF generation on ${level}-level..."
fi

# Recompile the simulation without verification mode on as chess_reports dont work
# on netlist-level and this would just increase the cycle-count
if ! chessmk -C Release ${compile_params} $appname.prx >& logs/compile_release_netlist.log ; then
    echo "ERROR: Compiling app for ${level}-level simulation failed!"
fi

if ! chessmk +H ${compile_params} $appname.prx >& logs/gen_netlist_input.log ; then
    echo "ERROR: Generating ${level}-level input failed!"
fi

export RCD_DIR="$appdir/rcd"
export TCL_VERIFY_INIT_SCRIPT="$appdir/data/conv2d_verify_init.tcl"
export EXPECTED_RESULTS_FILE="$appdir/logs/run_native.log"
export VERIFY_GATE_SCRIPT="$appdir/verify_gate.tcl"
export VERIFY_GATE=true
export TIMING=$timing
export CLOCK=$clock
if [ "$do_netlist_pwrest" == "1" ]; then
    export GEN_SAIF=true
fi
export LEVEL=${level}
export DENSITY=${density}
export ACTIVITY_FILE=$netlist_saif_file

if [ $level == "layout" ] ; then
    export VERIFY_LAYOUT="true"
fi

# In case the user specified a clock-period for the clock generator
if [ "$timing" != "$clock" ] ; then
    rm -f generics_override
    clk=$(echo "scale=0; (${clock} * 1)" | bc)
    echo "ASSIGN ${clk} test_bench_gate.clock_period"      >> generics_override
fi

# Generate input data for memories in required format
# Note: We do not use the chessmk command here, because we need to process the PM and DM data
#       in a specific way, which is done by our own Tcl script (read_elf_pm.tcl).
#read_elf -Ge +e -f hath -pPM=32 -mDM=16 -mDM_Glob=16 -o data $appdir/tmp/$run_name/Release/$appname
#read_elf -Ge +e -f hath -pPM=32 -mDM=16 -mDM_Glob=16 -o data -e $appdir/tmp/$run_name/Release/$appname -t ${projdir}/gatesim/read_elf_pm.tcl -Tmemory_name=PM

# Move the data file with data for the global memory (DDR=DM_Glob) to
# the Release folder of the project
cp -f data/conv2d.eDMv_Glob Release/$appname.eDMv_Glob

if ! ${gatesim_cmd} &> logs/run_netlist.log ; then
    echo "ERROR: Running ${level} failed (technode=${technode})!"
    cleanup_and_exit $appdir $run_name 1
fi

if ! grep -i "SUCCESS" logs/run_netlist.log &>/dev/null ; then
    echo "ERROR: ${level}-Level simulation does not match expected results from native model (technode=${technode})!"
    cleanup_and_exit $appdir $run_name 1
else
    echo "SUCCESS: Native simulation and ${level}-level simulation match (technode=${technode})."
fi


if [ ${do_netlist_pwrest} == 0 ] ; then
    echo "INFO: Exiting here due to do_netlist_pwrest=${do_netlist_pwrest}..."
    cleanup_and_exit $appdir $run_name 0
else
    printf "INFO: Starting PrimeTime PX to generate power reports...\n"
fi


export SYN_PREFIX=${syn_prefix}
export REPORTS_DIR="${power_rpt_dir}"

counter=1
while [ "$counter" -le "$pt_max_tries" ]; do
    if ! pt_shell -file $projdir/power_est/rm_pt_scripts/pt.tcl &> logs/run_primetime_netlist.log ; then
        echo "ERROR: Power estimation for ${level}-level failed (technode=${technode})!"
        cleanup_and_exit $appdir $run_name 1
    else
        if ! egrep -i '^error' logs/run_primetime_netlist.log &>/dev/null ; then
            echo "SUCCESS: Power estimation for ${level}-level succeeded (technode=${technode})."
            break
        else
            if [ "$counter" -lt "$pt_max_tries" ] && egrep -i 'Error: Cannot read .+ file' logs/run_primetime_netlist.log &>/dev/null ; then
                echo "WARNING: Power estimation has trouble opening some files on NFS (see report-file: $appdir/logs/run_primetime_netlist.log)"
                echo "         The script will retry power-estimation after a $retry_delay second delay..."
                sleep $retry_delay
            else
                echo "ERROR: Power estimation has errors in report-file: $appdir/logs/run_primetime_netlist.log"
                echo "### Start: First 10 errors ###"
                egrep -m10 -i '^error' $appdir/logs/run_primetime_netlist.log
                echo "### End: Errors ###"
                cleanup_and_exit $appdir $run_name 1
            fi
        fi
    fi

    let counter = counter + 1
done

# Compress the power-report files
gzip -f $power_rpt_dir/*.* &>/dev/null

##################################################################

cleanup_and_exit $appdir $run_name 0

popd &> /dev/null
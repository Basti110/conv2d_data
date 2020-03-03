set appname benchmark_conv2d
source /home/basti/data/hdd/test/cnn_asip/core/bin/verification_helpers.tcl
compare_chess_reports "logs/run_native.log" "chess_reports/$appname.mem" "chess_reports/$appname.diff" ;
exit 0
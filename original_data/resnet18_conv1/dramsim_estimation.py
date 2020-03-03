#! /usr/bin/python

# Call the power estimation script in the framework
import re
import os.path
import os
# ------- generate the profiling information -------

import subprocess
import shlex
# Read arguments
import sys, getopt


if __name__ == "__main__":
    bash_command = os.environ["PROJDIR"] + "/power_est/dram_power_est/dramsim_power_estimation_cnn_asip_app.py " + ' '.join(sys.argv[1:])
    #print(bash_command)
    process = subprocess.Popen(bash_command.split(), stdout=subprocess.PIPE)
    output, error = process.communicate()
    #print(output)
    #print(error)
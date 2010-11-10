#!/bin/bash

TRACEROOT=""
CURRENTTRACER="nop"
LATENCYENABLED=0
ENABLED=0
PID=-1

function usage () {
    cat <<-EOF
	Usage: $(basename $0) <tracer> [-p <pid>] [ -l] [ n of lines ]

	tracer: one of the tracers: 
        blk function_graph mmiotrace wakeup_rt wakeup irqsoff 
        function sched_switch 
	-l
	--latency: specify it to get the latency information on tracing
	       output
	-p
	--pid: specify a pid for the tracers that allow pid filtering
EOF
exit 10
} >&2

function do_error () {
    printf "$@"
    exit 10
} >&2

function find_debugfs () {
    DEBUGFS=$(mount -t debugfs | cut -d\  -f3)
    if [ ! -z $DEBUGFS ]
    then
        TRACEROOT="${DEBUGFS}/tracing"
    else
        do_error "You need the debugfs mounted somewhere\n"
    fi
}

function enable_tracing () {
    local ENABLERROR=0
    echo 1 > $TRACEROOT/tracing_enabled
    ENABLERROR=$(( ENABLERROR + $? ))
    echo $CURRENTTRACER > $TRACEROOT/current_tracer
    ENABLERROR=$(( ENABLERROR + $? ))
    if [ $LATENCYENABLED -eq 1 ]
    then
        echo "latency-format" > $TRACEROOT/trace_options
		ENABLERROR=$(( ENABLERROR + $? ))
    else
		echo "nolatency-format" > $TRACEROOT/trace_options
	fi
    if [ $CURRENTTRACER == "function" ]
    then
        sysctl kernel.ftrace_enabled=1
		ENABLERROR=$(( ENABLERROR + $? ))
    fi
	if [ $PID -ne -1 ]
	then
		echo $PID > $TRACEROOT/set_ftrace_pid
		ENABLERROR=$(( ENABLERROR + $? ))
	fi
    [ $ENABLERROR -ne 0 ] && do_error "Error enabling tracing\n"
	ENABLED=1
} 

function disable_tracing () {
	if [ $ENABLED -eq 0 ]
	then
		return
	fi
    local DISABLERROR=0
    echo 0 > $TRACEROOT/tracing_enabled
	DISABLERROR=$(( DISABLERROR + $? ))
    echo "nop" > $TRACEROOT/current_tracer
	DISABLERROR=$(( DISABLERROR + $? ))
	echo > $TRACEROOT/set_ftrace_pid
	DISABLERROR=$(( DISABLERROR + $? ))
	if [ $CURRENTTRACER == "function" ]
	then
		sysctl kernel.ftrace_enabled=0
	fi
    if [ $DISABLERROR -ne 0 ]
    then
        do_error "Something went wrong while disabling the tracing\n"
    else
		echo "Tracing disabled"
		ENABLED=0
	fi
}

function show_trace () {
	cat $TRACEROOT/trace_pipe
}

# Main
# Only starts if you're root
[ $(whoami) != 'root' ] && do_error "You must be root to enable tracing\n"

# Trap Ctrl+C to correctly disable the tracing
trap disable_tracing SIGINT

# Argument parsing
if (( $# < 1 ))
then
    usage
fi

while (( $# > 0 ))
do
    case $1 in
        function|blk|function_graph|mmiotrace|wakeup_rt|wakeup|irqsoff|function|sched_switch)
            CURRENTTRACER=$1
            shift
        ;;
        -l|--latency)
            LATENCYENABLED=1
            shift
        ;;
        -p|--pid) 
            PID=$2
            shift 2
        ;;
    esac
done

# Do the job
find_debugfs
enable_tracing
show_trace
disable_tracing

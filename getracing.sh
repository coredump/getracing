#!/bin/bash

TRACEROOT=""
CURRENTTRACER="nop"
LATENCYENABLED=0
LINESBEFOREHEADER=30

function usage () {
    cat <<-EOF
	Usage: $(basename $0) <tracer> [ --latency ] [ n of lines ]

	tracer: one of the tracers. Currently only 'function' works
	--latency: specify that to get the latency information on tracing
               output
	n of lines: number of lines before the header gets re-printed.
EOF
exit 10
}

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
    [ $(whoami) != 'root' ] && do_error "You must be root to enable tracing\n"
    echo 1 > $TRACEROOT/tracing_enabled
    local ENABLERROR=$?
    echo $CURRENTTRACER > $TRACEROOT/current_tracer
    local ENABLERROR=$?
    if [ $LATENCYENABLED -eq 1 ]
    then
        echo "latency-format" > $TRACEROOT/trace_options
        local ENABLERROR=$?
    fi
    [ $ENABLERROR -ne 0 ] && do_error "Error enabling tracing\n"
}

function disable_tracing () {
    echo 0 > $TRACEROOT/tracing_enabled
    local FIRST_TRY=$?
    echo "nop" > $TRACEROOT/current_tracer
    local SECOND_TRY=$?
    if [ $FIRST_TRY -ne 0 -a $SECOND_TRY -ne 0 ]
    then
        do_error "Something went wrong while disabling the tracing\n"
    fi
}

# Main

if (( $# < 1 ))
then
    usage
fi

while (( $# > 0 ))
do
    case $1 in
        function)
            CURRENTTRACER=$1
            shift
        ;;
        --latency)
            LATENCYENABLED=1
            shift
        ;;
        [0-9]*)
            LINESBEFOREHEADER=$1
            shift
        ;;
    esac
done

find_debugfs
enable_tracing
disable_tracing

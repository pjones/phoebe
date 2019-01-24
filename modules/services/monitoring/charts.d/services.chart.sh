#!/bin/bash
# Taken from: https://github.com/mo0nsniper/netdata/commit/157b6e04b1931f57f16433fae42e028c525bd5cb
# no need for shebang - this file is loaded from charts.d.plugin

# if this chart is called X.chart.sh, then all functions and global variables
# must start with X_

# _update_every is a special variable - it holds the number of seconds
# between the calls of the _update() function
services_update_every=2

# the priority is used to sort the charts on the dashboard
# 1 = the first chart
services_priority=60000

# global variables to store our collected data
# remember: they need to start with the module name example_
declare -a services_service
declare -a services_status

services_running=
services_dead=
services_exited=
services_failed=

services_get() {
	# do all the work to collect / calculate the values
	# for each dimension
	#
	# Remember:
	# 1. KEEP IT SIMPLE AND SHORT
	# 2. AVOID FORKS (avoid piping commands)
	# 3. AVOID CALLING TOO MANY EXTERNAL PROGRAMS
	# 4. USE LOCAL VARIABLES (global variables may overlap with other modules)

	declare -a services_line

	services_service=()
	services_status=()
	services_line=()

	services_running=0
	services_dead=0
	services_exited=0
	services_failed=0

	while read -a services_line ; do
		services_service+=(${services_line%.*})

		case ${services_line[3]} in
			running)	services_status+=("1") ; ((services_running++)) ;;
			dead)		services_status+=("-2"); ((services_dead++)) ;;
			exited)		services_status+=("-3"); ((services_exited++)) ;;
			failed)		services_status+=("-4"); ((services_failed++)) ;;
		esac
	done < <(systemctl --no-legend --no-pager --plain --state=loaded --all --type=service )

	# this should return:
	#  - 0 to send the data to netdata
	#  - 1 to report a failure to collect the data

	return 0
}

# _check is called once, to find out if this chart should be enabled or not
services_check() {
	# this should return:
	#  - 0 to enable the chart
	#  - 1 to disable the chart

	# check something
	require_cmd systemctl || return 1

	# check that we can collect data
	services_get || return 1

	return 0
}

# _create is called once, to create the charts
services_create() {

	cat <<EOF
CHART Services.summary '' "Summary: $((services_running + services_dead + services_exited + services_failed)) services" "Total" Summary summary stacked $((services_priority)) $services_update_every
DIMENSION running '' $services_running 1 1
DIMENSION dead '' $services_dead 1 1
DIMENSION exited '' $services_exited 1 1
DIMENSION failed '' $services_failed 1 1
EOF

	echo "CHART Services.status 'System services' 'Status of systemd services: 1=running -2=dead -3=exited -4=failed' 'Status' Services services line $((services_priority + 1)) $services_update_every"
	for ((i = 0; i < ${#services_service[@]}; i++)) do
		echo "DIMENSION ${services_service[$i]} '' absolute 1 1"
	done

	return 0
}

# _update is called continiously, to collect the values
services_update() {
	# the first argument to this function is the microseconds since last update
	# pass this parameter to the BEGIN statement (see bellow).

	services_get || return 1

	# write the result of the work.

	cat <<VALUESEOF
BEGIN Services.summary $1
SET running = $services_running
SET dead = $services_dead
SET exited = $services_exited
SET failed = $services_failed
END
VALUESEOF

	echo "BEGIN Services.status $1"
	for ((i = 0; i < ${#services_service[@]}; i++)) do
		echo "SET ${services_service[$i]} = ${services_status[$i]}"
	done
	echo "END"


	return 0
}

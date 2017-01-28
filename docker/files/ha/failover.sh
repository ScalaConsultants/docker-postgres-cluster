#!/bin/bash -e

if [ "$DEBUG" = "1" ]; then
  set -x
fi

failed_node=$1
new_master=$2
trigger_file=$3

is_recovery=$(psql -tnxc "select pg_is_in_recovery();" postgres | awk -F '|' '{ gsub(/ /, ""); print $2 }')
if [[ $failed_node = 1 && $is_recovery = "f" ]]; then
	exit 0
fi

# Create the trigger file.
ssh -T $new_master touch $trigger_file

exit 0

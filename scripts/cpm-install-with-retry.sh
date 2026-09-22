#!/bin/sh

log_file=$1
shift

attempt=1
attempts=${CPAN_CPM_RETRIES:-3}
delay=${CPAN_CPM_RETRY_DELAY:-30}
status=0

: > "$log_file"

while [ "$attempt" -le "$attempts" ]; do
  printf 'cpm install attempt %s/%s\n' "$attempt" "$attempts" >> "$log_file"
  "$@" >> "$log_file" 2>&1 && exit 0
  status=$?
  printf 'cpm install attempt %s/%s failed with exit code %s\n' "$attempt" "$attempts" "$status" >> "$log_file"
  if [ "$attempt" -lt "$attempts" ]; then
    printf 'retrying cpm install in %s seconds\n' "$delay" >> "$log_file"
    sleep "$delay"
  fi
  attempt=$((attempt + 1))
done

exit "$status"

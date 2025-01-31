#!/bin/bash

set -o errexit  # Exit on any command that returns a non-zero status
set -o nounset  # Treat unset variables as an error
set -o pipefail # Properly handle errors in piped commands

usage() {
 
    cat  <<EOF 
Usage: $0 -c <command> -d <destination> -j <num_jobs> <file1> <file2> ... <fileN>
    Example: $0 -c cp -d /backup/ -j 4 file1.txt file2.txt file3.txt
EOF
    exit 1
}

CORES=$(nproc)
num_jobs=$(( 2 * CORES))
command="cp"

while getopts "c:d:j:hv" opt; do
  case "$opt" in
    c) command="$OPTARG" ;;
    d) destination="$OPTARG" ;;
    h) usage ;;
    j) num_jobs="$OPTARG" ;;
    v) verbose=true ;;
    *) usage ;;
  esac
done

if ! [[ "$num_jobs" =~ ^[0-9]+$ ]]; then
  echo "Error: -j must be a positive integer."
  usage
fi

if [[ ! -d "$destination" ]]; then
  echo "Error: Destination '$destination' is not a directory."
  usage
fi

if ! command -v $command >/dev/null 2>&1; then
  echo "Error: Command '$command' not found."
  exit 1
fi

if [[  -z "$destination"  ]]; then
  echo "Error: Missing required arguments - destination path"
  usage
fi
shift $((OPTIND - 1))

if [[ $# -eq 0 ]]; then
  echo "Error: No files provided."
  usage
fi

parallel_jobs() {
  local max_jobs="$1"
  shift
  local job_count=0
  local pids=()

  for cmd in "$@"; do
    eval "$cmd" &
    pids+=($!)
    job_count=$((job_count + 1))
    if [ "${verbose:-false}" = true ]; then
        echo $cmd
    fi

    if [[ "$job_count" -ge "$max_jobs" ]]; then
      wait "${pids[@]}"
      job_count=0
      pids=()
    fi
  done

  wait "${pids[@]}"
}

commands=()
for file in "$@"; do
  commands+=("$command '$file' '$destination'")
done

parallel_jobs "$num_jobs" "${commands[@]}"

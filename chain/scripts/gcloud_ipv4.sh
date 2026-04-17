#!/usr/bin/env bash

set -euo pipefail

SDK_ROOT="${GCLOUD_SDK_ROOT:-$HOME/google-cloud-sdk}"
GCLOUD_PY="${SDK_ROOT}/lib/gcloud.py"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || true)}"

if [[ -z "${PYTHON_BIN}" ]]; then
  echo "python3 not found in PATH" >&2
  exit 1
fi

if [[ ! -f "${GCLOUD_PY}" ]]; then
  echo "gcloud SDK not found at: ${GCLOUD_PY}" >&2
  exit 1
fi

# Force IPv4 DNS resolution for gcloud subprocesses to avoid IPv6 timeout paths.
# Use -c (instead of stdin heredoc) so interactive commands can still read from TTY.
exec "${PYTHON_BIN}" -S -c '
import runpy
import socket
import sys

gcloud_py = sys.argv[1]
args = sys.argv[2:]
orig_getaddrinfo = socket.getaddrinfo

def ipv4_first(host, port, family=0, type=0, proto=0, flags=0):
    infos = orig_getaddrinfo(host, port, family, type, proto, flags)
    ipv4_infos = [i for i in infos if i[0] == socket.AF_INET]
    return ipv4_infos or infos

socket.getaddrinfo = ipv4_first
sys.argv = ["gcloud", *args]
runpy.run_path(gcloud_py, run_name="__main__")
' "${GCLOUD_PY}" "$@"

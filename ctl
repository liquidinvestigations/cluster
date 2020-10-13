#!/bin/bash -e
cd "$( dirname "${BASH_SOURCE[0]}" )"
exec ./cluster supervisorctl "$@"

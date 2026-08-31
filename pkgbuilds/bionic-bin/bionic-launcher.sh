#!/bin/sh

exec env BIONIC_SYSTEM_MANAGED_UPDATES=1 /opt/bionic/Bionic.AppImage "$@"

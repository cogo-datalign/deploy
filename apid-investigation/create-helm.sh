#!/usr/bin/env bash

ROOT=./leadalign
OUTDIR=${HOME}/src/deploy/apid-investigation/apid/

helmify -f ${ROOT} -r ${OUTDIR}
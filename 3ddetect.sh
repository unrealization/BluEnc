#!/bin/bash

#
# BluEnc - 3DDetect 0.9.0
#
# Detect a movie's 3D properties
#

INFILE=${1}

if [ ! -r "${INFILE}" ]; then
	echo "Cannot read ${INFILE}"
	exit -1
fi

FFPROBE=$(which ffprobe 2>/dev/null)

if [ "${FFPROBE}" == "" ]; then
	echo "ffprobe not found"
	exit -1
fi

TMPFILE=$(mktemp /tmp/3ddetect.XXXXXX)
${FFPROBE} -i ${INFILE} 2> ${TMPFILE}
STEREO3D=$(cat ${TMPFILE} | grep stereo3d | awk -F ': ' '{ print $2 }')
STEREOMODE=$(cat ${TMPFILE} | grep stereo_mode | awk -F ': ' '{ print $2 }')
rm ${TMPFILE}

echo "${STEREO3D}:${STEREOMODE}"
exit 0

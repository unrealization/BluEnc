#!/bin/bash

#
# BluRip - CropDetect 1.0.0
#
# Detect the crop size for movies
#

INFILE=${1}

if [ ! -r "${INFILE}" ]; then
	echo "Cannot read ${INFILE}"
	exit -1
fi

FFMPEG=$(which ffmpeg 2>/dev/null)

if [ "${FFMPEG}" == "" ]; then
	echo "ffmpeg not found"
	exit -1
fi

TMPFILE=$(mktemp /tmp/cropdetect.XXXXXX)
${FFMPEG} -ss 900 -i ${INFILE} -vframes 10 -vf cropdetect -f null - 2> ${TMPFILE}
${FFMPEG} -ss 1800 -i ${INFILE} -vframes 10 -vf cropdetect -f null - 2>> ${TMPFILE}
${FFMPEG} -ss 3600 -i ${INFILE} -vframes 10 -vf cropdetect -f null - 2>> ${TMPFILE}
VIDSIZE=$(cat ${TMPFILE} | grep Stream | grep -m 1 Video | sed 's@^.*, \([0-9]*x[0-9]*\) .*$@\1@')
CROPLINES=$(cat ${TMPFILE} | grep Parsed_cropdetect | awk -F ' ' '{ print $8 $9 $10 $11 $14 }')
rm ${TMPFILE}

CROPSIZELIST=""

for LINE in $(echo ${CROPLINES}); do
	CROPSIZE=$(echo ${LINE} | sed 's@^.*crop=\(.*\)$@\1@')

	if [ "$(echo ${CROPSIZELIST} | grep ${CROPSIZE})" == "" ]; then
		if [ "${CROPSIZE}" == "$(echo ${VIDSIZE} | awk -F 'x' '{ print $1 ":" $2 ":0:0" }')" ]; then
			echo "No cropping needed."
			exit 1
		fi

		CROPSIZELIST="${CROPSIZELIST} ${CROPSIZE}"
	fi
done

for CROPSIZE in $(echo ${CROPSIZELIST}); do
	echo ${CROPSIZE}
done

if [ "$(echo ${CROPSIZELIST} | wc -w)" == "1" ]; then
	exit 0
else
	exit 2
fi

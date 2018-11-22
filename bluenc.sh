#!/bin/bash

#
# BluEnc 1.7.1
#
# Encode BluRay movies
#

while [[ ${#} > 0 ]]; do
	PARAMETER="${1}"

	case "${PARAMETER}" in
		"-f")
		shift
		FORMAT="${1}"
		;;
		"-t")
		shift
		THREADS="${1}"
		;;
		"-copyvideo")
		COPY_VIDEO=1
		;;
		"-novideo")
		ENABLE_VIDEO=0
		;;
		"-res")
		shift
		RESOLUTION="${1}"
		;;
		"-fps")
		shift
		FRAMERATE="${1}"
		;;
		"-crop")
		shift
		CROP="${1}"
		;;
		"-vbr")
		shift
		BITRATE_VIDEO="${1}"
		;;
		"-copyaudio")
		COPY_AUDIO=1
		;;
		"-noaudio")
		ENABLE_AUDIO=0
		;;
		"-abr")
		shift
		BITRATE_AUDIO="${1}"
		;;
		"-copysubs")
		COPY_SUBS=1
		;;
		"-nosubs")
		ENABLE_SUBS=0
		;;
		"-l")
		shift
		LANGUAGES="${1}"
		;;
		"-o")
		shift
		OUTFILE="${1}"
		;;
		*)
		if [ "${INFILE}" != "" ]; then
			echo "Unknown parameter ${1}"
			exit 1
		fi

		INFILE="${1}"
		;;
	esac

	shift
done

if [ "${FORMAT}" == "" ]; then
	FORMAT="mkv"
fi

if [ "${THREADS}" == "" ]; then
	THREADS=2
fi

if [ "${COPY_VIDEO}" == "" ]; then
	COPY_VIDEO=0
fi

if [ "${ENABLE_VIDEO}" == "" ]; then
	ENABLE_VIDEO=1
fi

if [ "${RESOLUTION}" == "" ]; then
	RESOLUTION="auto"
fi

if [ "${FRAMERATE}" == "" ]; then
	FRAMERATE="auto"
fi

if [ "${BITRATE_VIDEO}" == "" ]; then
	BITRATE_VIDEO="4000k"
fi

if [ "${COPY_AUDIO}" == "" ]; then
	COPY_AUDIO=0
fi

if [ "${ENABLE_AUDIO}" == "" ]; then
	ENABLE_AUDIO=1
fi

if [ "${BITRATE_AUDIO}" == "" ]; then
	BITRATE_AUDIO="320k"
fi

if [ "${COPY_SUBS}" == "" ]; then
	COPY_SUBS=0
fi

if [ "${ENABLE_SUBS}" == "" ]; then
	ENABLE_SUBS=1
fi

if [ "${LANGUAGES}" == "" ]; then
	LANGUAGES="eng deu"
fi

if [ "${OUTFILE}" == "" ]; then
	OUTFILE="${INFILE}.${FORMAT}"
fi

# Basic checks

if [ "${FORMAT}" == "mkv" ] || [ "${FORMAT}" == "mp4" ]; then
	CODEC_VIDEO="h264"
	CODEC_AUDIO="aac"
elif [ "${FORMAT}" == "webm" ]; then
	CODEC_VIDEO="vp8"
	CODEC_AUDIO="libvorbis"
	ENABLE_SUBS=0
else
	echo "Unsupported format"
	exit 1
fi

if [ "${INFILE}" == "" ]; then
	echo "Missing filename"
	exit 1
fi

if [ ! -r "${INFILE}" ]; then
	echo "Cannot read ${INFILE}"
	exit 1
fi

FFMPEG=$(which ffmpeg 2>/dev/null)
FFPROBE=$(which ffprobe 2>/dev/null)
CROPDETECT=$(which cropdetect.sh 2>/dev/null)

if [ "${FFMPEG}" == "" ]; then
	echo "ffmpeg not found"
	exit 1
fi

if [ "${FFPROBE}" == "" ]; then
	echo "ffprobe not found"
	exit 1
fi

if [ "${ENABLE_VIDEO}" == "1" ] && [ "${CROPDETECT}" == "" ] && [ "${CROP}" == "auto" ]; then
	echo "cropdetect.sh not found"
	exit 1
fi

# File probing

TMPNAME=$(mktemp /tmp/bluenc.XXXXXX)

ffprobe ${INFILE} 2> ${TMPNAME}

if [ "${ENABLE_VIDEO}" == "1" ]; then
	VIDEO="$(cat ${TMPNAME} | grep Stream | grep Video -m 1 | awk -F '#' '{ print $2 }' | awk -F '(' '{ print $1 }')"

	if [ "${VIDEO}" != "" ]; then
		HAVE_VIDEO=1
	fi

	if [ "${RESOLUTION}" == "auto" ]; then
		RESOLUTION="$(cat ${TMPNAME} | grep Stream | grep Video -m 1 | sed 's@^.*, \([0-9]*x[0-9]*\) .*$@\1@')"
	fi

	if [ "${FRAMERATE}" == "auto" ]; then
		FRAMERATE="$(cat ${TMPNAME} | grep Stream | grep Video -m 1 | sed 's@^.*, \(.*\) fps.*$@\1@')"
	fi
fi

for LANGUAGE in ${LANGUAGES}; do
	LANGVAR="AUDIO_${LANGUAGE}"
	export ${LANGVAR}="$(cat ${TMPNAME} | grep Stream | grep Audio | grep ${LANGUAGE} | grep \(DTS\) -m 1 | awk -F '#' '{ print $2 }' | awk -F '(' '{ print $1 }')"

	if [ "${!LANGVAR}" == "" ]; then
		export ${LANGVAR}="$(cat ${TMPNAME} | grep Stream | grep Audio | grep ${LANGUAGE} -m 1 | awk -F '#' '{ print $2 }' | awk -F '(' '{ print $1 }')"
	fi

	if [ "${!LANGVAR}" != "" ]; then
		HAVE_AUDIO=1

		LANGVAR="CHANNELS_${LANGUAGE}"
		export ${LANGVAR}="$(cat ${TMPNAME} | grep Stream | grep Audio | grep ${LANGUAGE} | grep \(DTS\) -m 1 | awk -F '#' '{ print $2 }' | awk -F ', ' '{ print $3 }')"

		if [ "${!LANGVAR}" == "" ]; then
			export ${LANGVAR}="$(cat ${TMPNAME} | grep Stream | grep Audio | grep ${LANGUAGE} -m 1 | awk -F '#' '{ print $2 }' | awk -F ', ' '{ print $3 }')"
		fi
	fi

	LANGVAR="SUB_${LANGUAGE}"
	export ${LANGVAR}="$(cat ${TMPNAME} | grep Stream | grep Subtitle | grep ${LANGUAGE} -m 1 | awk -F '#' '{ print $2 }' | awk -F '(' '{ print $1 }')"

	if [ "${!LANGVAR}" != "" ]; then
		HAVE_SUBS=1
	fi
done

rm ${TMPNAME}

if [ "${CROP}" == "auto" ]; then
	CROPSIZE="$(${CROPDETECT} ${INFILE})"
	CROP="${?}"

	if [ "${CROP}" == "0" ]; then
		CROP=${CROPSIZE}
	else
		if [ "${CROP}" == "1" ]; then
			CROP=""
		else
			if [ "${CROP}" == "2" ]; then
				echo "Cannot auto-crop due to different detected crop sizes."
			else
				echo "There was a problem detecting the crop size."
			fi

			exit 1
		fi
	fi
fi

# Sanity checks

if [ "${ENABLE_VIDEO}" == "1" ] && [ "${HAVE_VIDEO}" != "1" ]; then
	echo "Video stream not found"
	exit 1
fi

if [ "${ENABLE_AUDIO}" == "1" ] && [ "${HAVE_AUDIO}" != "1" ]; then
	echo "No audio stream found"
	exit 1
fi

# Command building

FFMPEGOPTIONS=""

if [ "${ENABLE_SUBS}" == "1" ] && [ "${HAVE_SUBS}" == "1" ] && [ "${COPY_SUBS}" == "0" ]; then
	FFMPEGOPTIONS="${FFMPEGOPTIONS} -fix_sub_duration"
fi

FFMPEGOPTIONS="${FFMPEGOPTIONS} -i ${INFILE}"

if [ "${CODEC_AUDIO}" == "aac" ] && [ "${COPY_AUDIO}" == "0" ]; then
	FFMPEGOPTIONS="${FFMPEGOPTIONS} -strict -2"
fi

FFMPEGOPTIONS="${FFMPEGOPTIONS} -threads ${THREADS}"

if [ "${ENABLE_VIDEO}" == "1" ]; then
	FFMPEGOPTIONS="${FFMPEGOPTIONS} -s ${RESOLUTION} -r ${FRAMERATE} -map ${VIDEO}"

	if [ "${COPY_VIDEO}" == "1" ]; then
		FFMPEGOPTIONS="${FFMPEGOPTIONS} -c:v copy"
	else
		FFMPEGOPTIONS="${FFMPEGOPTIONS} -c:v ${CODEC_VIDEO} -b:v ${BITRATE_VIDEO}"

		if [ "${CROP}" != "" ]; then
			FFMPEGOPTIONS="${FFMPEGOPTIONS} -vf crop=${CROP}"
		fi
	fi
fi

if [ "${ENABLE_AUDIO}" == "1" ]; then
	CHANNEL=0

	for LANGUAGE in ${LANGUAGES}; do
		LANGVAR="AUDIO_${LANGUAGE}"

		if [ "${!LANGVAR}" != "" ]; then
			FFMPEGOPTIONS="${FFMPEGOPTIONS} -map ${!LANGVAR}"

			if [ "${COPY_AUDIO}" == "1" ]; then
				FFMPEGOPTIONS="${FFMPEGOPTIONS} -c:a:${CHANNEL} copy"
			else
				FFMPEGOPTIONS="${FFMPEGOPTIONS} -c:a:${CHANNEL} ${CODEC_AUDIO} -b:a:${CHANNEL} ${BITRATE_AUDIO}"
				LANGVAR="CHANNELS_${LANGUAGE}"

				if [ "${CODEC_AUDIO}" == "aac" ] && ([ "${!LANGVAR}" == "5.1(side)" ] || [ "${!LANGVAR}" == "6.1" ]); then
					FFMPEGOPTIONS="${FFMPEGOPTIONS} -ac:a:${CHANNEL} 6"
				fi
			fi

			CHANNEL=$(expr ${CHANNEL} + 1)
		fi
	done
fi

if [ "${ENABLE_SUBS}" == "1" ]; then
	CHANNEL=0

	for LANGUAGE in ${LANGUAGES}; do
		LANGVAR="SUB_${LANGUAGE}"

		if [ "${!LANGVAR}" != "" ]; then
			FFMPEGOPTIONS="${FFMPEGOPTIONS} -map ${!LANGVAR}"

			if [ "${COPY_SUBS}" == "1" ]; then
				FFMPEGOPTIONS="${FFMPEGOPTIONS} -c:s:${CHANNEL} copy"
			else
				FFMPEGOPTIONS="${FFMPEGOPTIONS} -c:s:${CHANNEL} dvd_subtitle"
			fi

			CHANNEL=$(expr ${CHANNEL} + 1)
		fi
	done
fi

FFMPEG="${FFMPEG} ${FFMPEGOPTIONS} ${OUTFILE}"

# Execution

#echo ${FFMPEG}
${FFMPEG}

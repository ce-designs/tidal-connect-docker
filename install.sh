#!/bin/bash

log() {
  script=$(basename "$0")
  echo "$(/bin/date) ${HOSTNAME} ${script}[$$]: [$1]: $2"
}

running_environment()
{
  echo "Running environment: "
  echo "  FRIENDLY_NAME:            ${FRIENDLY_NAME}"
  echo "  MODEL_NAME:               ${MODEL_NAME}"
  echo "  BEOCREATE_SYMLINK_FOLDER: ${BEOCREATE_SYMLINK_FOLDER}"
  echo "  DOCKER_DNS:               ${DOCKER_DNS}"
  echo "  DOCKER_IMAGE:             ${DOCKER_IMAGE}"
  echo "  BUILD_OR_PULL:            ${BUILD_OR_PULL}"
  echo "  MQA_PASSTHROUGH:          ${MQA_PASSTHROUGH}"
  echo "  MQA_CODEC:                ${MQA_CODEC}"
  echo "  PWD:                      ${PWD}"
  echo ""
}

usage()
{
  echo "$0 installs TIDAL Connect on your Raspberry Pi."
  echo ""
  echo "Usage: "
  echo ""
  echo "  [FRIENDLY_NAME=<FRIENDLY_NAME>] \\"
  echo "  [MODEL_NAME=<MODEL_NAME>] \\"
  echo "  [BEOCREATE_SYMLINK_FOLDER=<BEOCREATE_SYMLINK_FOLDER>] \\"
  echo "  [DOCKER_DNS=<DOCKER_DNS>] \\"
  echo "  [DOCKER_IMAGE=<DOCKER_IMAGE>] \\"
  echo "  [BUILD_OR_PULL=<build|pull>] \\"
  echo "  [MQA_PASSTHROUGH=<true|false>] \\"
  echo "  [MQA_CODEC=<true|false>] \\"
  echo "  $0 \\"
  echo "    [-f <FRIENDLY_NAME>] \\"
  echo "    [-m <MODEL_NAME>] \\"
  echo "    [-b <BEOCREATE_SYMLINK_FOLDER>] \\"
  echo "    [-d <DOCKER_DNS>] \\"
  echo "    [-i <Docker Image>] \\"
  echo "    [-p <build|pull>] \\"
  echo "    [-t <true|false>] \\"
  echo "    [-c <true|false>"
  echo ""
  echo "Defaults:"
  echo "  FRIENDLY_NAME:            ${FRIENDLY_NAME_DEFAULT}"
  echo "  MODEL_NAME:               ${MODEL_NAME_DEFAULT}"
  echo "  BEOCREATE_SYMLINK_FOLDER: ${BEOCREATE_SYMLINK_FOLDER_DEFAULT}"
  echo "  DOCKER_DNS:               ${DOCKER_DNS_DEFAULT}"
  echo "  DOCKER_IMAGE:             ${DOCKER_IMAGE_DEFAULT}"
  echo "  BUILD_OR_PULL:            ${BUILD_OR_PULL_DEFAULT}"
  echo "  MQA_PASSTHROUGH:          ${MQA_PASSTHROUGH_DEFAULT}"
  echo "  MQA_CODEC:                ${MQA_CODEC_DEFAULT}"
  echo ""

  echo "Example: "
  echo "  BUILD_OR_PULL=build \\"
  echo "  DOCKER_IMAGE=tidal-connect:latest \\"
  echo "  MQA_PASSTHROUGH=true \\"
  echo "  $0"
  echo ""

  running_environment

  echo "Please note that command line arguments "
  echo "take precedence over environment variables,"
  echo "which take precedence over defaults."
  echo ""
}

select_playback_device()
{
  ARRAY_DEVICES=()
  DEVICES=$(docker run --device /dev/snd \
    --entrypoint "" \
    edgecrush3r/tidal-connect \
    /app/ifi-tidal-release/bin/ifi-pa-devs-get 2>/dev/null | grep device#)

  echo ""
  echo "Found output devices..."
  echo ""
  #make newlines the only separator
  IFS=$'\n'
  re_parse="^device#([0-9])+=(.*)$"
  for line in $DEVICES
  do
    if [[ $line =~ $re_parse ]]
    then
      device_num="${BASH_REMATCH[1]}"
      device_name="${BASH_REMATCH[2]}"

      echo "${device_num}=${device_name}"
      ARRAY_DEVICES+=( ${device_name} )
    fi
  done

  while :; do
    read -ep 'Choose your output Device (0-9): ' number
    [[ $number =~ ^[[:digit:]]+$ ]] || continue
    (( ( (number=(10#$number)) <= 9999 ) && number >= 0 )) || continue
    # Here I'm sure that number is a valid number in the range 0..9999
    # So let's break the infinite loop!
    break
  done

  PLAYBACK_DEVICE="${ARRAY_DEVICES[$number]}"
}


# define defaults
FRIENDLY_NAME_DEFAULT=${HOSTNAME}
MODEL_NAME_DEFAULT=${HOSTNAME}
BEOCREATE_SYMLINK_FOLDER_DEFAULT="/opt/beocreate/beo-extensions/tidal"
DOCKER_DNS_DEFAULT="8.8.8.8"
DOCKER_IMAGE_DEFAULT="edgecrush3r/tidal-connect:latest"
BUILD_OR_PULL_DEFAULT="pull"
MQA_PASSTHROUGH_DEFAULT="false"
MQA_CODEC_DEFAULT="false"
PLAYBACK_DEVICE="default"

# override defaults with environment variables, if they have been set
FRIENDLY_NAME=${FRIENDLY_NAME:-${FRIENDLY_NAME_DEFAULT}}
MODEL_NAME=${MODEL_NAME:-${MODEL_NAME_DEFAULT}}
BEOCREATE_SYMLINK_FOLDER=${BEOCREATE_SYMLINK_FOLDER:-${BEOCREATE_SYMLINK_FOLDER_DEFAULT}}
DOCKER_DNS=${DOCKER_DNS:-${DOCKER_DNS_DEFAULT}}
DOCKER_IMAGE=${DOCKER_IMAGE:-${DOCKER_IMAGE_DEFAULT}}
BUILD_OR_PULL=${BUILD_OR_PULL:-${BUILD_OR_PULL_DEFAULT}}
MQA_PASSTHROUGH=${MQA_PASSTHROUGH:-${MQA_PASSTHROUGH_DEFAULT}}
MQA_CODEC=${MQA_CODEC:-${MQA_CODEC_DEFAULT}}

HELP=${HELP:-0}
VERBOSE=${VERBOSE:-0}

# override with command line parameters, if defined
while getopts "hvf:m:b:d:i:p:t:c:" option
do
  case ${option} in
    f)
      FRIENDLY_NAME=${OPTARG}
      ;;
    m)
      MODEL_NAME=${OPTARG}
      ;;
    b)
      BEOCREATE_SYMLINK_FOLDER=${OPTARG}
      ;;
    d)
      DOCKER_DNS=${OPTARG}
      ;;
    i)
      DOCKER_IMAGE=${OPTARG}
      ;;
    p)
      BUILD_OR_PULL=${OPTARG}
      ;;
    t)
      MQA_PASSTHROUGH=${OPTARG}
      ;;
    c)
      MQA_CODEC=${OPTARG}
      ;;
    v)
      VERBOSE=1
      ;;
    h)
      HELP=1
      usage
      exit 0
      ;;
  esac
done

running_environment

log INFO "Pre-flight checks."

log INFO "Checking to see if Docker is running."
docker info &> /dev/null
if [ $? -ne 0 ]
then
  log ERROR "Docker daemon isn't running."
  exit 1
else
  log INFO "Confirmed that Docker daemon is running."
fi

log INFO "Checking to see if Docker image ${DOCKER_IMAGE} exists."
docker inspect --type=image ${DOCKER_IMAGE} &> /dev/null
if [ $? -eq 0 ]
then
  log INFO "Docker image ${DOCKER_IMAGE} exist on the local machine."
  DOCKER_IMAGE_EXISTS=1
else
  log INFO "Docker image ${DOCKER_IMAGE} does not exist on local machine."
  DOCKER_IMAGE_EXISTS=0
fi

# Pull latest image or build Docker image if it doesn't already exist.
if [ ${DOCKER_IMAGE_EXISTS} -eq 0 ]
then
  if [ "${BUILD_OR_PULL}" == "pull" ]
  then
    # Pulling latest image
    log INFO "Pulling docker image ${DOCKER_IMAGE}."
    docker pull ${DOCKER_IMAGE}
    log INFO "Finished pulling docker image ${DOCKER_IMAGE}."
  elif [ "${BUILD_OR_PULL}" == "build" ]
  then
    log INFO "Building docker image."
    cd Docker && \
    DOCKER_IMAGE=${DOCKER_IMAGE} ./build_docker.sh && \
    cd ..
    log INFO "Finished building docker image."
  else
    log ERROR "BUILD_OR_PULL must be set to \"build\" or \"pull\""
    usage
    exit 1
  fi

  docker inspect --type=image ${DOCKER_IMAGE} &> /dev/null
  if [ $? -ne 0 ]
  then
    log ERROR "Docker image ${DOCKER_IMAGE} does not exist on the local machine even after we tried ${BUILD_OR_PULL}ing it."
    log ERROR "Exiting."
    exit 1
  fi
fi

if [ "$(docker ps -q -f name=tidal_connect)" ]; then
  log INFO "Stopping Tidal Container.."
  ./stop-tidal-service.sh
fi

log INFO "Select audio output device"
select_playback_device
echo ${PLAYBACK_DEVICE}

log INFO "Creating .env file."
ENV_FILE="${PWD}/Docker/.env"
CONFIG_FILE="${PWD}/Docker/CONFIG"

> ${ENV_FILE}
echo "FRIENDLY_NAME=${FRIENDLY_NAME}" >> ${ENV_FILE}
echo "MODEL_NAME=${MODEL_NAME}" >> ${ENV_FILE}
echo "MQA_PASSTHROUGH=${MQA_PASSTHROUGH}" >> ${ENV_FILE}
echo "MQA_CODEC=${MQA_CODEC}" >> ${ENV_FILE}
echo "PLAYBACK_DEVICE=${PLAYBACK_DEVICE}" >> ${ENV_FILE}
log INFO "Finished creating .env file."

if [ -L "${CONFIG_FILE}" ]; then
 log INFO "${CONFIG_FILE} already exists. this file will be replaced with new configuration."
 rm "${CONFIG_FILE}"
fi
log INFO "Create config symlink -> ${ENV_FILE}"
ln -s ${ENV_FILE} ${CONFIG_FILE}

# Generate docker-compose.yml
log INFO "Generating docker-compose.yml."
eval "echo \"$(cat templates/docker-compose.yml.tpl)\"" > Docker/docker-compose.yml
log INFO "Finished generating docker-compose.yml."

# Enable service
log INFO  "Enabling TIDAL Connect Service."
eval "echo \"$(cat templates/tidal.service.tpl)\"" >/etc/systemd/system/tidal.service

systemctl enable tidal.service

log INFO "Finished enabling TIDAL Connect Service."

log INFO "Installation Completed."

if [ "$(docker ps -q -f name=docker_tidal-connect)" ]; then
  log INFO "Stopping TIDAL Connect Service."
  ./stop-tidal-service.sh
fi

log INFO "Starting TIDAL Connect Service."
./start-tidal-service.sh

log INFO "Finished, exiting."

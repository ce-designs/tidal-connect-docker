# Tidal Connect Docker image for DietPi (and RaspbianOS)

Image based on https://github.com/TonyTromp/tidal-connect-docker and https://github.com/shawaj/ifi-tidal-release and https://github.com/seniorgod/ifi-tidal-release. 
Please visit https://www.raspberrypi.org/forums/viewtopic.php?t=297771 for full information on the backround of this project.

# Why this fork of tidal-connect-docker?
I was looking for a way to use the excellent ifi-tidal-release as a Docker image for DietPi Buster, because ifi-tidal-release depends on a older version of libcurl3. Installing libcurl3 removes the newer version and packages depending on the newer version. This broke some things in DietPi, like the updater.
Running tidal connect in a docker solves this problem, but the implementation I found was aimed at HifiberryOS, but I needed a solution that works for me.
That why I decided to fork this repository and strip off all code related to HifiberryOS and other stuff that I don't need. 

# Installation

1. SSH into your Raspberry and clone/copy this repository onto your system. 
```
cd /usr/local && \
  git clone https://github.com/ce-designs/tidal-connect-docker.git && \
  cd tidal-connect-docker
```

2. Install and run

```
./install.sh
```

This will download the Docker image from github and install and start TIDAL Connect as a service.

## Usage & Troubleshooting

Please visit https://github.com/TonyTromp/tidal-connect-docker 

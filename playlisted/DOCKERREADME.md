This directory is for converting playlistd into a docker image

#How To Run
Make sure you are in a linux system or VM, and in the project directory

## Build
Build with 'docker build -t playlistd .'

## Run
Run with 'docker run -p 0.0.0.0:8500:80 playlistd:latest'
runs the docker image on all network interfaces with the host port 8500, and nginx listening on port 80


Go to <your_server_ip>:8500 with http on the browser and you should be set!

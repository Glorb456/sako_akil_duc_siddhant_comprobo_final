#!/bin/bash

# Initialize the YAML variables to empty strings
blue=""
yellow=""
wrist=""
d435=""

# Run v4l2-ctl to fetch devices and parse them line by line
while IFS= read -r line; do
    # Check for the device identifiers and store them accordingly
    if [[ $line == *"Piwebcam: UVC Camera"* ]]; then
        wrist=$(echo "$line" | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
    elif [[ $line == *"HD Pro Webcam C920"* ]] && [ -z "$blue" ]; then
        blue=$(echo "$line" | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
    elif [[ $line == *"HD Pro Webcam C920"* ]]; then
        yellow=$(echo "$line" | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
    elif [[ $line == *"Intel(R) RealSense(TM) Depth Ca"* ]]; then
        d435=$(echo "$line" | awk -F 'Ca ' '{print $2}' | awk -F ')' '{print $1}')
    fi
done < <(v4l2-ctl --list-devices)

# Write only the webcams that were actually found. An empty entry would match the
# first device in `v4l2-ctl --list-devices` and stream the wrong camera.
# The RealSense (d435) is left out on purpose: the realsense2_camera node opens it
# by serial number (REALSENSE_SERIAL), and streaming it here as well would conflict.
{
    [ -n "$blue" ] && echo "blue: '$blue'"
    [ -n "$yellow" ] && echo "yellow: '$yellow'"
    [ -n "$wrist" ] && echo "wrist: '$wrist'"
    true
} > usb_connector_chart.yml
# start_streamers.py needs a mapping, so write {} when no webcams were found
[ -s usb_connector_chart.yml ] || echo "{}" > usb_connector_chart.yml
[ -n "$d435" ] && echo "RealSense found at $d435 (launched by realsense2_camera, not added to chart)"

# WidowX startup commands

Commands for bringing up the arm and keyboard teleop on this laptop. Each numbered
terminal is a separate terminal window; all of them start in the repo folder:

```bash
cd ~/ros2_ws/src/sako_akil_duc_siddhant_comprobo_final/bridge_data_robot-main
```

## Every session

### Terminal 1: robot container

Starts ROS, the arm driver and the camera node. Leave it running.

```bash
REALSENSE_SERIAL=943222071518 USB_CONNECTOR_CHART=$(pwd)/usb_connector_chart.yml docker compose up robonet
```

Wait for `Interbotix 'xs_sdk' node is up!` before going on.

If a `.env` file containing `REALSENSE_SERIAL=943222071518` exists in this folder, the
`REALSENSE_SERIAL=...` part can be left off.

### Terminal 2: robot server

Accepts movement commands from teleop. Leave it running.

```bash
docker compose exec robonet bash -lic "widowx_env_service --server"
```

It is ready when it prints `Action server is listening on port 5556`.

### Terminal 3: keyboard teleop

Keep the arm's workspace clear: on startup the arm moves to its start pose.

```bash
source ~/teleop_env/bin/activate
python3 widowx_envs/widowx_envs/teleop.py --no-camera
```

Wait for the key list to print (10 to 20 seconds), then click the "Robot Camera" window
and use the keys:

| Key | Action |
|---|---|
| `w` / `s` | forward / backward |
| `a` / `d` | left / right |
| `z` / `c` | up / down |
| `i` / `k` | rotate yaw |
| `j` / `l` | rotate pitch |
| `n` / `m` | rotate roll |
| space | open / close gripper |
| `r` | reset the arm |
| `q` | quit |

Options:

- Leave off `--no-camera` to show the RealSense feed (only works once the camera is streaming).
- Add `--ip <IP_ADDRESS>` to control the arm from another computer; get the address by
  running `hostname -I` on this laptop.

## Shutting down

1. Press `q` in the teleop window.
2. Put the arm in its sleep pose (from any free terminal in the repo folder):
   ```bash
   docker compose exec robonet bash -lic "go_sleep"
   ```
3. Press Ctrl+C in terminal 2 (server), then in terminal 1 (container).

## Other useful commands

```bash
# move the arm to its neutral pose / sleep pose (terminal 1 must be running)
docker compose exec robonet bash -lic "go_neutral"
docker compose exec robonet bash -lic "go_sleep"

# open a shell inside the container
docker compose exec robonet bash

# rebuild the image (only after changing the Dockerfile or requirements.txt)
USB_CONNECTOR_CHART=$(pwd)/usb_connector_chart.yml docker compose up --build robonet

# regenerate the webcam config after plugging in different webcams
./generate_usb_config.sh
```

## If something goes wrong

**`TypeError: 'type' object is not subscriptable` from moviepy**
The container was recreated and lost the moviepy fix. Reinstall it:

```bash
docker compose exec robonet bash -lic "pip install 'moviepy==1.0.3'"
```

**Teleop: `Failed to connect to action server`**
The server in terminal 2 is not running. Start it, then run teleop again.

**Teleop: `No module named 'widowx_envs'`**
The Python environment is not active. Run `source ~/teleop_env/bin/activate` first; the
prompt should start with `(teleop_env)`.

**Server stuck on `Trying to read camera info from ...`**
Teleop was started without `--no-camera` and the camera is not streaming. Stop both with
Ctrl+C, then start the server and teleop again with `--no-camera`.

**Camera: `The requested device with serial number ... is NOT found`**
The serial in the start command does not match the plugged-in camera. The correct one is
printed just above the error as `Device with serial number ... was found`.

**Camera: `RS2_USB_STATUS_ACCESS`**
The RealSense udev rules are missing on the host. Install them, then replug the camera:

```bash
sudo wget -O /etc/udev/rules.d/99-realsense-libusb.rules \
  https://raw.githubusercontent.com/IntelRealSense/librealsense/master/config/99-realsense-libusb.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

**Camera: `control_transfer returned error` / `Hardware Error`**
Usually the USB connection. Plug the camera straight into a USB 3 port with its original
cable, and check that `lsusb -t` shows `5000M` for it.

**Docker build fails with `no space left on device`**
Run `sudo bash fix_docker_space.sh` in this folder, then rebuild.

## One-time setup (already done on this laptop)

Only needed on a new machine.

```bash
# host dependencies and the Docker image
./host_install.sh
./generate_usb_config.sh
USB_CONNECTOR_CHART=$(pwd)/usb_connector_chart.yml docker compose up --build robonet

# Python environment for running teleop on the host
sudo apt install python3.12-venv
python3 -m venv ~/teleop_env
source ~/teleop_env/bin/activate
pip install opencv-python numpy funcsigs pyyaml
pip install git+https://github.com/youliangtan/edgeml
pip install -e widowx_envs
```

#!/usr/bin/env python3

import argparse
import time
import numpy as np
import cv2
from widowx_envs.widowx_env_service import WidowXClient, WidowXConfigs

def show_video(client, full_image=True):
    """
    This shows the video from the camera for a given duration.
    Full image is the image before resized to default 256x256.
    """
    res = client.get_observation()
    if res is None:
        print("No observation available... waiting")
        return

    if full_image:
        img = res["full_image"]
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
    else:
        img = res["image"]
        img = (img.reshape(3, 256, 256).transpose(1, 2, 0) * 255).astype(np.uint8)
    cv2.imshow("Robot Camera", img)
    cv2.waitKey(20)  # 20 ms

print_yellow = lambda x: print("\033[93m {}\033[00m" .format(x))

def print_help():
    print_yellow("  Teleop Controls:")
    print_yellow("    w, s : move forward/backward")
    print_yellow("    a, d : move left/right")
    print_yellow("    z, c : move up/down")
    print_yellow("    i, k:  rotate yaw")
    print_yellow("    j, l:  rotate pitch")
    print_yellow("    n  m:  rotate roll")
    print_yellow("    space: toggle gripper")
    print_yellow("    r: reset robot")
    print_yellow("    q: quit")

def wait_until_ready(client):
    """Block until the server answers again (it is silent while the arm is moving)."""
    time.sleep(1)
    while client.get_observation() is None:
        print("Waiting for robot to be ready...")
        time.sleep(1)

def main():
    parser = argparse.ArgumentParser(description='Teleoperation for WidowX Robot')
    parser.add_argument('--ip', type=str, default='localhost')
    parser.add_argument('--port', type=int, default=5556)
    parser.add_argument('--no-camera', action='store_true',
                        help='control the arm without any camera (no video is shown)')
    args = parser.parse_args()

    env_params = dict(WidowXConfigs.DefaultEnvParams)
    if args.no_camera:
        env_params["camera_topics"] = []

    client = WidowXClient(host=args.ip, port=args.port)
    client.init(env_params, image_size=256)

    # the server is busy (and does not answer) while it sets up the arm
    wait_until_ready(client)

    # step actions are relative to the pose recorded by a reset, so the arm has to be
    # reset once before the first key press (this moves it to its start pose)
    print("Moving the arm to its start pose...")
    client.reset()
    wait_until_ready(client)

    print_help()
    cv2.namedWindow("Robot Camera")
    if args.no_camera:
        # the window is still needed: it is what receives the key presses
        blank = np.zeros((240, 640, 3), dtype=np.uint8)
        cv2.putText(blank, "No camera - click here, then use the keys", (20, 125),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.imshow("Robot Camera", blank)
    is_open = 1
    running = True
    while running:
        # Check for key press
        key = cv2.waitKey(100) & 0xFF

        # escape key to quit
        if key == ord('q'):
            print("Quitting teleoperation.")
            running = False
            continue

        # Handle key press for robot control
        # translation
        if key == ord('w'):
            client.step_action(np.array([0.01, 0, 0, 0, 0, 0, is_open]))
        elif key == ord('s'):
            client.step_action(np.array([-0.01, 0, 0, 0, 0, 0, is_open]))
        elif key == ord('a'):
            client.step_action(np.array([0, 0.01, 0, 0, 0, 0, is_open]))
        elif key == ord('d'):
            client.step_action(np.array([0, -0.01, 0, 0, 0, 0, is_open]))
        elif key == ord('z'):
            client.step_action(np.array([0, 0, 0.01, 0, 0, 0, is_open]))
        elif key == ord('c'):
            client.step_action(np.array([0, 0, -0.01, 0, 0, 0, is_open]))
        
        # rotation
        elif key == ord('i'):
            client.step_action(np.array([0, 0, 0, 0.01, 0, 0, is_open]))
        elif key == ord('k'):
            client.step_action(np.array([0, 0, 0, -0.01, 0, 0, is_open]))
        elif key == ord('j'):
            client.step_action(np.array([0, 0, 0, 0, 0.01, 0, is_open]))
        elif key == ord('l'):
            client.step_action(np.array([0, 0, 0, 0, -0.01, 0, is_open]))
        elif key == ord('n'):
            client.step_action(np.array([0, 0, 0, 0, 0, 0.01, is_open]))
        elif key == ord('m'):
            client.step_action(np.array([0, 0, 0, 0, 0, -0.01, is_open]))    
        
        # space bar to change gripper state
        elif key == ord(' '):
            is_open = 1 - is_open
            print("Gripper is now: ", is_open)
            client.step_action(np.array([0, 0, 0, 0, 0, 0, is_open]))
        elif key == ord('r'):
            print("Resetting robot...")
            client.reset()
            print_help()

        if not args.no_camera:
            show_video(client)

    client.stop()  # Properly stop the client
    cv2.destroyAllWindows()
    print("Teleoperation ended.")

if __name__ == "__main__":
    main()

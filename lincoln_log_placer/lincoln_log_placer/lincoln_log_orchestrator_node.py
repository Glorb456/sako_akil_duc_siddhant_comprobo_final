#a finite state machine that switches between looking for log, picking up the log,
#moving towards the current structure, and placing the log on the structure
#localizes the robot in space, knows the current state of the log tower
#subscribes to : servo positions
#publishes to : motor control topic

def main():
    print('Hi from lincoln_log_placer.')


if __name__ == '__main__':
    main()

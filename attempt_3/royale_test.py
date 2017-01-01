from __future__ import division

import time
import royale

import numpy as np
import scipy.misc

def normalize_image(image, max_val=None):
    max_val = max_val or np.max(image)
    return (image / max_val * 255).astype(np.uint8)

i = 0
def save_image(depth_image, gray_image):
    global i
    print i
    filename = 'images/depth_{:03d}.png'.format(i)
    scipy.misc.imsave(filename, normalize_image(depth_image, 3))
    filename = 'images/gray_{:03d}.png'.format(i)
    scipy.misc.imsave(filename, gray_image)
    i += 1


def _aaa(arg):
    print arg


def test2():
    manager = royale.CameraManager()
    manager.initialize()
    cameras = manager.get_connected_cameras()
    print cameras
    h_camera = manager.create_camera_device(cameras[0])
    print h_camera
    camera = royale.CameraDevice(h_camera)
    camera.initialize()
    print camera.get_camera_name()
    cases = camera.get_use_cases()
    if cases:
        print cases
        camera.set_use_case('MODE_9_15FPS_700')
        print camera.get_camera_info()
        print camera.get_current_use_case()
        camera.start_capture()
        camera.register_data_listener(save_image)
        time.sleep(3)
        camera.unregister_data_listener()
        camera.stop_capture()

    print 'Exiting'


if __name__ == '__main__':
    test2()

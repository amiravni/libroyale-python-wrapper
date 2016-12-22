from __future__ import division

import time
import royale

import numpy as np
import scipy.misc

def normalize_image(image):
    return (image / np.max(image) * 255).astype(np.uint8)

i = 0
def aaa(image):
    global i
    filename = 'images/frame_{}.png'.format(i)
    print filename
    scipy.misc.imsave(filename, normalize_image(image))
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
    cases = camera.get_use_cases()
    print cases
    camera.set_use_case(cases[0])
    camera.register_data_listener(aaa)
    camera.start_capture()
    time.sleep(3)
    camera.stop_capture()
    camera.unregister_data_listener()

if __name__ == '__main__':
    test2()

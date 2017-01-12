from __future__ import division
from __future__ import print_function
from __future__ import absolute_import

import os
import sys
import time
import argparse
from royale_wrapper import royale

import numpy as np
import scipy.misc


def _normalize_image(image, max_val=None):
    max_val = max_val or np.max(image)
    return (image / max_val * 255).astype(np.uint8)


def _save_image(depth_image, gray_image):
    if not os.path.exists('tmp'):
        os.makedirs('tmp')

    print('Saving image:', _save_image.counter)
    filename = 'tmp/depth_{:03d}.png'.format(_save_image.counter)
    scipy.misc.imsave(filename, _normalize_image(depth_image, 3))

    filename = 'tmp/gray_{:03d}.png'.format(_save_image.counter)
    scipy.misc.imsave(filename, gray_image)

    _save_image.counter += 1

_save_image.counter = 0


def _parse_command_line_args():
    ap = argparse.ArgumentParser(
        description='Test royale API'
    )
    ap.add_argument('--camera', type=int, default=0)
    ap.add_argument('--use-case')
    return ap.parse_args(sys.argv[2:])


def test():
    """Test royale_wrapper"""
    args = _parse_command_line_args()

    manager = royale.CameraManager()
    manager.initialize()
    cameras = manager.get_connected_cameras()

    h_camera = manager.create_camera_device(cameras[args.camera])
    camera = royale.CameraDevice(h_camera)
    camera.initialize()

    print('ID:', camera.get_id())
    print('Name:', camera.get_camera_name())

    cases = camera.get_use_cases()
    print('Cases:')
    for case in cases:
        print('  - {}'.format(case))

    case = args.use_case or cases[0]
    print('Using:', case)
    camera.set_use_case(case)

    camera.register_python_callback(_save_image)
    camera.register_data_listener()

    print('Start capturing')
    camera.start_capture()
    time.sleep(3)

    print('Stop capturing')
    camera.stop_capture()
    time.sleep(1)

    camera.unregister_data_listener()
    camera.unregister_python_callback()

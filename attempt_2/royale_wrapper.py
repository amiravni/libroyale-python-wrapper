import os
from ctypes import cdll

royale_lib = cdll.LoadLibrary(os.path.join(
    os.path.dirname(__file__),'royale_c_wrapper.so'))


class Royale(object):
    def __init__(self):
        pass

    def test(self):
        royale_lib.test()

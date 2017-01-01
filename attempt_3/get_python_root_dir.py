from __future__ import print_function

import os
import sys


def _main():
    print(os.path.dirname(os.path.dirname(sys.executable)))


if __name__ == '__main__':
    _main()


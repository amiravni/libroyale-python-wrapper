from __future__ import print_function
from __future__ import absolute_import

import os
import setuptools
import subprocess
from setuptools.command.build_py import build_py as _build_py


def _build_royale_wrapper():
    source_dir = os.path.dirname(os.path.abspath(__file__))
    build_dir = os.path.join(source_dir, 'royale_wrapper')
    cmd = ['cmake', '-B{}'.format(build_dir), '-H{}'.format(source_dir)]
    subprocess.call(cmd)
    cmd = ['make', '-C', build_dir]
    subprocess.call(cmd)


class _BuildPyCommand(_build_py):
    """Custom build command."""
    def run(self):
        _build_royale_wrapper()
        _build_py.run(self)


def _setup():
    setuptools.setup(
        name='royale_wrapper',
        version='v0.1.0',
        cmdclass={
            'build_py': _BuildPyCommand,
        },
        packages=[
            'royale_wrapper',
        ],
        package_data={
            'royale_wrapper': [
                '_royale.so',
            ],
        },
        entry_points={
            'console_scripts': [
                'royale=royale_wrapper.main:main',
            ],
        }
    )


if __name__ == '__main__':
    _setup()

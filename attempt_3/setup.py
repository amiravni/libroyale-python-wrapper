#!/usr/bin/env python
from distutils.core import setup, Extension


if __name__ == '__main__':
    module = Extension(
        '_royale',
        sources=['royale_wrap.c'],
        extra_compile_args=['-I../libroyale/include/royaleCAPI'],
    )

    setup(
        name='royale',
        version='0.1',
        author="moto",
        description="""Python wrapper of libroyale C API""",
        ext_modules=[module],
        py_modules=["royale"],
    )

### Royale Python Wrapper

This is a python simple wrapper of [libroyale, the API of picoflexx depth sensor](http://pmdtec.com/picoflexx/software/).

Currently only work on LINUX and Mac. Windows build is not implemented.


### Installation

#### Dependencies

- SWIG
- CMake
- NumPy (CustomAPI)

So as to simplify installation script, CMake file provided by this repository assumes that libroyale is installed separatedly.
That is, include files and binary files are stored in the path accessible from CMake, such as `/usr/local`.

If they are not in the standard location, use `-DCMAKE_INCLUDE_PATH=<path_to_royale_dir>/include` and/or `-DCMAKE_LIBRARY_PATH=<path_to_royale_dir>/bin`. In this case, library files (all `libroyale`, `libroyaleCAPI` and `libuvc`) need to be included in path searched by `dlopen`, (`LD_LIBRARY_PATH` in Unix or `DYLD_LIBRARY_PATH` in Mac).


#### One-line installation

pip install git+https://github.com/mthrok/libroyale-python-wrapper


#### Manual Build & Installation
```bash
git clone https://github.com/mthrok/libroyale-python-wrapper
mkdir libroyale-python-wrapper/build
cd libroyale-python-wrapper/build
cmake ..
make
make install
```


#### Windows build

The following scripts have to be fixed for Windows build

- cmake/FindRoyale.cmake
- cmake/FindPython.cmake
- Windows specific initlallization `CoInitializeEx`. See official example code for this.


### Usage

See [test script](royale_wrapper/test.py) for the usage.


### Command line utilities

This package also includes csome utility commands.

- `royale profile`

Print the list of connected cameras and their use cases.

- `royale test`

Save the images from the designated camera. This requires `SciPy` package.


### Limitation

This code was developped, with minimal effort, yet extendability in mind, to make libroyale accessible from Python.

So not all the functionalities are correctly wrapped.

Check [CustomAPI.i](src/CustomAPI.i) for the list of available functions.

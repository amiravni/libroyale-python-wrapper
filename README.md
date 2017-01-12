### Installation

So as to simplify installation script, CMake file provided by this repository assumes that libroyale is installed separatedly.
That is, include files and binary files are stored in the path accessible from CMake, such as `/usr/local`.

If they are not in the standard location, use `-DCMAKE_INCLUDE_PATH=<path_to_royale_dir>/include` and/or `-DCMAKE_LIBRARY_PATH=<path_to_royale_dir>/bin`. In this case, library files (all `libroyale`, `libroyaleCAPI` and `libuvc`) need to be included in path searched by `dlopen`, (`LD_LIBRARY_PATH` in Unix or `DYLD_LIBRARY_PATH` in Mac).

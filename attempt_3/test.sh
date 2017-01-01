set -eux

PYTHON_ROOT_DIR=$(python get_python_root_dir.py)
PYTHON_INCLUDE_DIR="${PYTHON_ROOT_DIR}/include/python2.7"
PYTHON_LIB_DIR="${PYTHON_ROOT_DIR}/lib"

NUMPY_INCLUDE_DIR=$(python -c "import numpy;print(numpy.get_include())")

LIBROYALE_ROOT_DIR="../libroyale"
LIBROYALE_INCLUDE_DIR="${LIBROYALE_ROOT_DIR}/include/royaleCAPI"
LIBROYALE_LIB_DIR="${LIBROYALE_ROOT_DIR}/bin"

swig -python -c++ -I${LIBROYALE_INCLUDE_DIR} royale.i

g++ -g -fPIC -c royale_wrap.cxx -o royale_wrap.o \
    -std=c++11 \
    -I${LIBROYALE_INCLUDE_DIR} \
    -I${PYTHON_INCLUDE_DIR} \
    -I${NUMPY_INCLUDE_DIR}

g++ -g royale_wrap.o -shared -o _royale.so \
    -L${LIBROYALE_LIB_DIR} -lroyaleCAPI \
    -L${PYTHON_LIB_DIR} -lpython2.7

if [ $(uname -s) = Darwin ]; then
    DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH+''}:${LIBROYALE_LIB_DIR}" python royale_test.py
elif [ $(uname -s) = Linux ]; then
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH+''}:${LIBROYALE_LIB_DIR}:/usr/local/lib" python royale_test.py
fi

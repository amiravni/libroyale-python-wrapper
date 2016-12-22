set -eux

swig -python -c++ -I../libroyale/include/royaleCAPI royale.i

g++ -g -fPIC -c royale_wrap.cxx -o royale_wrap.o \
    -std=c++11 \
    -I../libroyale/include/royaleCAPI \
    -I/Users/moto/anaconda/envs/picoflexx-python/include/python2.7 \
    -I/Users/moto/anaconda/envs/picoflexx-python/lib/python2.7/site-packages/numpy/core/include/

g++ -g royale_wrap.o -shared -o _royale.so \
    -L../libroyale/bin -lroyaleCAPI \
    -L/Users/moto/anaconda/envs/picoflexx-python/lib -lpython2.7

DYLD_LIBRARY_PATH=../libroyale/bin/ python royale_test.py

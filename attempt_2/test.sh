set -eu

echo "Building wrapper"
g++ -g -fPIC -I../libroyale/include -std=c++11 -o royale_c_wrapper.o -c royale_c_wrapper.cxx
g++ -g royale_c_wrapper.o -shared -o royale_c_wrapper.so -L../libroyale/bin -lroyale
echo "Testing warpper"
DYLD_LIBRARY_PATH=../libroyale/bin python royale_wrapper_test.py

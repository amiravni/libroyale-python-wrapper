set -eux

cd royale_wrapper
cmake ..
make
cd ../
python royale_test.py

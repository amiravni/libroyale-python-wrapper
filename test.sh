set -eux

function abspath() {
    pushd . > /dev/null;
    if [ -d "$1" ]; then
	cd "$1"; dirs -l +0;
    else
	cd "`dirname \"$1\"`";
	cur_dir=`dirs -l +0`;
	if [ "$cur_dir" == "/" ]; then
	    echo "$cur_dir`basename \"$1\"`";
	else
	    echo "$cur_dir/`basename \"$1\"`";
	fi;
    fi;
    popd > /dev/null;
}

LIBROYALE_PATH=$(abspath "./libroyale/bin")

mkdir -p build
cd build
cmake .. -DROYALE_ROOT_DIR=./libroyale
make
cp ../royale_test.py ./
mkdir -p images

if [ $(uname -s) = Darwin ]; then
    DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH+''}:${LIBROYALE_PATH}" python royale_test.py
elif [ $(uname -s) = Linux ]; then
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH+''}:${LIBROYALE_PATH}:/usr/local/lib" python royale_test.py
fi

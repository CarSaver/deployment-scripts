#!/bin/sh
## We need to determine what OS the dev is using

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo 'LINUX'
elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo 'OSX'
elif [[ "$OSTYPE" == "cygwin" ]]; then
        echo 'emulator'
elif [[ "$OSTYPE" == "msys" ]]; then
        echo 'Windows'
fi


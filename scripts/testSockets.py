#!/usr/bin/python
import sys, os
from socket import *
testfile = sys.argv[1] + "_tmp_"
try:
    socket(AF_UNIX, SOCK_DGRAM).bind(testfile)
except:
    sys.exit(1)
finally:
    os.remove(testfile) if os.path.exists(testfile) else ''
sys.exit(0)


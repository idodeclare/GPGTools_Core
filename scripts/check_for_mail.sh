#!/bin/bash

if [ "" == "`ps wux|grep /Mail.app/|grep -v grep`" ]; then
    exit 0;
else
    exit 1;
fi


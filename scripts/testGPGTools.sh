#!/bin/bash
################################################################################
# Test all GPGTools sub projects.
#
# @prereq   OS X >= 10.5, Xcode >= 3, and SDK 10.5
# @tested   OS X Lion 10.7.0
# @see      http://gpgtools.org
# @see      http://hints.macworld.com/article.php?story=20110318050811544
# @version  2011-07-25
################################################################################


# config #######################################################################
root="`pwd`/build";
logfile="/tmp/gpgtools.log";
projects=( \
"Libmacgpg" \
"GPGKeychainAccess" \
"GPGServices" \
"GPGTools_Preferences" \
"GPGMail" \
"MacGPG1" \
"MacGPG2" \
)
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtrst=$(tput sgr0)       # Text reset
txtOK="${txtgrn}OK${txtrst}"
txtFAIL="${txtred}FAILED${txtrst}"
txtSKIPPED="${txtylw}SKIPPED${txtrst}"
################################################################################


# functions ####################################################################
function testEnvironment {
    echo " * Testing environment...";
    echo -n "   * 10.5 SDK: ";
    if [ -d "/Developer/SDKs/MacOSX10.5.sdk" ]; then echo "$txtOK"; else echo "$txtFAIL"; fi
    echo -n "   * git: ";
    if [ "`which git`" != "" ]; then echo "$txtOK"; else echo "$txtFAIL"; fi
    echo -n "   * make: ";
    if [ "`which make`" != "" ]; then echo "$txtOK"; else echo "$txtFAIL"; fi
    echo -n "   * Xcode: ";
    if [ "`which xcodebuild`" != "" ]; then echo "$txtOK"; else echo "$txtFAIL"; fi
    echo -n "   * GCC (ppc): ";
    if [ -f "/Developer/usr/bin/powerpc-apple-darwin10-gcc-4.2.1" ]; then echo "$txtOK"; else echo "$txtFAIL"; fi
    echo -n "   * LLVM (ppc): ";
    if [ -f "/Developer/usr/llvm-gcc-4.2/bin/powerpc-apple-darwin10-llvm-gcc-4.2" ]; then echo "$txtOK"; else echo "$txtFAIL"; fi

}

function evalResult {
    _e=$(date +%s); _t=$(( $_e - $3 ));
    if [ "$1" == "0" ]; then
        echo "$txtOK ($_t seconds)";
    else
        echo "$txtFAIL ($1)! See '$2' for details.";
    fi
}

function downloadProject {
    _name="$1";
    _url="git://github.com/GPGTools/$_name.git";
    : > $logfile.$_name
    echo -n "   * Downloading '$_name'...";
    _s=$(date +%s)
    if [ -d "$_name" ]; then
        pushd . > /dev/null
        cd "$_name";
        git pull origin master > $logfile.$_name 2>&1;
        git submodule foreach git pull origin master > $logfile.$_name 2>&1;
        popd > /dev/null
    else
        git clone --recursive --depth 1 $_url $_name > $logfile.$_name 2>&1;
    fi
    evalResult $? $logfile.$_name $_s
}

function compileProject {
    echo -n "   * Building '$_name'...";
    _s=$(date +%s)
    make clean compile >> $logfile.$_name 2>&1;
    evalResult $? $logfile.$_name $_s
}

function testProject {
    echo -n "   * Testing '$_name'...";
    if [ "`grep test: Makefile`" == "" ]; then
        echo "$txtSKIPPED";
    else
        _s=$(date +%s)
        make test >> $logfile.$_name 2>&1;
        evalResult $? $logfile.$_name $_s
    fi
}

function workonProject {
    _name="$1";
    echo " * Working on '$_name'...";
    : > $logfile.$_name
    mkdir -p $root; cd $root;
    downloadProject $_name; cd $_name;
    compileProject $_name;
    testProject $_name;
}
################################################################################

# main #########################################################################
echo "Testing GPGTools...";
testEnvironment
for project in "${projects[@]}"; do
    workonProject $project
done
################################################################################

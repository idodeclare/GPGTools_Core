#!/usr/bin/env python

"""Prepares a new release for a tool of our GPGTools suite.

Possible version bumps are:
- Patch -> for bugfixes
- Minor -> small features
- Major -> major new features

Following steps are executed in order to prepare a release:

1.) Check if the repository is clean. If there are any uncommitted changes, ABORT!
2.) Internally bump the version - don't update any files yet.
    Prompt the user to specify the version themselves but provide an educated guess based
    default.
    Possible options for version bumps:
        - Major -> 2.x.x to 3.x.x (--major)
        - Minor -> 2.1.x to 2.2.x (--minor)
        - Patch -> 2.1.1 to 2.1.2 (--patch)
3.) Check if there's a release note file available for the new version.
    Prompt for the file path if it's missing.
    Add and commit the file via git.
    No file found. ABORT!
4.) Update the necessary files with the new version and commit the updated version.
5.) Create a git tag for the new version so it can be checked out anytime.
6.) Last, merge the changes into the master branch and push it to make start the actual
    publishing via the build server.

"""

import os, sys
from optparse import OptionParser, OptionValueError

sys.path.insert(1, os.path.join(os.getcwd(), './Dependencies/GPGTools_Core/python'))

from clitools import *
from clitools.color import *

CWD = os.getcwd()
VERSION_FILE = "Makefile.config"
VERSION_PATH = "%s/%s" % (CWD, VERSION_FILE)

def check_version(version):
    """Check if the format of the version string represents a valid version.
    
    Each version consists of 3 parts: major.minor.patch
    """
    if not version:
        raise Exception("version must not be None")
    
    parts = version.split(".")
    if len(parts) != 3:
        raise Exception("version must consist of exactly 3 numbers: major.minor.patch")
    for part in parts:
        try:
            part = int(part)
        except ValueError:
            raise Exception("each version part has to be a number")
    
    return True

def parse_options():
    parser = OptionParser()
    parser.add_option("-m", "--major", dest="release_type", action="store_const", const="major", 
                      help="bump major version")
    parser.add_option("-i", "--minor", dest="release_type", action="store_const", const="minor",
                      help="bump minor version")
    parser.add_option("-p", "--patch", dest="release_type", action="store_const", const="patch",
                      help="bump patch version")
    
    # Parse the version if given, otherwise prompt for it.
    def parse_custom_version(option, opt_str, value, parser, *args, **kwargs):
        for arg in parser.rargs:
            # stop on --foo like options
            if arg[:2] == "--" and len(arg) > 2:
                break
            # stop on -a, but not on -3 or -3.0
            if arg[:1] == "-" and len(arg) > 1 and not floatable(arg):
                break
            
            if value:
                break
            
            value = arg
        
        del parser.rargs[:1]
        
        if not value:
            parser.values.custom = value
            return
        
        try:
            check_version(value)
        except Exception, e:
            raise OptionValueError(str(e))
        
        parser.values.custom = value
    
    parser.add_option("-c", "--custom", dest="custom", action="callback", callback=parse_custom_version,
                      nargs=1, help="use custom version VERSION", metavar="VERSION")
    
    (options, args) = parser.parse_args()
    
    
    if not options.release_type:
        options.release_type = "custom"
    
    return (options, args)

def bailout(message):
    error("%s" % (message))
    sys.exit(1)

def ask_for_custom_version():
    while True:
        value = ask_for("Please enter the new version")
        try:
            check_version(value)
            break
        except Exception, e:
            print e
    
    (major, minor, patch) = value.split(".")
    
    return {"major": major, "minor": minor, "patch": patch}

def current_version():
    if not os.path.isfile(VERSION_PATH):
        bailout("Version file can't be found - make sure Makefile.config exists.")
    
    variables = []
    with open(VERSION_PATH) as fh:
        # Find only lines which are variables. Contains an =
        variables = filter(lambda x: [None, x.strip().replace("'", "").replace("\"", "")][x.find("=") != -1], 
                    fh.readlines())
        version = {}
        for variable in variables:
            (key, value) = variable.split("=")
            if key.lower() in ["major", "minor", "revision"]:
                version[key.lower().replace("revision", "patch")] = int(value.strip())
    
    return version

def next_version(version, release_type, custom_version=None):
    if not release_type in version:
        bailout("Allowed values for release_type: minor, major, patch - received: %s" % (release_type))
    
    new_version = {"patch": version["patch"], "minor": version["minor"], "major": version["major"]}
    
    new_version[release_type] = [custom_version, new_version[release_type] + 1][not custom_version]
    
    if release_type == "minor" or release_type == "major":
        new_version["patch"] = 0
    if release_type == "major":
        new_version["minor"] = 0
    
    return new_version

def confirm_version(release_type):
    new_version = next_version(current_version(), release_type)
    proposal = new_version[release_type]
    while True:
        value = ask_for("New %s version [default %s]" % (release_type, proposal))
        if value == "":
            value = proposal
            break
        
        try:
            value = int(value)
            break
        except ValueError:
            print "Version has to be a number"
    
    new_version[release_type] = value
    
    return new_version

def is_workspace_clean():
    out = run("git status --short").strip()
    return out == ""

def format_version(version):
    return "%s.%s.%s" % (str(version["major"]), str(version["minor"]), str(version["patch"]))

def run(cmd):
    return check_output(cmd.split(" "))

def main():
    (options, args) = parse_options()
    
    # Make sure the workspace is clean, otherwise abort!
    if not is_workspace_clean():
        error("There are non-committed changes in the workspace. Make sure all changes are checked in before trying to release!\nRun `git status` for more info.")
    
    version = current_version()
    title("Current version: %s" % format_version(version))
    
    if options.release_type == "custom" and not options.custom:
        new_version = ask_for_custom_version()
    else:
        new_version = confirm_version(options.release_type)
    
    title("Prepare release for %s %s" % ("MacGPG", format_version(new_version)))
    
    
    print run("ls -l")
    
    print "New version: %s" % (new_version)
    
    return True

if __name__ == "__main__":
    try:
        sys.exit(not main())
    except SystemExit:
        pass
    except KeyboardInterrupt:
        print ""
        sys.exit(1)


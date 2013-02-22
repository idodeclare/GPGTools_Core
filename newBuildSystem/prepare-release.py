#!/usr/bin/env python

"""Prepare a new release for a GPGTools project.

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
import fileinput
import re
import shlex

from optparse import OptionParser, OptionValueError

sys.path.insert(1, os.path.join(os.getcwd(), './Dependencies/GPGTools_Core/python'))

from clitools import *
from clitools.color import *

CWD = os.getcwd()
VERSION_FILE = "Makefile.config"
VERSION_PATH = "%s/%s" % (CWD, VERSION_FILE)
RELEASE_NOTES_FOLDER = "Release Notes"
RELEASE_NOTES_FOLDER_PATH = "%s/%s" % (CWD, RELEASE_NOTES_FOLDER)
COMMIT_MSG = """Release of version: %s"""
SOURCE_BRANCH="deploy-dev"
DESTINATION_BRANCH="deploy-master"

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
    
    # Patch is not required to be set.
    if "patch" not in version:
        version["patch"] = 0
    
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
    """In order to release a new version, it's absolutely necessary that the
    workspace doesn't contain any changes.
    
    The only files which are allowed to be new or modified during a commit, are
    release notes, since the release script is responsible for adding them and checking
    them in.
    """
    out = run("git status --short").strip()
    # Release Notes/ entries are allowed, even necessary.
    lines = out.split("\n")
    clean = True
    for l in lines:
        if l != "" and l.find("Release Notes") == -1:
            clean = False
    
    return clean

def find_release_notes(version):
    """Checks if there's a release notes file available for the specified version.
    
    Optionally allows the developer to create one automatically.
    """
    release_notes_path = "%s/%s.json" % (RELEASE_NOTES_FOLDER_PATH, format_version(version))
    
    if not os.path.isfile(release_notes_path):
        return None
    
    return release_notes_path

def release_notes_file(version):
    return "%s/%s.json" % (RELEASE_NOTES_FOLDER_PATH, format_version(version))

def update_version(version):
    """Write the new version to the Makefile.config file."""
    version["revision"] = version["patch"]
    
    #fp = open(VERSION_PATH, "r")
    for line in fileinput.FileInput(VERSION_PATH, inplace=True):
        line = line.strip()
        if line.find("=") == -1:
            print line
            continue
            
        (key, value) = line.split("=")
        if key.lower() not in version.keys():
            print line
            continue
        
        line = re.sub(r'%s=([^\s]+)' % (key.upper()), '%s=%s' % (key.upper(), version[key.lower()]), line)
        print line
    
def checkin_release_info_and_tag(version):
    """Commit the release notes and the updated Makefile.config"""
    def run_or_undo(cmd, undo_cmds):
        try:
            run(cmd)
        except Exception, e:
            undo(undo_cmds, e)
    
    def undo(cmds, e):
        for c in cmds:
            print c
            run(c)
        error("Couldn't checkin updated version files.\n\n%s" % (e))
    
    undo_cmds = []
    
    run('git add "%s"' % (VERSION_PATH))
    undo_cmds.append('git reset HEAD "%s"' % (VERSION_PATH))
    
    run_or_undo('git add "%s"' % release_notes_file(version), 
                undo_cmds)
    undo_cmds.append('git reset HEAD "%s"' % (release_notes_file(version)))
    
    run_or_undo('git commit -m "%s"' % (COMMIT_MSG % (format_version(version))),
                undo_cmds)
    
    run_or_undo('git tag -a %s  -m "%s"' % (format_version(version), COMMIT_MSG % (format_version(version))),
                ['git reset --soft HEAD~1', 'git reset HEAD', 'git checkout %s' % (VERSION_PATH)])
    
    return True

def merge_and_push(src, dst):
    # Checkout the master branch.
    run("git checkout %s" % (dst))
    # Merge in the release info from the dev branch.
    run("git merge %s" % (src))
    # Push the master branch so the actual deployment of the release
    # is triggered on the build server.
    print("git push origin %s" % (dst))
    # Checkout the dev branch again, so the developer can continue to develop. 
    run("git checkout %s" % (src))

def format_version(version):
    return "%s.%s.%s" % (str(version["major"]), str(version["minor"]), str(version["patch"]))

def run(cmd):
    if type(cmd) == type(""):
        cmd = shlex.split(cmd)
    
    return check_output(cmd)

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
    
    # Find the release notes. If none are available, ask the developer
    # to create one for them.
    status("Finding Release Notes")
    
    release_notes = find_release_notes(new_version)
    if not release_notes:
        error("""There are no release notes available - can't continue!\n"""
              """Consider running `make release-notes version=%s` and try again.""" % (format_version(new_version)))
    
    status("  Found: %s/%s" % (RELEASE_NOTES_FOLDER, os.path.basename(release_notes)))
    
    # Release notes are available, not onto updating the version in the config
    # file and checking everything in.
    # Tag the version so it can be easily re-created.
    status("Update version in Makefile.config")
    update_version(new_version)
    status("Create version tag: v%s" % (format_version(new_version)))
    checkin_release_info_and_tag(new_version) 
    
    # Merge the changes into the master branch (or the one specified) and push it.
    status("Pushing release to start deployment")
    merge_and_push(SOURCE_BRANCH, DESTINATION_BRANCH)
    
    success("""The new release %s has been successfully prepared.\n"""
            """Check http://build-ml.gpgtools.org to follow further progress.""" % (format_version(new_version)))
    
    return True

if __name__ == "__main__":
    try:
        sys.exit(not main())
    except SystemExit:
        pass
    except KeyboardInterrupt:
        print ""
        sys.exit(1)


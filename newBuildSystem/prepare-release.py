#!/usr/bin/env python

"""Prepare a new release for a GPGTools project.

Possible version bumps are:
- Patch -> for bugfixes
- Minor -> small features
- Major -> major new features
- Pre-Release -> Alpha/Beta Versions of a new major version.

Following steps are executed in order to prepare a release:

1.) Check if the repository is clean. If there are any uncommitted changes, ABORT!
2.) Internally bump the version - don't update any files yet.
    Prompt the user to specify the version themselves but provide an educated guess based
    default.
    Possible options for version bumps:
        - Major -> 2.x.x to 3.x.x (--major)
        - Minor -> 2.1.x to 2.2.x (--minor)
        - Patch -> 2.1.1 to 2.1.2 (--patch)
        - Pre-Relelase -> 2.1(a|b)x (--pre)

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
import traceback

from optparse import OptionParser, OptionValueError

sys.path.insert(1, os.path.join(os.getcwd(), './Dependencies/GPGTools_Core/python'))

from clitools import *
from clitools.color import *

# Regular expression to match the minor or patch version part
# including the optional pre-release info.
VERSION_PRERELEASE = r"""(?P<%(part)s_pre>
    (?P<%(part)s_pre_type>a|b) # Matches the pre-release type (alpha or beta)
    (?P<%(part)s_pre_number>[0-9]+) # Matches the pre-release number
    (?P<%(part)s_pre_suffix>[\w\-]+)? # Matches an optional pre-suffix, e.g: -preview-ML1
)"""

VERSION_PART_AND_PRERELEASE = r"""((?P<%(part)s>\d+) # Matches the part number
                                 %(pre_release)s? # Pre-release info is optional of course.
                                )""" % ({"pre_release" : VERSION_PRERELEASE, "part": "%(part)s"})

VERSION_MATCHER = r"""(?P<major>\d+) # Matches the major version  number
                      \.
                      %s # Minor version number and maybe pre-release
                      (.%s)? # Patch version number and maybe pre-release. Is optional.
                   """ % (VERSION_PART_AND_PRERELEASE % ({"part": "minor"}), VERSION_PART_AND_PRERELEASE % ({"part": "patch"}))

VERSION_REGEX = re.compile(VERSION_MATCHER, re.X)
VERSION_PART_AND_PRERELEASE_REGEX = re.compile(VERSION_PART_AND_PRERELEASE % {"part": "general"}, re.X)
VERSION_PRERELEASE_REGEX = re.compile(VERSION_PRERELEASE % {"part": "general"}, re.X)

CWD = os.getcwd()
VERSION_FILE = "Makefile.config"
VERSION_PATH = "%s/%s" % (CWD, VERSION_FILE)
RELEASE_NOTES_FOLDER = "Release Notes"
RELEASE_NOTES_FOLDER_PATH = "%s/%s" % (CWD, RELEASE_NOTES_FOLDER)
COMMIT_MSG = """Release of version: %s"""

def parse_options():
    parser = OptionParser()
    parser.add_option("-m", "--major", dest="release_type", action="store_const", const="major", 
                      help="bump or create major version")
    parser.add_option("-i", "--minor", dest="release_type", action="store_const", const="minor",
                      help="bump or create minor version")
    parser.add_option("-p", "--patch", dest="release_type", action="store_const", const="patch",
                      help="bump or create a patch version")
    parser.add_option("-a", "--pre", dest="release_type", action="store_const", const="pre",
                      help="bump or create a pre-release version (alpha, beta)")
    parser.add_option("-t", "--test", dest="test", action="store_true", default=False,
                      help="run in test mode. Disables some checks and uses deploy-master and deploy-dev as default branches.")
    parser.add_option("-u", "--updates", dest="changes_branch", default=None)
    parser.add_option("-s", "--master", dest="master_branch", default="master")
    
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
        
        version = None
        try:
            version = parse_version(value)
        except Exception, e:
            raise OptionValueError(str(e))
        
        parser.values.custom = version
    
    parser.add_option("-c", "--custom", dest="custom", action="callback", callback=parse_custom_version,
                      nargs=1, help="use custom version VERSION", metavar="VERSION")
    
    (options, args) = parser.parse_args()
    
    
    if not options.release_type:
        options.release_type = "custom"
    
    options.changes_branch = options.changes_branch != "dev" and options.changes_branch or current_git_branch()
    if options.test:
        options.master_branch = options.master_branch != "master" and options.master_branch or "deploy-master"
    
    return (options, args)

def parse_version(version_raw):
    """Check if the format of the version string represents a valid version.
    
    Each version consists of at least 2 parts and max 3 parts.
    Possible versions:
        major.minor.patch
        major.minor
        major.minor(a|b)x<suffix>
        major.minor.patch(a|b)x<suffix>
    """
    if not version_raw:
        raise Exception("version must not be None")
    
    match = VERSION_REGEX.match(version_raw)
    
    if not match:
        raise Exception("invalid version. Please check")
    
    # We have a valid version, now let's make sure that there's only
    # one pre-release info for either minor or patch but not both.
    version_info = match.groupdict()
    
    if version_info["minor_pre"] and version_info["patch_pre"]:
        raise Exception("Found pre-release info for both minor and patch. Only one is allowed.")
    
    new_version = {"major": int(version_info["major"]), "minor": int(version_info["minor"]), 
                   "patch": version_info["patch"] and int(version_info["patch"]) or None,
                   "pre_type": None, "pre_number": None, "pre_suffix": None, "pre": None}
    
    # Make sure, there's not patch info, if pre-release info for minor is available.
    if version_info["minor_pre"] and version_info["patch"]:
        raise Exception("invalid version. Found pre-release info for minor and a patch version.")
    
    # Add pre-release info if available.
    if version_info["patch_pre"] or version_info["minor_pre"]:
        pre_type = version_info["patch_pre"] and "patch" or "minor"
        
        new_version["pre_type"] = version_info[pre_type + "_pre_type"]
        new_version["pre_number"] = int(version_info[pre_type + "_pre_number"])
        new_version["pre_suffix"] = version_info[pre_type + "_pre_suffix"]
    
    # Check if the version matches the raw_version, otherwise
    # raise an error, because something went wrong (not properly formatted version)
    if format_version(new_version) != version_raw:
        raise Exception("parsed version '%s' doesn't match input '%s'" % (format_version(new_version), version_raw))
    
    set_pre_part(new_version)
    
    return new_version

def bailout(message):
    error("%s" % (message))
    sys.exit(1)

def ask_for_custom_version():
    version = None
    while True:
        value = ask_for("Please enter the new version")
        try:
            version = parse_version(value)
            break
        except Exception, e:
            print e
    
    return version

def current_version():
    variables = []
    config = tool_config()
    
    raw_version = "%s.%s%s%s%s" % (config["MAJOR"] or "0", config["MINOR"] or "0",
                                   (not config["REVISION"] and config["PRERELEASE"]) and config["PRERELEASE"] or "",
                                   config["REVISION"] and "%s" % (config["REVISION"]) or "",
                                   (config["REVISION"] and config["PRERELEASE"]) and config["PRERELEASE"] or "")
    
    try:
        version = parse_version(raw_version)
    except Exception, e:
        bailout("Couldn't parse version. This might be a bug in this program.\n%s" % (traceback.format_exc()))
    
    return version
    

def next_version(version, release_type, custom_version=None):
    if not release_type in version and release_type != "pre":
        bailout("Allowed values for release_type: minor, major, patch, pre - received: %s" % (release_type))
    
    new_version = dict(version)
    
    if release_type == "pre":
        # Figure out what the current pre version is.
        # The pre-release version always consists of the a(lpha) or b(eta)
        # letter and a number, in addition there might be other letters after
        # the number which we will ignore.
        if not version["pre_type"]:
            reset_version_parts(new_version, ("pre",), {"pre_number": 0, "pre_type": "a"})
        
        new_version["pre_number"] = new_version["pre_number"] + 1
        set_pre_part(new_version)
    else:
        if not new_version[release_type] and not custom_version:
            new_version[release_type] = 0
        
        new_version[release_type] = [custom_version, new_version[release_type] + 1][not custom_version]
    
    if release_type == "minor" or release_type == "major":
        reset_version_parts(new_version, ("patch", "pre"))
        
    if release_type == "major":
        reset_version_parts(new_version, ("minor", "pre"))
    
    return new_version

def set_pre_part(version):
    pre = None
    if not version["pre_type"]:
        return
    
    version["pre"] = "%s%s%s" % (version["pre_type"], version["pre_number"], version["pre_suffix"] or "")

def reset_version_parts(version, parts, reset_dict=None):
    for p in parts:
        if p == "pre":
            version["pre_type"] = None
            version["pre_number"] = None
            version["pre_suffix"] = None
        else:
            version[p] = 0
    
    if reset_dict:
        version.update(reset_dict)
    
    # Re-create pre part if necessary.
    if "pre" in parts:
        set_pre_part(version)

def confirm_version(release_type):
    new_version = next_version(current_version(), release_type)
    proposal = new_version[release_type]
    
    part_dict = None
    while True:
        value = ask_for("New %s version [default %s]" % (release_type.replace("pre", "pre-release"), proposal))
        if value == "":
            value = proposal
            break
        
        part_dict = validate_part(release_type, value)
        if not part_dict:
            if release_type == "pre":
                print "Pre-release version must be of format: (a|b)<number><suffix>"
            else:
                print "Version hast to be a number"
        else:
            break
    
    if part_dict:
        new_version.update(part_dict)
    set_pre_part(new_version)
    
    return new_version

def validate_part(part, value):
    part_dict = None
    
    if part == "pre":
        match = VERSION_PRERELEASE_REGEX.match(value)
        if match:
            version_info = match.groupdict()
            part_dict = {"pre_type": version_info["general_pre_type"],
                         "pre_number": version_info["general_pre_number"],
                         "pre_suffix": version_info["general_pre_suffix"]}
    else:
        if value.isdigit():
            part_dict = {part: value}
    
    return part_dict

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

def workspace_is_behind():
    """In order to release new version, it's necessary that the local branch
    is not behind."""
    # There's no easy way to do this, but it's easiest to simply parse this.
    status = run("git status")
    if status.find("branch is behind") != -1:
        return True
    
    return False

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
    # Adapt the version info to match the expected var names
    # in Makefile.config
    version = dict(version)
    version["revision"] = version["patch"]
    del version["patch"]
    if version["pre"]:
        version["prerelease"] = version["pre"]
        for p in ["pre", "pre_suffix", "pre_number", "pre_type"]: 
            del version[p]
    
    key_order = ("major", "minor", "revision", "prerelease")
    
    for line in fileinput.FileInput(VERSION_PATH, inplace=True):
        line = line.strip()
        if line.find("=") == -1 and line.find("versioning.sh") == -1:
            print line
            continue
        
        # If the current line is a variable declaration and
        # not part of the version info, simply print it, otherwise
        # omit it, since we'll print them at the end.
        if line.find("=") != -1:
            (key, value) = line.split("=")
            if key.lower() not in version.keys():
                print line
                continue
        
        # If the current line is including versioning.sh, print the
        # version info first and then add that line.
        if line.find("versioning.sh") != -1:
            for key in key_order:
                if key in version and version[key]:
                    print "%s=%s" % (key.upper(), version[key])
                    
            print "\n%s" % (line)
            
    

def current_git_branch():
    return run("git rev-parse --abbrev-ref HEAD").strip()

def checkout_master_and_merge(master_branch, changes_branch):
    """Checkout the master branch and merge in the changes from changes_branch."""
    
    # Check if the is already master, in which case there's no need
    # to check it out again.
    current_branch = current_git_branch()
    
    if current_branch != master_branch:
        run_or_error("git checkout %s" % (master_branch),
                     "Failed to checkout master branch!\n%s" + 
                     "\nConsider running `%s` to completely revert the release commit." % (
                        emphasize("git reset --hard HEAD~1")), silent=True)
    
    # Check if this is the master branch now, otherwise, bail out,
    # something must have gone terribly wrong.
    current_branch = current_git_branch()
    
    if current_branch != master_branch:
        bailout("Checking out the master branch %s failed. Abort" % (current_branch))
    
    # On the correct branch, now merge in the changes.
    try:
        run("git merge %s" % (changes_branch))
    except: 
        bailout("Failed to merge in changes from %s\nPlease undo the merge manually." % (changes_branch))
    

def checkin_release_info(version):
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
    
    return True

def tag_release(version):
    try:
        run('git tag -a %s -m "%s"' % (format_version(version), COMMIT_MSG % format_version(version)))
    except:
        bailout("Failed to create version tag. Abort")

def push_release(master_branch):
    # Push the master branch so the actual deployment of the release
    # is triggered on the build server.
    try:
        print("git push origin %s" % (master_branch))
    except Exception, e:
        print e
        error("Failed to push release to github. Abort")

def format_version(version):
    version_parts = []
    version_parts.append(version["major"] or "0")
    version_parts.append(version["minor"] or "0")
    
    if version["patch"]:
        version_parts.append("%s%s" % (version["patch"], version["pre_type"] and "%s%s%s" % (version["pre_type"], version["pre_number"], version["pre_suffix"] or "") or ""))
    else:
        version_parts[1] = "%s%s" % (version_parts[1], version["pre_type"] and "%s%s%s" % (version["pre_type"], version["pre_number"], version["pre_suffix"] or "") or "")
    
    return ".".join([str(x) for x in version_parts])
    
def git_tag_exists(version):
    tag = run("git tag -l %s" % (version)).strip()
    if tag == version:
        return True
        
    return False

def main():
    (options, args) = parse_options()
    
    original_branch = current_git_branch()
    
    # Make sure the workspace is clean, otherwise abort!
    if not options.test and not is_workspace_clean():
        error("There are non-committed changes in the workspace. Make sure all changes are checked in before trying to release!\nRun `git status` for more info.")
    
    if not options.test and not workspace_is_behind():
        error("There are commits which were not yet pulled.\n"
              "Make sure to pull before trying to release!")
    
    version = current_version()
    title("Current version: %s" % format_version(version))
    
    if options.release_type == "custom":
        if not options.custom:
            new_version = ask_for_custom_version()
        else:
            new_version = options.custom
    else:
        new_version = confirm_version(options.release_type)
    
    if format_version(new_version) == format_version(version):
        bailout("You're trying to release the same version %s again." % (format_version(new_version)))
    
    title("Prepare release for %s %s" % (tool_config("name"), format_version(new_version)))
    
    # Check if there's already a tag for this version.
    if git_tag_exists(format_version(new_version)):
        error("Tag for version %s already exists!" % (format_version(new_version)))
    
    # Find the release notes. If none are available, ask the developer
    # to create one for them.
    status("Finding Release Notes")
    
    release_notes = find_release_notes(new_version)
    if not release_notes:
        should_create = ask_with_expected_answers("Can't find release notes. Would you like to create them now? [default y]", 
                                              ["y", "n"], 
                                              default="y")
        if should_create == "n":
            error("""There are no release notes available - can't continue!\n"""
                  """Consider running `make release-notes version=%s` and try again.""" % (format_version(new_version)))
        else:
            ret = call(["make", "release-notes", "version=%s" % (format_version(new_version))])
            if ret != 0:
                error("%s" % ("Failed to create release notes. Abort"))
            
            release_notes = find_release_notes(new_version)
    
    status("  Found: %s/%s" % (RELEASE_NOTES_FOLDER, os.path.basename(release_notes)))
    
    should_continue = ask_with_expected_answers("%s\nAre you sure you want to proceed? [default n]" % (
        emphasize("The version is now being updated and the deploy process started.")), ["y", "n"], default="n")
    
    if should_continue != "y":
        error("Aborting release of %s %s upon users request." % (tool_config("name"), format_version(new_version)))
    
    # Updating the version in the config file.
    status("Update version in Makefile.config")
    update_version(new_version)
    
    # Checkin the updated config file and release notes.
    checkin_release_info(new_version)
    
    # Release notes are available, now onto checking out the master branch
    # if we're not already on it and branch in the changes from dev or any given branch.
    status("Checking out master %s and merging changes from %s" % (options.master_branch, 
                                                                   options.changes_branch))
    checkout_master_and_merge(options.master_branch, options.changes_branch)
    
    # And ready to create the version tag.
    status("Create version tag: v%s" % (format_version(new_version)))
    tag_release(new_version)
    
    # Merge the changes into the master branch (or the one specified) and push it.
    status("Pushing release to start deployment")
    #push_release(options.master_branch)
    
    success("""The new release %s has been successfully prepared.\n"""
            """Check http://build-ml.gpgtools.org to follow further progress.""" % (format_version(new_version)))
    
    # Re-checkout the original branch
    if original_branch != current_git_branch():
        run("git checkout %s" % (original_branch), silent=True)
    
    return True

if __name__ == "__main__":
    try:
        sys.exit(not main())
    except SystemExit:
        pass
    except KeyboardInterrupt:
        print ""
        sys.exit(1)


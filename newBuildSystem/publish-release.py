#!/usr/bin/env python

"""Publish a new version of a GPGTools tool on the website.

Inserts the new version in the <tool>-versions.json in order
to update the website info and the sparkle appcast.
"""

import os, sys
sys.path.insert(1, os.path.join(os.getcwd(), './Dependencies/GPGTools_Core/python'))

import json
import time

from optparse import OptionParser, OptionValueError

from __init__ import *
from clitools import *
from clitools.color import *

CWD = os.getcwd()
BUILD_DIR = os.path.join(CWD, "build")
DOWNLOAD_BASE_URL = "https://releases.gpgtools.org"
WEBSITE_REPOSITORY_URL = "gpgtools@gpgtools.org:git-repositories/release-info.git"
WEBSITE_REPOSITORY_BRANCH = "master"
WEBSITE_FOLDER = os.path.join(BUILD_DIR, "gpgtools-website")

def parse_options():
    parser = OptionParser()
    parser.add_option("-i", "--min-os", dest="minOS")
    parser.add_option("-m", "--max-os", dest="maxOS")
    parser.add_option("-b", "--base-url", dest="base_url")
    parser.add_option("-r", "--website-folder", dest="website_folder")
    
    (options, args) = parser.parse_args()
    
    if not options.website_folder:
        options.checkout_repository = True
    else:
        options.checkout_repository = False
    
    if options.website_folder and not os.path.isdir(options.website_folder):
        parser.error("Website folder doesn't exist at %s" % options.website_folder)
    
    if not tool_config("name"):
        parser.error("Not able to read tool name. Make sure Makefile.config exists in the current folder.")
    
    # Check environment variables for configuration.
    options.minOS = options.minOS or os.environ.get("MIN_OS")
    if not options.minOS:
        options.minOS = "10.7"
    
    options.maxOS = options.maxOS or os.environ.get("MAX_OS")
    
    options.website_folder = options.website_folder or os.environ.get("WEBSITE_FOLDER")
    
    options.base_url = options.base_url or os.environ.get("BASE_URL")
    if not options.base_url:
        options.base_url = DOWNLOAD_BASE_URL
    
    return (options, args)

def main():
    """Updates the websites version-<tool>.json file with the current
       release information.
    """
    (options, args) = parse_options()
    
    title("Publish %s %s release on gpgtools.org" % (tool_config("name"), tool_config("version")))
    
    website_folder = WEBSITE_FOLDER
    if options.checkout_repository and not os.path.isdir(options.website_folder):
        if not os.path.isdir(website_folder):
            status("No website repository found. Checking it out from github")
            run_or_error("git clone %s -b %s %s" % (WEBSITE_REPOSITORY_URL, WEBSITE_REPOSITORY_BRANCH, path_to_script(WEBSITE_FOLDER)),
                         "Failed to checkout gpgtools website.\n"
                         "Try to checkout the website manually and specify the path by using --website-folder")
    else:
        website_folder = options.website_folder
    
    short_name = nname(tool_config("name"))
    versions_file = "%s-versions.json" % (short_name)
    versions_path = os.path.join(website_folder, versions_file)
    release_notes = "%s.md" % (tool_config("version"))
    release_notes_file = os.path.join("Release Notes", release_notes)
    release_notes_path = os.path.join(CWD, release_notes_file)
    buildnr = tool_config("build_version")
    dmg = tool_config("dmgName")
    dmg_path = os.path.join(BUILD_DIR, dmg)
    dmg_url = "%s/%s" % (options.base_url, dmg)
    
    json_config = dict(indent=4, separators=(',', ': '), sort_keys=True)
    
    
    # Check whether the release-notes exists.
    if not os.path.isfile(release_notes_path):
        error("Couldn't find the release notes for this version: %s" % (release_notes_file))
    
    
    # Check whether the website-folder exists.
    if not os.path.isdir(website_folder):
        error("Couldn't find website repository: %s" % (website_folder))
    
    # Change into the website repository.
    os.chdir(website_folder)
    
    # Reset the repository status.
    status("git reset")
    run_or_error("git reset HEAD", "Failed to reset the website repository.", silent=True)
    status("git checkout")
    run_or_error("git checkout .", "Failed to undo local changes.", silent=True)
    
    # Pull new changes in.
    status("git pull")
    run_or_error("git pull origin %s" % (WEBSITE_REPOSITORY_BRANCH), "Failed to update website repository.", silent=True)


    # Check whether the versions-file exists.
    if not os.path.isfile(versions_path):
        error("Couldn't find the versions file for %s" % (versions_path))
        
    
    # Load release notes.
    status("Load release notes from %s" % (release_notes_file))
    release_notes = convert_markdown_to_release_notes(filename=release_notes_path)
    if release_notes[1]:
        error("Failed to load release notes file\nError: %s" % (release_notes[1]))
    release_notes = release_notes[0]
    
    if not release_notes:
        error("Failed to load release notes file")
    
    
    # Find out the filesize of the release dmg.
    filesize = 0
    try:
        stat = os.stat(dmg_path)
        filesize = stat.st_size
    except Exception, e:
         error("Failed to determine release disk image file size\nError: %s" % (e))
    
    dmg_hash = sha1_hash(dmg_path)
    
    release = {"version": tool_config("version"), "build": buildnr, "release_date": int(time.time()),
               "checksum": dmg_hash, "info": release_notes["info"],
               "sparkle": {"url": dmg_url, "size": filesize, "minOS": options.minOS},
               "newest-version": True}
    if options.maxOS:
        release["sparkle"]["maxOS"] = options.maxOS
    
    
    # Load the versions file of the website to add this version.
    current_versions = None
    try:
        with open(versions_path, "r") as fp:
            current_versions = json.load(fp)
    except Exception, e:
        error("Failed to load the website's %s versions file\n* %s" % (tool_config("name"), e))
    
    
    # Update the newest-version flag of each current version.
    for entry in current_versions:
        if entry["version"] == release["version"]:
            error("Version %s was already released." % (release["version"]))
        entry["newest-version"] = False
    
    
    # Insert the new version to the current versions as first version.
    current_versions.insert(0, release)
    
    status("Add version %s %s to %s version file" % (tool_config("name"), tool_config("version"), 
                                                     tool_config("name")))
    # Save the versions.
    try:
        with open(versions_path, "w") as fp:
          json.dump(current_versions, fp, **json_config)
    except Exception, e:
        error("Failed to save the new version to the website's %s versions file\n* %s" % (tool_config("name"), e))
    
        
    # Add the versions file.
    run_or_error("git add %s" % (path_to_script(versions_path)), "Failed to checkin the versions file.", silent=True)
    
    
    # Commit the versions file.
    run_or_error('git commit -m "Adding release of %s: %s"' % (tool_config("name"), tool_config("version")),
                 "Failed to commit the versions file changes.", silent=True)
    
    # Push the new version info.
    status("Push changes to remote repository")
    run_or_error("git push origin %s" % (WEBSITE_REPOSITORY_BRANCH), "Failed to push changes to server.", silent=True)
    
    success("Release was published successfully.")
    
    return True
    
if __name__ == "__main__":
    try:
        sys.exit(not main())
    except KeyboardInterrupt:
        print ""
        sys.exit(1)
        
#!/usr/bin/env python

"""Prepare a release notes file.

The release notes file will include all commits from
the last tag to HEAD.

The commit log should help creating the actual release notes
and will check for [FEATURE] or [FIX] in order to find
feature commits and bug fixes.
"""

import os, sys
sys.path.insert(1, os.path.join(os.getcwd(), './Dependencies/GPGTools_Core/python'))

from optparse import OptionParser
import json

from clitools import *
from clitools.color import *

CWD = os.getcwd()
FIELD_SEP = "--end-field--"
COMMIT_SEP = "--end-commit--"
TITLE_FIELD = "Title:"
BODY_FIELD = "Body:"
LOG_FORMAT = "%(title_field)s %%s%(field_sep)s%%n%(body_field)s %%b%(field_sep)s%%n%(commit_sep)s" % (
    {"field_sep": FIELD_SEP, "commit_sep": COMMIT_SEP, "title_field": TITLE_FIELD, 
     "body_field": BODY_FIELD})
FIX_PREFIX = "[FIX]"
FEATURE_PREFIX = "[FEATURE]"
RELEASE_NOTES_FOLDER = "Release Notes"
RELEASE_NOTES_FILE = "%s.json"

def parse_options():
    parser = OptionParser(usage="usage: %prog [options] <version>")
    parser.add_option("-f", "--from", dest="from_tag", metavar="FROM_TAG", help="The tag which should be used as start tag")
    parser.add_option("-t", "--to", dest="to_tag", metavar="TO_TAG", help="The tag which should be used as end tag")
    
    (options, args) = parser.parse_args()
    
    if len(args) > 1:
        print __doc__
        parser.print_usage()
        sys.exit(1)
    
    options.from_tag = options.from_tag or current_git_tag()
    if not options.from_tag:
        parser.error("Couldn't find start tag. Please specify one manually")
    options.to_tag = options.to_tag or "HEAD"
    
    return (options, args)

def current_git_tag():
    return run("git describe --abbrev=0", silent=True)

def commit_log(from_tag, to_tag):
    commit_log = run('git log %s..%s --pretty=format:"%s"' % (from_tag, to_tag, LOG_FORMAT))
    return commit_log

def build_release_notes_from_commit_log(commit_log):
    commit_entry = commit_log.split(COMMIT_SEP)
    
    fixes = []
    features = []
    
    for entry in commit_entry:
        fields = entry.split(FIELD_SEP)
        title = fields[0][len(TITLE_FIELD)+1:].strip()
        body = ""
        if len(fields) > 1:
            body = fields[1][len(BODY_FIELD)+1:].strip()
        
        line = "%s%s" % (title, body and "\n\n%s" % body or "")
        if title.find(FEATURE_PREFIX) != -1:
            features.append(line)
        else:
            fixes.append(line)
    
    return {"info": {"features": features, "fixes": fixes}}

def save_release_notes(release_notes, version):
    path = os.path.join(CWD, RELEASE_NOTES_FOLDER)
    if not os.path.isdir(path):
        os.mkdir(RELEASE_NOTES_FOLDER)
    
    file_path = os.path.join(path, RELEASE_NOTES_FILE % (version))
    
    json_config = dict(indent=4, separators=(',', ': '), sort_keys=True)
    
    release_notes_json = json.dumps(release_notes, **json_config)
    with open(file_path, "w") as fp:
        fp.write(release_notes_json)
    
    # Open the file in the favorite editor.
    open_in_editor(file_path)
    
    # Check if the contents of the file are exactly the same.
    # In that case, abort!
    content = open(file_path, "r").read()
    
    if content == release_notes_json:
        os.unlink(file_path)
        error("You can't use the exact commit log as the release notes!", exitcode=4)
    
    return True

def main():
    (options, args) = parse_options()
    
    tool_name = tool_config("name")
    tool_version = len(args) == 1 and args[0] or tool_config("version")
    
    if not tool_version:
        error("Version is not set. Abort")
    
    # Check if the version file doesn't already exist.
    if os.path.isfile(os.path.join(CWD, RELEASE_NOTES_FOLDER, RELEASE_NOTES_FILE % (tool_version))):
        error("Release notes file already exists")
    
    title("Creating Release Notes for %s v%s" % (tool_name, tool_version))
    status("Retrieving commit log from %s to %s" % (options.from_tag, options.to_tag))
    
    log = commit_log(options.from_tag, options.to_tag)
    
    status("Building release notes from commit log")
    
    release_notes = build_release_notes_from_commit_log(log)
    
    status("Save release notes to Release Notes/%s.json" % (tool_version))
    
    save_release_notes(release_notes, tool_version)
    
    success("Successfully created the release notes!")
    
    return True

if __name__ == "__main__":
    try:
        sys.exit(not main())
    except KeyboardInterrupt:
        print ""
        sys.exit(1)
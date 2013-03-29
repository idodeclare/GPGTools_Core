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
import re
import tempfile
import webbrowser
import time

from __init__ import *
from clitools import *
from clitools.color import *
from vendor import markdown

CWD = os.getcwd()
FIELD_SEP = "--end-field--"
COMMIT_SEP = "--end-commit--"
TITLE_FIELD = "Title:"
BODY_FIELD = "Body:"
LOG_FORMAT = "%(title_field)s %%s%(field_sep)s%%n%(body_field)s %%b%(field_sep)s%%n%(commit_sep)s" % (
    {"field_sep": FIELD_SEP, "commit_sep": COMMIT_SEP, "title_field": TITLE_FIELD, 
     "body_field": BODY_FIELD})
FIX_PREFIXES = ["FIX", "PATCH", "BUGFIX"]
FEATURE_PREFIXES = ["NEW", "FEATURE"]
RELEASE_NOTES_FOLDER = "Release Notes"
RELEASE_NOTES_FILE = "%s.md"
RELEASE_NOTES_PATH = None
PREVIEW_URL = "https://gpgtools.org/releases/%s/preview-release-notes"

def parse_options():
    parser = OptionParser(usage="usage: %prog [options] <version>")
    parser.add_option("-f", "--from", dest="from_tag", metavar="FROM_TAG", help="The tag which should be used as start tag")
    parser.add_option("-t", "--to", dest="to_tag", metavar="TO_TAG", help="The tag which should be used as end tag")
    parser.add_option("-p", "--preview-url", dest="preview_url", metavar="PREVIEW_URL", 
                      help="The URL which is able to preview release notes")
    (options, args) = parser.parse_args()
    
    if len(args) > 1:
        print __doc__
        parser.print_usage()
        sys.exit(1)
    
    options.from_tag = options.from_tag or current_git_tag()
    if not options.from_tag:
        parser.error("Couldn't find start tag. Please specify one manually")
    options.to_tag = options.to_tag or "HEAD"
    
    options.preview_url = options.preview_url or os.getenv("PREVIEW_URL", PREVIEW_URL % tool_config("name").lower())
    
    return (options, args)

def current_git_tag():
    return run("git describe --abbrev=0", silent=True)

def commit_log(from_tag, to_tag):
    commit_log = run('git log %s..%s --pretty=format:"%s"' % (from_tag, to_tag, LOG_FORMAT))
    return commit_log

def build_release_notes_from_commit_log(commit_log):
    commit_entry = commit_log.split(COMMIT_SEP)
    
    temp_fixes = []
    temp_features = []
    temp_discarded = []
    
    for entry in commit_entry:
        # A log entry is considered to be describing a feature if
        # either FEATURE_PREFIX is found or if two \n\n are found after
        # the first line. 
        is_feature = False
        
        fields = entry.split(FIELD_SEP)
        title = fields[0][len(TITLE_FIELD)+1:].strip()
        
        body = ""
        if len(fields) > 1:
            body = fields[1][len(BODY_FIELD)+1:].strip()
        
        title.replace("\r\n", "\n")
        body.replace("\r\n", "\n")
        
        # Ignore any entries which don't have either prefix.
        # Only if no commmits with prefixes are found, add them all
        # (This will be the case in older releases)
        is_fix = len(["[%s]" % prefix for prefix in FIX_PREFIXES if title.find("[%s]" % prefix) != -1]) > 0
        is_feature = len(["[%s]" % prefix for prefix in FEATURE_PREFIXES if title.find("[%s]" % prefix) != -1]) > 0
        
        if not is_fix and not is_feature:
            temp_discarded.append({"title": title, "body": body != "" and body or None}) 
        elif is_feature:
            temp_features.append({"title": title, "body": body})
        elif is_fix:
            temp_fixes.append({"title": title, "body": None})
    
    features = []
    fixes = []
    
    # We only have old commmit messages, so let's include everyone.
    # Not good, but well.
    if not len(temp_features) and not len(temp_fixes):
        for entry in temp_discarded:
            if entry["body"]:
                features.append({"title": entry["title"], 
                                 "description": [x.strip() for x in entry["body"].split("\n")]})
            else:
                line = "%s%s" % (entry["title"], entry["body"] and "\n\n%s" % entry["body"] or "")
                # Strip white space from each line.
                line = "\n".join([x.strip() for x in line.split("\n")])
                fixes.append(line)
    else:
        for entry in temp_features:
            # Find the prefix and replace it.
            prefix = ["[%s]" % prefix for prefix in FIX_PREFIXES if entry["title"].find("[%s]" % prefix) != -1][0]
            title = re.sub(r"^\s*%s\s*" % (re.escape(prefix)), r"", entry["title"])
            description = [x.strip() for x in entry["body"].split("\n")]
            features.append({"title": title, "description": description})
        
        for entry in temp_fixes:
            # Find the prefix and replace it.
            prefix = ["[%s]" % prefix for prefix in FIX_PREFIXES if entry["title"].find("[%s]" % prefix) != -1][0]
            title = re.sub(r"^\s*%s\s*" % (re.escape(prefix)), r"", entry["title"])
            fixes.append(title)
    
    return {"info": {"features": features, "fixes": fixes}}

def preview_release_notes(version, release_notes):
    preview_url = PREVIEW_URL
    html_template = """
        <html>
            <head>
                <script src="http://code.jquery.com/jquery-1.9.1.min.js"></script>
            </head>
        </html>
        <body>
            <form action="%s" method="post">
                <textarea type="hidden" id="release_notes" name="release_notes"></textarea>
            </form>
            
            <script>
                var release_notes = '%s'
                $("#release_notes").val(release_notes)
                $("form").submit()
            </script>
        </body>
    """
    
    version_info = {"version": version, "release_date": int(time.time())}
    version_info.update(release_notes)
    
    # Create a temporary file.
    tempfh = tempfile.NamedTemporaryFile(suffix=".html", delete=False)
    path = tempfh.name
    tempfh.write(html_template % (preview_url, json.dumps(version_info).replace("'", "\\\'").replace("""\\\"""", """\\\\\"""")))
    # Write changes to file.
    tempfh.flush()
    
    # Open in webbrowser.
    webbrowser.open("file://%s" % (path))
    
    return tempfh

def save_release_notes(release_notes, version):
    path = os.path.join(CWD, RELEASE_NOTES_FOLDER)
    if not os.path.isdir(path):
        os.mkdir(RELEASE_NOTES_FOLDER)
    
    file_path = os.path.join(path, RELEASE_NOTES_FILE % (version))
    
    md = convert_release_notes_to_markdown(release_notes, version)
    
    with open(file_path, "w") as fp:
        fp.write(md)
    
    release_notes = None
    while True:
        # Open the file in the favorite editor.
        open_in_editor(file_path)
        
        # Check if the contents of the file are exactly the same.
        # In that case, abort!
        content = open(file_path, "r").read()
        if content == md:
            error("You can't use the exact commit log as the release notes!", noexit=True)
            continue
        
        # Check if the markdown can be converted back.
        try:
            release_notes = convert_markdown_to_release_notes(content)
        except:
            error("Invalid Markdown. Please verify!", noexit=True)
            continue
        
        if release_notes[1]:
            error(release_notes[1], noexit=True)
            continue
        
        # Release notes are okay, prompt for preview.
        release_notes = release_notes[0]
        preview = ask_with_expected_answers("Do you want to see a preview of the release notes? [yes|no, default yes]:", ["yes", "no"], default="yes")
        if preview != "yes":
            break
        
        html_file = preview_release_notes(version, release_notes)
        okay = ask_with_expected_answers("Are the release notes as you want them? [yes|no, default yes]:", ["yes", "no"], default="yes")
        # Remove the file.
        os.unlink(html_file.name)
        if okay == "yes":
            break
    
    return True

def main():
    global RELEASE_NOTES_PATH, PREVIEW_URL
    (options, args) = parse_options()
    
    tool_name = tool_config("name")
    tool_version = len(args) == 1 and args[0] or tool_config("version")
    
    if not tool_version:
        error("Version is not set. Abort")
    
    PREVIEW_URL = options.preview_url
    
    RELEASE_NOTES_PATH = os.path.join(CWD, RELEASE_NOTES_FOLDER, RELEASE_NOTES_FILE % (tool_version))
    # Check if the version file doesn't already exist.
    if os.path.isfile(RELEASE_NOTES_PATH):
        error("Release notes file %s already exists" % (RELEASE_NOTES_FILE % (tool_version)))
    
    title("Creating Release Notes for %s v%s" % (tool_name, tool_version))
    status("Retrieving commit log from %s to %s" % (options.from_tag, options.to_tag))
    
    log = commit_log(options.from_tag, options.to_tag)
    
    status("Building release notes from commit log")
    
    release_notes = build_release_notes_from_commit_log(log)
    
    status("Save release notes to Release Notes/%s.json" % (tool_version))
    
    save_release_notes(release_notes, tool_version)
    
    success("Successfully created the release notes!")
    
    return True

def cleanup():
    if RELEASE_NOTES_PATH and os.path.isfile(RELEASE_NOTES_PATH):
        os.unlink(RELEASE_NOTES_PATH)

if __name__ == "__main__":
    try:
        sys.exit(not main())
    except KeyboardInterrupt:
        cleanup()
        sys.exit(1)

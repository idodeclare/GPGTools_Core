#!/usr/bin/env python

"""Publish a nightly version of a GPGTools tool on nightly.gpgtools.org

Updates the appcast.xml file of the tool in order to include
the new nightly disk image.
"""

import os, sys
sys.path.insert(1, os.path.join(os.getcwd(), './Dependencies/GPGTools_Core/python'))
sys.path.insert(1, os.path.join(os.getcwd(), './Dependencies/GPGTools_Core/newBuildSystem'))

import time
import json
import cgi

from clitools import *
from clitools.color import *

try:
    import lxml
    from pyquery_lxml_extension import ElementMaker, pq
except ImportError:
    error("Please install lxml and cssselect by running `%s` and then `%s`" % (
        emphasize("STATIC_DEPS=true sudo pip install lxml==3.1.0"),
        emphasize("sudo pip install cssselect")))

CWD = os.getcwd()
NIGHTLY_BASE_PATH = os.getenv("NIGHTLY_BUILD_BASE_PATH", "/tmp/gpgtools.org-nightly-releases")
APPCASTER = "./Dependencies/GPGTools_Core/newBuildSystem/appcaster.py"
BUILD_JOB_URL = os.getenv("JOB_URL")
BUILD_SERVER_USER = os.getenv("JENKINS_USER")
BUILD_SERVER_TOKEN = os.getenv("JENKINS_TOKEN")
BUILD_NR = int(os.getenv("BUILD_NUMBER"))
BUILD_REVISION = os.getenv("GIT_COMMIT")

E = ElementMaker()

def html_for_release_notes(release_notes, tool):
    title = "Test Release Notes"
    minOS = "10.6"
    maxOS = None
    
    def klass(l):
        if type(l) == ():
            return " ".join(l)
        return l
    
    def attrs(*attr_list):
        attrs = []
        if len(attr_list) % 2 != 0:
            return ""
        for i in range(0, len(attr_list), 2):
            attrs.append((attr_list[i], attr_list[i+1]))
        
        return dict(attrs)
        
    def html_template():
        root = E("html",
            E("head",
                E("meta", charset="utf-8"),
                E("title", title),
                E("link", rel="stylesheet", href="https://gpgtools.org/css/sparkle-release-notes.1364588334.css"),
                E("link", rel="stylesheet", href="https://gpgtools.org/css/futura-general.css")
            ),
            E("body",
                E("div", 
                    E("div", {"class": "sparkle-release-notes"}),
                    role="main"
                )
            )
        )
        
        return root
    
    def date_suffix(day):
        "English ordinal suffix for the day of the month, 2 characters; i.e. 'st', 'nd', 'rd' or 'th'"
        if day in (11, 12, 13): # Special case
            return 'th'
        last = day % 10
        if last == 1:
            return 'st'
        if last == 2:
            return 'nd'
        if last == 3:
            return 'rd'
        return 'th'
    
    root = html_template()
    
    def add_release(tool):
        options = {"class": "version", "data-version": tool.get("version"), "data-build": tool.get("build_version")}
        date = time.strftime("%B %d{S} %Y at %H:%M").replace("{S}", date_suffix(time.gmtime().tm_mday))
        if minOS:
            options["data-min-os"] = minOS
        if maxOS:
            options["data-max-os"] = maxOS
        
        parent = E(pq(root.element).find(".sparkle-release-notes")[0])
        release = E("div", 
            E("h1", 
                E("span", "Nightly Build %s" % (tool.get("build_version"))),
                E("time", date, datetime="%s" % (time.strftime("%Y-%m-%d")))),
              options)
        
        features = None
        if "features" in release_notes and len(release_notes["features"]):
            features = E("div", {"class": "features"})
            for feature in release_notes["features"]:
                fe = E("div", {"class": "feature"})
                fe.append(E("h3", feature["title"].decode('utf-8)')))
                description_list = E("ul").append(
                    *([E("li", d) for d in feature["description"]])
                )
                
                fe.append(description_list)
                
                features.append(fe)
        
        features and release.append(features)
        
        fixes = None
        if "fixes" in release_notes and len(release_notes["fixes"]):
            fixes = E("div", {"class": "fixes"})
            fixes.append(E("h2", "Bugfixes"))
            
            fixes.append(E("ul").append(
                *([E("li", f) for f in release_notes["fixes"]])
            ))
        
        fixes and release.append(fixes)
        
        parent.prepend(release)
    
    add_release(tool)
    
    return lxml.etree.tostring(root.element, pretty_print=True, encoding="UTF-8", doctype="<!doctype html>").replace(
        "&lt;", "<").replace("&gt;", ">")

def fetch_build_revisions(current_build):
    """Fetch the git revision of the current build and previous build.
    
    Return None as revision, if no previous revision exists.
    """
    current_build = int(current_build)
    builds_json = run("curl --user %s:%s %sapi/json" % (BUILD_SERVER_USER, 
                                                                BUILD_SERVER_TOKEN,
                                                                BUILD_JOB_URL), silent=True)
    builds = json.loads(builds_json)
    previous_build = builds.get("lastCompletedBuild", {}).get("number", None)
    
    # Fetch the revision of the previous build.
    previous_revision = None
    if previous_build is not None:
        previous_revision = run("curl --user %s:%s %s%s/api/xml?xpath=//lastBuiltRevision/SHA1" % (
            BUILD_SERVER_USER, BUILD_SERVER_TOKEN, BUILD_JOB_URL, previous_build), silent=True)
        if previous_revision:
            previous_revision = previous_revision.lower().replace("<sha1>", "").replace("</sha1>", "")
    
    return (BUILD_REVISION, previous_revision)

def main():
    tool_name = tool_config("name")
    name = tool_name.lower()
    
    title("Publishing %s nightly build %s" % (tool_name, tool_config("build_version")))
    
    # TOOL_ALT_NAME allows to specify an alternative name for the tool,
    # which is required for example for GPGMail to support various OS X versions.
    alt_name = os.environ.get("TOOL_ALT_NAME", nname(name)).lower()
    
    # Create the nightlies releases dir if it doesn't exist.
    tool_path = os.path.join(NIGHTLY_BASE_PATH, alt_name)
    if not os.path.isdir(tool_path):
        status("Creating nightly releases folder %s" % (tool_path))
        os.makedirs(tool_path)
    
    # Init the git repository to track the nightly releases.
    if not is_git_repository(NIGHTLY_BASE_PATH):
        status("Initializing git repository")
        run("git init %s" % (path_to_script(NIGHTLY_BASE_PATH)))
    
    status("Adding new nightly release to %s Sparkle appcast file" % (name))
    appcast_path = os.path.join(tool_path, "appcast.xml")
    if not os.path.isfile(appcast_path):
        # Create the Sparkle appcast file.
        run_or_error("%s --from-config -o %s" % (path_to_script(APPCASTER), path_to_script(appcast_path)),
                     "Failed to add nightly release\n%s")
    else:
        # Update the Sparkle appcast file.
        run_or_error("%s --from-config --replace %s" % (path_to_script(APPCASTER), path_to_script(appcast_path)),
                     "Failed to add nightly release\n%s")
    
    # Fetch the revision from the last and the current build.
    (current_revision, last_revision) = fetch_build_revisions(BUILD_NR)
    
    # Create the release notes.
    prn = __import__("prepare-release-notes")
    commit_log = prn.commit_log(last_revision, current_revision)
    
    release_notes = prn.build_release_notes_from_commit_log(commit_log)
    
    # Create the release notes file.
    html = html_for_release_notes(release_notes["info"], tool_config())
    
    # Store the release notes html file.
    release_notes_path = os.path.join(tool_path, "release-notes.html")
    with open(release_notes_path, "w") as fp:
        fp.write(html)
    
    # Temporarily change into the git repository to add the appcast
    # and release notes files.
    cli = CommandLine(NIGHTLY_BASE_PATH)
    with cli.cd(NIGHTLY_BASE_PATH):
        # Checkin the appcast.xml file.
        run_or_error("git add %s" % (path_to_script(appcast_path.replace("%s/" % (NIGHTLY_BASE_PATH), ""))),
                     "Failed to check in appcast.xml\n%s")
        run_or_error("git add %s" % (path_to_script(release_notes_path.replace("%s/" % (NIGHTLY_BASE_PATH), ""))),
                     "Failed to check in release-notes.html\n%s")
        run_or_error("git commit -m \"%s\"" % (
            "Release of %s nightly build: %s" % (tool_name, tool_config("build_version"))),
                     "Failed to commit nightly release.\n%s")
    
    success("Successfully created Sparkle info for nightly %s" % (BUILD_NR))
    
    return True
    
if __name__ == "__main__":
    try:
        sys.exit(not main())
    except KeyboardInterrupt:
        print ""
        sys.exit(1)
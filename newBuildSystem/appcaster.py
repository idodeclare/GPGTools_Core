#!/usr/bin/env python

"""Create and update appcast.xml files for Sparkle.

Based on the options passed to this script, new entries will be appended
or the whole file replaced with only one entry.
"""

import os, sys
sys.path.insert(1, os.path.join(os.path.dirname(os.path.realpath(__file__)), '../python'))

import urllib2
import time

from optparse import OptionParser, OptionValueError

from clitools import *
from clitools.color import *

try:
    import lxml
    from pyquery_lxml_extension import ElementMaker, pq
except ImportError:
    error("Please install lxml and cssselect by running `%s` and then `%s`" % (
        emphasize("pip install lxml"),
        emphasize("pip install cssselect")))

def parse_options():
    parser = OptionParser(usage="%prog [options] <appcast.xml>")
    parser.add_option("-c", "--from-config", dest="from_config", help="Read the configuration from Makefile.config",    
                      default=False, action="store_true")
    parser.add_option("-q", "--quiet", dest="quiet", action="store_true", 
                      help="Suppress any output except the resulting XML")
    parser.add_option("--name", dest="name", help="Name of the tool")
    parser.add_option("--url", dest="url", help="The download URL of the release")
    parser.add_option("--short-version", dest="version", help="Short version string of the release.")
    parser.add_option("--version", dest="build_version", help="Version of the release")
    parser.add_option("--filesize", dest="filesize", help="File size of the release")
    parser.add_option("--release-notes", dest="release_notes_url", help="URL to the release notes")
    parser.add_option("--appcast-url", dest="appcast_url", help="The URL where the appcast will be located")
    parser.add_option("--appicon-url", dest="appicon_url", default=None, help="Optional image for the app")
    parser.add_option("--min-os", dest="minOS", default=None, help="Minimum required OS version")
    parser.add_option("--max-os", dest="maxOS", default=None, help="Maximum required OS version")
    parser.add_option("--add", dest="add", action="store_true", help="Add the release to an existing appcast",
                      default=False)
    parser.add_option("--replace", dest="replace", action="store_true", default=False, 
                      help="Replace all prior releases in an existing appcast")
    parser.add_option("-o", "--outfile", dest="outfile", default=None)
    
    (options, args) = parser.parse_args()
    
    if (options.add or options.replace) and len(args) != 1:
        parser.error("--add|--replace require an already existing Sparkle appcast.xml file to be speficied")
    
    if (options.add or options.replace) and (not os.path.isfile(args[0]) or not os.access(args[0], os.W_OK)):
        parser.error("Sparkle appcast.xml file has to exist and be writable.")
    
    if options.outfile and not os.access(os.path.dirname(os.path.realpath(options.outfile)), os.W_OK):
        parser.error("Can't write to outfile. Please make sure the folder is writable")
    
    if not options.add and not options.replace and len(args) > 0:
        if not os.access(os.path.realpath(args[0]), os.R_OK):
            parser.error("Specified Sparkle appcast.xml file can't be read. Make sure it exists and is readable.")
        options.add = True
    
    if not options.from_config:
        if not options.name:
            parser.error("Name is required to be set with --name")
        if not options.url:
            parser.error("Download URL is required to be set with --url")
        if not options.version:
            parser.error("Version is to be set with --short-version")
        if not options.build_version:
            parser.error("Build nr is to be set with --version")
        if not options.filesize:
            parser.error("Filesize is required to be set with --filesize")
        if not options.release_notes_url:
            parser.error("Release notes URL is required to be set with --release-notes")
        if not options.appcast_url and not options.add and not options.replace:
            parser.error("Appcast URL is required to be set with --appcast-url")
    
    return (options, args)

NIGHTLY_BASE_URL = "http://releases.gpgtools.org/nightlies"
NIGHTLY_DOWNLOAD_BASE_URL = NIGHTLY_BASE_URL
CWD = os.getcwd()
NAMESPACES = {"atom": "http://www.w3.org/2005/Atom", 
              "sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle",
              "dc": "http://purl.org/dc/elements/1.1/"}

E = ElementMaker(nsmap=NAMESPACES)

XML_PRINT_CONFIG = {"pretty_print": True, "encoding": "utf-8", "xml_declaration": True}
# Appcast root.
APPCAST_ROOT = E("rss", version="2.0")

def add_channel_info(root, title, link, description=None, docs=None, image=None, language="en"):
    channel = E("channel").append(
        E("title", title),
        E("link", link),
        E("atom:link", href=link, rel="self", type="application/rss+xml"))
    
    if docs:
        channel.append(E("docs", docs))
    if description:
        channel.append(E("description", description))
    
    if image:
        channel.append(E("image").append(
            E("url", image),
            E("link", link),
            E("title", title)))
    
    channel.append(E("language", language))
    
    root.append(channel)

def add_release(root, url, length, version, shortVersion, title, releaseNotes, minOS=None, maxOS=None, 
                signature=None):
    root = E(root)
    
    firstItem = pq(root.element).find("item:first")
    method = "before"
    if not firstItem.size():
        firstItem = [root.element]
        method = "append"
    
    c = getattr(E(firstItem[0]), method)
    
    c(
        E("item").append(
            E("title", title),
            E("sparkle:releaseNotesLink", releaseNotes),
            minOS and E("sparkle:minimumSystemVersion", minOS),
            maxOS and E("sparkle:maximumSystemVersion", maxOS),
            E("pubDate", time.strftime("%a, %d %b %Y %X %z", time.gmtime())),
            E("enclosure", url=url,
                           length=str(length),
                           type="application/octet-stream",
                           **({"sparkle:version": version, 
                               "sparkle:dsaSignature": signature and "MCwCFAmB39sazl2xGIxSF8pHBbBh1zBLAhRmawuNanltHMlkCLv6R8OYiDRigQ==",
                               "sparkle:shortVersionString": shortVersion}))))

def additional_options_from_config(config, options):
    tool_name = config["name"].lower()
    name = os.environ.get("TOOL_ALT_NAME", nname(tool_name)).lower()
    config["appcast_url"] = "%s/releases/%s/%s" % (NIGHTLY_BASE_URL, name, "appcast.xml")
    config["appicon_url"] = "%s/releases/%s/%s" % (NIGHTLY_BASE_URL, name, 
                                        "%s-icon.png" % (nname(tool_name)))
    config["release_notes_url"] = "%s/releases/%s/%s" % (NIGHTLY_BASE_URL, name, "release-notes.html")
    config["url"] = "%s/%s" % (NIGHTLY_DOWNLOAD_BASE_URL, urllib2.quote(config.get("dmgName")))
    config["minOS"] = os.environ.get("TOOL_MIN_OS", "10.6")
    config["maxOS"] = os.environ.get("TOOL_MAX_OS", None)
    config["title"] = "%s nightly development builds" % (config.get("name"))
    config["description"] = "Release Notes for the nightly versions of %s" % (config.get("name"))
    # Find out the filesize of the release dmg.
    filesize = 0
    try:
        stat = os.stat(os.path.join(CWD, config.get("dmgPath")))
        filesize = stat.st_size
        config["filesize"] = filesize
    except Exception, e:
         error("Failed to determine release disk image file size\nError: %s" % (e))
    
    options_to_override = dict([(k,v) for k, v in options.__dict__.iteritems() if v != None])
    config.update(options_to_override)

def load_appcast(appcast_file):
    parser = lxml.etree.XMLParser(remove_blank_text=True)
    xml = lxml.etree.parse(appcast_file, parser)
    root = pq(xml.getroot())
    
    if not root.find("channel").size():
        return None
    
    return E(root[0])

def main():
    global APPCAST_ROOT
    
    (options, args) = parse_options()
    
    infile = None
    if len(args) == 1:
        infile = os.path.realpath(args[0])
    
    # If a infile is given but no outfile is set,
    # write to infile.
    if not options.outfile and infile:
        options.outfile = infile
    
    config = options.from_config and tool_config() or options.__dict__
    
    tool_name = config["name"].lower()
    
    if options.from_config:
        additional_options_from_config(config, options)
    else:
        config["title"] = "%s Releases" % (config.get("name"))
        config["description"] = None
    
    if not options.quiet:
        title("%s %s Sparkle appcast.xml" % (infile and "Update" or "Create", 
              config.get("name")))
    
    channel = None
    
    if infile:
        APPCAST_ROOT = None
        APPCAST_ROOT = load_appcast(infile)
        channel = pq(APPCAST_ROOT.element).find("channel")[0]
        
        if not APPCAST_ROOT:
            error("Couldn't load Sparkle appcast.xml file")
    
    if not infile:
        # Adding the channel info.
        add_channel_info(APPCAST_ROOT, title=config.get("title"), 
                         link=config.get("appcast_url"),
                         description=config.get("description"),
                         image=config.get("appicon_url"))
        channel = pq(APPCAST_ROOT.element).find("channel")[0]
    
    if options.from_config:
       filesize = config["filesize"]
    else:
        filesize = options.filesize
    
    # Adding the release item.
    if not options.quiet:
        status("Adding release info of %s v%s" % (config["name"], config.get("version")))
    
    # If replace is set, remove all releases first.
    if options.replace:
        pq(channel).find("item").remove()
    
    add_release(channel,
                url=config.get("url"), length=filesize, version=config.get("build_version"),
                shortVersion=config.get("version"), 
                title="%s v%s" % (config.get("name"), 
                                  config.get("version").replace(")", " build %s)" % config.get("build_version"))),
                releaseNotes=config.get("release_notes_url"),
                minOS=config.get("minOS"), maxOS=config.get("maxOS"))
    
    xml = APPCAST_ROOT.xml(**XML_PRINT_CONFIG)
    
    if options.outfile:
        with open(options.outfile, "w") as fp:
            fp.write(xml)
    else:
        print xml
    
    if not options.quiet:
        success("Sparkle appcast.xml file was successfully %s" % (infile and "updated" or "created"))
    
    return True

if __name__ == "__main__":
    try:
        sys.exit(not main())
    except KeyboardInterrupt:
        print ""
        sys.exit(1)



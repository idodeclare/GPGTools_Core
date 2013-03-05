#!/usr/bin/env python

"""Deploy a new release of a GPGTools project.

This script performs the following steps to deploy a new release:

1.) Sign the project dmg using OpenPGP.
2.) Upload the dmg and signature file to Amazon S3.
3.) Calculate the SHA1 hash of the project dmg.
4.) Sign the project dmg using an SSL key for Sparkle updates.
5.) Create the version json file pertaining to the release.
6.) Integrate the version json file into the gpgtools.org website
    The Sparkle Appcast file is dynamically created from the version json file.

If any step fails, its trying to undo the changes in a best
effort attempt.
"""

import os, sys
sys.path.insert(1, os.path.join(os.getcwd(), './Dependencies/GPGTools_Core/python'))

import shlex
import hashlib
import re
import smtplib
from email.mime.text import MIMEText

from clitools import *
from clitools.color import *

CWD = os.getcwd()
BUILD_DIR = "build"
CONFIG_SCRIPT = "../GPGTools_Core/newBuildSystem/core.sh"

TOOL_CONFIG = None

EMAIL_SUBJECT = "%(name)s v%(version)s successfully deployed!"
EMAIL_FROM = "GPGTools Release-Bot <release@gpgtools.org>"
EMAIL_TO = "team@gpgtools.org"
EMAIL_BODY = """Congrats GPGTools-Team,

%(name)s v%(version)s has been successfully deployed!

To share this new release with the world, update your Sparkle
Appcast with the information below and push it.

Release URLs
=========================================================

%(release_dmg)s
%(release_dmg_sig)s

SHA1: %(release_hash)s

=========================================================

Wish you all the best that nothing goes wrong!

Sincerely yours,

GPGTools Release-Bot
"""

def tool_config(configkey=None):
    global TOOL_CONFIG
    if not TOOL_CONFIG:
        CONFIG_SCRIPT_PATH = os.path.join(CWD, CONFIG_SCRIPT)
        if not os.path.exists(CONFIG_SCRIPT_PATH):
            die("Couldn't find the config script. Abort!") 
    
        raw_config = run("%s print-config" % (CONFIG_SCRIPT_PATH))
    
        lines = raw_config.split("\n")
        TOOL_CONFIG = {}
        for line in lines:
            if line.find(":") == -1:
                continue
        
            parts = line.split(":")
            key = parts[0]
            if len(parts) == 1:
                value = None
            else:
                value = parts[1].strip()
            TOOL_CONFIG[key] = value
        
    if not configkey:
        return TOOL_CONFIG
    
    return TOOL_CONFIG[configkey]

def run(cmd, silent=False):
    if type(cmd) == type(""):
        cmd = shlex.split(cmd)
    
    kwargs = {}
    if silent:
        kwargs['stderr'] = open("/dev/null", "w")
        
    return check_output(cmd, **kwargs)

def run_or_error(cmd, error_msg, silent=False):
    try:
        return run(cmd, silent=silent)
    except Exception, e:
        #print "Error: %s" % (e)
        error("%s" % (error_msg))

def emphasize(msg):
    return "%s%s%s%s" % (TerminalColor.reset(), TerminalColor.em(), msg, TerminalColor.reset())

def sha1_hash(file):
    sha1_hash = None
    
    with open(file, "r") as f:
        sha1_hash = hashlib.sha1(f.read()).hexdigest()
    
    return sha1_hash

def current_git_branch():
    return run("git rev-parse --abbrev-ref HEAD").strip()

def inform_team(release_info):
    """Inform the team that the deploy was successful and the version is now ready."""
    msg = MIMEText(EMAIL_BODY.replace("\n", "\r\n") % release_info)
    msg['Subject'] = EMAIL_SUBJECT % release_info
    msg['From'] = EMAIL_FROM
    msg['To'] = EMAIL_TO
    
    s = smtplib.SMTP('localhost')
    s.sendmail(EMAIL_FROM, [EMAIL_TO], msg.as_string())
    s.quit()

def main():
    if current_git_branch() != "master" and current_git_branch() != "deploy-master":
        error("You can only deploy from the master branch!\nRun `git checkout master` first.")
    
    title("Deploying %s v%s" % (tool_config("name"), tool_config("version")))
    
    DMG = tool_config("dmgName")
    PKG = tool_config("pkgName")
    GPG_SIG = "%s.sig" % (DMG)
    PKG_GPG_SIG = "%s.sig" % (PKG)
    # Check if the product dmg exists. If not, abort!
    if not os.path.isfile("%s/%s" % (BUILD_DIR, DMG)):
        error("The product disk image doesn't exist: %s.\nRun `%s` to create it." % (
              DMG, emphasize("make dmg")))
    
    # Create the gpg signature.
    run("make gpg-sig")
    # Check if the signature was successfully created and the file verifies.
    if not os.path.isfile("%s/%s" % (BUILD_DIR, GPG_SIG)):
        error("Failed to sign the product disk image.")
    
    run_or_error("gpg -v %s/%s" % (BUILD_DIR, GPG_SIG),
                 "Couldn't verify the product disk image signature.", silent=True)
    
    # Upload product disk image.
    status("Uploading %s to AWS" % (DMG))
    dmg_url = run_or_error("make upload-to-aws file=%s/%s" % (BUILD_DIR, DMG), 
                           "Couldn't upload product disk image.")
    status("    %s" % (dmg_url.strip()))
    
    # Upload gpg signature.
    status("Uploading %s to AWS" % (GPG_SIG))
    signature_url = run_or_error("make upload-to-aws file=%s/%s" % (BUILD_DIR, GPG_SIG),
                                 "Couldn't upload product disk image signature.")
    status("    %s" % (signature_url.strip()))
    
    sha1 = sha1_hash("%s/%s" % (BUILD_DIR, DMG))
    status("DMG SHA1: %s" % (sha1))
    
    status("Informing team of successful deploy.")
    inform_team({"release_dmg": dmg_url.strip(), "release_dmg_sig": signature_url.strip(), "release_hash": sha1.strip(),
                 "name": tool_config("name"), "version": tool_config("version")})
    
    success("Deploy is ready!\n"
            "For the old GPGTools website, please update the <tool>/config.php with this info and push.")
    
    return True
    
if __name__ == "__main__":
    try:
        sys.exit(not main())
    except SystemExit:
        pass
    except KeyboardInterrupt:
        print ""
        sys.exit(1)


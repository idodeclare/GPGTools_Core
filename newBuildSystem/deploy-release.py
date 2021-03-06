#!/usr/bin/env python

"""Deploy a new release of a GPGTools project.

This script performs the following steps to deploy a new release:

1.) Sign the project dmg using OpenPGP.
2.) Copy the dmg and signature file into "/GPGTools/public/releases.gpgtools.org/".
3.) Update the version json file pertaining to the release.
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
from shutil import copy
from email.mime.text import MIMEText
from clitools import *
from clitools.color import *

CWD = os.getcwd()
BUILD_DIR = "build"
RELEASE_DIR = "/GPGTools/public/releases.gpgtools.org"
RELEASE_URL = "https://releases.gpgtools.org"

EMAIL_SUBJECT = "%(name)s v%(version)s successfully deployed!"
EMAIL_FROM = "GPGTools Release-Bot <release@gpgtools.org>"
EMAIL_TO = "team@gpgtools.org"
EMAIL_BODY = """Congrats GPGTools-Team,

%(name)s v%(version)s has been successfully deployed!

Release URLs
=========================================================

%(release_dmg)s
%(release_dmg_sig)s

=========================================================

Wish you all the best that nothing goes wrong!

Sincerely yours,

GPGTools Release-Bot
"""



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

def update_website_for_release():
    if os.system(path_to_script("%s/publish-release.py" % (os.path.dirname(__file__)))) != 0:
        error("Failed to add release to the GPGTools website.")

def copy_for_release(file):
    src = "%s/%s" % (BUILD_DIR, file)
    dst = "%s/%s" % (RELEASE_DIR, file)
        
    if os.path.isfile(dst):
        error("The file '%s' already exists in the release directoy!" % file)

    # Copy files into the release directory.
    copy(src, dst)
    url = "https://releases.gpgtools.org/%s" % file

    status(url)
    return url

def main():
    if current_git_branch() not in ["master", "deploy-master", "jenkins-master"]:
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
        
    run_or_error("gpg -v %s" % (path_to_script("%s/%s" % (BUILD_DIR, GPG_SIG))),
                 "Couldn't verify the product disk image signature.\n%s", silent=True)
        
    status("Copy files into release directory.")
    dmg_url = copy_for_release(DMG)
    signature_url = copy_for_release(GPG_SIG)


    status("Update website and create appcast for Sparkle.")
    update_website_for_release()
    
    
    status("Informing team of successful deploy.")
    release_info = {"release_dmg": dmg_url.strip(), "release_dmg_sig": signature_url.strip(),
                    "name": tool_config("name"), "version": tool_config("version")}
    try:
        inform_team(release_info)
    except:
        status("    Not able to send the mail. Skipping...")
    
    
    success("%s %s was successfully released!" % (tool_config("name"), tool_config("version")))
    
    return True
    
if __name__ == "__main__":
    try:
        sys.exit(not main())
    except KeyboardInterrupt:
        print ""
        sys.exit(1)


import os
import glob
import types
import sys
import shutil
import shlex
import traceback
import hashlib
from optparse import OptionParser

from subprocess import call
import subprocess

class CommandError(Exception):
    def __init__(self, retcode, cmd, output=None, error=None):
        self.retcode = retcode
        self.cmd = cmd
        self.output = output
        if error:
            self.error = error.strip()
        else:
            self.error = None

    def __str__(self):
        return repr(self.error)

def check_output(*popenargs, **kwargs):
    if 'stdout' in kwargs:
        raise ValueError('stdout argument not allowed, it will be overridden.')
    if 'silent' in kwargs:
        kwargs['stderr'] = subprocess.PIPE
        del kwargs['silent']
    
    process = subprocess.Popen(stdout=subprocess.PIPE, *popenargs, **kwargs)
    output, error = process.communicate()
    retcode = process.poll()
    if retcode:
        cmd = kwargs.get("args")
        if cmd is None:
            cmd = popenargs[0]
        raise CommandError(retcode, cmd, output=output, error=error)
    
    return output

from color import *

def xcopy(src, dst, makedirs=False, symlinks=False, verbose=False):
    """
    Provides an extended copy version of shutil.copy2 also copying
    extended attributes in addition to group and owner, which shutil
    doesn't copy at all.
    
    If makedirs is set, create intermediate directories.
    """
    import shutil, xattr
    stat = os.stat(src)
    if makedirs and not os.path.isdir(os.path.dirname(dst)):
        os.makedirs(os.path.dirname(dst), 0755)
    
    if os.path.isdir(dst):
        dst = os.path.join(dst, os.path.basename(src))
    
    if symlinks and os.path.islink(src):
        if verbose:
            status("symlink: %s -> %s" % (src, dst))
        linkto = os.readlink(src)
        os.symlink(linkto, dst)
        
        return
    
    # Copy the file
    if verbose:
        status("copy: %s -> %s" % (src, dst))
    # If the file exists, remove it first.
    if os.path.isfile(dst) or os.path.islink(dst):
        if verbose:
            status("rm %s" % (dst))
        os.unlink(dst)
    shutil.copy2(src, dst)
    # Might fail on some files. simply ignore.
    try:
        os.lchown(dst, stat.st_uid, stat.st_gid)
    except:
        pass
    # And copy the extended attributes.
    src_attrs = xattr.xattr(src)
    dst_attrs = xattr.xattr(dst)
    for key, value in src_attrs.iteritems():
        dst_attrs[key] = value

def tree_files(directory):
    return reduce(lambda l1,l2: l1 + l2,
                  map(lambda entry: map(lambda x: os.path.join(entry[0], x), entry[2]), 
                                        os.walk(directory, followlinks=True)))

def create_and_mount_if_necessary(func):
    def _create_and_mount(self, *args, **kw):
        if "no_mount_or_create" not in kw:
            if not self.created() and not self.readonly():
                self.create()
            if not self.mounted():
                self.mount()
        return func(self, *args, **kw)
    return _create_and_mount

class CommandLine(object):
    def __init__(self, path, verbose=False):
        self.pathStack = []
        self.rootDir = path
        self.currentPath = path
        self.verbose = verbose
        # If the path doesn't exist yet, don't push it yet.
        if os.path.isdir(path):
            self.pushPath(path)
    
    def find(self, path):
        if self.verbose:
            status("find: %s" % (path))
        files = glob.glob(self.fullpath(path))
        if self.verbose:
            status("found files: %s" % (files))
        return files
    
    def cp(self, sourcePath, targetPath="."):
        sourcePath = sourcePath
        targetPath = self.fullpath(targetPath)
        files = [sourcePath]
        if os.path.isdir(sourcePath):
            files = tree_files(sourcePath)
        
        for file in files:
            if os.path.isdir(sourcePath):
                basename = os.path.basename(sourcePath)
                targetFile = file.replace(sourcePath, os.path.join(targetPath, basename))
            else:
                targetFile = targetPath
            xcopy(file, targetFile, makedirs=True, symlinks=True, verbose=self.verbose)
    
    def ln(self, source, dest):
        if self.verbose:
            status("link %s -> %s" % (source, dest))
        files = glob.glob(source)
        if self.verbose:
            status("found files: %s" % (files))
        for file in files:
            if dest.startswith("/"):
                target = os.path.join(dest, os.path.basename(file))
            else:
                target = dest
            if self.verbose:
                status("-> link %s -> %s" % (file, target))
            os.symlink(file, target)
    
    def mkdir(self, directory, chmod=0755):
        if not directory.startswith("/"):
            directory = os.path.join(self.currentPath, directory)
        else:
            directory
        if self.verbose:
            status("mkdir: %s" % (directory))
        os.makedirs(directory, chmod)
    
    def run(self, path, args, sudo=False, dry=False):
        args.insert(0, path)
        if sudo:
            args.insert(0, "sudo")
        cmd = "%s" % (" ".join(args))
        if self.verbose:
            status("%s" % cmd)
        ret = 0
        if not dry:
            fd = None
            if not self.verbose:
                fd = open("/dev/null", "w")
            ret = call(args, stdout=fd, stderr=fd)
        
        return ret
    
    def cd(self, path):
        if path.startswith("//"):
            path = path[1:]
        else:
            path = self.fullpath(path)
        self.pushPath(path)
        return self
    
    def pushPath(self, path):
        if self.verbose:
            status("pushd %s" % (path))
        self.currentPath = path
        self.pathStack.append(path)
        self._chdir(path)
    
    def popPath(self):
        self.pathStack.pop()
        self.currentPath = self.pathStack[-1]
        if self.verbose:
            status("popd %s" % (self.currentPath))
        self._chdir(self.currentPath)
        
    def _chdir(self, path):
        os.chdir(path)
    
    def remove(self, paths):
        for path in paths:
            path = self.fullpath(path)
            if os.path.isdir(path):
                if self.verbose:
                    status("rm -rf %s" % (path))
                shutil.rmtree(path)
            else:
                if self.verbose:
                    status("rm %s" % (path))
                os.unlink(path)
    
    def __getitem__(self, path):
        return self.find(self.fullpath(path))
    
    def __enter__(self):
        return self
    
    def fullpath(self, path):
        if path.startswith(self.rootDir):
            return path
        
        if path.startswith("/"):
            path = path[1:]
        else:
            path = os.path.join(self.currentPath, path)
        
        if not path.startswith(self.rootDir):
            path = os.path.join(self.rootDir, path)
        
        return path
    
    def __exit__(self, type, value, exc_traceback):
        traceback.print_tb(exc_traceback)
        self.popPath()
        return True

class Package(CommandLine):
    tool = "/usr/sbin/installer"
    
    def __init__(self, path, verbose=False):
        super(Package, self).__init__(path, verbose)
        self._path = not path.endswith(".pkg") and "%s.pkg" % (path) or path
    
    def install(self, target):
        namedArgs = NamedArguments(pkg=self._path, target=target.mountpath(),
                                   key_prefix="-")
        self.run(Package.tool, namedArgs.args(), sudo=True)
    

class NamedArguments(object):
    def __init__(self, **options):
        key_prefix = "--"
        if "key_prefix" in options:
            key_prefix = options["key_prefix"]
            del options["key_prefix"]
        
        self._key_prefix = key_prefix
        self._options = options
    
    def set(self, key, value):
        self._options[key] = value
    
    def __setattr__(self, key, value):
        if not key.startswith("_"):
            self.__setitem__(key, value)
        else:
            self.__dict__[key] = value
    
    def __setitem__(self, key, value):
        self.set(key, value)
    
    def args(self):
        args = []
        for key, value in self._options.iteritems():
            args.append("%s%s" % (self._key_prefix, key))
            if value:
                args.append(value)
        
        return args
    
    def __str__(self):
        return " ".join(self.args())

class Diskimage(CommandLine):
    tool = "/usr/bin/hdiutil"
    
    def __init__(self, path, volname=None, size="100m", layout="GPTSPUD", fs="Journaled HFS+", type="UDIF",
                 spotlight=False, mountroot="/Volumes", readonly=False, verbose=False):
        self._size = size
        self._layout = layout
        self._fs = fs
        self._type = type
        self._spotlight = spotlight
        self._mounted = False
        self._mountroot = mountroot
        path = os.path.realpath(os.path.expanduser(path))
        self._path = os.path.dirname(path)
        self._name, self._extension = os.path.splitext(os.path.basename(path))
        self._extension = self._extension[1:]
        self._volname = volname and volname or self._name
        self._created = False
        self._readonly = readonly
        
        super(Diskimage, self).__init__(self.mountpath(no_mount_or_create=True), verbose=verbose)
    
    def create(self):
        namedArgs = NamedArguments(size=self._size, layout=self._layout, fs=self._fs,
                                   volname=self._volname, type=self._type,
                                   key_prefix="-")
        spotlightOption = "%sspotlight" % (["no", ""][self._spotlight])
        namedArgs[spotlightOption] = ""
        args = namedArgs.args()
        args.extend([self.path()])
        ret = self.run("create", args)
        self._created = True
        return ret
    
    def mount(self):
        namedArgs = NamedArguments(noverify="", mountpoint=self.mountpath(no_mount_or_create=True), key_prefix="-")
        args = namedArgs.args()
        args.extend([self.path()])
        ret = self.run("attach", args)
        self._mounted = True
        
        self.cd(self.mountpath())
        
        return ret
    
    def unmount(self):
        # Change into a directory that exists but is not the
        # mountpath.
        if not self.mounted():
            return
        self.cd("//Volumes")
        self.run("detach", [self.mountpath()])
        self._mounted = False
    
    def readonly(self):
        return self._readonly
    
    def mounted(self):
        return self._mounted
    
    def created(self):
        return self._created
    
    def convert(self, name=None, format="UBDZ", replace=False):
        orig_file = self.path()
        
        if replace:
            orig_file = "%s.convert" % (orig_file)
            new_file = self.path()
            shutil.move(new_file, orig_file)
        else:
            new_file = os.path.realpath(os.path.expanduser(name))
        
        namedArgs = NamedArguments(format=format, o=new_file, key_prefix="-")
        args = namedArgs.args()
        args.extend([orig_file])
        
        self.run("convert", args)
        
        if replace:
            os.unlink(orig_file)
        
    
    @create_and_mount_if_necessary
    def mountpath(self, no_mount_or_create=False):
        return os.path.join(self._mountroot, self._volname)
    
    @create_and_mount_if_necessary
    def package(self, name):
        directories = [self.mountpath(), os.path.join(self.mountpath(), "Packages")]
        packagePath = None
        for directory in directories:
            path = os.path.join(directory, "%s.%s" % (name, "pkg"))
            if os.path.isfile(path) or os.path.isdir(path):
                packagePath = path
                break
        
        if not packagePath:
            raise Exception("No Package found: %s" % (name))
        
        return Package(packagePath, verbose=self.verbose)
    
    def __getitem__(self, path):
        return self.find(path)
    
    @create_and_mount_if_necessary
    def find(self, path):
        return super(Diskimage, self).find(path)
    
    @create_and_mount_if_necessary
    def cp(self, sourcePath, targetPath=None):
        targetPath = [self.currentPath, targetPath][targetPath != None]
        if isinstance(sourcePath, types.StringTypes):
            super(Diskimage, self).cp(sourcePath, targetPath)
        else:
            for source in sourcePath:
                super(Diskimage, self).cp(source, targetPath)
    
    @create_and_mount_if_necessary
    def ln(self, source, dest=None):
        # If dest is no path but only the name
        # assume a relative link to be made.
        relative = dest and dest.find("/") == -1
        
        # If the source doesn't start with a /, assume cd was
        # used and don't apply fullpath.
        if not source.startswith("/"):
            relative = 0
        
        dest = [self.currentPath, dest][dest != None]
        if relative:
            with self.cd(os.path.dirname(source)):
                source = source.replace("%s/" % (os.path.dirname(source)), "")
                super(Diskimage, self).ln(source, dest)
        else:
            super(Diskimage, self).ln(source, dest)
    
    @create_and_mount_if_necessary
    def mkdir(self, directory, chmod=0755):
        super(Diskimage, self).mkdir(directory, chmod)
    
    @create_and_mount_if_necessary
    def cd(self, path):
        return super(Diskimage, self).cd(path)
    
    @create_and_mount_if_necessary
    def remove(self, paths=None):
        if paths:
            super(Diskimage, self).remove(paths)
            return
        
        # Otherwise remove the diskimage itself.
        # Unmount first.
        self.unmount()
        # Delete the mountpath
        super(Diskimage, self).remove([self.path()])
    
    def path(self):
        return os.path.join(self._path, "%s.%s" % (self._name, self._extension))
    
    def run(self, cmd, args, dry=False):
        args.insert(0, cmd)
        return super(Diskimage, self).run(Diskimage.tool, args, dry=dry) == 0

def print_status(message, end=False):
    if not end:
        sys.stdout.write("%s==>%s %s: " % (TerminalColor.blue(), TerminalColor.reset(), message))
    elif end:
        sys.stdout.write("%s\n" % (message))

def ask_for(message):
    return raw_input("%s==> %s%s: %s" % (TerminalColor.blue(), TerminalColor.color(39), message, TerminalColor.reset()))

def run(cmd, silent=False, debug=False):
    kwargs = {}
    if type(cmd) == type(""):
        cmd = shlex.split(cmd)
    
    if silent:
        kwargs['silent'] = silent
    
    if debug:
        print "$# %s" % (cmd)
    
    return check_output(cmd, **kwargs).strip()

def run_or_error(cmd, error_msg, silent=False, debug=False):
    try:
        return run(cmd, silent=silent, debug=debug).strip()
    except Exception, e:
        if error_msg.find("%s") != -1:
            if isinstance(e, OSError):
                cmd_error = e.message
            else:
                cmd_error = e.error or ""
            error_msg = error_msg % (cmd_error)
        
        error_msg = debug and "%s\n%s" % (error_msg, traceback.format_exc()) or "%s" % (error_msg)
        
        error("%s" % (error_msg))

TOOL_CONFIG = None

def tool_config(configkey=None):
    global TOOL_CONFIG
    
    CWD = os.getcwd()
    VERSION_FILE = "Makefile.config"
    VERSION_PATH = "%s/%s" % (CWD, VERSION_FILE)
    CONFIG_SCRIPT = "%s/Dependencies/GPGTools_Core/newBuildSystem/core.sh" % (CWD)
    
    if not TOOL_CONFIG:
        # Make sure Makefile.config exists.
        if not os.path.isfile(VERSION_PATH):
            bailout("Version file can't be found - make sure Makefile.config exists.")
        
        CONFIG_SCRIPT_PATH = os.path.join(CWD, CONFIG_SCRIPT)
        if not os.path.exists(CONFIG_SCRIPT_PATH):
            bailout("Couldn't find the config script. Abort!") 
    
        raw_config = run("\"%s\" print-config" % (CONFIG_SCRIPT_PATH))
    
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

def editor():
    # Good old vi as default.
    default = "vi"
    program = os.environ.get("GIT_EDITOR")
    if program:
       return program
    
    # Check if git has some info
    program = run("git var GIT_EDITOR")
    if program:
        return program
    
    # Check if visual is set
    program = os.environ.get("VISUAL")
    if program:
        return program
    
    # Check if editor is set
    program = os.environ.get("EDITOR")
    if program:
        return program
    
    # If still no result, use vi.
    return default

def open_in_editor(file):
    """Open a file in the preferred editor and return the content."""
    edit = editor()
    
    ret = call(shlex.split('%s "%s"' % (edit, file)))
    
    contents = ""
    with open(file, "r") as fp:
        contents = fp.read()
    
    return contents

def ask_with_expected_answers(msg, expected_answers, default):
    while True:
        value = raw_input("%s " % msg).strip()
        value = value or default
        if value in expected_answers:
            break
        else:
            print "invalid answer. Possible answers: %s" % "|".join(expected_answers)
    
    return value

def sha1_hash(file):
    sha1_hash = None
    
    with open(file, "r") as f:
        sha1_hash = hashlib.sha1(f.read()).hexdigest()
    
    return sha1_hash

def is_git_repository(path):
    if not os.path.isdir(path):
        return False
    
    original_path = os.getcwd()
    try:
        os.chdir(path)
    except OSError, e:
        return False
    
    try:
        run("git rev-parse --is-inside-work-tree", silent=True)
    except:
        return False
    finally:
        os.chdir(original_path)
    
    return True

def path_to_script(path):
    """Quotes paths if they contain spaces."""
    if path.find(" ") == -1:
        return path
    
    return '"%s"' % (path)


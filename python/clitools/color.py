import sys

class TerminalColor(object):
    @classmethod
    def blue(cls):
        return TerminalColor.bold(34)
    
    @classmethod
    def white(cls):
        return TerminalColor.bold(39)
    
    @classmethod
    def red(cls):
        return TerminalColor.underline(31)
    
    @classmethod
    def yellow(cls):
        return TerminalColor.underline(33)
    
    @classmethod
    def reset(cls):
        return TerminalColor.escape(0)
    
    @classmethod
    def em(cls):
        return TerminalColor.underline(39)
    
    @classmethod
    def green(cls):
        return TerminalColor.color(92)
    
    @classmethod
    def color(cls, s):
        return TerminalColor.escape("0;%s" % (s))
    
    @classmethod
    def bold(cls, s):
        return TerminalColor.escape("1;%s" % (s))
    
    @classmethod
    def underline(cls, s):
        return TerminalColor.escape("4;%s" % (s))
    
    @classmethod
    def escape(cls, s):
        return "\033[%sm" % (s)

def status(msg):
    print "%s==>%s - %s" % (TerminalColor.blue(), TerminalColor.reset(), msg)

def title(msg):
    print "%s==>%s %s%s" % (TerminalColor.blue(), TerminalColor.white(), msg, TerminalColor.reset())

def success(msg):
    print "%s==>%s %s%s" % (TerminalColor.green(), TerminalColor.white(), msg, TerminalColor.reset())

def error(msg, noexit=False, exitcode=2):
    print "%sError%s: %s" % (TerminalColor.red(), TerminalColor.reset(), msg)
    if not noexit:
        sys.exit(exitcode)


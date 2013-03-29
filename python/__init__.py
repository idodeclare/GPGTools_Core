"""A collection of python functions which are used across the core scripts."""

import re
import types
import codecs

from clitools import *
from clitools.color import *

from vendor import markdown

try:
    import lxml
    from pyquery_lxml_extension import ElementMaker, pq
except ImportError:
    error("Please install lxml and cssselect by running `%s` and then `%s`" % (
        emphasize("STATIC_DEPS=true sudo pip install lxml==3.1.0"),
        emphasize("sudo pip install cssselect")))

def convert_release_notes_to_markdown(release_notes, version, title="%s v%s - Release Notes",
                                      features_title="Features", fixes_title="Bugfixes"):
    """Converts release notes dictionary into markdown output.
    
    The format is: {
        "info": {"
            features: [
                {"title": "Title 1", "description": ["Line 1", "Line 2"]}
            ],
            fixes: [
                "Fix 1",
                "Fix 2"
            ]
        "}
    }
    """
    lines = []
    
    def titles(value, level=1):
        length = len(value)
        
        if level == 1:
            return "%s\n%s\n" % (value, "=" * length)
        elif level == 2:
            return "%s\n%s\n" % (value, "-" * length)
        elif level == 3:
            return "%s %s\n" % ("#" * level, value)
    
    def item(value, level=1):
        if not len(value):
            return value
        
        return "*%s%s" % (" " * (level * 4), clean_item(value))
    
    def clean_item(value):
        value = re.sub(r"^\s*[-\*]+\s*(.*)", r'\1', value)
        return value
    
    lines.append(titles(title % (tool_config("name"), version)))
    if "features" in release_notes["info"] and len(release_notes["info"]["features"]):
        lines.append(titles(features_title, 2))
        
        for feature in release_notes["info"]["features"]:
            lines.append(titles(feature["title"], 3))
            
            if len(feature["description"]):
                for line in feature["description"]:
                    lines.append(item(line))
            
            lines.append("")
        
    if "fixes" in release_notes["info"] and len(release_notes["info"]["fixes"]):
        lines.append(titles(fixes_title, 2))
        
        for fix in release_notes["info"]["fixes"]:
            if not fix:
                continue
            
            lines.append(item(fix))
        
        lines.append("")
    
    return "\n".join(lines)

def convert_markdown_to_release_notes(md_code):
    # Also Handle 
    if type(md_code) not in types.StringTypes:
        md_code = codecs.open(md_code, mode="r", encoding="utf8").read()
    elif type(md_code) == types.StringType:
        md_code = md_code.decode("utf8")
    
    html = markdown.markdown(md_code)
    if not html:
        return (None, "Markdown document is empty.")
    
    root = pq("<html>%s</html>" % (html))
    
    # Check if the required elements are available.
    if not root.find("h1").size():
        return (None, "Title is missing! Please check your markdown for a line which looks like this:\n\n"
                      "Title 1\n=======")
    if not root.find("h2").size():
        return (None, "No Features or Bugfixes subtitle found! Please check your Markdown for a line that looks like this.\n\n"
                      "Subtitle\n--------")
    if not root.find("ul").size():
        return (None, "No Lists found! Please check your Markdown for at least one line that looks like this:\n\n"
                      "* Item 1")
    
    # Format seems to be okay.
    # On to converting the markdown to release_notes dict.
    release_notes = {"info": {}}
    
    info = release_notes["info"]
    key = ""
    fixes = []
    i = -1
    
    titles = []
    features = []
    fixes = []
    # First, find the items between two h2 titles (features and fixes.)
    for item in root.find("h1").nextAll():
        item = pq(item)
        
        if item.is_("h2"):
            titles.append({"title": item.text().lower() == "features" and "features" or "fixes",
                           "items": []})
            i += 1
        
        titles[i]["items"].append(item)
    
    for title in titles:
        if title["title"] == "features":
            j = -1
            for item in title["items"]:
                if item.is_("h3"):
                    features.append({
                        "title": item.html().strip(),
                        "description": []})
                    j += 1
                
                if item.is_("ul"):
                    for item in item.children("li"):
                        item = pq(item)
                        features[j]["description"].append(item.html().strip())
                
        elif title["title"] == "fixes":
            for item in title["items"]:
                if item.is_("ul"):
                    for item in item.children("li"):
                        item = pq(item)
                        fixes.append(item.html())
    
    info["fixes"] = fixes
    info["features"] = features
    
    return (release_notes, None)

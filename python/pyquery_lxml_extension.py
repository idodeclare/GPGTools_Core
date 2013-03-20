import lxml
from vendor import pyquery
from lxml.builder import ElementMaker as _ElementMaker

# The default outerHtml method of pyquery doesn't have the option
# to pretty print the output. The following function adds this feature.
def outerHtml(self, **config_args):
    if not config_args:
        config_args = {}
        
    if "pretty_print" not in config_args:
        config_args["pretty_print"] = True
    if "encoding" not in config_args:
        config_args["encoding"] = unicode
    
    if not self:
        return None
    e0 = self[0]
    if e0.tail:
        e0 = deepcopy(e0)
        e0.tail = ''
    return lxml.etree.tostring(e0, **config_args)

class Element(object):
    def __init__(self, element):
        self.element = element
    
    def __str__(self):
        return str(self.element)
    
    def __repr__(self):
        return repr(self.element)
    
    def _modifyNode(self, method, *elements):
        for element in elements:
            if not element:
                continue
            if isinstance(element, Element):
                relement = element.element
            else:
                relement = element
            
            if method == "append":
                self.element.append(relement)
            elif method == "prepend":
                self.element.insert(0, relement)
            elif method == "before":
                self.element.addprevious(relement)
            elif method == "after":
                self.element.addnext(relement)
        
        return self
    
    def append(self, *elements):
        return self._modifyNode("append", *elements)
    
    def prepend(self, *elements):
        return self._modifyNode("prepend", *elements)
    
    def before(self, *elements):
        return self._modifyNode("before", *elements)
    
    def after(self, *elements):
        return self._modifyNode("after", *elements)
    
    def xml(self, **config):
        return lxml.etree.tostring(self.element, **config)

class ElementMaker(object):
    def __init__(self, **kw):
        self.namespaces = {}
        if "nsmap" not in kw:
            kw["nsmap"] = {}
        else:
            self.namespaces = kw["nsmap"]
        
        self.factory = _ElementMaker(**kw)
    
    def _resolveNamespace(self, key):
        if key.find(":") == -1:
            return key
        
        key_parts = key.split(":")
        return "{%s}%s" % (self.namespaces.get(key_parts[0]), key_parts[1])
    
    def __call__(self, tag, *elements, **kw):
        # Should the tag be a lxml Element, simply return it.
        if isinstance(tag, lxml.etree._Element):
            return Element(tag)
        
        cleansed_elements = []
        tag = self._resolveNamespace(tag)
        ns_kw = {}
        
        for k, v in kw.iteritems():
            if not v:
                continue
            ns_kw[self._resolveNamespace(k)] = v
        
        for e in elements:
            if not e:
                continue
            if isinstance(e, Element):
                cleansed_elements.append(e.element)
            else:
                cleansed_elements.append(e)
        
        return Element(self.factory(tag, *cleansed_elements, **ns_kw))

# Install the new outerHtml method.
pyquery.PyQuery.outerHtml = outerHtml
# Alias pyquery.PyQuery
pq = pyquery.PyQuery

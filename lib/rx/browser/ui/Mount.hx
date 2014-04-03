package rx.browser.ui;

class Mount {

  public static var totalInstantiationTime: Int = 0;
  public static var totalInjectionTime: Int = 0;
  public static var ATTR_NAME = rx.browser.ui.dom.Property.ID_ATTRIBUTE_NAME;

  public static function scrollMonitor(container: js.html.Element, renderCallback: Dynamic) {
    renderCallback();
  }

  public static inline var DOC_NODE_TYPE:Int = 9;
  public static function getReactRootElementInContainer(container: js.html.Element): js.html.Node {
    if (container == null) {
      return null;
    }
    if (container.nodeType == DOC_NODE_TYPE) {
      return js.Browser.document.documentElement;
    } else {
      return container.firstChild;
    }
  }

  public static function internalGetId(node: js.html.Node):String {
    var id = '';
    if (Reflect.hasField(node, 'getAttribute') != null) {
      id = Reflect.callMethod(node, Reflect.getProperty(node, 'getAttribute'), [ATTR_NAME]);
    }
    return id;
  }

  static var nodeCache = new Map<String, js.html.Node>();
  public static function getId(node: js.html.Node):String {
    var id = internalGetId(node);
    if (id != null) {
      if (nodeCache.exists(id)) {
        var cached = nodeCache.get(id);
        if (cached != node) throw 'Mount: Two valid but unequal nodes with the same `$ATTR_NAME`:$id';
        nodeCache.set(id, node);
      } else {
        nodeCache.set(id, node);
      }
    }
    return id;
  }

  public static function purgeId(id: String):Void {
    nodeCache.remove(id);
  }

  public static function getNode(id: String):js.html.Node {
    if (!nodeCache.exists(id) || !isValid(nodeCache.get(id), id)) {
      nodeCache.set(id, findReactNodeForId(id));
    }
    return nodeCache.get(id);
  }


  public static function isValid(node: js.html.Node, id: String):Bool {
    if (node != null) {
      if (internalGetId(node) != id) throw 'Mount: unexpected modification of `$ATTR_NAME`';
    
      var container = findReactContainerForId(id);
      if (container != null && rx.browser.ui.dom.Node.containsNode(container, node)) {
        return true;
      }
    }
    return false;
  }

  public static function getReactRootId(container: js.html.Element):String {
    var rootElement = getReactRootElementInContainer(container);
    if (rootElement != null) return getId(rootElement);
    return null;
  }

  public static function findReactNodeForId(id: String):js.html.Node {
    var reactRoot = findReactContainerForId(id);

    return findComponentRoot(reactRoot, id);
  }

  static var findComponentRootReusableArray = new Array<js.html.Node>();
  public static function findComponentRoot(ancestorNode, targetId):js.html.Node {
    var firstChildren = findComponentRootReusableArray;
    var childIndex = 0;

    var deepestAncestor = findDeepestCachedAncestor(targetId);
    if (deepestAncestor == null) deepestAncestor = ancestorNode;

    firstChildren[0] = deepestAncestor.firstChild;
    firstChildren.splice(1, firstChildren.length);

    while (childIndex < firstChildren.length) {
      var child = firstChildren[childIndex++];
      var targetChild = null;

      while (child != null) {

        var childId = getId(child);
        if (childId != null) {
          if (targetId == childId) {
            targetChild = child;
          } else if (rx.core.InstanceHandles.isAncestorIdOf(childId, targetId)) {
            firstChildren.splice(0, firstChildren.length);
            childIndex = 0;
            firstChildren.push(child.firstChild);
          }

        } else {

          firstChildren.push(child.firstChild);

        }

        child = child.nextSibling;

      }

      if (targetChild != null) {
        firstChildren.splice(0, firstChildren.length);
        return targetChild;
      }
    }

    firstChildren.splice(0, firstChildren.length);

    throw 'findComponentRoot(..., $targetId) Unable to find element.';
  }

  public static function findDeepestCachedAncestorImpl(ancestorId) {
    var ancestor = nodeCache.get(ancestorId);
    if (ancestor != null && isValid(ancestor, ancestorId)) {
      deepestNodeSoFar = ancestor;
    } else {
      return;
    }
  }

  static var deepestNodeSoFar:js.html.Node = null;
  public static function findDeepestCachedAncestor(targetId: String) {
    deepestNodeSoFar = null;
    rx.core.InstanceHandles.traverseAncestors(targetId, findDeepestCachedAncestorImpl);

    var foundNode = deepestNodeSoFar;
    deepestNodeSoFar = null;
    return foundNode;
  }

  public static function findReactContainerForId(id: String):js.html.Node {
    var reactRootId = rx.core.InstanceHandles.getReactRootIdFromNodeId(id);
    var container = containersByReactRootId.get(reactRootId);
    return container;
  }

  public static function getInstanceByContainer(container: js.html.Element):rx.core.Component {
    var id:String = getReactRootId(container);
    return instancesByReactRootId.get(id);
  }

  public static function shouldUpdateReactComponent(prev: rx.core.Component, next: rx.core.Component):Bool {
    if (
      (prev != null && next != null) && 
      (Type.getClass(prev) == Type.getClass(next)) &&
      (prev.descriptor.props.get('key') == next.descriptor.props.get('key')) &&
      (prev.owner == next.owner)) {
      return true;
    }
    return false;
  }

  public static function updateRootComponent(prev: rx.core.Component, next: rx.core.Component, container: js.html.Element, callback:Dynamic):rx.core.Component {
    var nextProps = next.props;
    scrollMonitor(container, function () {
      prev.replaceProps(nextProps, callback);
    });
    return prev;
  }

  public static function unmountComponentAtNode(container: js.html.Element) {

  }

  public static var containersByReactRootId = new Map<String, js.html.Element>();
  public static function registerContainer(container: js.html.Element):String {
    var reactRootId = getReactRootId(container);
    if (reactRootId != null) {
      // If one exists, make sure it is a valid "reactRoot" ID.
      reactRootId = rx.core.InstanceHandles.getReactRootIdFromNodeId(reactRootId);
    }
    if (reactRootId == null) {
      // No valid "reactRoot" ID found, create one.
      reactRootId = rx.core.InstanceHandles.createReactRootId();
    }
    containersByReactRootId.set(reactRootId, container);
    return reactRootId;
  }

  public static function registerComponent(component: rx.core.Component, container:js.html.Element):String {
    var reactRootId = registerContainer(container);
    instancesByReactRootId.set(reactRootId, component);
    return reactRootId; 
  }

  public static function renderNewRootComponent(component: rx.core.Component, container: js.html.Element, shouldReuseMarkup: Bool):rx.core.Component {
    var reactRootId = registerComponent(component, container);
    component.mountComponentIntoNode(reactRootId, container, shouldReuseMarkup);
    return component;
  }

  public static inline var SEPARATOR:String = '.';
  public static function isRenderedByReact(node: js.html.Node):Bool {
    if (node.nodeType != 1) {
      // Not a DOMElement, therefore not a React component
      return false;
    }
    var id = getId(node);
    return (id != null) ? id.charAt(0) == SEPARATOR : false;
  }

  public static var instancesByReactRootId = new Map<String, rx.core.Component>();
  public static function renderComponent(component: rx.core.Component, container: js.html.Element, ?callback: Dynamic) {
    var prevComponent = getInstanceByContainer(container);
    if (prevComponent != null) {
      var prevDescriptor = prevComponent.descriptor;
      var nextDescriptor = component.descriptor;
      if (shouldUpdateReactComponent(prevComponent, component)) {
        return updateRootComponent(prevComponent, component, container, callback);
      } else {
        unmountComponentAtNode(container);
      }
    }

    var reactRootElement = getReactRootElementInContainer(container);
    var containerHasReactMarkup = (reactRootElement != null && isRenderedByReact(reactRootElement));
    var shouldReuseMarkup = containerHasReactMarkup && (prevComponent == null);

    var component = renderNewRootComponent(component, container, shouldReuseMarkup);
    return component;
  } 
   
  /*
  static var instancesByReactRootId: Map<String, Component> = new Map<String,Component>();

  public static function internalGetId(node: js.html.Node):String {
    var id = '';
    if (Reflect.hasField(node, 'getAttribute') != null) {
      id = Reflect.callMethod(node, Reflect.getProperty(node, 'getAttribute'), [rx.DomProperty.ID_ATTRIBUTE_NAME]);
    }
    return id;
  }

  public static function getId(node: js.html.Node):String {
    var id = internalGetId(node);
    // TODO: node cache
    return id;
  }

  public static inline var DOC_NODE_TYPE:Int = 9;

  public static function getReactRootElementInContainer(container: js.html.Element): js.html.Node {
    if (container == null) {
      return null;
    }
    if (container.nodeType == DOC_NODE_TYPE) {
      return js.Browser.document.documentElement;
    } else {
      return container.firstChild;
    }
  }

  public static function getReactRootId(container: js.html.Element):String {
    var rootElement = getReactRootElementInContainer(container);
    if (rootElement != null) return getId(rootElement);
    return null;
  }

  public static function getInstanceByContainer(container: js.html.Element):Component {
    var id:String = getReactRootId(container);
    return instancesByReactRootId[id];
  }

  public static inline var SEPARATOR:String = '.'
;  public static function isRenderedByReact(node: js.html.Node):Bool {
    if (node.nodeType != 1) {
      // Not a DOMElement, therefore not a React component
      return false;
    }
    var id = getId(node);
    return (id != null) ? id.charAt(0) == SEPARATOR : false;
  }

  public static function instantiateReactComponent(cmpClass: Class<Component>):Component {
    return Type.createInstance(cmpClass, []);
  }

  public static function registerComponent(instance:Component, container: js.html.Element):String {
    return null;
  }

  public static function renderNewRootComponent(cmpClass: Class<Component>, container: js.html.Element, shouldReuseMarkup: Bool) {
    var instance = instantiateReactComponent(cmpClass);
    var reactRootId = registerComponent(instance,container);
    instance.mountComponentIntoNode(reactRootId, container, shouldReuseMarkup);
    return instance;
  }

  public static function renderComponent(cmpClass: Class<Component>, container: js.html.Element):Component {

    var prevComponent = getInstanceByContainer(container);
    if (prevComponent != null) {
      // todo: check if need update
      return prevComponent;
    }

    var reactRootElement = getReactRootElementInContainer(container);
    var containerHasReactMarkup = (reactRootElement != null) && isRenderedByReact(reactRootElement);
    var shouldReuseMarkup = containerHasReactMarkup && (prevComponent == null);

    var cmp = renderNewRootComponent(cmpClass, container, shouldReuseMarkup);
    return cmp;
  }
  */
}
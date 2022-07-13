//
//  OutlineView.swift
//
//  Created by Robert Nikander on 10/17/20.
//

import SwiftUI
import os

#if os(macOS)

// private let log = os.Logger(subsystem: "", category: "OutlineView")
private let log = os.Logger(OSLog.disabled)

private let selectionColor = Color(.init(deviceRed: 0.5, green: 0.5, blue: 1.0, alpha: 0.5))

/// Helper for ``OutlineNodeView``
private struct ChevronOrSpace: View {
    let canExpand: Bool
    let isExpanded: Bool
    let frameWidth: CGFloat = 18
    init(_ canExpand: Bool, _ isExpanded: Bool) {
        self.canExpand = canExpand
        self.isExpanded = isExpanded
    }
    var body: some View {
        if canExpand {
            // These chevrons seem to be 13x23 (right) and 23x12 (down) in *pixel* size, when I look
            // in the debugger. But from a frame here... ??
            if isExpanded {
                Image(systemName: "chevron.down").frame(width: frameWidth)
                    .transition(.identity)
            } else {
                Image(systemName: "chevron.right").frame(width: frameWidth)
                    .transition(.identity)
            }
        } else {
            // Image(systemName: "circle.fill").scaleEffect(0.5)
            Spacer().frame(width: frameWidth, height: 1)
        }
    }
}

/// Shows an item, and maybe recurses to it's sub-items. Shows an icon to expand/collapse.
struct OutlineNodeView<Node, ContentView>: View
    where Node: TreeNodeProtocol, ContentView: View, Node.Child == Node
{
    // typealias SelectionType = Dictionary<Node.ID, Node>
    
    @ObservedObject var node: Node
    let content: (Node) -> ContentView
    let onNodeClick: ((Node) -> Void)?
    let depth: Int
    @Binding var expansion: Set<Node.ID>
    // @Binding var selection: Node.ID?
    // @Binding var selection: Node?
    // @Binding var selection: SelectionType
    @ObservedObject private var selection: OutlineViewSelectionModel<Node>
    
    init(node: Node, depth: Int, expansion: Binding<Set<Node.ID>>, selection: OutlineViewSelectionModel<Node>,
         onNodeClick: ((Node) -> Void)? = nil, @ViewBuilder content: @escaping (Node) -> ContentView) {
        self.node = node
        self.depth = depth
        self._expansion = expansion
        self.selection = selection
        self.onNodeClick = onNodeClick
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            let canExpand = node.canHaveChildren
            let isExpanded = canExpand && expansion.contains(node.id)
            HStack(spacing: 0) {
                ChevronOrSpace(canExpand, isExpanded)
                content(node).layoutPriority(2.0)
                // .frame(maxWidth: .infinity, alignment:.leading)
                if node.isLoadingChildren {
                    Text("Loading...").fixedSize().foregroundColor(Color.secondary).scaleEffect(0.8)
                    // ProgressView() // ??
                }
                Spacer().frame(maxWidth: .infinity)
            }
            .gesture(TapGesture().modifiers(.command).onEnded { commandTapGesture() })
            .onTapGesture { plainTapGesture() }
            .background(selection.contains(node) ? selectionColor : nil)
            VStack(spacing: 0) {
                if isExpanded, let kids = node.children {
                    VStack(spacing: 0) {
                        ForEach(kids) { subNode in
                            OutlineNodeView(node: subNode, depth:depth+1, expansion: $expansion, selection: selection, onNodeClick: onNodeClick, content: content)
                                .padding(.leading, 18)
                        }
                    }
                    // .border(Color.red, width: 1)
                    .transition(.move(edge: .top))
                } else {
                    // Needed to get the move-in-from-top transition animation to work. I don't know why.
                    Color.clear.frame(height: 0)
                }
            }
            .clipped()
        }
    }
    
    private func plainTapGesture() {
        onNodeClick?(node)
        let canExpand = node.canHaveChildren
        // Different ways to do selection/expansion behavior.
        // 1. Any tap on entire HStack causes both a) selection to go to this node, b) toggle expansion. The problem with
        //    this is that you have an open folder. You click on it to maybe see it's stats or just select it, and everything
        //    closes up. I don't like that.
        // 2. Only change the status if the click is on an already selected item
        // print("Node tapped: \(node.id), selection: \(selection?.id)")
        let alreadySelected = selection.contains(node)
        if !selection.allowsSelection || alreadySelected {
            if canExpand {
                toggleExpansion(node.id)
            }
        } else {
            selection.removeAll()
            selection.add(node)
        }
        log.debug("plainTapGesture canExpand=\(canExpand), alreadySelected=\(alreadySelected), node.id=\(String(describing:node.id))")
    }
    
    /// Adding/removing from selection, if it's in a multi-selectt mode.
    private func commandTapGesture() {
        // let canExpand = node.canHaveChildren
        let alreadySelected = selection.contains(node)
        if alreadySelected {
            selection.remove(node)
        } else {
            selection.add(node)
        }
    }
    
    private func toggleExpansion(_ id: Node.ID) {
        withAnimation(.linear(duration: 0.2)) {
            if expansion.contains(id) { expansion.remove(id) }
            else { expansion.insert(id) }
        }
    }
}

/// This is an abstract class.
public class OutlineViewSelectionModel<Node> : ObservableObject where Node: TreeNodeProtocol {
    var allowsSelection: Bool { true }
    func contains(_ node: Node) -> Bool { false }
    func removeAll() { }
    func remove(_ node: Node) { }
    func add(_ node: Node) { }
}

public class OutlineViewNoSelectionModel<Node: TreeNodeProtocol>: OutlineViewSelectionModel<Node> {
    public override init() {
        
    }
    override var allowsSelection: Bool { false }
}

public class OutlineViewSingleSelectionModel<Node: TreeNodeProtocol>: OutlineViewSelectionModel<Node> {
    /// Last I checked `@Published` was still buggy on `ObserableObject` subclasses.
    @Published public var sel: Node? = nil {
        willSet {
            objectWillChange.send()
        }
        didSet {
            // log.debug("OVSSM.sel.didSet")
        }
    }
    
    /// Convenience.
    public var isEmpty: Bool { selectedNode == nil }
    /// Convenience.
    public var values: [Node] {
        if let n = selectedNode { return [n] } else { return [] }
    }
    
    public override init() {}

    public var selectedNode: Node? { sel }
    
    override func contains(_ node: Node) -> Bool { node.id == sel?.id }
    override func removeAll() { sel = nil }
    override func remove(_ node: Node) {
        if sel?.id == node.id {
            sel = nil
        }
    }

    public override func add(_ node: Node) {
        sel = node
    }
}

public class OutlineViewMultiSelectionModel<Node: TreeNodeProtocol>: OutlineViewSelectionModel<Node> {
    @Published var nodes: [Node.ID: Node] = [:]
    public override init() {}
    override func contains(_ node: Node) -> Bool { nodes[node.id] != nil }
    override func removeAll() { nodes.removeAll() }
    override func remove(_ node: Node) {
        nodes.removeValue(forKey: node.id)
    }
    override func add(_ node: Node) {
        nodes[node.id] = node
    }
}

/// Experimenting with this because the hierarchical `List` and `OutlineGroup` stuff on macOS does not work right. It loads the whole tree at once.
///
/// https://stackoverflow.com/questions/64236386/how-to-make-swiftui-list-outlinegroup-lazy-for-use-with-large-trees-like-a-file
///
public struct OutlineView<Node, ContentView>: View where Node: TreeNodeProtocol, ContentView: View, Node.Child == Node {
    let roots: [Node]
    let content: (Node) -> ContentView
    let onNodeClick: ((Node) -> Void)?
    
    @Binding var expansion: Set<Node.ID>
    
    /// Single at first.
    // @State var selection: Node.ID? = nil
    // @Binding var selection: [Node.ID: Node]
    var selection: OutlineViewSelectionModel<Node>
    
    /// - parameters:
    ///   - roots: the roots of the tree
    ///   - selection: the selection model. Defaults to ``OutlineViewNoSelectionModel``. You also have options for single and multiselection.
    ///   - expansion: the set of expanded nodes. The model is passed in like this rather than handled internally, so that the app can save it as desired to user defaults.
    ///        Maybe I can have the ``OutlineView`` handle this too.
    ///   - onNodeClick: called for direct clicks without modifier keys. This allows an app to implement a navigation model. In other words, when they click on a node,
    ///      the app will display a detail view for that node. That is easier to implement and matches expected UI behavior better than watching the `selection ` model
    ///      and moving navigation when the selection changes. For example, in Xcode's left nav, that's not how it works. You can Cmd-select things and get to state where
    ///      the selection is not the navigation state.
    ///   - content: the usual `ViewBuilder`, for the tree node's content. The simplest case would be something like a `Text(node.name)`, assuming nodes have a
    ///        name property.
    public init(roots: [Node], selection: OutlineViewSelectionModel<Node> = OutlineViewNoSelectionModel(), expansion: Binding<Set<Node.ID>>,
                onNodeClick: ((Node) -> Void)? = nil, @ViewBuilder content: @escaping (Node) -> ContentView) {
        self.roots = roots
        self.content = content
        self.selection = selection // ?? OutlineViewNoSelectionModel()
        self.onNodeClick = onNodeClick
        self._expansion = expansion
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ForEach(roots) { root in
                OutlineNodeView(node: root, depth: 0, expansion: $expansion, selection: selection, onNodeClick: onNodeClick, content: content)
            }
        }
    }
}


#endif


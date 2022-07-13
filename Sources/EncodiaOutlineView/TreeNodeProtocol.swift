//
//  TreeNodeProtocol.swift
//  
//
//  Created by Robert Nikander on 7/13/22.
//

import Foundation

/// The model for an ``OutlineView`` is a tree of objects that implement this protocol.
///
@MainActor public protocol TreeNodeProtocol: Identifiable, ObservableObject {
    associatedtype Child: TreeNodeProtocol

    /// True if the node _might_ have children. For example, nodes representing a folder in a file system hierachy would return true. A file in that example would return false.
    /// The ``OutlineView`` will render an expand/collapse icon for items that can have children.
    var canHaveChildren: Bool { get }
    
    /// This allows for an asynchronous `children` property. Imagine a folder that needs to read from a server. `canHaveChildren` is true, the user clicks to
    /// expand the node, but `children` can't immediately give an answer, so `children` would return `[]` after starting an internal process and publish a change to
    /// this `isLoadingChildren` property.  This should appear in the UI as some kind of progress indicator, showing the user that the app is fetching the child list from somewhere.
    var isLoadingChildren: Bool { get }
    
    var children: [Child] { get }
}

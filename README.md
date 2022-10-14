# OutlineView

Currently (as of July 2022) there is no obvious way to implement an outline view in SwiftUI and macOS that lazily loads it's children.
See the [stackoverflow question here.](https://stackoverflow.com/questions/64236386/how-to-make-swiftui-list-outlinegroup-lazy-for-use-with-large-trees-like-a-file)

This package contains an `OutlineView` that does just that. It is not the prettiest thing, but if people are interested in using it, I will clean it up and add features.

Example use:

<img width="685" alt="outline_test_screenshot2" src="https://user-images.githubusercontent.com/108823282/178790752-196e4b4b-14c2-4857-b42c-2bdcd4b18ffd.png">


```swift


import SwiftUI
import EncodiaOutlineView

struct ContentView: View {
    
    @State var roots: [Thing] = makeOutlineRoots()
    @StateObject var selection = OutlineViewSingleSelectionModel<Thing>()
    // @StateObject var selection = OutlineViewMultiSelectionModel<Thing>()
    @State var expansion: Set<UUID> = []
    
    var body: some View {
        HStack {
            ScrollView {
                // OutlineView(roots: roots, expansion: $expansion) { node in
                OutlineView(roots: roots, selection: selection, expansion: $expansion) { node in
                    Text(node.name)
                }
            }
            .frame(width: 200)
            Divider()
            Text("Some detail view would go here.")
                .frame(maxWidth: .infinity)
        }
    }
}

@MainActor func makeOutlineRoots() -> [Thing] {
    var roots = [Thing]()
    for i in 1...5 {
        let t = Thing(name: "Thing \(i)")
        roots.append( t )
    }
    return roots
}

final class Thing: TreeNodeProtocol {
    let id: UUID
    let depth: Int
    let name: String
    let color: Color
    init(name: String, depth: Int = 0) {
        self.id = UUID()
        self.name = name
        self.depth = depth
        self.color = Color(hue: Double.random(in: 0...1), saturation: 0.7, brightness: 0.7, opacity: 0.5)
    }
    
    var canHaveChildren: Bool { depth < 5 }
    var isLoadingChildren: Bool { false }
    
    /// Lazy computed property
    var children: [Thing] {
        if depth >= 5 { return [] }
        if _children == nil {
            print("Computing children property, name=\(name), depth=\(depth)")
            _children = (1...5).map { n in
                Thing(name: "\(name).\(n)", depth:depth+1)
            }
        }
        return _children!
    }
    private var _children: [Thing]? = nil
}


```

Here's another example that uses lazy loading to view the filesystem.


```
struct FileSystemView: View {
    
    @StateObject var selection = OutlineViewSingleSelectionModel<FileSystemNode>()
    // @StateObject var selection = OutlineViewMultiSelectionModel<Thing>()
    @State var expansion: Set<URL> = []
    @State var detailText: String = "??"
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                // OutlineView(roots: roots, expansion: $expansion) { node in
                OutlineView(roots: AppModel.shared.fileSystemRoots, selection: selection, expansion: $expansion, onNodeClick: onNodeClick) { node in
                    Text(node.name)
                }
            }
            .frame(width: 350)
            Divider()
            Text("Some detail view for \(detailText) would go here.")
                .frame(maxWidth: .infinity)
        }
    }
    
    func onNodeClick(_ node: FileSystemNode) {
        detailText = node.url.description
    }
}

final class FileSystemNode: TreeNodeProtocol {
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    // Needs to implement Identifiable.
    var id: URL { url }
    
    var name: String {
        url.lastPathComponent
    }

    var isDirectory: Bool {
        // Is there a better `isDirectory` check in Swift these days?
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        else {
            return false
        }
    }
    
    var canHaveChildren: Bool { isDirectory }

    @Published var isLoadingChildren: Bool = false
    
    /// Lazy computed property
    var children: [FileSystemNode] {
        if let cached = _children {
            return cached
        } else {
            if !isLoadingChildren {
                isLoadingChildren = true
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    let childNodes = loadChildNodes()
                    DispatchQueue.main.async { [self] in
                        _children = childNodes
                        isLoadingChildren = false
                    }
                }
            }
            return []
        }
    }
    
    private func loadChildNodes() -> [FileSystemNode] {
        do {
            // Simulate something that takes longer
            Thread.sleep(forTimeInterval: 3.0)
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [])            
            let nodes = urls.map { url in FileSystemNode(url: url)}
            return nodes
        } catch let err {
            print("Error reading directory: \(url)")
            return []
        }
    }
    
    @Published private var _children: [FileSystemNode]? = nil
}
```

```

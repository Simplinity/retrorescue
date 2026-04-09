# Tree View Research — Finder-like File Browser for macOS SwiftUI Apps

## Problem Statement
SwiftUI's `List(children:)` and `OutlineGroup` cannot handle 6000+ items.
We need a Finder-like tree view with disclosure triangles that handles thousands of files.

## Research Summary (50+ apps/libs/discussions analyzed)

### DEFINITIVE FINDING: Every serious macOS app uses NSOutlineView (AppKit)

| App/Project | Stars | Approach | Notes |
|---|---|---|---|
| **CodeEdit** | 22,400 | NSOutlineView + delegate/datasource | "SwiftUI's OutlineGroup has bugs and is slow, so our current implementation of NSOutlineView would still be used" |
| **PixleyReader** | New | NSOutlineView-backed sidebar | "handles large trees without lag", zero dependencies |
| **Xcode** | N/A | NSOutlineView | Apple's own IDE uses it |
| **Finder** | N/A | NSOutlineView | The gold standard |
| **BetterZip** | N/A | NSOutlineView (assumed) | Archive browser with tree view for thousands of files |

### NSOutlineView Wrappers/Libraries for SwiftUI

| Library | Stars | License | Approach | Pros | Cons |
|---|---|---|---|---|---|
| **Sameesunkaria/OutlineView** | 76 | MIT | NSOutlineView wrapper for SwiftUI | Ready-made, closure-based lazy children, selection binding, drag & drop, row animations | Requires NSView cells (not SwiftUI), last updated Feb 2023 |
| **dnadoba/Tree** | ~50 | MIT | Tree data structure + OutlineViewTreeDataSource | Value types, tree diffing, also works with SwiftUI OutlineGroup | Less focused on UI |
| **cocoabits/OutlineViewDiffableDataSource** | ~30 | MIT | Diffable data source for NSOutlineView | Efficient updates | More complex setup |
| **PXSourceList** | 450 | BSD | NSOutlineView subclass | Badges, group styling, well-established | Older, Obj-C oriented |
| **Apple SourceView sample** | N/A | Apple | NSOutlineView + NSTreeController | Official reference, Finder-like | Storyboard-based |

### SwiftUI Performance Limitations (confirmed by Apple Developer Forums)

- **Table with 1219 entries**: 13-second hang on click/select (Apple Forums thread/739849)
- **List with 100+ rows**: "Scrolling gets unacceptably slow" (Apple Forums thread/650238)
- **OutlineGroup**: Known bugs with incorrect cell updates and crashes (Sameesunkaria README)
- **CodeEdit issue #977**: Explicitly chose to keep NSOutlineView over SwiftUI migration

### WHY NSOutlineView Works (Delegate-Based Architecture)

NSOutlineView uses a pull-based delegate pattern:
```swift
// Only called for VISIBLE rows — this is the key difference
func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int
func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any
func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool
func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView?
```

SwiftUI's `List(children:)` eagerly evaluates ALL children to build the view hierarchy.
NSOutlineView only asks for data when rows become visible. This is fundamental.

### CodeEdit's Implementation (Most Relevant Reference)

CodeEdit's file navigator consists of:
1. `ProjectNavigatorViewController` — NSViewController hosting NSOutlineView
2. `+NSOutlineViewDelegate.swift` — View creation, selection handling
3. `+NSOutlineViewDataSource.swift` — Data provision (numberOfChildren, child, isExpandable)
4. `FileSystemTableViewCell` — Custom NSTableCellView with icon + label
5. `StandardTableViewCell` — Base cell class
6. Wrapped in SwiftUI via NSViewControllerRepresentable

Key patterns:
- File system monitoring triggers `reloadData()` on the outline view
- Selection changes notify SwiftUI via Combine/observation
- Filtering works by modifying the data source, then reloading
- Multi-selection supported natively by NSOutlineView
- Context menus via NSOutlineView delegate
- Drag & drop via NSOutlineViewDelegate methods

### Three Implementation Options for RetroRescue

**Option A: Sameesunkaria/OutlineView package (FASTEST, ~1 hour)**
- Add via SwiftPM: `https://github.com/Sameesunkaria/OutlineView.git`
- Use closure-based children: `OutlineView(roots) { item in vault.children(of: item) } content: { ... }`
- MIT license ✅ compatible with GPLv3
- Caveat: requires NSView cells (NSTableCellView), not SwiftUI views
- Risk: package not updated since Feb 2023, may have compatibility issues

**Option B: Custom NSOutlineView in NSViewRepresentable (RECOMMENDED, ~3 hours)**
- Full control, no dependencies
- NSViewRepresentable wrapping NSScrollView > NSOutlineView
- Coordinator as NSOutlineViewDelegate + NSOutlineViewDataSource
- Lazy data loading from Vault in delegate methods
- Selection sync via Binding
- This is what PixleyReader does — proven approach

**Option C: Full NSViewController like CodeEdit (MOST ROBUST, ~5 hours)**
- NSViewControllerRepresentable wrapping a custom NSViewController
- Separate delegate/datasource files
- Custom NSTableCellView subclass
- Most code but most battle-tested approach
- Overkill for our use case (we're not a code editor)

### RECOMMENDATION

**Option B** — Custom NSOutlineView in NSViewRepresentable.

Rationale:
1. No external dependency risk
2. Full control over the data flow (Vault → delegate → visible rows)
3. Proven pattern (PixleyReader, countless tutorials)
4. Moderate effort (~200 lines of code)
5. Can be extended later with drag & drop, multi-column, etc.

### Key Design Decisions

1. **Data model**: VaultEntry (already a struct with id, name, isDirectory, parentID)
2. **Node wrapper**: Simple class wrapping VaultEntry (NSOutlineView needs reference types)
3. **Lazy loading**: `numberOfChildrenOfItem` queries vault only when needed
4. **Selection**: Coordinator posts selection changes back to VaultState via Binding
5. **Context menu**: NSOutlineView delegate's menuForEvent or rightMouseDown
6. **Integration**: Replace extractedFilesSection with the NSViewRepresentable

### References

- CodeEdit: https://github.com/CodeEditApp/CodeEdit
- PixleyReader: https://github.com/Applacat/PixleyReader  
- OutlineView package: https://github.com/Sameesunkaria/OutlineView
- Apple SourceView: https://github.com/ooper-shlab/SourceView-Swift
- Tree package: https://github.com/dnadoba/Tree
- NSOutlineView tutorial: https://www.appcoda.com/macos-programming-nsoutlineview/
- NSOutlineView docs: https://developer.apple.com/documentation/appkit/nsoutlineview
- NSOutlineView in Swift: https://github.com/danielpi/NSOutlineViewInSwift
- OutlineViewDiffableDataSource: https://github.com/cocoabits/OutlineViewDiffableDataSource
- PXSourceList: https://github.com/Perspx/PXSourceList
- Apple Forums (SwiftUI Table perf): https://developer.apple.com/forums/thread/739849
- Apple Forums (SwiftUI List perf): https://developer.apple.com/forums/thread/650238
- CodeEdit SwiftUI issue: https://github.com/CodeEditApp/CodeEdit/issues/977

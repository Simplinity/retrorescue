import AppKit
import SwiftUI
import VaultEngine

// MARK: - Node wrapper (NSOutlineView needs reference-type items)

final class FileOutlineItem: NSObject {
    let entry: VaultEntry
    private(set) var children: [FileOutlineItem]?
    private weak var vault: Vault?
    private var childrenLoaded = false

    init(entry: VaultEntry, vault: Vault?) {
        self.entry = entry
        self.vault = vault
        super.init()
    }

    var isExpandable: Bool {
        if entry.isDirectory { return true }
        // Check if this is an extracted archive with children
        if !childrenLoaded, let vault {
            let kids = (try? vault.entries(parentID: entry.id)) ?? []
            if !kids.isEmpty { return true }
        }
        return children != nil && !(children?.isEmpty ?? true)
    }

    var childCount: Int {
        loadChildrenIfNeeded()
        return children?.count ?? 0
    }

    func child(at index: Int) -> FileOutlineItem? {
        loadChildrenIfNeeded()
        guard let children, index < children.count else { return nil }
        return children[index]
    }

    private func loadChildrenIfNeeded() {
        guard !childrenLoaded, let vault else { return }
        childrenLoaded = true
        let kids = (try? vault.entries(parentID: entry.id)) ?? []
        if kids.isEmpty {
            children = nil
        } else {
            children = kids.map { FileOutlineItem(entry: $0, vault: vault) }
        }
    }

    func reloadChildren() {
        childrenLoaded = false
        children = nil
    }
}

// MARK: - NSViewController hosting NSOutlineView

final class OutlineFileBrowserController: NSViewController {
    private var scrollView: NSScrollView!
    private(set) var outlineView: NSOutlineView!
    private var rootItems: [FileOutlineItem] = []
    private weak var vault: Vault?

    /// Callbacks to SwiftUI
    var onSelectionChanged: ((String?) -> Void)?
    var onDoubleClick: ((VaultEntry) -> Void)?
    var onExtract: ((String) -> Void)?
    var onExport: ((VaultEntry) -> Void)?
    var onGetInfo: ((VaultEntry) -> Void)?
    var onDelete: ((String) -> Void)?
    var onPreview: ((VaultEntry) -> Void)?
    var onQuickLook: ((VaultEntry) -> Void)?

    override func loadView() {
        // Create outline view
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.allowsMultipleSelection = false
        outlineView.rowSizeStyle = .small
        outlineView.floatsGroupRows = false
        outlineView.autoresizesOutlineColumn = true
        outlineView.indentationPerLevel = 16
        outlineView.target = self
        outlineView.doubleAction = #selector(outlineDoubleClicked)

        // Single column
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        col.title = "Name"
        col.resizingMask = .autoresizingMask
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col

        outlineView.delegate = self
        outlineView.dataSource = self

        // Embed in scroll view
        scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        self.view = scrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Context menu
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu
    }

    /// Load root items for a given parent entry
    func loadEntries(parentID: String, vault: Vault) {
        self.vault = vault
        let entries = (try? vault.entries(parentID: parentID)) ?? []
        rootItems = entries.map { FileOutlineItem(entry: $0, vault: vault) }
        outlineView.reloadData()
        // Auto-expand items with children if few root items
        if rootItems.count <= 5 {
            for item in rootItems where item.isExpandable {
                outlineView.expandItem(item, expandChildren: false)
            }
        }
    }

    func selectItem(withID id: String?) {
        guard let id else {
            outlineView.deselectAll(nil)
            return
        }
        // Find the item by ID in loaded items
        if let row = findRow(for: id) {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
        }
    }

    private func findRow(for id: String) -> Int? {
        for row in 0..<outlineView.numberOfRows {
            if let item = outlineView.item(atRow: row) as? FileOutlineItem,
               item.entry.id == id {
                return row
            }
        }
        return nil
    }

    @objc private func outlineDoubleClicked() {
        let row = outlineView.clickedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? FileOutlineItem else { return }
        if item.isExpandable {
            if outlineView.isItemExpanded(item) {
                outlineView.collapseItem(item)
            } else {
                outlineView.expandItem(item)
            }
        } else {
            onDoubleClick?(item.entry)
        }
    }
}

// MARK: - NSOutlineViewDataSource

extension OutlineFileBrowserController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return rootItems.count }
        guard let node = item as? FileOutlineItem else { return 0 }
        return node.childCount
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return rootItems[index] }
        guard let node = item as? FileOutlineItem else { return NSObject() }
        return node.child(at: index) ?? NSObject()
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? FileOutlineItem else { return false }
        return node.isExpandable
    }
}

// MARK: - NSOutlineViewDelegate

extension OutlineFileBrowserController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FileOutlineItem else { return nil }
        let entry = node.entry
        let cellID = NSUserInterfaceItemIdentifier("FileCell")

        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellID

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.font = .systemFont(ofSize: 11)
            cell.addSubview(textField)
            cell.textField = textField

            let sizeLabel = NSTextField(labelWithString: "")
            sizeLabel.translatesAutoresizingMaskIntoConstraints = false
            sizeLabel.font = .systemFont(ofSize: 10)
            sizeLabel.textColor = .secondaryLabelColor
            sizeLabel.alignment = .right
            sizeLabel.tag = 100
            cell.addSubview(sizeLabel)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                textField.trailingAnchor.constraint(lessThanOrEqualTo: sizeLabel.leadingAnchor, constant: -4),
                sizeLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                sizeLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                sizeLabel.widthAnchor.constraint(equalToConstant: 60),
            ])
        }

        // Configure content
        let icon: String
        if entry.isDirectory {
            icon = "folder.fill"
        } else if node.isExpandable {
            icon = "archivebox"
        } else {
            icon = "doc"
        }
        cell.imageView?.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        cell.imageView?.contentTintColor = entry.isDirectory ? .systemBlue :
            (node.isExpandable ? .systemOrange : .secondaryLabelColor)
        cell.textField?.stringValue = entry.name

        let sizeLabel = cell.viewWithTag(100) as? NSTextField
        sizeLabel?.stringValue = ByteCountFormatter.string(fromByteCount: entry.dataForkSize, countStyle: .file)

        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        if row >= 0, let item = outlineView.item(atRow: row) as? FileOutlineItem {
            onSelectionChanged?(item.entry.id)
        } else {
            onSelectionChanged?(nil)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat { 22 }
}

// MARK: - Context Menu

extension OutlineFileBrowserController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = outlineView.clickedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? FileOutlineItem else { return }
        let entry = item.entry

        menu.addItem(withTitle: "Preview", action: #selector(menuPreview(_:)), keyEquivalent: "").representedObject = entry
        menu.addItem(withTitle: "Quick Look", action: #selector(menuQuickLook(_:)), keyEquivalent: " ").representedObject = entry

        if VaultState.isExtractable(entry.name) {
            menu.addItem(.separator())
            menu.addItem(withTitle: "Extract", action: #selector(menuExtract(_:)), keyEquivalent: "").representedObject = entry
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Export to Finder", action: #selector(menuExport(_:)), keyEquivalent: "").representedObject = entry
        menu.addItem(withTitle: "Get Info", action: #selector(menuGetInfo(_:)), keyEquivalent: "i").representedObject = entry
        menu.addItem(.separator())
        let deleteItem = menu.addItem(withTitle: "Delete", action: #selector(menuDelete(_:)), keyEquivalent: "\u{08}")
        deleteItem.representedObject = entry
    }

    @objc func menuPreview(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? VaultEntry else { return }
        onPreview?(entry)
    }
    @objc func menuQuickLook(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? VaultEntry else { return }
        onQuickLook?(entry)
    }
    @objc func menuExtract(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? VaultEntry else { return }
        onExtract?(entry.id)
    }
    @objc func menuExport(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? VaultEntry else { return }
        onExport?(entry)
    }
    @objc func menuGetInfo(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? VaultEntry else { return }
        onGetInfo?(entry)
    }
    @objc func menuDelete(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? VaultEntry else { return }
        onDelete?(entry.id)
    }
}

// MARK: - SwiftUI Wrapper (NSViewControllerRepresentable)

struct OutlineFileBrowserView: NSViewControllerRepresentable {
    @ObservedObject var state: VaultState

    func makeNSViewController(context: Context) -> OutlineFileBrowserController {
        let controller = OutlineFileBrowserController()
        controller.onSelectionChanged = { id in
            DispatchQueue.main.async { state.selectExtractedFile(id: id) }
        }
        controller.onDoubleClick = { entry in
            DispatchQueue.main.async { state.quickLook(entry) }
        }
        controller.onExtract = { id in
            DispatchQueue.main.async { state.extractEntry(id: id) }
        }
        controller.onExport = { entry in
            DispatchQueue.main.async { state.exportToFinder(entry) }
        }
        controller.onGetInfo = { entry in
            DispatchQueue.main.async { state.getInfoEntry = entry }
        }
        controller.onDelete = { id in
            DispatchQueue.main.async {
                state.selectedExtractedID = id
                state.deleteSelectedExtractedFile()
            }
        }
        controller.onPreview = { entry in
            DispatchQueue.main.async { state.previewFile(entry) }
        }
        controller.onQuickLook = { entry in
            DispatchQueue.main.async { state.quickLook(entry) }
        }
        return controller
    }

    func updateNSViewController(_ controller: OutlineFileBrowserController, context: Context) {
        guard let vault = state.vault, let entry = state.selectedEntry else { return }
        // Reload when the selected sidebar entry changes
        let currentParentID = entry.id
        if context.coordinator.lastParentID != currentParentID {
            context.coordinator.lastParentID = currentParentID
            controller.loadEntries(parentID: currentParentID, vault: vault)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var lastParentID: String?
    }
}

import AppKit
import SwiftUI
import QuickLookUI

/// AppKit-based file list with multi-select and drag support for file URLs.
struct FileListTableView: NSViewRepresentable {
    @Binding var filePaths: [String]
    @Binding var selectedIndexes: IndexSet
    var onMenuAppear: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = CustomFileTableView()
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = true
        tableView.backgroundColor = NSColor.clear
        tableView.allowsEmptySelection = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        tableView.allowsTypeSelect = false
        tableView.rowSizeStyle = .small

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        column.title = "Files"
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.coordinator = context.coordinator

        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.setDraggingSourceOperationMask(.copy, forLocal: true)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = NSColor.clear

        context.coordinator.tableView = tableView
        context.coordinator.onMenuAppear = onMenuAppear

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? CustomFileTableView else { return }
        context.coordinator.filePaths = filePaths
        tableView.reloadData()

        // Keep selection in sync with binding
        if selectedIndexes != tableView.selectedRowIndexes {
            tableView.selectRowIndexes(selectedIndexes, byExtendingSelection: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(filePaths: filePaths, selectedIndexes: $selectedIndexes)
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var filePaths: [String]
        @Binding var selectedIndexes: IndexSet
        weak var tableView: CustomFileTableView?
        var previewController: PreviewPanelController?
        var onMenuAppear: (() -> Void)?

        init(filePaths: [String], selectedIndexes: Binding<IndexSet>) {
            self.filePaths = filePaths
            self._selectedIndexes = selectedIndexes
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            filePaths.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let identifier = NSUserInterfaceItemIdentifier("FileCell")
            let cell: NSTableCellView

            if let existing = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
                cell = existing
            } else {
                cell = NSTableCellView()
                cell.identifier = identifier

                let textField = NSTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.lineBreakMode = .byTruncatingMiddle

                cell.addSubview(textField)
                cell.textField = textField

                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
            }

            let path = filePaths[row]
            cell.textField?.stringValue = URL(fileURLWithPath: path).lastPathComponent
            cell.toolTip = path

            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            selectedIndexes = tableView.selectedRowIndexes
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            let path = filePaths[row]
            guard FileManager.default.fileExists(atPath: path) else { return nil }

            let url = URL(fileURLWithPath: path)
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)
            return pasteboardItem
        }

        func handleSpaceKey() {
            // Check if preview panel is open
            if let previewPanel = QLPreviewPanel.shared(), previewPanel.isVisible {
                // Close the panel
                previewPanel.close()
            } else {
                // Open the panel
                previewSelectedFiles()
            }
        }

        private func previewSelectedFiles() {
            let selectedRows = selectedIndexes.sorted()
            guard !selectedRows.isEmpty else { return }

            // Get the URLs of selected files
            var previewURLs: [URL] = []
            for index in selectedRows {
                if index < filePaths.count {
                    let path = filePaths[index]
                    previewURLs.append(URL(fileURLWithPath: path))
                }
            }

            guard !previewURLs.isEmpty else { return }

            // Create and configure the preview controller
            previewController = PreviewPanelController(urls: previewURLs)

            // Get the shared Quick Look panel
            if let previewPanel = QLPreviewPanel.shared() {
                previewPanel.dataSource = previewController
                previewPanel.delegate = previewController
                previewPanel.reloadData()
                previewPanel.makeKeyAndOrderFront(nil)
            }
        }
    }
}

// MARK: - Custom Table View to handle key events
class CustomFileTableView: NSTableView {
    weak var coordinator: FileListTableView.Coordinator?

    override func keyDown(with event: NSEvent) {
        // Space bar key code is 49
        if event.keyCode == 49 {
            coordinator?.handleSpaceKey()
            return
        }

        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)

        // Handle clicks on valid rows
        if row >= 0 {
            let modifierFlags = event.modifierFlags
            
            // Check if shift or cmd is pressed for multi-selection
            if modifierFlags.contains(.shift) || modifierFlags.contains(.command) {
                // Allow default behavior for shift+click and cmd+click
                super.mouseDown(with: event)
            } else {
                // If the row is already selected, don't change selection (allows dragging multiple selected rows)
                // Only change selection if the row wasn't selected
                if !selectedRowIndexes.contains(row) {
                    selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                }
                super.mouseDown(with: event)
            }
            return
        }

        super.mouseDown(with: event)
    }
}

// MARK: - Quick Look Preview Controller
class PreviewPanelController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var urls: [URL]

    init(urls: [URL]) {
        self.urls = urls
        super.init()
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return urls[index] as QLPreviewItem
    }
}
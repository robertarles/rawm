/// RawmShortcutsViewController.swift
///
/// A unified Shortcuts preferences tab for rawm that shows all three action types:
/// Window Actions, Clipboard Actions, and Shell Actions.
///
/// This view controller presents a table (Name | Shortcut | Delete) with an
/// "Add Shortcut" button at the bottom. Existing Rectangle window shortcuts are
/// included for reference. Non-window actions (Clipboard, Shell) can be added,
/// edited, and deleted here.

import Cocoa
import MASShortcut

// MARK: - Row Model

/// A row in the shortcuts table.
private struct ShortcutRow {
    let action: any RawmActionItem
    /// Window action rows are read-only (their shortcuts are managed by ShortcutManager/MASShortcut).
    let isWindowAction: Bool

    var name: String { action.name }
    var defaultsKey: String { action.defaultsKey }
}

// MARK: - RawmShortcutsViewController

class RawmShortcutsViewController: NSViewController {

    // MARK: Properties

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var addButton: NSButton!
    private var rows: [ShortcutRow] = []
    private var shortcutViewsByKey: [String: MASShortcutView] = [:]
    private let shortcutRecordingObserver = ShortcutRecordingObserver()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 420))
        setupUI()
        reloadRows()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        reloadRows()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Create table columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Action"
        nameColumn.minWidth = 180
        nameColumn.width = 220

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.minWidth = 80
        typeColumn.width = 100

        let shortcutColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("shortcut"))
        shortcutColumn.title = "Shortcut"
        shortcutColumn.minWidth = 160
        shortcutColumn.width = 180

        let deleteColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("delete"))
        deleteColumn.title = ""
        deleteColumn.minWidth = 30
        deleteColumn.width = 40

        tableView = NSTableView()
        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(typeColumn)
        tableView.addTableColumn(shortcutColumn)
        tableView.addTableColumn(deleteColumn)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 8, height: 2)
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false

        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addButton = NSButton(title: "Add Shortcut…", target: self, action: #selector(addShortcut(_:)))
        addButton.bezelStyle = .rounded
        addButton.translatesAutoresizingMaskIntoConstraints = false

        let headerLabel = NSTextField(labelWithString: "rawm Shortcuts — Window, Clipboard, and Shell Actions")
        headerLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        let noteLabel = NSTextField(wrappingLabelWithString: "Window action shortcuts below are shown for reference. Edit them in the Shortcuts tab. Clipboard and Shell action shortcuts can be added here.")
        noteLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.preferredMaxLayoutWidth = 540

        view.addSubview(headerLabel)
        view.addSubview(noteLabel)
        view.addSubview(scrollView)
        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            noteLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 6),
            noteLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            noteLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -12),

            addButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Data

    private func reloadRows() {
        shortcutViewsByKey.removeAll()

        // Window action rows (read-only reference)
        let windowRows: [ShortcutRow] = WindowAction.active.compactMap { action in
            guard action.displayName != nil else { return nil }
            return ShortcutRow(action: WindowActionItem(windowAction: action), isWindowAction: true)
        }

        // Non-window action rows (editable)
        let nonWindowRows: [ShortcutRow] = HotkeyRegistry.shared.nonWindowActions.map {
            ShortcutRow(action: $0, isWindowAction: false)
        }

        rows = windowRows + nonWindowRows
        tableView?.reloadData()
    }

    // MARK: - Actions

    @objc func addShortcut(_ sender: Any) {
        let sheet = AddShortcutSheet { [weak self] action in
            guard let self, let action = action else { return }
            HotkeyRegistry.shared.register(action)
            self.reloadRows()
        }
        presentAsSheet(sheet)
    }

    fileprivate func deleteRow(at index: Int) {
        guard index >= 0 && index < rows.count else { return }
        let row = rows[index]
        guard !row.isWindowAction else { return } // can't delete window actions from here
        HotkeyRegistry.shared.unregister(defaultsKey: row.defaultsKey)
        reloadRows()
    }
}

// MARK: - NSTableViewDataSource

extension RawmShortcutsViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
}

// MARK: - NSTableViewDelegate

extension RawmShortcutsViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < rows.count else { return nil }
        let shortcutRow = rows[row]

        switch tableColumn?.identifier.rawValue {

        case "name":
            let label = NSTextField(labelWithString: shortcutRow.name)
            label.lineBreakMode = .byTruncatingTail
            return label

        case "type":
            let typeString: String
            if shortcutRow.isWindowAction {
                typeString = "Window"
            } else if shortcutRow.action is ClipboardAction {
                typeString = "Clipboard"
            } else if shortcutRow.action is ShellAction {
                typeString = "Shell"
            } else {
                typeString = "Unknown"
            }
            let label = NSTextField(labelWithString: typeString)
            label.textColor = .secondaryLabelColor
            label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            return label

        case "shortcut":
            let shortcutView = MASShortcutView(frame: NSRect(x: 0, y: 0, width: 160, height: 19))
            shortcutView.setAssociatedUserDefaultsKey(shortcutRow.defaultsKey, withTransformerName: MASDictionaryTransformerName)
            shortcutView.style = .texturedRect
            // Window action shortcut views are interactive (they modify the window action shortcut)
            // Non-window action shortcut views modify HotkeyEngine bindings via UserDefaults observation
            shortcutViewsByKey[shortcutRow.defaultsKey] = shortcutView
            shortcutRecordingObserver.observe([shortcutView])

            if Defaults.allowAnyShortcut.enabled {
                shortcutView.shortcutValidator = PassthroughShortcutValidator()
            }
            return shortcutView

        case "delete":
            if shortcutRow.isWindowAction {
                return nil // no delete button for window actions
            }
            let button = NSButton(title: "✕", target: self, action: #selector(deleteButtonClicked(_:)))
            button.bezelStyle = .rounded
            button.isBordered = false
            button.tag = row
            return button

        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 24 }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        return rowView
    }

    @objc private func deleteButtonClicked(_ sender: NSButton) {
        let rowIndex = sender.tag
        deleteRow(at: rowIndex)
    }
}

// MARK: - AddShortcutSheet

/// Modal sheet for adding a new Clipboard or Shell action shortcut.
class AddShortcutSheet: NSViewController {

    private var completionHandler: ((any RawmActionItem)?) -> Void
    private var actionTypePopup: NSPopUpButton!
    private var actionDetailField: NSTextField!
    private var actionDetailLabel: NSTextField!
    private var clipboardActionPopup: NSPopUpButton!
    private var shortcutView: MASShortcutView!
    private var nameField: NSTextField!
    private let shortcutRecordingObserver = ShortcutRecordingObserver()

    init(completion: @escaping ((any RawmActionItem)?) -> Void) {
        self.completionHandler = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Not implemented") }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 260))
        setupUI()
    }

    private func setupUI() {
        let titleLabel = NSTextField(labelWithString: "Add Shortcut")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Action Type picker
        let typeLabel = NSTextField(labelWithString: "Action Type:")
        typeLabel.alignment = .right
        typeLabel.translatesAutoresizingMaskIntoConstraints = false

        actionTypePopup = NSPopUpButton()
        actionTypePopup.addItems(withTitles: ["Shell Command", "Clipboard: Show History", "Clipboard: Paste Item N"])
        actionTypePopup.target = self
        actionTypePopup.action = #selector(actionTypeChanged(_:))
        actionTypePopup.translatesAutoresizingMaskIntoConstraints = false

        // Display Name
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.alignment = .right
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        nameField = NSTextField()
        nameField.placeholderString = "e.g. Open WezTerm"
        nameField.translatesAutoresizingMaskIntoConstraints = false

        // Action detail (command for Shell, index for ClipboardPasteItem)
        actionDetailLabel = NSTextField(labelWithString: "Command:")
        actionDetailLabel.alignment = .right
        actionDetailLabel.translatesAutoresizingMaskIntoConstraints = false

        actionDetailField = NSTextField()
        actionDetailField.placeholderString = "e.g. open -a WezTerm"
        actionDetailField.translatesAutoresizingMaskIntoConstraints = false

        // Shortcut recorder
        let shortcutLabel = NSTextField(labelWithString: "Shortcut:")
        shortcutLabel.alignment = .right
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false

        shortcutView = MASShortcutView(frame: NSRect(x: 0, y: 0, width: 180, height: 22))
        shortcutView.translatesAutoresizingMaskIntoConstraints = false
        shortcutRecordingObserver.observe([shortcutView])

        // Buttons
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let addButton = NSButton(title: "Add", target: self, action: #selector(add(_:)))
        addButton.bezelStyle = .rounded
        addButton.keyEquivalent = "\r"
        addButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = NSStackView(views: [cancelButton, addButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let formGrid = NSGridView(views: [
            [typeLabel, actionTypePopup],
            [nameLabel, nameField],
            [actionDetailLabel, actionDetailField],
            [shortcutLabel, shortcutView],
        ])
        formGrid.columnSpacing = 8
        formGrid.rowSpacing = 10
        formGrid.column(at: 0).xPlacement = .trailing
        formGrid.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(formGrid)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            formGrid.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            formGrid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            formGrid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            buttonStack.topAnchor.constraint(equalTo: formGrid.bottomAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            shortcutView.widthAnchor.constraint(equalToConstant: 180),
            actionTypePopup.widthAnchor.constraint(equalToConstant: 220),
            nameField.widthAnchor.constraint(equalToConstant: 220),
            actionDetailField.widthAnchor.constraint(equalToConstant: 220),
        ])

        updateDetailFieldVisibility()
    }

    @objc private func actionTypeChanged(_ sender: NSPopUpButton) {
        updateDetailFieldVisibility()
    }

    private func updateDetailFieldVisibility() {
        let index = actionTypePopup.indexOfSelectedItem
        switch index {
        case 0: // Shell Command
            actionDetailLabel.stringValue = "Command:"
            actionDetailField.placeholderString = "e.g. open -a WezTerm"
            actionDetailField.isHidden = false
        case 1: // Clipboard: Show History
            actionDetailLabel.stringValue = ""
            actionDetailField.isHidden = true
        case 2: // Clipboard: Paste Item N
            actionDetailLabel.stringValue = "Item index (0-based):"
            actionDetailField.placeholderString = "0"
            actionDetailField.isHidden = false
        default:
            break
        }
    }

    @objc private func cancel(_ sender: Any) {
        dismiss(self)
        completionHandler(nil)
    }

    @objc private func add(_ sender: Any) {
        let typeIndex = actionTypePopup.indexOfSelectedItem
        let nameText = nameField.stringValue.isEmpty ? nil : nameField.stringValue

        var action: any RawmActionItem

        switch typeIndex {
        case 0: // Shell
            let command = actionDetailField.stringValue
            guard !command.isEmpty else {
                let alert = NSAlert()
                alert.messageText = "Command Required"
                alert.informativeText = "Please enter a shell command."
                alert.runModal()
                return
            }
            let actionName = nameText ?? "Run: \(command)"
            action = ShellAction(name: actionName, command: command)

        case 1: // Clipboard Show History
            action = ClipboardAction.showHistory

        case 2: // Clipboard Paste Item
            let indexText = actionDetailField.stringValue
            let itemIndex = Int(indexText) ?? 0
            action = ClipboardAction.pasteItem(index: itemIndex)

        default:
            dismiss(self)
            completionHandler(nil)
            return
        }

        // Save the shortcut recorded in the shortcut view to UserDefaults
        // The MASShortcutView with no associated key stores the shortcut temporarily;
        // we set the associated key to persist it.
        if let shortcut = shortcutView.shortcutValue {
            let binder = MASShortcutBinder.shared()
            binder?.registerDefaultShortcuts([action.defaultsKey: shortcut])
            // Store it in UserDefaults
            if let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName)) {
                if let dict = transformer.reverseTransformedValue(shortcut) as? [String: Any] {
                    UserDefaults.standard.set(dict, forKey: action.defaultsKey)
                }
            }
        }

        dismiss(self)
        completionHandler(action)
    }
}

// MARK: - Storyboard Instantiation

extension RawmShortcutsViewController {
    static func freshController() -> RawmShortcutsViewController {
        return RawmShortcutsViewController()
    }
}

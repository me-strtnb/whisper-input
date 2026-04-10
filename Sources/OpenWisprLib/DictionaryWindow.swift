import AppKit

class DictionaryWindow {
    private static var shared: DictionaryWindow?
    private var window: NSWindow?
    private var dictionary: CustomDictionary = .empty

    private var vocabStack: NSStackView?
    private var replacementStack: NSStackView?
    private var buttonTargets: [ButtonTarget] = []

    var onSave: (() -> Void)?

    static func show(onSave: (() -> Void)? = nil) {
        if let existing = shared, let win = existing.window, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let instance = DictionaryWindow()
        instance.onSave = onSave
        shared = instance
        instance.showWindow()
    }

    private func showWindow() {
        dictionary = CustomDictionary.load()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dictionary"
        window.center()
        window.minSize = NSSize(width: 400, height: 400)
        self.window = window

        let outerStack = NSStackView()
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 16
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        // --- Vocabulary section ---

        let vocabHeader = makeLabel("Vocabulary (\u{8a9e}\u{5f59}\u{30d2}\u{30f3}\u{30c8})", font: .systemFont(ofSize: 14, weight: .semibold))
        outerStack.addArrangedSubview(vocabHeader)

        let vocabDesc = makeLabel(
            "Words added here help Whisper recognize proper nouns and technical terms.",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )
        outerStack.addArrangedSubview(vocabDesc)
        outerStack.setCustomSpacing(8, after: vocabHeader)

        let vocabStackView = NSStackView()
        vocabStackView.orientation = .vertical
        vocabStackView.alignment = .leading
        vocabStackView.spacing = 8
        self.vocabStack = vocabStackView

        let vocabScroll = makeScrollView(for: vocabStackView)
        outerStack.addArrangedSubview(vocabScroll)
        outerStack.setCustomSpacing(8, after: vocabDesc)
        NSLayoutConstraint.activate([
            vocabScroll.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -40),
            vocabScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
        ])

        let addVocabButton = makeAddButton { [weak self] in
            self?.addVocabularyRow("")
        }
        outerStack.addArrangedSubview(addVocabButton)
        outerStack.setCustomSpacing(8, after: vocabScroll)

        // --- Separator ---

        let separator = NSBox()
        separator.boxType = .separator
        outerStack.addArrangedSubview(separator)
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -40),
        ])

        // --- Replacements section ---

        let replHeader = makeLabel("Replacements (\u{7f6e}\u{63db}\u{30eb}\u{30fc}\u{30eb})", font: .systemFont(ofSize: 14, weight: .semibold))
        outerStack.addArrangedSubview(replHeader)

        let replDesc = makeLabel(
            "Fix recurring misrecognitions.",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )
        outerStack.addArrangedSubview(replDesc)
        outerStack.setCustomSpacing(8, after: replHeader)

        let replStackView = NSStackView()
        replStackView.orientation = .vertical
        replStackView.alignment = .leading
        replStackView.spacing = 8
        self.replacementStack = replStackView

        let replScroll = makeScrollView(for: replStackView)
        outerStack.addArrangedSubview(replScroll)
        outerStack.setCustomSpacing(8, after: replDesc)
        NSLayoutConstraint.activate([
            replScroll.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -40),
            replScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
        ])

        let addReplButton = makeAddButton { [weak self] in
            self?.addReplacementRow(from: "", to: "")
        }
        outerStack.addArrangedSubview(addReplButton)
        outerStack.setCustomSpacing(8, after: replScroll)

        // --- Save button ---

        let saveButton = NSButton(title: "Save", target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        let saveTarget = ButtonTarget { [weak self] in
            self?.save()
        }
        buttonTargets.append(saveTarget)
        saveButton.target = saveTarget
        saveButton.action = #selector(ButtonTarget.invoke)

        let saveContainer = NSStackView()
        saveContainer.orientation = .horizontal
        saveContainer.alignment = .centerY
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        saveContainer.addArrangedSubview(spacer)
        saveContainer.addArrangedSubview(saveButton)
        NSLayoutConstraint.activate([
            saveContainer.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -40),
        ])
        outerStack.addArrangedSubview(saveContainer)

        // --- Outer scroll view wrapping everything ---

        let mainScroll = NSScrollView()
        mainScroll.hasVerticalScroller = true
        mainScroll.drawsBackground = false
        mainScroll.documentView = outerStack
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        window.contentView = mainScroll
        mainScroll.translatesAutoresizingMaskIntoConstraints = false
        if let contentView = window.contentView?.superview ?? window.contentView {
            NSLayoutConstraint.activate([
                mainScroll.topAnchor.constraint(equalTo: contentView.topAnchor),
                mainScroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                mainScroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                mainScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            ])
        }

        // Pin outerStack width to scroll view
        NSLayoutConstraint.activate([
            outerStack.widthAnchor.constraint(equalTo: mainScroll.widthAnchor),
        ])

        // --- Populate data ---

        for word in dictionary.vocabulary {
            addVocabularyRow(word)
        }

        for replacement in dictionary.replacements {
            addReplacementRow(from: replacement.from, to: replacement.to)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Row builders

    private func addVocabularyRow(_ word: String) {
        guard let stack = vocabStack else { return }

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let textField = NSTextField()
        textField.stringValue = word
        textField.font = .systemFont(ofSize: 13)
        textField.placeholderString = "Word or phrase"
        textField.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(textField)

        let removeButton = makeRemoveButton { [weak self, weak row] in
            guard let row = row else { return }
            self?.removeRow(row, from: self?.vocabStack)
        }
        row.addArrangedSubview(removeButton)

        row.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(row)

        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            textField.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func addReplacementRow(from: String, to: String) {
        guard let stack = replacementStack else { return }

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let fromField = NSTextField()
        fromField.stringValue = from
        fromField.font = .systemFont(ofSize: 13)
        fromField.placeholderString = "From"
        fromField.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(fromField)

        let toField = NSTextField()
        toField.stringValue = to
        toField.font = .systemFont(ofSize: 13)
        toField.placeholderString = "To"
        toField.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(toField)

        let removeButton = makeRemoveButton { [weak self, weak row] in
            guard let row = row else { return }
            self?.removeRow(row, from: self?.replacementStack)
        }
        row.addArrangedSubview(removeButton)

        row.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(row)

        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalTo: stack.widthAnchor),
            fromField.widthAnchor.constraint(equalTo: toField.widthAnchor),
            fromField.heightAnchor.constraint(equalToConstant: 24),
            toField.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func removeRow(_ row: NSStackView, from stack: NSStackView?) {
        guard let stack = stack else { return }
        stack.removeArrangedSubview(row)
        row.removeFromSuperview()
    }

    // MARK: - Save

    private func save() {
        var vocabulary: [String] = []
        if let stack = vocabStack {
            for view in stack.arrangedSubviews {
                guard let row = view as? NSStackView else { continue }
                if let textField = row.arrangedSubviews.first as? NSTextField {
                    let word = textField.stringValue.trimmingCharacters(in: .whitespaces)
                    if !word.isEmpty {
                        vocabulary.append(word)
                    }
                }
            }
        }

        var replacements: [CustomDictionary.Replacement] = []
        if let stack = replacementStack {
            for view in stack.arrangedSubviews {
                guard let row = view as? NSStackView else { continue }
                let fields = row.arrangedSubviews.compactMap { $0 as? NSTextField }
                if fields.count >= 2 {
                    let from = fields[0].stringValue.trimmingCharacters(in: .whitespaces)
                    let to = fields[1].stringValue.trimmingCharacters(in: .whitespaces)
                    if !from.isEmpty {
                        replacements.append(CustomDictionary.Replacement(from: from, to: to))
                    }
                }
            }
        }

        let dict = CustomDictionary(vocabulary: vocabulary, replacements: replacements)
        do {
            try dict.save()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to save dictionary"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        onSave?()
        window?.close()
    }

    // MARK: - UI helpers

    private func makeLabel(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }

    private func makeScrollView(for stackView: NSStackView) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = stackView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        ])

        return scrollView
    }

    private func makeRemoveButton(action: @escaping () -> Void) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.image = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Remove")
        button.title = ""
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 24),
            button.heightAnchor.constraint(equalToConstant: 24),
        ])
        let target = ButtonTarget(handler: action)
        buttonTargets.append(target)
        button.target = target
        button.action = #selector(ButtonTarget.invoke)
        return button
    }

    private func makeAddButton(action: @escaping () -> Void) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .inline
        button.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Add")
        button.title = " Add"
        button.imagePosition = .imageLeading
        button.isBordered = false
        let target = ButtonTarget(handler: action)
        buttonTargets.append(target)
        button.target = target
        button.action = #selector(ButtonTarget.invoke)
        return button
    }
}

// MARK: - ButtonTarget

private class ButtonTarget: NSObject {
    let handler: () -> Void
    init(handler: @escaping () -> Void) { self.handler = handler }
    @objc func invoke() { handler() }
}

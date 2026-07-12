//  Copyright (C) 2020  D0miH <https://github.com/D0miH> & Contributors <https://github.com/iglance/OpenGlance/graphs/contributors>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.

import Cocoa
import CocoaLumberjack

/// Draws the quiet, layered background used by the main window. The colour
/// washes are deliberately subtle so charts and labels remain the focus.
private final class ModernShellView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let base = NSColor.windowBackgroundColor.withAlphaComponent(0.82)
        base.setFill()
        dirtyRect.fill()

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        let accent: NSColor
        if #available(macOS 10.14, *) {
            accent = .controlAccentColor
        } else {
            accent = ThemeManager.currentTheme().sidebarButtonHighlightColor
        }
        let glow = NSGradient(colors: [
            accent.withAlphaComponent(0.16),
            accent.withAlphaComponent(0.0)
        ])
        glow?.draw(in: NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 360,
                                                    y: bounds.maxY - 210,
                                                    width: 460,
                                                    height: 300)), angle: 0)
        context.restoreGState()
    }
}

/// A compact, responsive navigation item in the vertical sidebar.
private final class ModernNavigationButton: NSButton {
    var isSelected = false {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        isBordered = false
        setButtonType(.momentaryChange)
        imagePosition = .imageLeading
        imageScaling = .scaleProportionallyDown
        font = .systemFont(ofSize: 13, weight: .medium)
        focusRingType = .none
        alignment = .left
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 2),
                                 xRadius: 8,
                                 yRadius: 8)
        if isSelected {
            let accent: NSColor
            if #available(macOS 10.14, *) {
                accent = .controlAccentColor
            } else {
                accent = ThemeManager.currentTheme().sidebarButtonHighlightColor
            }
            accent.withAlphaComponent(0.12).setFill()
            shape.fill()
            accent.withAlphaComponent(0.35).setStroke()
            shape.lineWidth = 1.0
            shape.stroke()
        } else if isHighlighted {
            NSColor.labelColor.withAlphaComponent(0.06).setFill()
            shape.fill()
        }

        let textColor: NSColor
        if isSelected {
            if #available(macOS 10.14, *) {
                textColor = .controlAccentColor
            } else {
                textColor = .labelColor
            }
        } else {
            textColor = .labelColor.withAlphaComponent(0.85)
        }

        // Draw title
        let textRect = NSRect(x: 42, y: (bounds.height - 18) / 2 - 1, width: bounds.width - 50, height: 18)
        let titleFont = font ?? NSFont.systemFont(ofSize: 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor
        ]
        title.draw(in: textRect, withAttributes: attributes)

        // Draw image
        if let img = image {
            let tintedImg = img.tint(color: textColor)
            let iconRect = NSRect(x: 18, y: (bounds.height - 16) / 2, width: 16, height: 16)
            tintedImg.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }
}

private final class StatusPillView: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: 76, height: 28) }

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
        NSColor.systemGreen.withAlphaComponent(0.13).setFill()
        shape.fill()
    }
}

class MainWindowViewController: NSViewController {
    var contentManagerViewController: ContentManagerViewController?
    var sidebarViewController: SidebarViewController?

    private var navigationButtons: [String: ModernNavigationButton] = [:]
    private var pageTitleLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        DDLogError("MainWindowViewController viewDidLoad called")
        buildModernShell()

        ThemeManager.addThemeChangeObserver(self) { _ in
            self.view.needsDisplay = true
            self.navigationButtons.values.forEach { $0.needsDisplay = true }
        }
    }

    private func buildModernShell() {
        DDLogError("buildModernShell start")
        view.subviews.forEach { $0.removeFromSuperview() }
        (view as? BackgroundColorView)?.backgroundColor = .clear
        DDLogError("buildModernShell backdrop setup")

        let backdrop = ModernShellView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        installGlassBackground()

        // Sidebar Surface
        let sidebarSurface = NSVisualEffectView()
        sidebarSurface.material = .sidebar
        sidebarSurface.blendingMode = .behindWindow
        sidebarSurface.state = .active
        sidebarSurface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebarSurface)

        // Sidebar Header
        let appIcon = NSImageView()
        if let image = NSImage(named: "OpenGlance_logo_white") {
            appIcon.image = image
        } else if let image = NSImage(named: "OpenGlance_logo_black") {
            appIcon.image = image
        }
        appIcon.imageScaling = .scaleProportionallyDown
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        appIcon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let appName = NSTextField(labelWithString: "OpenGlance")
        appName.font = .systemFont(ofSize: 20, weight: .bold)
        appName.textColor = .labelColor
        appName.translatesAutoresizingMaskIntoConstraints = false

        let appHeader = NSStackView(views: [appIcon, appName])
        appHeader.orientation = .horizontal
        appHeader.alignment = .centerY
        appHeader.spacing = 8
        appHeader.translatesAutoresizingMaskIntoConstraints = false
        sidebarSurface.addSubview(appHeader)

        // Navigation Stack in Sidebar
        let navigationStack = NSStackView()
        navigationStack.orientation = .vertical
        navigationStack.alignment = .leading
        navigationStack.spacing = 4
        navigationStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarSurface.addSubview(navigationStack)

        for item in SidebarButton.allCases {
            let button = ModernNavigationButton(frame: .zero)
            button.title = navigationTitle(for: item)
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: item.instance.symbolName,
                                       accessibilityDescription: button.title)
            }
            button.image?.size = NSSize(width: 16, height: 16)
            button.identifier = NSUserInterfaceItemIdentifier(item.instance.mainViewStoryboardID)
            button.target = self
            button.action = #selector(navigationButtonPressed(_:))
            button.toolTip = button.title
            
            navigationButtons[item.instance.mainViewStoryboardID] = button
            navigationStack.addArrangedSubview(button)
            
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: 36),
                button.leadingAnchor.constraint(equalTo: navigationStack.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: navigationStack.trailingAnchor)
            ])
        }

        // Live Status Pill
        let statusPill = makeStatusPill()
        statusPill.translatesAutoresizingMaskIntoConstraints = false
        sidebarSurface.addSubview(statusPill)

        // Page Title Label in Right Area
        pageTitleLabel = NSTextField(labelWithString: "Overview")
        pageTitleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        pageTitleLabel.textColor = .labelColor
        pageTitleLabel.lineBreakMode = .byTruncatingTail
        pageTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageTitleLabel)

        // Content Surface in Right Area
        let contentSurface = NSVisualEffectView()
        if #available(macOS 10.14, *) {
            contentSurface.material = .contentBackground
        } else {
            contentSurface.material = .sidebar
        }
        contentSurface.blendingMode = .withinWindow
        contentSurface.state = .active
        contentSurface.wantsLayer = true
        contentSurface.layer?.cornerRadius = 16
        contentSurface.layer?.borderWidth = 1
        let borderColor: NSColor
        if #available(macOS 10.14, *) {
            borderColor = .separatorColor
        } else {
            borderColor = .gridColor
        }
        contentSurface.layer?.borderColor = borderColor.withAlphaComponent(0.28).cgColor
        contentSurface.layer?.masksToBounds = true
        contentSurface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentSurface)

        // The old storyboard host was removed above. Its embed segue may not
        // have run yet while this controller's view is loading, so relying on
        // `prepare(for:)` here left the new content surface with no child at
        // all. Create the manager explicitly and retain it as a child before
        // embedding its view.
        let manager: ContentManagerViewController
        if let existingManager = contentManagerViewController {
            manager = existingManager
        } else if let storyboardManager = storyboard?.instantiateController(withIdentifier: "ContentManagerViewController") as? ContentManagerViewController {
            addChild(storyboardManager)
            contentManagerViewController = storyboardManager
            manager = storyboardManager
        } else {
            DDLogError("Could not instantiate ContentManagerViewController")
            return
        }

        let contentView = manager.view
        contentView.removeFromSuperview()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentSurface.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: contentSurface.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentSurface.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: contentSurface.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentSurface.bottomAnchor)
        ])

        NSLayoutConstraint.activate([
            // Sidebar constraints
            sidebarSurface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarSurface.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarSurface.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarSurface.widthAnchor.constraint(equalToConstant: 200),

            // Sidebar Header constraints
            appHeader.leadingAnchor.constraint(equalTo: sidebarSurface.leadingAnchor, constant: 18),
            appHeader.trailingAnchor.constraint(equalTo: sidebarSurface.trailingAnchor, constant: -18),
            appHeader.topAnchor.constraint(equalTo: sidebarSurface.topAnchor, constant: 28),

            // Sidebar Navigation constraints
            navigationStack.leadingAnchor.constraint(equalTo: sidebarSurface.leadingAnchor, constant: 0),
            navigationStack.trailingAnchor.constraint(equalTo: sidebarSurface.trailingAnchor, constant: 0),
            navigationStack.topAnchor.constraint(equalTo: appHeader.bottomAnchor, constant: 24),

            // Status Pill constraints
            statusPill.leadingAnchor.constraint(equalTo: sidebarSurface.leadingAnchor, constant: 18),
            statusPill.bottomAnchor.constraint(equalTo: sidebarSurface.bottomAnchor, constant: -24),

            // Page Title constraints (Right Area)
            pageTitleLabel.leadingAnchor.constraint(equalTo: sidebarSurface.trailingAnchor, constant: 24),
            pageTitleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            pageTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // Content Surface constraints (Right Area)
            contentSurface.leadingAnchor.constraint(equalTo: sidebarSurface.trailingAnchor, constant: 20),
            contentSurface.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentSurface.topAnchor.constraint(equalTo: pageTitleLabel.bottomAnchor, constant: 18),
            contentSurface.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])

        selectNavigationItem(storyboardID: SidebarButton.Dashboard.instance.mainViewStoryboardID)
    }

    private func makeStatusPill() -> NSView {
        let pill = StatusPillView()
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        dot.layer?.cornerRadius = 3.5
        dot.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "LIVE")
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .systemGreen
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(dot)
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            dot.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 7),
            dot.heightAnchor.constraint(equalToConstant: 7),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 7),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor)
        ])
        return pill
    }

    private func installGlassBackground() {
        guard #available(macOS 11.0, *) else { return }
        let glass = NSVisualEffectView()
        glass.material = .underWindowBackground
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glass, positioned: .below, relativeTo: nil)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glass.topAnchor.constraint(equalTo: view.topAnchor),
            glass.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func navigationTitle(for item: SidebarButton) -> String {
        switch item {
        case .Dashboard: return "Overview"
        case .Cpu: return "CPU"
        case .Memory: return "Memory"
        case .Network: return "Network"
        case .Fan: return "Cooling"
        case .Battery: return "Battery"
        case .Disk: return "Storage"
        case .Settings: return "Settings"
        }
    }

    @objc private func navigationButtonPressed(_ sender: ModernNavigationButton) {
        guard let storyboardID = sender.identifier?.rawValue else { return }
        selectNavigationItem(storyboardID: storyboardID)
        guard let controller = storyboard?.instantiateController(withIdentifier: storyboardID) as? MainViewViewController else {
            DDLogError("Could not instantiate selected page \(storyboardID)")
            return
        }
        contentManagerViewController?.display(viewController: controller)
    }

    private func selectNavigationItem(storyboardID: String) {
        navigationButtons.forEach { $0.value.isSelected = $0.key == storyboardID }
        if let item = SidebarButton.allCases.first(where: { $0.instance.mainViewStoryboardID == storyboardID }) {
            pageTitleLabel?.stringValue = navigationTitle(for: item)
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let manager = segue.destinationController as? ContentManagerViewController {
            // `buildModernShell()` owns the active manager. Ignore the
            // storyboard's now-detached embed controller if it finishes later.
            if contentManagerViewController == nil {
                contentManagerViewController = manager
            }
        } else if let sidebar = segue.destinationController as? SidebarViewController {
            sidebarViewController = sidebar
        }
    }

    override func viewWillAppear() {
        NSApp.setActivationPolicy(.regular)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        DDLogError("--- DEBUG VIEW HIERARCHY ---")
        DDLogError("Main View: \(view), frame: \(view.frame), isHidden: \(view.isHidden)")
        DDLogError("Subviews count: \(view.subviews.count)")
        for sv in view.subviews {
            DDLogError("  - Subview: \(sv), frame: \(sv.frame), isHidden: \(sv.isHidden), alpha: \(sv.alphaValue)")
            for ssv in sv.subviews {
                DDLogError("    * Child: \(ssv), frame: \(ssv.frame), isHidden: \(ssv.isHidden), alpha: \(ssv.alphaValue)")
            }
        }
        DDLogError("----------------------------")
    }
}


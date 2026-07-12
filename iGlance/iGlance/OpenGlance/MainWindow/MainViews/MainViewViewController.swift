//  Copyright (C) 2020  D0miH <https://github.com/D0miH> & Contributors <https://github.com/iglance/OpenGlance/graphs/contributors>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Cocoa

/**
 * Parent class for the main views.
 */
class MainViewViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // set the color of the main view and add a callback to change the color on theme change
        let backgroundView = self.view as! BackgroundColorView
        if #available(macOS 11.0, *) {
            backgroundView.backgroundColor = .clear
        } else {
            backgroundView.backgroundColor = ThemeManager.currentTheme().mainViewBackgroundColor
        }
        // Preserve the dashboard's card layout, while presenting configuration
        // pages as a single native grouped-settings surface.
        backgroundView.drawsGroupedSurface = !(self is DashboardViewController)
        ThemeManager.addThemeChangeObserver(self) { _ in
            if #available(macOS 11.0, *) {
                backgroundView.backgroundColor = .clear
            } else {
                backgroundView.backgroundColor = ThemeManager.currentTheme().mainViewBackgroundColor
            }
        }

        // trigger didSet methods of all outlets to update GUI
        updateGUIComponents()

        // Storyboard scenes intentionally keep ownership of their actions and
        // constraints. Apply one modern component language after every outlet
        // is connected so visual polish never interferes with setup logic.
        ModernComponentStyler.apply(to: view, isDashboard: self is DashboardViewController)
    }

    /**
     * This function will trigger the didSet of all outlets in the main view.
     */
    func updateGUIComponents() {
        // Implement in inherited class
        fatalError("Function 'updateGUIComponents' not implemented")
    }
}

struct SettingsFormRow {
    let leftView: NSView?
    let rightView: NSView?
    
    init(left: NSView? = nil, right: NSView? = nil) {
        self.leftView = left
        self.rightView = right
    }
    
    init(label: String, subtitle: String? = nil, control: NSView) {
        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 13, weight: .medium)
        labelField.textColor = .labelColor
        labelField.lineBreakMode = .byTruncatingTail
        labelField.translatesAutoresizingMaskIntoConstraints = false
        
        if let sub = subtitle {
            let subtitleField = NSTextField(labelWithString: sub)
            subtitleField.font = .systemFont(ofSize: 11, weight: .regular)
            subtitleField.textColor = .secondaryLabelColor
            subtitleField.lineBreakMode = .byTruncatingTail
            subtitleField.translatesAutoresizingMaskIntoConstraints = false
            
            let labelStack = NSStackView(views: [labelField, subtitleField])
            labelStack.orientation = .vertical
            labelStack.alignment = .leading
            labelStack.spacing = 2
            labelStack.translatesAutoresizingMaskIntoConstraints = false
            self.leftView = labelStack
        } else {
            self.leftView = labelField
        }
        
        self.rightView = control
    }
}

struct SettingsFormSection {
    let title: String?
    let rows: [SettingsFormRow]
}

class SettingsFormBuilder {
    @discardableResult
    static func build(in rootView: NSView, sections: [SettingsFormSection]) -> [[NSView]] {
        rootView.subviews.forEach { $0.removeFromSuperview() }
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Flexible size settings to prevent forcing window size changes
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        rootView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: rootView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])
        
        let clipView = scrollView.contentView
        let containerStack = NSStackView()
        containerStack.orientation = .vertical
        containerStack.alignment = .centerX
        containerStack.spacing = 20
        containerStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = containerStack
        
        NSLayoutConstraint.activate([
            containerStack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            containerStack.topAnchor.constraint(equalTo: clipView.topAnchor)
        ])
        
        var result: [[NSView]] = []
        for section in sections {
            var sectionRows: [NSView] = []
            let sectionStack = NSStackView()
            sectionStack.orientation = .vertical
            sectionStack.alignment = .leading
            sectionStack.spacing = 10
            sectionStack.translatesAutoresizingMaskIntoConstraints = false
            containerStack.addArrangedSubview(sectionStack)
            
            sectionStack.leadingAnchor.constraint(equalTo: containerStack.leadingAnchor, constant: 16).isActive = true
            sectionStack.trailingAnchor.constraint(equalTo: containerStack.trailingAnchor, constant: -16).isActive = true
            
            if let title = section.title {
                let titleLabel = NSTextField(labelWithString: title.uppercased())
                titleLabel.font = .systemFont(ofSize: 11, weight: .bold)
                titleLabel.textColor = .secondaryLabelColor
                titleLabel.translatesAutoresizingMaskIntoConstraints = false
                sectionStack.addArrangedSubview(titleLabel)
                titleLabel.leadingAnchor.constraint(equalTo: sectionStack.leadingAnchor, constant: 6).isActive = true
            }
            
            let cardBox = NSBox()
            cardBox.boxType = .custom
            cardBox.borderWidth = 1
            let borderColor: NSColor
            if #available(macOS 10.14, *) {
                borderColor = .separatorColor
            } else {
                borderColor = .gridColor
            }
            cardBox.borderColor = borderColor.withAlphaComponent(0.24)
            cardBox.cornerRadius = 12
            cardBox.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72)
            cardBox.translatesAutoresizingMaskIntoConstraints = false
            sectionStack.addArrangedSubview(cardBox)
            
            cardBox.leadingAnchor.constraint(equalTo: sectionStack.leadingAnchor).isActive = true
            cardBox.trailingAnchor.constraint(equalTo: sectionStack.trailingAnchor).isActive = true
            
            let cardContentStack = NSStackView()
            cardContentStack.orientation = .vertical
            cardContentStack.alignment = .leading
            cardContentStack.spacing = 0
            cardContentStack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
            cardContentStack.translatesAutoresizingMaskIntoConstraints = false
            cardBox.contentView?.addSubview(cardContentStack)
            
            NSLayoutConstraint.activate([
                cardContentStack.leadingAnchor.constraint(equalTo: cardBox.contentView!.leadingAnchor),
                cardContentStack.trailingAnchor.constraint(equalTo: cardBox.contentView!.trailingAnchor),
                cardContentStack.topAnchor.constraint(equalTo: cardBox.contentView!.topAnchor),
                cardContentStack.bottomAnchor.constraint(equalTo: cardBox.contentView!.bottomAnchor)
            ])
            
            for (index, row) in section.rows.enumerated() {
                if index > 0 {
                    let separator = NSBox()
                    separator.boxType = .separator
                    separator.translatesAutoresizingMaskIntoConstraints = false
                    cardContentStack.addArrangedSubview(separator)
                    
                    separator.leadingAnchor.constraint(equalTo: cardContentStack.leadingAnchor, constant: 4).isActive = true
                    separator.trailingAnchor.constraint(equalTo: cardContentStack.trailingAnchor, constant: -4).isActive = true
                    
                    cardContentStack.setCustomSpacing(14, after: separator)
                }
                
                let rowStack = NSStackView()
                rowStack.orientation = .horizontal
                rowStack.alignment = .centerY
                rowStack.distribution = .fill
                rowStack.spacing = 12
                rowStack.translatesAutoresizingMaskIntoConstraints = false
                cardContentStack.addArrangedSubview(rowStack)
                
                rowStack.leadingAnchor.constraint(equalTo: cardContentStack.leadingAnchor).isActive = true
                rowStack.trailingAnchor.constraint(equalTo: cardContentStack.trailingAnchor).isActive = true
                rowStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
                
                if let left = row.leftView {
                    rowStack.addArrangedSubview(left)
                    left.translatesAutoresizingMaskIntoConstraints = false
                    left.setContentHuggingPriority(.defaultLow, for: .horizontal)
                }
                
                if let right = row.rightView {
                    rowStack.addArrangedSubview(right)
                    right.translatesAutoresizingMaskIntoConstraints = false
                    right.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                    right.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                }
                
                cardContentStack.setCustomSpacing(14, after: rowStack)
                sectionRows.append(rowStack)
            }
            result.append(sectionRows)
        }
        return result
    }
}

private enum ModernComponentStyler {
    static func apply(to rootView: NSView, isDashboard: Bool) {
        style(view: rootView, isDashboard: isDashboard, depth: 0)
    }

    private static func style(view: NSView, isDashboard: Bool, depth: Int) {
        if let stack = view as? NSStackView {
            stack.detachesHiddenViews = true
            if stack.orientation == .vertical {
                stack.spacing = max(stack.spacing, isDashboard ? 10 : 12)
            } else {
                stack.spacing = max(stack.spacing, 8)
            }
        }

        if let popUp = view as? NSPopUpButton {
            popUp.controlSize = .regular
            popUp.font = .systemFont(ofSize: 12.5, weight: .medium)
            popUp.bezelStyle = .rounded
        } else if let button = view as? NSButton {
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.controlSize = .regular
            button.focusRingType = .default
            if button.bezelStyle == .regularSquare {
                button.imagePosition = .imageLeading
                button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            }
        } else if let slider = view as? NSSlider {
            slider.controlSize = .regular
        } else if let segmented = view as? NSSegmentedControl {
            segmented.controlSize = .regular
            segmented.segmentStyle = .rounded
            segmented.font = .systemFont(ofSize: 12, weight: .medium)
        } else if let field = view as? NSTextField {
            if field.isEditable {
                field.controlSize = .regular
                field.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
                field.focusRingType = .default
                field.wantsLayer = true
                field.layer?.cornerRadius = 7
            } else {
                field.textColor = .labelColor
                if field.font?.pointSize ?? 0 < 13 {
                    field.font = .systemFont(ofSize: 13, weight: .regular)
                }
            }
        } else if let image = view as? NSImageView, !isDashboard {
            image.imageScaling = .scaleProportionallyDown
        }

        view.subviews.forEach { style(view: $0, isDashboard: isDashboard, depth: depth + 1) }
    }
}

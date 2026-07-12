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


class BackgroundColorView: NSView {
    /// Applies a native grouped-settings surface behind a controller's controls.
    var drawsGroupedSurface = false {
        didSet { needsDisplay = true }
    }

    var backgroundColor: NSColor? {
        didSet {
            self.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if let color = self.backgroundColor {
            color.setFill()
            self.bounds.fill()
        }

        if drawsGroupedSurface {
            drawModernComponentSurfaces()
        }

        // draw the content
        super.draw(dirtyRect)
    }

    private func drawModernComponentSurfaces() {
        let visibleSubviews = subviews.filter {
            !$0.isHidden && $0.alphaValue > 0 && !($0 is NSBox && ($0 as? NSBox)?.boxType == .separator)
        }
        guard !visibleSubviews.isEmpty else { return }
        
        // Skip legacy surface drawing if using the new responsive scroll-based form layout
        if visibleSubviews.contains(where: { $0 is NSScrollView }) {
            return
        }

        let accent: NSColor
        if #available(macOS 10.14, *) {
            accent = .controlAccentColor
        } else {
            accent = ThemeManager.currentTheme().sidebarButtonHighlightColor
        }

        // Each top-level setting becomes a distinct, tactile row. Complex
        // horizontal stacks remain one surface, keeping related controls clear.
        for component in visibleSubviews {
            var rect = component.frame.insetBy(dx: -14, dy: -10)
            rect.origin.x = max(14, rect.origin.x)
            rect.size.width = min(bounds.maxX - rect.minX - 14, rect.width)
            guard rect.width > 20, rect.height > 12 else { continue }

            NSColor.controlBackgroundColor.withAlphaComponent(0.72).setFill()
            let card = NSBezierPath(roundedRect: rect, xRadius: 11, yRadius: 11)
            card.fill()

            let separator: NSColor
            if #available(macOS 10.14, *) {
                separator = .separatorColor
            } else {
                separator = .gridColor
            }
            separator.withAlphaComponent(0.24).setStroke()
            card.lineWidth = 1
            card.stroke()

            let marker = NSBezierPath(roundedRect: NSRect(x: rect.minX + 1,
                                                          y: rect.minY + 7,
                                                          width: 3,
                                                          height: max(8, rect.height - 14)),
                                      xRadius: 1.5,
                                      yRadius: 1.5)
            accent.withAlphaComponent(0.55).setFill()
            marker.fill()
        }
    }

    override func isAccessibilityElement() -> Bool {
        true
    }
}

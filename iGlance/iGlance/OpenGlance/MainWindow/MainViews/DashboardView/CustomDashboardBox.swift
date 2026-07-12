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
 * Custom NSBox class to display info in the dashboard.
 */
class CustomDashboardBox: NSBox {
    // MARK: -
    // MARK: Variable Overrides
    override var borderWidth: CGFloat {
        get {
            0.0
        }
        // swiftlint:disable:next unused_setter_value
        set {
            super.borderWidth = 0.0
        }
    }

    override var fillColor: NSColor {
        get {
            NSColor.controlBackgroundColor.withAlphaComponent(0.76)
        }
        // swiftlint:disable:next unused_setter_value
        set {
            super.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.76)
        }
    }

    override var cornerRadius: CGFloat {
        get {
            14
        }
        // swiftlint:disable:next unused_setter_value
        set {
            super.cornerRadius = 14
        }
    }

    // MARK: -
    // MARK: Function Overrides
    override func draw(_ dirtyRect: NSRect) {
        // update the color depending on the current theme
        self.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.76)
        self.wantsLayer = true
        self.layer?.borderWidth = 1
        let borderColor: NSColor
        if #available(macOS 10.14, *) {
            borderColor = .separatorColor
        } else {
            borderColor = .gridColor
        }
        self.layer?.borderColor = borderColor.withAlphaComponent(0.28).cgColor
        self.layer?.cornerRadius = 14
        self.layer?.shadowColor = NSColor.black.cgColor
        self.layer?.shadowOpacity = ThemeManager.isDarkTheme() ? 0.20 : 0.08
        self.layer?.shadowRadius = 10
        self.layer?.shadowOffset = NSSize(width: 0, height: -2)

        super.draw(dirtyRect)
    }
}

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
import CocoaLumberjack

class FanViewController: MainViewViewController {
    private var unitRow: NSView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupProgrammaticLayout()
    }
    
    private func setupProgrammaticLayout() {
        let sections = [
            SettingsFormSection(title: "Fan Settings", rows: [
                SettingsFormRow(left: fanSpeedCheckbox, right: nil),
                SettingsFormRow(left: fanSpeedUnitCheckbox, right: nil)
            ])
        ]
        let rows = SettingsFormBuilder.build(in: self.view, sections: sections)
        unitRow = rows[0][1]
        
        // Initial visibility
        unitRow?.isHidden = !AppDelegate.userSettings.settings.fan.showFanSpeed
    }

    // MARK: -
    // MARK: Outlets

    @IBOutlet private var fanSpeedCheckbox: NSButton! {
        didSet {
            fanSpeedCheckbox.state = AppDelegate.userSettings.settings.fan.showFanSpeed ? NSButton.StateValue.on : NSButton.StateValue.off
        }
    }

    @IBOutlet private var fanSpeedUnitCheckbox: NSButton! {
        didSet {
            fanSpeedUnitCheckbox.state = AppDelegate.userSettings.settings.fan.showFanSpeedUnit ? NSButton.StateValue.on : NSButton.StateValue.off
            fanSpeedUnitCheckbox.isHidden = (fanSpeedCheckbox.state == .off)
        }
    }

    // MARK: -
    // MARK: Function Overrides
    override func updateGUIComponents() {
        // Call didSet methods of all GUI components
        self.fanSpeedCheckbox = { self.fanSpeedCheckbox }()
        self.fanSpeedUnitCheckbox = { self.fanSpeedUnitCheckbox }()
        // Both outlets must be connected before this method changes the unit
        // checkbox. Calling it from fanSpeedCheckbox.didSet crashes while the
        // storyboard is still instantiating the controller on fanless Macs.
        configureFanAvailability()
    }

    private func configureFanAvailability() {
        guard AppDelegate.systemInfo.fan.getNumberOfFans() == 0 else { return }

        fanSpeedCheckbox.state = .off
        fanSpeedCheckbox.isEnabled = false
        fanSpeedCheckbox.title = "Fan speed — Unavailable on this Mac"
        fanSpeedCheckbox.toolTip = "This Mac has no fan sensor available to OpenGlance."
        unitRow?.isHidden = true
        AppDelegate.userSettings.settings.fan.showFanSpeed = false
    }

    // MARK: -
    // MARK: Actions

    @IBAction private func fanSpeedCheckboxChanged(_ sender: NSButton) {
        // get the boolean value of the checkbox
        let activated = sender.state == NSButton.StateValue.on

        // depending on the state of the checkbox hide or show the unit checkbox
        unitRow?.isHidden = !activated

        // set the user setting
        AppDelegate.userSettings.settings.fan.showFanSpeed = activated

        if activated {
            AppDelegate.menuBarItemManager.fan.show()
        } else {
            AppDelegate.menuBarItemManager.fan.hide()
        }

        DDLogInfo("Did set fan speed checkbox value to (\(activated))")
    }

    @IBAction private func fanSpeedUnitCheckboxChanged(_ sender: NSButton) {
        // get the boolean value of the checkbox
        let activated = sender.state == NSButton.StateValue.on

        // set the user setting
        AppDelegate.userSettings.settings.fan.showFanSpeedUnit = activated

        // update the menu bar items to visualize the change
        AppDelegate.menuBarItemManager.updateMenuBarItems()

        DDLogInfo("Did set fan speed unit checkbox value to (\(activated))")
    }
}

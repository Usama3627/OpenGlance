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

class BatteryViewController: MainViewViewController {
    private var formatRow: NSView?
    private var lowBatteryThresholdRow: NSView?
    private var highBatteryThresholdRow: NSView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupProgrammaticLayout()
    }
    
    private func setupProgrammaticLayout() {
        batterySelector.translatesAutoresizingMaskIntoConstraints = false
        batterySelector.widthAnchor.constraint(equalToConstant: 140).isActive = true
        
        lowBatteryNotificationTextField.translatesAutoresizingMaskIntoConstraints = false
        lowBatteryNotificationTextField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        
        let lowThresholdRightStack = NSStackView(views: [lowBatteryNotificationTextField])
        lowThresholdRightStack.orientation = .horizontal
        lowThresholdRightStack.alignment = .centerY
        lowThresholdRightStack.spacing = 26
        lowThresholdRightStack.translatesAutoresizingMaskIntoConstraints = false
        
        highBatteryNotificationTextField.translatesAutoresizingMaskIntoConstraints = false
        highBatteryNotificationTextField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        
        let highThresholdRightStack = NSStackView(views: [highBatteryNotificationTextField])
        highThresholdRightStack.orientation = .horizontal
        highThresholdRightStack.alignment = .centerY
        highThresholdRightStack.spacing = 26
        highThresholdRightStack.translatesAutoresizingMaskIntoConstraints = false
        
        let sections = [
            SettingsFormSection(title: "Battery Status", rows: [
                SettingsFormRow(left: batteryCheckbox, right: nil),
                SettingsFormRow(label: "Display Format", subtitle: "Select format in the menu bar", control: batterySelector)
            ]),
            SettingsFormSection(title: "Notifications", rows: [
                SettingsFormRow(left: lowBatteryNotificationCheckbox, right: nil),
                SettingsFormRow(label: "Low Battery Level", subtitle: "Notify when charge drops below this percent", control: lowThresholdRightStack),
                SettingsFormRow(left: highBatteryNotificationCheckbox, right: nil),
                SettingsFormRow(label: "High Battery Level", subtitle: "Notify when charge rises above this percent", control: highThresholdRightStack)
            ])
        ]
        
        let rows = SettingsFormBuilder.build(in: self.view, sections: sections)
        formatRow = rows[0][1]
        lowBatteryThresholdRow = rows[1][1]
        highBatteryThresholdRow = rows[1][3]
        
        // Initial visibility
        formatRow?.isHidden = !AppDelegate.userSettings.settings.battery.showBatteryMenuBarItem
        lowBatteryThresholdRow?.isHidden = !AppDelegate.userSettings.settings.battery.lowBatteryNotification.notifyUser
        highBatteryThresholdRow?.isHidden = !AppDelegate.userSettings.settings.battery.highBatteryNotification.notifyUser
    }

    // MARK: -
    // MARK: Outlets

    @IBOutlet private var batteryCheckbox: NSButton! {
        didSet {
            batteryCheckbox.state = AppDelegate.userSettings.settings.battery.showBatteryMenuBarItem ? .on : .off
        }
    }

    @IBOutlet private var batterySelector: NSPopUpButton! {
        didSet {
            if AppDelegate.userSettings.settings.battery.showPercentage {
                // showing percentage is the second option
                batterySelector.selectItem(at: 1)
            } else {
                // showing the remaining time is the first option
                batterySelector.selectItem(at: 0)
            }
        }
    }

    @IBOutlet private var displayedInfoStackView: NSStackView! {
        didSet {
            // if the usage is not displayed hide it
            if !AppDelegate.userSettings.settings.battery.showBatteryMenuBarItem {
                displayedInfoStackView.isHidden = true
            }
        }
    }

    @IBOutlet private var lowBatteryNotificationCheckbox: NSButton! {
        didSet {
            lowBatteryNotificationCheckbox.state = AppDelegate.userSettings.settings.battery.lowBatteryNotification.notifyUser ? .on : .off
        }
    }

    @IBOutlet private var highBatteryNotificationCheckbox: NSButton! {
        didSet {
            highBatteryNotificationCheckbox.state = AppDelegate.userSettings.settings.battery.highBatteryNotification.notifyUser ? .on : .off
        }
    }

    @IBOutlet private var lowBatteryNotificationTextField: NSTextField! {
        didSet {
            lowBatteryNotificationTextField.tag = 1
            configureThresholdField(lowBatteryNotificationTextField, value: AppDelegate.userSettings.settings.battery.lowBatteryNotification.value)

            // set the action that is called when the user finished editing
            lowBatteryNotificationTextField.target = self
            lowBatteryNotificationTextField.action = #selector(lowBatteryNotificationTextFieldChanged(_:))
        }
    }

    @IBOutlet private var lowBatteryNotificationStackView: NSStackView! {
        didSet {
            if !AppDelegate.userSettings.settings.battery.lowBatteryNotification.notifyUser {
                lowBatteryNotificationStackView.isHidden = true
            }
        }
    }

    @IBOutlet private var highBatteryNotificationTextField: NSTextField! {
        didSet {
            highBatteryNotificationTextField.tag = 2
            configureThresholdField(highBatteryNotificationTextField, value: AppDelegate.userSettings.settings.battery.highBatteryNotification.value)

            // set the action that is called when the user finished editing
            highBatteryNotificationTextField.target = self
            highBatteryNotificationTextField.action = #selector(highBatteryNotificationTextFieldChanged(_:))
        }
    }

    @IBOutlet private var highBatteryNotificationStackView: NSStackView! {
        didSet {
            if !AppDelegate.userSettings.settings.battery.highBatteryNotification.notifyUser {
                highBatteryNotificationStackView.isHidden = true
            }
        }
    }

    // MARK: -
    // MARK: Function Overrides
    override func updateGUIComponents() {
        // Call didSet methods of all GUI components
        self.batteryCheckbox = { self.batteryCheckbox }()
        self.batterySelector = { self.batterySelector }()
        self.displayedInfoStackView = { self.displayedInfoStackView }()
        self.lowBatteryNotificationCheckbox = { self.lowBatteryNotificationCheckbox }()
        self.highBatteryNotificationCheckbox = { self.highBatteryNotificationCheckbox }()
        self.lowBatteryNotificationTextField = { self.lowBatteryNotificationTextField }()
        self.lowBatteryNotificationStackView = { self.lowBatteryNotificationStackView }()
        self.highBatteryNotificationTextField = { self.highBatteryNotificationTextField }()
        self.highBatteryNotificationStackView = { self.highBatteryNotificationStackView }()
    }

    // MARK: -
    // MARK: Actions

    @IBAction private func batteryCheckboxChanged(_ sender: NSButton) {
        // get the boolean value of the checkbox
        let activated = sender.state == .on

        // set the user settings
        AppDelegate.userSettings.settings.battery.showBatteryMenuBarItem = activated

        if activated {
            AppDelegate.menuBarItemManager.battery.show()
        } else {
            AppDelegate.menuBarItemManager.battery.hide()
        }

        // hide the other settings
        formatRow?.isHidden = !activated

        DDLogInfo("Did set battery checkbox value to (\(activated))")
    }

    @IBAction private func batterySelectorChanged(_ sender: NSPopUpButton) {
        if batterySelector.indexOfSelectedItem == 0 {
            // the first item is to display the remaining time
            AppDelegate.userSettings.settings.battery.showPercentage = false
        } else {
            // the second item is to display the percentage
            AppDelegate.userSettings.settings.battery.showPercentage = true
        }

        // update the menu bar items to make the change visible immediately
        AppDelegate.menuBarItemManager.updateMenuBarItems()

        DDLogInfo("Selected option to display battery percentage: \(AppDelegate.userSettings.settings.battery.showPercentage)")
    }

    @IBAction private func lowBatteryNotificationCheckboxChanged(_ sender: NSButton) {
        // get the status of the checkbox
        let activated = sender.state == .on

        // update the user settings
        AppDelegate.userSettings.settings.battery.lowBatteryNotification.notifyUser = activated

        //  hide the value text field stack view if necessary
        lowBatteryThresholdRow?.isHidden = !activated
    }

    @IBAction private func highBatteryNotificationCheckboxChanged(_ sender: NSButton) {
        // get the status of the checkbox
        let activated = sender.state == .on

        // update the user settings
        AppDelegate.userSettings.settings.battery.highBatteryNotification.notifyUser = activated

        //  hide the value text field stack view if necessary
        highBatteryThresholdRow?.isHidden = !activated
    }

    @objc
    private func lowBatteryNotificationTextFieldChanged(_ sender: NSTextField) {
        let value = validatedThreshold(sender.intValue)
        sender.intValue = Int32(value)

        // update the user settings
        AppDelegate.userSettings.settings.battery.lowBatteryNotification.value = value

        // set the first responder to nil in order to loose focus
        lowBatteryNotificationTextField.window?.makeFirstResponder(lowBatteryNotificationTextField.window?.contentView)
    }

    @objc
    private func highBatteryNotificationTextFieldChanged(_ sender: NSTextField) {
        let value = validatedThreshold(sender.intValue)
        sender.intValue = Int32(value)

        // update the user settings
        AppDelegate.userSettings.settings.battery.highBatteryNotification.value = value

        // set the first responder to nil in order to loose focus
        highBatteryNotificationTextField.window?.makeFirstResponder(highBatteryNotificationTextField.window?.contentView)
    }

    private func configureThresholdField(_ field: NSTextField, value: Int) {
        field.intValue = Int32(validatedThreshold(Int32(value)))
        field.placeholderString = "0–100%"
        field.toolTip = "Enter a percentage from 0 to 100. Use the adjacent stepper or type a value."

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
        formatter.maximum = 100
        formatter.maximumFractionDigits = 0
        formatter.positiveSuffix = "%"
        field.formatter = formatter

        let stepperTag = 1_000 + field.tag
        if let existingStepper = field.superview?.viewWithTag(stepperTag) as? NSStepper {
            existingStepper.integerValue = field.integerValue
            return
        }

        let stepper = NSStepper()
        stepper.minValue = 0
        stepper.maxValue = 100
        stepper.increment = 1
        stepper.integerValue = field.integerValue
        stepper.tag = stepperTag
        stepper.target = self
        stepper.action = #selector(thresholdStepperChanged(_:))
        field.superview?.addSubview(stepper)
        stepper.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stepper.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 6),
            stepper.centerYAnchor.constraint(equalTo: field.centerYAnchor)
        ])
    }

    @objc
    private func thresholdStepperChanged(_ sender: NSStepper) {
        let value = validatedThreshold(Int32(sender.integerValue))
        sender.integerValue = value
        guard let target = sender.tag == 1_000 + lowBatteryNotificationTextField.tag
            ? lowBatteryNotificationTextField : highBatteryNotificationTextField else {
            return
        }
        target.integerValue = value
        if target === lowBatteryNotificationTextField {
            AppDelegate.userSettings.settings.battery.lowBatteryNotification.value = value
        } else {
            AppDelegate.userSettings.settings.battery.highBatteryNotification.value = value
        }
    }

    private func validatedThreshold(_ value: Int32) -> Int {
        min(max(Int(value), 0), 100)
    }
}

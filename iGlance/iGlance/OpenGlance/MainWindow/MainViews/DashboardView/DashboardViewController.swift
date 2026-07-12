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
import SMCKit

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

class DashboardViewController: MainViewViewController {
    // MARK: -
    // MARK: Outlets
    @IBOutlet private var daysUptimeLabel: NSTextField!
    @IBOutlet private var hoursUptimeLabel: NSTextField!

    @IBOutlet private var cpuNameLabel: NSTextField!
    @IBOutlet private var gpuNameLabel: NSTextField!
    @IBOutlet private var ramSizeLabel: NSTextField!
    @IBOutlet private var diskSizeLabel: NSTextField!

    @IBOutlet private var batteryHealthLabel: NSTextField!
    @IBOutlet private var batteryCyclesLabel: NSTextField!

    private var dashboardModeControl: NSSegmentedControl!
    private var compactDashboardView: NSStackView!
    private var compactLabels: [NSTextField] = []
    private var standardDashboardViews: [NSView] = []

    // Custom view references for gauges & graphs
    private var cpuGauge: CircularProgressView?
    private var ramGauge: CircularProgressView?
    private var batteryGauge: CircularProgressView?
    private var networkGraph: MiniLineGraphView?
    
    private var cpuValueLabel: NSTextField?
    private var ramValueLabel: NSTextField?
    private var batteryValueLabel: NSTextField?
    private var networkValueLabel: NSTextField?

    // Custom layout stack containers
    private var scrollView: NSScrollView!
    private var docStackView: NSStackView!
    private var processStackView: NSStackView?
    private var sensorStackView: NSStackView?
    private var processRows: [ProcessRow] = []

    // Timer for active real-time refresh
    private var updateTimer: RepeatingTimer?

    // MARK: -
    // MARK: Private Variables

    // the variables for the system info on the dashboard
    // these are static such that when the user selects another main view the values are preserved
    private static var cpuName: String?
    private static var gpuName: String?
    private static var ramSize: String?
    private static var diskSize: String?

    // MARK: -
    // MARK: Function Overrides
    override func viewDidLoad() {
        super.viewDidLoad()

        setupScrollableLayout()
        installDashboardModeControl()
        makeOverviewResponsive()

        // set the info for all the dashboard boxes
        self.updateUptimeInfo()
        self.setSystemInfo()
        self.setBatteryInfo()
        self.configureSystemInfoLabels()
        self.updateSensorBoard()

        DDLogInfo("Dashboard view did load")
    }

    private func setupScrollableLayout() {
        let initialSubviews = view.subviews
        
        // 1. Create Scroll View
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        view.addSubview(scrollView)
        
        self.scrollView = scrollView
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 2. Create Document Stack View (Vertical)
        let docStack = FlippedStackView()
        docStack.orientation = .vertical
        docStack.alignment = .centerX
        docStack.spacing = 16
        docStack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 20, right: 16)
        docStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = docStack
        
        self.docStackView = docStack
        
        NSLayoutConstraint.activate([
            docStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            docStack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            docStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor)
        ])
        
        // 3. Create Custom Header Row for Dashboard Title & Toggle Control
        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.distribution = .fill
        headerRow.spacing = 12
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Dashboard")
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerRow.addArrangedSubview(titleLabel)
        docStack.addArrangedSubview(headerRow)
        
        headerRow.leadingAnchor.constraint(equalTo: docStack.leadingAnchor, constant: 16).isActive = true
        headerRow.trailingAnchor.constraint(equalTo: docStack.trailingAnchor, constant: -16).isActive = true
        
        // 4. Find and Move overviewStack
        if let overviewStack = initialSubviews.first(where: { $0 is NSStackView }) as? NSStackView {
            overviewStack.removeFromSuperview()
            docStack.addArrangedSubview(overviewStack)
            
            overviewStack.leadingAnchor.constraint(equalTo: docStack.leadingAnchor, constant: 16).isActive = true
            overviewStack.trailingAnchor.constraint(equalTo: docStack.trailingAnchor, constant: -16).isActive = true
        }
        
        // 5. Create & Add Top Processes Box
        let processCard = makeProcessManagerCard()
        processCard.translatesAutoresizingMaskIntoConstraints = false
        docStack.addArrangedSubview(processCard)
        processCard.leadingAnchor.constraint(equalTo: docStack.leadingAnchor, constant: 16).isActive = true
        processCard.trailingAnchor.constraint(equalTo: docStack.trailingAnchor, constant: -16).isActive = true
        
        // 6. Create & Add Sensor Board Box
        let sensorCard = makeSensorBoardCard()
        sensorCard.translatesAutoresizingMaskIntoConstraints = false
        docStack.addArrangedSubview(sensorCard)
        sensorCard.leadingAnchor.constraint(equalTo: docStack.leadingAnchor, constant: 16).isActive = true
        sensorCard.trailingAnchor.constraint(equalTo: docStack.trailingAnchor, constant: -16).isActive = true
        
        // Hide initial subviews (except our scroll view)
        for sv in initialSubviews {
            if sv !== scrollView {
                sv.isHidden = true
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Refresh all dashboard metrics
        self.refreshDashboardData()
        
        // Setup timer to refresh details continuously while visible
        let interval = AppDelegate.userSettings.settings.updateInterval
        let timer = RepeatingTimer(timeInterval: interval)
        timer.eventHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.refreshDashboardData()
            }
        }
        timer.resume()
        self.updateTimer = timer
        
        applyDashboardMode()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        // Suspend and release the timer to save resources
        self.updateTimer?.suspend()
        self.updateTimer = nil
    }

    override func updateGUIComponents() {
        // do nothing, since we don't need to update the GUI here
    }

    // MARK: -
    // MARK: Private Functions

    private func refreshDashboardData() {
        // Keep the view hierarchy intact during periodic refreshes. Rebuilding
        // cards/rows every interval causes AppKit to relayout the entire
        // document view, which presents as a visible dashboard blink.
        self.updateUptimeInfo()
        self.refreshCompactDashboard()
        self.updateProcessManager()
    }

    /**
     * Sets the values in the uptime dashboard box.
     */
    private func updateUptimeInfo() {
        // get the system uptime in seconds
        let uptime = AppDelegate.systemInfo.getSystemUptime()

        daysUptimeLabel.stringValue = "\(uptime.days) days"
        hoursUptimeLabel.stringValue = "\(uptime.hours) hours"

        DDLogInfo("Updated uptime info")
    }

    /**
     * Sets the system information on the system dashboard box.
     */
    private func setSystemInfo() {
        if DashboardViewController.cpuName == nil {
            // set the cpu name
            let cpuName = AppDelegate.systemInfo.cpu.getCpuName()
            // remove the intel core branding
            DashboardViewController.cpuName = cpuName.replacingOccurrences(of: "Intel(R) Core(TM) ", with: "")
        }
        cpuNameLabel.stringValue = DashboardViewController.cpuName!

        if DashboardViewController.gpuName == nil {
            // set the gpu name
            DashboardViewController.gpuName = AppDelegate.systemInfo.gpu.getGpuName()
        }
        gpuNameLabel.stringValue = DashboardViewController.gpuName!

        if DashboardViewController.ramSize == nil {
            // set the ram size
            DashboardViewController.ramSize = "\(AppDelegate.systemInfo.memory.getTotalMemorySize()) GB"
        }
        ramSizeLabel.stringValue = DashboardViewController.ramSize!

        if DashboardViewController.diskSize == nil {
            let (usedSpace, freeSpace) = DiskInfo.getFreeDiskUsageInfo()
            let diskSize = convertToCorrectUnit(bytes: (usedSpace + freeSpace))
            let sizeString = diskSize.unit <= .Gigabyte ? String(Int(diskSize.value)) : String(format: "%.2f", diskSize.value)
            DashboardViewController.diskSize = "\(sizeString) \(diskSize.unit.rawValue)"
        }
        diskSizeLabel.stringValue = DashboardViewController.diskSize!

        DDLogInfo("Updated system info")
    }

    /// Long model names must stay inside the System card rather than drawing
    /// over the RAM and Disk columns. The full value remains available as a
    /// tooltip.
    private func configureSystemInfoLabels() {
        for label in [cpuNameLabel, gpuNameLabel].compactMap({ $0 }) {
            label.lineBreakMode = .byTruncatingTail
            label.cell?.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        cpuNameLabel.toolTip = DashboardViewController.cpuName
        gpuNameLabel.toolTip = DashboardViewController.gpuName
    }

    /**
     * Sets the battery information on the battery dashboard box.
     */
    private func setBatteryInfo() {
        let health = Int((AppDelegate.systemInfo.battery.getBatteryHealth() * 100.0).rounded())
        batteryHealthLabel.stringValue = "\(health)%"
        batteryHealthLabel.toolTip = batteryHealthStatus(health)

        // set the cycle count of the battery
        batteryCyclesLabel.stringValue = "\(AppDelegate.systemInfo.battery.getBatteryCycles())"

        DDLogInfo("Updated battery info")
    }

    private func batteryHealthStatus(_ health: Int) -> String {
        switch health {
        case 80...100:
            return "\(health)% — Good"
        case 60..<80:
            return "\(health)% — Service recommended soon"
        case 1..<60:
            return "\(health)% — Service recommended"
        default:
            return "Unavailable on this Mac"
        }
    }

    private func makeOverviewResponsive() {
        // Find the overview stack view in docStackView
        guard let overviewStack = docStackView.arrangedSubviews.first(where: { $0 is NSStackView && $0 !== compactDashboardView && $0 !== dashboardModeControl.superview }) as? NSStackView else {
            return
        }

        overviewStack.translatesAutoresizingMaskIntoConstraints = false
        // The centre System card contains four values while the side cards
        // contain only two. Keep it substantially wider instead of forcing
        // all three cards to the same width.
        overviewStack.distribution = .fill
        overviewStack.spacing = 16
        
        for subview in overviewStack.arrangedSubviews {
            for constraint in subview.constraints {
                if constraint.firstAttribute == .width || constraint.firstAttribute == .height {
                    constraint.isActive = false
                }
            }
            if let superview = subview.superview {
                for constraint in superview.constraints {
                    if (constraint.firstItem === subview || constraint.secondItem === subview) &&
                       (constraint.firstAttribute == .width || constraint.firstAttribute == .height) {
                        constraint.isActive = false
                    }
                }
            }
            
            subview.translatesAutoresizingMaskIntoConstraints = false
            subview.heightAnchor.constraint(equalToConstant: 120).isActive = true
        }

        NSLayoutConstraint.activate([
            overviewStack.leadingAnchor.constraint(equalTo: docStackView.leadingAnchor, constant: 16),
            overviewStack.trailingAnchor.constraint(equalTo: docStackView.trailingAnchor, constant: -16),
            overviewStack.heightAnchor.constraint(equalToConstant: 120)
        ])

        // Preserve the original dashboard's 112 : 325 : 112 visual balance
        // while allowing all cards to scale with the window.
        let cards = overviewStack.arrangedSubviews
        if cards.count == 3 {
            NSLayoutConstraint.activate([
                cards[0].widthAnchor.constraint(equalTo: cards[2].widthAnchor),
                cards[1].widthAnchor.constraint(equalTo: cards[0].widthAnchor, multiplier: 2.8)
            ])
        }
    }

    private func installDashboardModeControl() {
        let control = NSSegmentedControl(labels: ["Overview", "Compact"], trackingMode: .selectOne, target: self, action: #selector(dashboardModeChanged(_:)))
        control.selectedSegment = AppDelegate.userSettings.settings.compactDashboard ? 1 : 0
        control.controlSize = .small
        control.translatesAutoresizingMaskIntoConstraints = false
        dashboardModeControl = control

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        
        if let headerRow = docStackView.arrangedSubviews.first as? NSStackView {
            headerRow.addArrangedSubview(spacer)
            headerRow.addArrangedSubview(control)
        }

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (title, symbol) in [("CPU", "cpu"), ("Memory", "memorychip"), ("Battery", "battery.100"), ("Network", "network")] {
            stack.addArrangedSubview(makeCompactCard(title: title, symbolName: symbol))
        }
        docStackView.addArrangedSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: docStackView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: docStackView.trailingAnchor, constant: -16),
            stack.heightAnchor.constraint(equalToConstant: 120)
        ])
        compactDashboardView = stack
        applyDashboardMode()
    }

    private func makeCompactCard(title: String, symbolName: String) -> NSBox {
        let card = NSBox()
        card.boxType = .custom
        card.borderWidth = 0
        card.cornerRadius = 12
        card.fillColor = .controlBackgroundColor

        let icon = NSImageView()
        if #available(macOS 11.0, *) {
            icon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
            icon.contentTintColor = .secondaryLabelColor
        }
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 14).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = NSStackView(views: [icon, titleLabel])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 4
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let cardStack = NSStackView()
        cardStack.orientation = .vertical
        cardStack.alignment = .centerX
        cardStack.spacing = 8
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardStack.addArrangedSubview(headerStack)

        if title == "Network" {
            let valueLabel = NSTextField(labelWithString: "—")
            valueLabel.font = .systemFont(ofSize: 11, weight: .semibold)
            valueLabel.alignment = .center
            valueLabel.drawsBackground = false
            valueLabel.isBordered = false
            valueLabel.isEditable = false
            valueLabel.isSelectable = false
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            self.networkValueLabel = valueLabel
            
            let graph = MiniLineGraphView()
            graph.translatesAutoresizingMaskIntoConstraints = false
            graph.graphColor = .systemPurple
            self.networkGraph = graph
            
            cardStack.addArrangedSubview(valueLabel)
            cardStack.addArrangedSubview(graph)
            
            // The graph is owned by `cardStack`, not by the card yet. Pin it
            // to that stack so these constraints are activated only between
            // views that already share an ancestor. Anchoring to
            // `card.contentView` here raised NSGenericException during nib
            // loading and prevented the entire dashboard from being created.
            NSLayoutConstraint.activate([
                graph.leadingAnchor.constraint(equalTo: cardStack.leadingAnchor),
                graph.trailingAnchor.constraint(equalTo: cardStack.trailingAnchor),
                graph.heightAnchor.constraint(equalToConstant: 32)
            ])
        } else {
            let gauge = CircularProgressView()
            gauge.translatesAutoresizingMaskIntoConstraints = false
            gauge.lineWidth = 4.0
            
            let valColor: NSColor
            if title == "CPU" {
                gauge.progressColor = .systemGreen
                valColor = .systemGreen
            } else if title == "Memory" {
                gauge.progressColor = .systemBlue
                valColor = .systemBlue
            } else {
                gauge.progressColor = .systemOrange
                valColor = .systemOrange
            }
            
            let valueLabel = NSTextField(labelWithString: "—")
            valueLabel.font = .systemFont(ofSize: 11, weight: .bold)
            valueLabel.textColor = valColor
            valueLabel.alignment = .center
            valueLabel.drawsBackground = false
            valueLabel.isBordered = false
            valueLabel.isEditable = false
            valueLabel.isSelectable = false
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            
            gauge.addSubview(valueLabel)
            NSLayoutConstraint.activate([
                valueLabel.centerXAnchor.constraint(equalTo: gauge.centerXAnchor),
                valueLabel.centerYAnchor.constraint(equalTo: gauge.centerYAnchor),
                valueLabel.widthAnchor.constraint(equalTo: gauge.widthAnchor, constant: -4)
            ])
            
            cardStack.addArrangedSubview(gauge)
            
            NSLayoutConstraint.activate([
                gauge.widthAnchor.constraint(equalToConstant: 52),
                gauge.heightAnchor.constraint(equalToConstant: 52)
            ])
            
            if title == "CPU" {
                self.cpuGauge = gauge
                self.cpuValueLabel = valueLabel
            } else if title == "Memory" {
                self.ramGauge = gauge
                self.ramValueLabel = valueLabel
            } else {
                self.batteryGauge = gauge
                self.batteryValueLabel = valueLabel
            }
        }

        card.contentView?.addSubview(cardStack)
        
        NSLayoutConstraint.activate([
            cardStack.leadingAnchor.constraint(equalTo: card.contentView!.leadingAnchor, constant: 8),
            cardStack.trailingAnchor.constraint(equalTo: card.contentView!.trailingAnchor, constant: -8),
            cardStack.topAnchor.constraint(equalTo: card.contentView!.topAnchor, constant: 10),
            cardStack.bottomAnchor.constraint(equalTo: card.contentView!.bottomAnchor, constant: -10)
        ])
        
        return card
    }

    private func makeProcessManagerCard() -> NSBox {
        let card = CustomDashboardBox()
        card.boxType = .custom
        
        let titleLabel = NSTextField(labelWithString: "Top Resource Consumers")
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        
        let processStack = NSStackView()
        processStack.orientation = .vertical
        processStack.alignment = .leading
        processStack.spacing = 8
        processStack.translatesAutoresizingMaskIntoConstraints = false
        self.processStackView = processStack
        
        let cardStack = NSStackView(views: [titleLabel, processStack])
        cardStack.orientation = .vertical
        cardStack.alignment = .leading
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView?.addSubview(cardStack)
        
        NSLayoutConstraint.activate([
            cardStack.leadingAnchor.constraint(equalTo: card.contentView!.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: card.contentView!.trailingAnchor, constant: -16),
            cardStack.topAnchor.constraint(equalTo: card.contentView!.topAnchor, constant: 16),
            cardStack.bottomAnchor.constraint(equalTo: card.contentView!.bottomAnchor, constant: -16)
        ])
        
        return card
    }

    private struct ProcessRow {
        let container: NSStackView
        let nameLabel: NSTextField
        let cpuLabel: NSTextField
        let memoryLabel: NSTextField
        let killButton: NSButton
    }

    private func makeProcessRow(pid: Int32, name: String, cpu: Double, memory: Double) -> ProcessRow {
        let container = NSStackView()
        container.orientation = .horizontal
        container.alignment = .centerY
        container.distribution = .fill
        container.spacing = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.drawsBackground = false
        nameLabel.isBordered = false
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        nameLabel.widthAnchor.constraint(equalToConstant: 180).isActive = true
        
        let cpuLabel = NSTextField(labelWithString: String(format: "%.1f%% CPU", cpu))
        cpuLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        cpuLabel.textColor = .secondaryLabelColor
        cpuLabel.drawsBackground = false
        cpuLabel.isBordered = false
        cpuLabel.isEditable = false
        cpuLabel.isSelectable = false
        cpuLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        let memLabel = NSTextField(labelWithString: String(format: "%.1f%% RAM", memory))
        memLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        memLabel.textColor = .secondaryLabelColor
        memLabel.drawsBackground = false
        memLabel.isBordered = false
        memLabel.isEditable = false
        memLabel.isSelectable = false
        memLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        let killButton = NSButton()
        killButton.title = ""
        if #available(macOS 11.0, *) {
            killButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Terminate Process")
            killButton.contentTintColor = .systemRed.withAlphaComponent(0.8)
        } else {
            killButton.title = "X"
        }
        killButton.isBordered = false
        killButton.bezelStyle = .shadowlessSquare
        killButton.target = self
        killButton.action = #selector(killProcessPressed(_:))
        killButton.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(pid)")
        killButton.widthAnchor.constraint(equalToConstant: 16).isActive = true
        killButton.heightAnchor.constraint(equalToConstant: 16).isActive = true
        
        container.addArrangedSubview(nameLabel)
        container.addArrangedSubview(cpuLabel)
        container.addArrangedSubview(memLabel)
        container.addArrangedSubview(killButton)
        
        return ProcessRow(
            container: container,
            nameLabel: nameLabel,
            cpuLabel: cpuLabel,
            memoryLabel: memLabel,
            killButton: killButton
        )
    }

    @objc private func killProcessPressed(_ sender: NSButton) {
        guard let pidString = sender.identifier?.rawValue, let pid = Int32(pidString) else { return }
        
        let alert = NSAlert()
        alert.messageText = "Force Quit Process?"
        alert.informativeText = "Are you sure you want to terminate process \(pid)?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Force Quit")
        alert.addButton(withTitle: "Cancel")
        
        if let window = view.window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    if let app = NSRunningApplication(processIdentifier: pid) {
                        app.forceTerminate()
                    } else {
                        kill(pid, SIGKILL)
                    }
                    self.refreshDashboardData()
                }
            }
        } else {
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.forceTerminate()
            } else {
                kill(pid, SIGKILL)
            }
            self.refreshDashboardData()
        }
    }

    private func makeSensorBoardCard() -> NSBox {
        let card = CustomDashboardBox()
        card.boxType = .custom
        
        let titleLabel = NSTextField(labelWithString: "System Temperatures")
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        
        let sensorStack = NSStackView()
        sensorStack.orientation = .vertical
        sensorStack.alignment = .leading
        sensorStack.spacing = 6
        sensorStack.translatesAutoresizingMaskIntoConstraints = false
        self.sensorStackView = sensorStack
        
        let cardStack = NSStackView(views: [titleLabel, sensorStack])
        cardStack.orientation = .vertical
        cardStack.alignment = .leading
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView?.addSubview(cardStack)
        
        NSLayoutConstraint.activate([
            cardStack.leadingAnchor.constraint(equalTo: card.contentView!.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: card.contentView!.trailingAnchor, constant: -16),
            cardStack.topAnchor.constraint(equalTo: card.contentView!.topAnchor, constant: 16),
            cardStack.bottomAnchor.constraint(equalTo: card.contentView!.bottomAnchor, constant: -16)
        ])
        
        return card
    }

    private func updateSensorBoard() {
        guard let sensorStack = sensorStackView else { return }
        
        sensorStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // SMCKit's legacy temperature-sensor catalogue contains duplicate
        // sensor codes on Apple Silicon. Its static catalogue construction
        // traps before the throwing API can report an error, taking down the
        // app while the dashboard is being shown. Do not enumerate that
        // Intel-only catalogue on arm64.
        #if arch(arm64)
        let unavailableLabel = NSTextField(labelWithString: "Temperature sensors are unavailable on this Mac")
        unavailableLabel.font = .systemFont(ofSize: 12)
        unavailableLabel.textColor = .secondaryLabelColor
        sensorStack.addArrangedSubview(unavailableLabel)
        return
        #endif
        
        let tempUnit = AppDelegate.userSettings.settings.tempUnit
        
        do {
            let sensors = try SMCKit.allKnownTemperatureSensors()
            
            for sensor in sensors {
                if let temp = try? SMCKit.temperature(sensor.code, unit: tempUnit) {
                    let row = NSStackView()
                    row.orientation = .horizontal
                    row.spacing = 12
                    row.translatesAutoresizingMaskIntoConstraints = false
                    
                    let readableName = formatSensorName(sensor.name)
                    let nameLabel = NSTextField(labelWithString: readableName)
                    nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
                    nameLabel.textColor = .labelColor
                    nameLabel.drawsBackground = false
                    nameLabel.isBordered = false
                    nameLabel.isEditable = false
                    nameLabel.isSelectable = false
                    nameLabel.widthAnchor.constraint(equalToConstant: 180).isActive = true
                    
                    let unitStr = tempUnit == .celsius ? "°C" : (tempUnit == .fahrenheit ? "°F" : "K")
                    let tempLabel = NSTextField(labelWithString: String(format: "%.1f %@", temp, unitStr))
                    tempLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
                    tempLabel.textColor = .secondaryLabelColor
                    tempLabel.drawsBackground = false
                    tempLabel.isBordered = false
                    tempLabel.isEditable = false
                    tempLabel.isSelectable = false
                    
                    row.addArrangedSubview(nameLabel)
                    row.addArrangedSubview(tempLabel)
                    
                    sensorStack.addArrangedSubview(row)
                }
            }
        } catch {
            let errorLabel = NSTextField(labelWithString: "Failed to read temperature sensors")
            errorLabel.font = .systemFont(ofSize: 12)
            errorLabel.textColor = .secondaryLabelColor
            errorLabel.drawsBackground = false
            errorLabel.isBordered = false
            errorLabel.isEditable = false
            errorLabel.isSelectable = false
            sensorStack.addArrangedSubview(errorLabel)
        }
    }
    
    private func formatSensorName(_ rawName: String) -> String {
        var clean = rawName.replacingOccurrences(of: "_", with: " ")
        clean = clean.replacingOccurrences(of: " 0", with: "")
        clean = clean.replacingOccurrences(of: " 1", with: "")
        clean = clean.replacingOccurrences(of: " 2", with: "")
        clean = clean.replacingOccurrences(of: " 3", with: "")
        return clean.capitalized
    }

    private func updateProcessManager() {
        guard let processStack = processStackView,
              let output = executeCommand(launchPath: "/bin/ps", arguments: ["-Ao", "pid,%cpu,%mem,comm", "-r"]) else {
            return
        }

        let processes = output.split(separator: "\n").dropFirst().compactMap { line -> (Int32, String, Double, Double)? in
            let columns = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard columns.count >= 4,
                  let pid = Int32(columns[0]),
                  let cpu = Double(columns[1]),
                  let memory = Double(columns[2]) else { return nil }

            let name = URL(fileURLWithPath: String(columns[3])).lastPathComponent
            return name == "ps" ? nil : (pid, name, cpu, memory)
        }.prefix(4)

        // Reuse row views and only change their text. This avoids removing and
        // re-adding arranged subviews on every timer tick.
        for (index, process) in processes.enumerated() {
            let row: ProcessRow
            if index < processRows.count {
                row = processRows[index]
            } else {
                row = makeProcessRow(pid: process.0, name: process.1, cpu: process.2, memory: process.3)
                processRows.append(row)
                processStack.addArrangedSubview(row.container)
            }

            row.container.isHidden = false
            row.nameLabel.stringValue = process.1
            row.cpuLabel.stringValue = String(format: "%.1f%% CPU", process.2)
            row.memoryLabel.stringValue = String(format: "%.1f%% RAM", process.3)
            row.killButton.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(process.0)")
        }

        for row in processRows.dropFirst(processes.count) {
            row.container.isHidden = true
        }
    }

    private func convertToReadableSpeed(bytesPerSec: UInt64) -> String {
        let speed = convertToCorrectUnit(bytes: Int(bytesPerSec))
        return String(format: "%.1f %@", speed.value, speed.unit.rawValue) + "/s"
    }

    @objc
    private func dashboardModeChanged(_ sender: NSSegmentedControl) {
        AppDelegate.userSettings.settings.compactDashboard = sender.selectedSegment == 1
        applyDashboardMode()
        refreshCompactDashboard()
    }

    private func applyDashboardMode() {
        let compact = AppDelegate.userSettings.settings.compactDashboard
        
        if let overviewStack = docStackView.arrangedSubviews.first(where: { $0 is NSStackView && $0 !== compactDashboardView && $0 !== dashboardModeControl.superview }) {
            overviewStack.isHidden = compact
        }
        compactDashboardView.isHidden = !compact
        dashboardModeControl.selectedSegment = compact ? 1 : 0
    }

    private func refreshCompactDashboard() {
        // CPU
        let cpu = AppDelegate.systemInfo.cpu.getCpuUsage()
        let cpuUsageVal = Double(max(0, 100 - cpu.idle))
        cpuGauge?.progress = CGFloat(cpuUsageVal / 100.0)
        cpuValueLabel?.stringValue = String(format: "%.0f%%", cpuUsageVal)
        
        // RAM
        let memory = AppDelegate.systemInfo.memory.getMemoryUsage()
        let totalMemory = Double(AppDelegate.systemInfo.memory.getTotalMemorySize())
        let usedMemory = totalMemory - memory.free
        let ramProgress = usedMemory / totalMemory
        ramGauge?.progress = CGFloat(ramProgress)
        ramValueLabel?.stringValue = String(format: "%.0f%%", ramProgress * 100.0)
        
        // Battery
        let hasBattery = AppDelegate.systemInfo.battery.hasBattery()
        if hasBattery {
            let charge = Double(AppDelegate.systemInfo.battery.getCharge())
            batteryGauge?.progress = CGFloat(charge / 100.0)
            batteryValueLabel?.stringValue = String(format: "%.0f%%", charge)
        } else {
            batteryGauge?.progress = 0.0
            batteryValueLabel?.stringValue = "N/A"
        }
        
        // Network
        let interface = AppDelegate.systemInfo.network.getCurrentlyUsedInterface()
        let bandwidth = AppDelegate.systemInfo.network.getNetworkBandwidth(interface: interface)
        let combinedSpeed = Double(bandwidth.up + bandwidth.down)
        networkGraph?.addValue(combinedSpeed)
        
        let speedStr = convertToReadableSpeed(bytesPerSec: bandwidth.up + bandwidth.down)
        networkValueLabel?.stringValue = "\(interface): \(speedStr)"
    }
}

// MARK: -
// MARK: Custom Subviews

@objc class CircularProgressView: NSView {
    var progress: CGFloat = 0.0 {
        didSet {
            let clamped = min(max(progress, 0.0), 1.0)
            if clamped != oldValue {
                needsDisplay = true
            }
        }
    }
    
    var progressColor: NSColor = .systemGreen {
        didSet { needsDisplay = true }
    }
    
    var trackColor: NSColor = NSColor.labelColor.withAlphaComponent(0.08) {
        didSet { needsDisplay = true }
    }
    
    var lineWidth: CGFloat = 5.0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        
        guard radius > 0 else { return }
        
        // Draw track
        let trackPath = NSBezierPath()
        trackPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        trackPath.lineWidth = lineWidth
        trackColor.setStroke()
        trackPath.stroke()
        
        // Draw progress arc
        if progress > 0 {
            let progressPath = NSBezierPath()
            progressPath.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - (360 * progress), clockwise: true)
            progressPath.lineWidth = lineWidth
            progressPath.lineCapStyle = .round
            progressColor.setStroke()
            progressPath.stroke()
        }
    }
}

@objc class MiniLineGraphView: NSView {
    var values: [Double] = [] {
        didSet {
            needsDisplay = true
        }
    }
    
    var graphColor: NSColor = .systemBlue {
        didSet { needsDisplay = true }
    }
    
    var maxValuesCount: Int = 30
    
    func addValue(_ value: Double) {
        values.append(value)
        if values.count > maxValuesCount {
            values.removeFirst()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard values.count > 1 else { return }
        
        let path = NSBezierPath()
        let step = bounds.width / CGFloat(maxValuesCount - 1)
        
        let maxValue = values.max() ?? 1.0
        let limit = max(maxValue, 1024.0) // 1 KB/s threshold
        
        for (i, val) in values.enumerated() {
            let x = step * CGFloat(i)
            let y = CGFloat(val / limit) * (bounds.height - 4) + 2
            
            if i == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        
        path.lineWidth = 1.8
        path.lineJoinStyle = .round
        graphColor.setStroke()
        path.stroke()
        
        let fillPath = path.copy() as! NSBezierPath
        fillPath.line(to: NSPoint(x: step * CGFloat(values.count - 1), y: 0))
        fillPath.line(to: NSPoint(x: 0, y: 0))
        fillPath.close()
        
        if let gradient = NSGradient(starting: graphColor.withAlphaComponent(0.20), ending: graphColor.withAlphaComponent(0.0)) {
            gradient.draw(in: fillPath, angle: 90)
        }
    }
}

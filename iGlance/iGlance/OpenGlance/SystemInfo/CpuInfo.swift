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

import Foundation
import CocoaLumberjack
import SMCKit
import SystemKit
#if arch(arm64)
import IOKit
#endif

class CpuInfo {
    private var skSystem: SKSystem

    init(skSystem: SKSystem) {
        self.skSystem = skSystem
    }

    /**
     * Gets the name of the cpu.
     *
     * - Returns: The name of the cpu as a string (e.g. Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz on Intel,
     *            or Apple M1 / Apple M2 Pro on Apple Silicon)
     */
    func getCpuName() -> String {
        #if arch(arm64)
        return getArmCpuName()
        #else
        return getIntelCpuName()
        #endif
    }

    /**
     * Returns the cpu temperature as a double. If an error occured or the
     * temperature could not be read the function returns -1.0.
     *
     * - Parameter unit: The unit in which the temperature should be returned.
     */
    func getCpuTemp() -> Double {
        let tempUnit = AppDelegate.userSettings.settings.tempUnit

        #if arch(arm64)
        // On Apple Silicon the Intel-era SMC key (TC0P) is absent. Probe the
        // known Apple Silicon thermal keys and return the first valid reading.
        for key in TemperatureSensors.appleSiliconCpuTempKeys {
            do {
                let cpuTemp = try SMCKit.temperature(key, unit: tempUnit)
                DDLogInfo("Read cpu temperature (key \(key.toString())): \(cpuTemp)")
                return cpuTemp
            } catch SMCKit.SMCError.keyNotFound {
                // try the next candidate key
                continue
            } catch SMCKit.SMCError.notPrivileged {
                DDLogError("Not privileged to read the SMC")
                return -1.0
            } catch {
                DDLogError("An unknown error occurred while reading key \(key.toString())")
                continue
            }
        }
        DDLogError("No Apple Silicon CPU temperature SMC key was found on this machine")
        return -1.0
        #else
        do {
            let cpuTemp = try SMCKit.temperature(TemperatureSensors.CPU_0_PROXIMITY.code, unit: tempUnit)

            DDLogInfo("Read cpu temperature: \(cpuTemp)")

            return cpuTemp
        } catch SMCKit.SMCError.keyNotFound {
            DDLogError("The given SMC key was not found")
        } catch SMCKit.SMCError.notPrivileged {
            DDLogError("Not privileged to read the SMC")
        } catch {
            DDLogError("An unknown error occurred")
        }

        return -1.0
        #endif
    }

    /**
     * Returns the cpu usage. Each value is rounded to the nearest integer value and represents the usage in percent.
     */
    func getCpuUsage() -> (system: Int, user: Int, idle: Int, nice: Int) {
        let usage = skSystem.usageCPU()

        DDLogInfo("Read cpu usage: \(usage)")

        return (Int(round(usage.0)), Int(round(usage.1)), Int(round(usage.2)), Int(round(usage.3)))
    }

    // MARK: -
    // MARK: Private Functions

    /**
     * Gets the cpu name on Intel Macs via the `machdep.cpu.brand_string` sysctl.
     */
    private func getIntelCpuName() -> String {
        // get the length of the cpu name
        var stringSize = 0
        if sysctlbyname("machdep.cpu.brand_string", nil, &stringSize, nil, 0) != 0 {
            DDLogError("Could not get the length of the cpu name")
            return ""
        }

        var cpuName = [CChar](repeating: 0, count: Int(stringSize))
        if sysctlbyname("machdep.cpu.brand_string", &cpuName, &stringSize, nil, 0) != 0 {
            DDLogError("Could not get the name of the cpu")
            return ""
        }

        DDLogInfo("Raw cpu name value: \(cpuName)")

        let cpuNameString = String(cString: cpuName)
        DDLogInfo("Got the cpu name: \(cpuNameString)")

        return cpuNameString
    }

    #if arch(arm64)
    /**
     * Gets the cpu name on Apple Silicon Macs. The `machdep.cpu.brand_string`
     * sysctl is x86-only, so the name is read from the IODeviceTree "cpu0"
     * node's "compatible" property instead (e.g. "apple,firestorm" → mapped to
     * a marketing name) or the "processor-name" property when available.
     */
    private func getArmCpuName() -> String {
        // Try the IODeviceTree "cpu0" node first.
        if let name = readIORegistryCpuName(matchingName: "cpu0", property: "compatible") {
            DDLogInfo("Got the cpu name from IORegistry: \(name)")
            return name
        }

        // Fallback: try the "ARM64" service node "processor-name" property.
        if let name = readIORegistryCpuName(matchingName: "ARM64", property: "processor-name") {
            DDLogInfo("Got the cpu name from IORegistry (ARM64): \(name)")
            return name
        }

        // Last resort: hw.model gives the machine model identifier (e.g.
        // "MacBookPro17,1"), not a chip name, but it's better than empty.
        var size = 0
        if sysctlbyname("hw.model", nil, &size, nil, 0) == 0 {
            var model = [CChar](repeating: 0, count: Int(size))
            if sysctlbyname("hw.model", &model, &size, nil, 0) == 0 {
                let modelString = String(cString: model)
                DDLogInfo("Falling back to hw.model: \(modelString)")
                return modelString
            }
        }

        DDLogError("Could not get the cpu name on Apple Silicon")
        return ""
    }

    /**
     * Reads a string property from an IORegistry service matched by name.
     * Returns nil if the service or property could not be found.
     */
    private func readIORegistryCpuName(matchingName: String, property: String) -> String? {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(matchingName))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let unmanagedProperty = IORegistryEntryCreateCFProperty(service, property as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }

        let propertyData = unmanagedProperty.takeRetainedValue()

        // The "compatible" property is typically an array of OSString/NSData
        // entries; "processor-name" is usually a single string.
        if let string = propertyData as? String {
            return string
        }

        // "compatible" on arm64 is often returned as raw Data with null-separated
        // strings (e.g. "apple,icestorm\0apple,firestorm\0"). Take the first entry.
        if let data = propertyData as? Data {
            if let firstNull = data.firstIndex(of: 0) {
                return String(data: data.prefix(firstNull), encoding: .utf8)
            }
            return String(data: data, encoding: .utf8)
        }

        return nil
    }
    #endif
}

#!/usr/bin/env xcrun swift

// SetupXcodeDerivedDataRamDisk 2.3.0
//
// Copyright (c) 2019 ikiApps LLC.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

/**
Create a Derived Data RAM disk for use by Xcode.
The regex matching is designed for English language systems.
Tested with macOS 10.14.3 (Mojave), Xcode 10.2 and Swift 5.0.

The disk is mounted into the default path for Xcode's Derived Data path and will
be used automatically by Xcode if the path is corresponds to the one set in
Xcode's preferences.

The console app, built in Xcode, can be added as a startup agent inside
~/Library/LaunchAgents. The raw script itself can also be made executable like a
shell script.

The path below refers to a bin directory contained in your home directory.
This folder needs to be created if it does not already exist.

The console app or script copied into that directory will need to have execute
(+x) permissions. The property list inside LaunchAgents only requires read (+r)
permissions to work. It is sufficient to simply copy the property list into the
LaunchAgents directory. The directory itself will have to be created if it does
not already exist.

Here is the content of an example property list (plist) that will have the RAM
disk created at startup.

** REMEMBER TO CHANGE THE USERNAME BELOW TO MATCH YOUR USERNAME. **

filename: com.ikiapps.setupXcodeDerivedDataRamDisk.plist
-------------------------------------------------------------------
<?xml version=1.0 encoding=UTF-8?>
<!DOCTYPE plist PUBLIC -//Apple//DTD PLIST 1.0//EN http://www.apple.com/DTDs/PropertyList-1.0.dtd>
<plist version=1.0>
<dict>
<key>Label</key>
<string>com.ikiapps.setupXcodeDerivedDataRamDisk.plist</string>
<key>ProgramArguments</key>
<array>
<string>/usr/bin/xcrun</string>
<string>/Users/USERNAME/bin/setupXcodeDerivedDataRAMDisk</string>
</array>
<key>RunAtLoad</key>
<true/>
<key>LaunchOnlyOnce</key>
<true/>
</dict>
</plist>
-------------------------------------------------------------------

The launch agent can be tested with:

launchctl load ~/Library/LaunchAgents/com.ikiapps.setupXcodeDerivedDataRamDisk.plist

*/

/// File systems:
enum FileSystemType {
    case apfs
    case hfsPlus
}

/// Constants:
let RAMDISK_GB = 4 // Set the number of gigabytes for the RAM disk here!
let home = NSHomeDirectory()
let derivedDataPath = "\(home)/Library/Developer/Xcode/DerivedData"
let encoding: String.Encoding = .utf8
let fileSystem = FileSystemType.apfs

/// Error cases:
enum RamDiskSetupError: Error {
    case taskFailed
}

/// - returns: Bool true if the ram disk already exists.
func ramDiskExists() throws -> Bool
{
    let output = try runTask(launchPath: "/sbin/mount", arguments: [])
    let regex = try NSRegularExpression(
        pattern: "/dev/disk.*Library/Developer/Xcode/DerivedData.*mounted",
        options: .caseInsensitive)
    if regex.numberOfMatches(in: output, options: [], range: NSMakeRange(0, output.count)) == 1
    {
        print("RAM disk is already mounted.\n")
        print(output)
        return true
    }
    return false
}

/// - parameter Int for number of blocks to use for the ram disk.
/// - returns: Bool true if the creation of the ram disk is successful.
func createRamDisk(blocks: Int) throws -> Bool
{
    let output = try runTask(launchPath: "/usr/bin/hdid",
                             arguments: ["-nomount", "ram://\(blocks)"])
    let allOutput = NSMakeRange(0, output.count)
    let regex = try NSRegularExpression(pattern: "/dev/disk(\\d+)", options: .caseInsensitive)
    print("output \(output)")
    if regex.numberOfMatches(in: output, options: [], range: allOutput) == 1
    {
        for match in regex.matches(in: output, options: [], range: allOutput)
        {
            let matchRange: NSRange = match.range(at: 1)
            let disk = output[output.index(output.startIndex, offsetBy: matchRange.location) ..<
                              output.index(output.startIndex, offsetBy: (matchRange.location + matchRange.length))]
            try makeFilesystemOn(disk: String(disk))
            try addRamDiskToSpotlight()
        }
    } else { return false }
    return true
}

func makeFilesystemOn(disk: String) throws
{
    var drive = "/dev/rdisk\(disk)"
    var output: String!
    switch fileSystem {
    case .apfs:
        output = try runTask(launchPath: "/usr/sbin/diskutil",
                             arguments: ["ap", "createContainer", drive])
        print(output!)
        let apfsMsg = "Disk from APFS operation: "
        let regex = try NSRegularExpression(pattern: "\(apfsMsg)[[:alnum:]]+\n", options: .caseInsensitive)
        var allOutput = NSMakeRange(0, output.count)
        var matchRange = regex.firstMatch(in: output, options: [], range: allOutput)!.range
        drive = String(output[output.index(output.startIndex, offsetBy: (matchRange.location + apfsMsg.count)) ..<
            output.index(output.startIndex, offsetBy: (matchRange.location + matchRange.length - 1))])
        output = try runTask(launchPath: "/usr/sbin/diskutil",
                             arguments: ["ap", "addVolume", drive, "APFS", "DerivedData", "-nomount"])
        allOutput = NSMakeRange(0, output.count)
        matchRange = regex.firstMatch(in: output, options: [], range: allOutput)!.range
        drive = String(output[output.index(output.startIndex, offsetBy: (matchRange.location + apfsMsg.count)) ..<
            output.index(output.startIndex, offsetBy: (matchRange.location + matchRange.length - 1))])
    case .hfsPlus:
        output = try runTask(launchPath: "/sbin/newfs_hfs",
                             arguments: ["-v", "DerivedData", drive])
    }
    print(output!)
    try mountRamDisk(drive: drive)
}

func ensureDerivedData() throws
{
    let output = try runTask(launchPath: "/bin/mkdir",
                             arguments: ["-p", derivedDataPath])
    print(output)
}

func mountRamDisk(drive: String) throws
{
    try ensureDerivedData()
    let output = try runTask(launchPath: "/usr/sbin/diskutil",
                             arguments: ["mount", "-mountPoint", derivedDataPath, drive])
    print(output)
}

/// Add the ram disk to Spotlight so that Instruments can find symbols.
func addRamDiskToSpotlight() throws
{
    let output = try runTask(launchPath: "/usr/bin/mdutil",
                             arguments: [derivedDataPath, "-i", "on"])
    print(output)
}

func runTask(launchPath: String,
             arguments: [String]) throws -> String
{
    let task = Process()
    task.launchPath = launchPath
    task.arguments = arguments
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                        encoding: encoding)
    if result == nil { throw RamDiskSetupError.taskFailed }
    return result!
}

// ------------------------------------------------------------
// MARK: - Main Program
// ------------------------------------------------------------

print("Setting up RAM disk for Xcode.\n")
if try !ramDiskExists()
{
    if try createRamDisk(blocks: RAMDISK_GB * 1024 * 2048)
    {
        print("Created RAM disk.")
    } else {
        print("Unable to create RAM disk.")
    }
} else {
    print("RAM disk for Derived Data already exists.")
}

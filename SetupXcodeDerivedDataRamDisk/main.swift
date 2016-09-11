#!/usr/bin/env xcrun swift

// Copyright (c) 2016 ikiApps LLC.
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
Tested with OS X 10.11.6 (El Capitan) and Swift 3.0.

The disk is mounted into the default path for Xcode's Derived Data path and will be used automatically
by Xcode if the path is correct for the one set in Xcode's preferences.
 
This script can be added as a startup agent inside ~/Library/LaunchAgents.

** BE SURE TO CHANGE USERNAME BELOW TO MATCH YOUR USERNAME. **

The path below refers to a bin directory contained in your home directory.
This folder needs to be created if it does not already exist.

This script copied into that directory will need to have execute (+x) permissions.
The property list inside LaunchAgents only requires read (+r) permissions to work.
It is sufficient to simply copy the property list into the LaunchAgents directory.
The directory itself will have to be created if it does not already exist.

Here is the content of an example plist (property list) that will have the RAM disk created at startup.

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
<string>/Users/USERNAME/bin/setupXcodeDerivedDataRAMDisk.swift</string>
</array>
<key>RunAtLoad</key>
<true/>
<key>LaunchOnlyOnce</key>
<true/>
</dict>
</plist>
-------------------------------------------------------------------

The launch agent can be tested with:
 
launchctl load com.ikiapps.setupXcodeDerivedDataRamDisk.plist

*/

/// Constants:
let RAMDISK_GB = 4 // Set the number of gigabytes for the RAM disk here!
let home = NSHomeDirectory()
let derivedDataPath = "\(home)/Library/Developer/Xcode/DerivedData"

/**
 - returns: Bool true if the ram disk already exists.
 */
func ramDiskExists() -> Bool
{
    let output = runTask(launchPath: "/sbin/mount", arguments: [])
    let regex: NSRegularExpression?

    do {
        regex = try NSRegularExpression(pattern: "/dev/disk.*Library/Developer/Xcode/DerivedData.*mounted",
                                        options: NSRegularExpression.Options.caseInsensitive)

        let numberOfMatches = regex!.numberOfMatches(in: output,
                                                     options: [],
                                                     range: NSMakeRange(0, output.characters.count))

        if numberOfMatches == 1 {
            print("RAM disk is already mounted.\n")
            print(output)

            return true
        }
    } catch let error as NSError {
        print("error: \(error.localizedDescription)")
        assert (false)
    }

    return false
}

/**
 - parameter Int for number of blocks to use for the ram disk.
 - returns: Bool true if the creation of the ram disk is successful.
 */
func createRamDisk(blocks: Int) -> Bool
{
    let output = runTask(launchPath: "/usr/bin/hdid", arguments: ["-nomount", "ram://\(blocks)"])
    let allOutput = NSMakeRange(0, output.characters.count)
    let regex: NSRegularExpression?

    do {
        regex = try NSRegularExpression(pattern: "/dev/disk(\\d+)", options: NSRegularExpression.Options.caseInsensitive)
        let numberOfMatches = regex!.numberOfMatches(in: output, options: [], range: allOutput)

        print("output \(output)")

        if numberOfMatches == 1 {
            let matches = regex?.matches(in: output, options: [], range: allOutput)

            for match in matches! {
                let matchRange: NSRange = match.rangeAt(1)
                let disk = output.substring(with: output.index(output.startIndex, offsetBy: matchRange.location) ..<
                    output.index(output.startIndex, offsetBy: (matchRange.location + matchRange.length)))
                makeFilesystemOn(disk: disk)
                addRamDiskToSpotlight()
            }
        } else {
            return false
        }
    } catch let error as NSError {
        print("error: \(error.localizedDescription)")
        assert (false)
    }

    return true
}

func makeFilesystemOn(disk: String)
{
    let drive = "/dev/rdisk\(disk)"
    let output = runTask(launchPath: "/sbin/newfs_hfs",
                         arguments: ["-v", "DerivedData", drive])

    print(output)

    mountRamDisk(drive: drive)
}

func mountRamDisk(drive: String)
{
    let output = runTask(launchPath: "/usr/sbin/diskutil",
                         arguments: ["mount", "-mountPoint", derivedDataPath, drive])

    print(output)
}

/// Add to Spotlight so that Instruments can find symbols.
func addRamDiskToSpotlight()
{
    let output = runTask(launchPath: "/usr/bin/mdutil",
                         arguments: [derivedDataPath, "-i", "on"])

    print(output)
}

func runTask(launchPath: String, arguments: [String]) -> String
{
    let task = Process()
    task.launchPath = launchPath
    task.arguments = arguments

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()

    return NSString(data: data, encoding: String.Encoding.utf8.rawValue) as! String
}

print("Setting up RAM disk for Xcode.\n")

if !ramDiskExists() {
    let result = createRamDisk(blocks: RAMDISK_GB * 1024 * 2048)
    if result {
        print("Created RAM disk.")
    } else {
        print("Unable to create RAM disk.")
    }
} else {
    print("RAM disk for Derived Data already exists.")
}

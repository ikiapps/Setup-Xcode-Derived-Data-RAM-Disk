# Get the Fastest Build Times in Xcode

Instead of having Xcode’s Derived Data based in a spinning disk or solid-state drive, move it to a RAM disk. Then, the performance of Xcode build operations run *as fast as possible.* A side benefit is the contents do not persist across reboots and, therefore, do not accumulate excessively.

I have crafted a script in Swift to perform the necessary configuration for you. It can automatically start using a launch agent at startup, so the RAM disk is always available. Returning to a standard Xcode configuration requires ejecting the RAM disk.

It works because the RAM disk mounts to the default path for the DerivedData folder that Xcode uses. You can verify this path in Xcode under Locations in Preferences. The RAM disk gets used by command-line builds and is thereby compatible with alternative IDEs such as AppCode.

## Installation

Define the install path in the build settings under `INSTALL_DIR`. The binary product is copied to this location when building the project. A default path of `$(HOME)/bin` is set. Configuration of this value is by two settings in Xcode's build settings: `INSTALL_ROOT` and `INSTALL_PATH`.

**Complete the following steps to build and install the compiled version of the script.**

* If needed, change the size of `RAMDISK_GB` in `main.swift`
* If needed, change the install path under Targets > SetupXcodeDerivedDataRamDisk > Build Settings > Installation Build Products Location + Installation Directory
* Build the project in Xcode

## Alternative installation

Copy `main.swift` to a local path of your choosing, such as

    ~/bin/setupXcodeDerivedDataRAMDisk.swift

Make it executable with

    chmod +x ~/bin/setupXcodeDerivedDataRAMDisk.swift

## Run at startup

Create a file with the following content. **Edit it to fit your system. Replace ${INSERT_YOUR_USERNAME} with your username. Add `.swift` to the filename if using the text-based script.**

    <?xml version=1.0 encoding=UTF-8?>
    <!DOCTYPE plist PUBLIC -//Apple//DTD PLIST 1.0//EN http://www.apple.com/DTDs/PropertyList-1.0.dtd>
    <plist version=1.0>
    <dict>
    <key>Label</key>
    <string>com.ikiApps.setupXcodeDerivedDataRamDisk.plist</string>
    <key>ProgramArguments</key>
    <array>
    <string>/usr/bin/xcrun</string>
    <string>/Users/${INSERT_YOUR_USERNAME}/bin/setupXcodeDerivedDataRAMDisk</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>LaunchOnlyOnce</key>
    <true/>
    </dict>
    </plist>

Give it a name, for example, `com.ikiApps.setupXcodeDerivedDataRamDisk.plist`, and copy it to

    ~/Library/LaunchAgents

User readable is the minimum permission for the property list. That corresponds to a permission value of 0400 for chmod.

Make sure Xcode is not running, and manually test starting the agent with the following command:

    launchctl load com.ikiApps.setupXcodeDerivedDataRamDisk.plist

If everything went well, the script should now run every time you log in. You can see the mounted RAM disk in the Finder when it is available. It will also be available in the list of mounts using the `mount` or `df` command.

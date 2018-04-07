# Get the Fastest Build Times in Xcode

Instead of having Xcode’s Derived Data be based in a spinning disk or solid-state drive, moving it to a RAM disk can make the performance of Xcode build operations *as fast as possible* and make it so that your Derived Data content is continually freshened.

I’ve crafted a script in Swift 4 to perform the necessary configuration. I start the script in a launch agent that runs at startup so that my RAM disk is always available. Returning to a standard Xcode configuration simply requires ejecting the RAM disk.

The reason this works is because the RAM disk is mounted to the default path for the DerivedData folder that Xcode uses. You can verify this path in Xcode 9 under Locations in its preferences.

## Installation

The install path is defined in the build settings under `INSTALL_PATH`. This is where the binary product will be copied every time the project is built. A default path of `~/bin` has been set.

**Therefore, the following steps should be completed to build and install the compiled version of the script.**

* If needed, change the size of `RAMDISK_GB` in `main.swift`
* If needed, change the install path under Targets > SetupXcodeDerivedDataRamDisk > Build Settings > Installation Directory
* Build the project

## Alternative installation

Copy `main.swift` to a local path of your choosing such as

	~/bin/setupXcodeDerivedDataRAMDisk.swift
	
Make it executable using `chmod +x ~/bin/setupXcodeDerivedDataRAMDisk.swift`.

## Run at startup

Create a file with the following content. **Edit it so that it fits your system. Replace ${INSERT_YOUR_USERNAME} with your username.**

    <?xml version=1.0 encoding=UTF-8?>
    <!DOCTYPE plist PUBLIC -//Apple//DTD PLIST 1.0//EN http://www.apple.com/DTDs/PropertyList-1.0.dtd>
    <plist version=1.0>
    <dict>
    <key>Label</key>
    <string>com.ikiApps.setupXcodeDerivedDataRamDisk.plist</string>
    <key>ProgramArguments</key>
    <array>
    <string>/usr/bin/xcrun</string>
    <string>/Users/${INSERT_YOUR_USERNAME}/bin/setupXcodeDerivedDataRAMDisk.swift</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>LaunchOnlyOnce</key>
    <true/>
    </dict>
    </plist>

Give it a name like `com.ikiApps.setupXcodeDerivedDataRamDisk.plist` and copy it to

	~/Library/LaunchAgents
	
The minimum permission for this property list launch agent file is that it is readable by you. That corresponds to a permission value of 0400 in chmod terms.

The agent can be started manually using

	launchctl load com.ikiApps.setupXcodeDerivedDataRamDisk.plist
	
If everything went well, the script will now run every time you login. You can see the mounted RAM disk in the Finder when it is available. It will also be available in the list of mounts using the ‘mount’ or ‘df’ command.

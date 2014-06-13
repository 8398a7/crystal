#!/usr/bin/env bin/crystal --run

# based on http://www.cocoawithlove.com/2010/09/minimalist-cocoa-programming.html
require "objc"

NSAutoreleasePool.new
NSApplication.sharedApplication

NSApp.activationPolicy = NSApplication::ActivationPolicyRegular

menubar = NSMenu.new
appMenuItem = NSMenuItem.new
menubar << appMenuItem
NSApp.mainMenu = menubar

appMenu = NSMenu.new
appName = NSProcessInfo.processInfo.processName

quitMenuItem = NSMenuItem.new "Quit #{appName}", "terminate:", "q"
appMenu << quitMenuItem
appMenuItem.submenu = appMenu

window = NSWindow.new(NSRect.new(0, 0, 200, 200), NSWindow::NSTitledWindowMask, NSWindow::NSBackingStoreBuffered, false)
window.cascadeTopLeftFromPoint = NSPoint.new(20, 20)
window.title = appName
window.makeKeyAndOrderFront = nil


b = NSButton.new NSRect.new(50, 50, 100, 100)
# b.action = "terminate:"

objc_class :Foo do
  def bar
    puts "Hi there"
  end
  objc_export :Foo, :bar
end

b.target = Foo.new
b.action = "bar"

window.contentView.addSubview b

NSApp.activateIgnoringOtherApps = true
NSApp.run
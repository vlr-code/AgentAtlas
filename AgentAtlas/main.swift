//
//  main.swift
//  AgentAtlas
//
//  Programmatic entry point. `--scan-dump` runs a headless scan and exits
//  before NSApplication is ever created (no GUI event loop). Otherwise the
//  normal AppKit app launches.
//

import Cocoa

if CommandLine.arguments.contains("--selftest-fixes") {
    FixSelfTest.runAndExit()   // headless apply→revert gate, never returns
}

if CommandLine.arguments.contains("--scan-dump") {
    ScanDump.runAndExit()   // headless scan, never returns
}

MainActor.assumeIsolated {
    let appDelegate = AppDelegate()
    let application = NSApplication.shared
    application.delegate = appDelegate
    application.run()
}

//
//  ImageRounding.swift
//  AgentAtlas
//
//  Rounds an image by redrawing it clipped to a rounded rect — produces a new
//  NSImage, touches no view layer (so it can't break NSImageView rendering).
//

import AppKit

@MainActor
func roundedImage(_ image: NSImage, side: CGFloat, radius: CGFloat) -> NSImage {
    let out = NSImage(size: NSSize(width: side, height: side))
    out.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: side, height: side)
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    out.unlockFocus()
    return out
}

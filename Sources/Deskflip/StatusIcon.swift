import AppKit

/// The menu bar icon: a monitor with a left/right arrow on its screen.
/// A filled screen means natural scrolling is on, an outlined screen means it is off.
enum StatusIcon {
    static let size = NSSize(width: 20, height: 16)

    static func image(natural: Bool) -> NSImage {
        let image = NSImage(size: size, flipped: true) { _ in
            draw(natural: natural)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = natural ? "Natural scrolling: On" : "Natural scrolling: Off"
        return image
    }

    /// Draws in flipped coordinates (origin top-left), 20 by 16 points.
    private static func draw(natural: Bool) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        NSColor.black.setFill()
        NSColor.black.setStroke()

        // Stand: neck and base.
        NSBezierPath(rect: NSRect(x: 9.25, y: 12, width: 1.5, height: 2)).fill()
        NSBezierPath(roundedRect: NSRect(x: 6, y: 14, width: 8, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill()

        let screen = NSRect(x: 1.5, y: 1, width: 17, height: 11)
        if natural {
            // Filled screen with the arrow cut out of it.
            NSBezierPath(roundedRect: screen, xRadius: 2, yRadius: 2).fill()
            NSGraphicsContext.current?.compositingOperation = .clear
            fillArrow()
        } else {
            // Outlined screen with a solid arrow.
            let outline = NSBezierPath(roundedRect: screen.insetBy(dx: 0.75, dy: 0.75), xRadius: 1.5, yRadius: 1.5)
            outline.lineWidth = 1.5
            outline.stroke()
            fillArrow()
        }
    }

    /// Fills each piece as its own path so overlaps never cancel out.
    private static func fillArrow() {
        NSBezierPath(rect: NSRect(x: 6.5, y: 5.8, width: 7, height: 1.4)).fill()
        triangle(NSPoint(x: 4.4, y: 6.5), NSPoint(x: 7.2, y: 4.0), NSPoint(x: 7.2, y: 9.0)).fill()
        triangle(NSPoint(x: 15.6, y: 6.5), NSPoint(x: 12.8, y: 4.0), NSPoint(x: 12.8, y: 9.0)).fill()
    }

    private static func triangle(_ a: NSPoint, _ b: NSPoint, _ c: NSPoint) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: a)
        path.line(to: b)
        path.line(to: c)
        path.close()
        return path
    }
}

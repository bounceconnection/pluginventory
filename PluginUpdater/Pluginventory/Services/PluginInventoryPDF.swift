import AppKit
import CoreGraphics

/// Renders the plugin inventory to a multi-page PDF (Plugoff-style export).
enum PluginInventoryPDF {

    struct Row: Sendable {
        let name: String
        let vendor: String
        let format: String
        let version: String
        let category: String
        let size: String
    }

    /// US Letter, in points.
    private static let pageSize = CGSize(width: 612, height: 792)
    private static let inset: CGFloat = 36

    static func generate(title: String, rows: [Row], generatedAt: Date) -> Data {
        paginate(makeAttributedInventory(title: title, rows: rows, generatedAt: generatedAt))
    }

    // MARK: - Content

    private static func makeAttributedInventory(title: String, rows: [Row], generatedAt: Date) -> NSAttributedString {
        let out = NSMutableAttributedString()
        out.append(NSAttributedString(
            string: title + "\n",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 16)]
        ))

        let stamp = DateFormatter()
        stamp.dateStyle = .medium
        stamp.timeStyle = .short
        out.append(NSAttributedString(
            string: "Generated \(stamp.string(from: generatedAt)) · \(rows.count) plugins\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.secondaryLabelColor]
        ))

        let mono = NSFont.monospacedSystemFont(ofSize: 8, weight: .regular)
        let monoBold = NSFont.monospacedSystemFont(ofSize: 8, weight: .bold)

        out.append(NSAttributedString(string: headerLine() + "\n", attributes: [.font: monoBold]))
        out.append(NSAttributedString(
            string: String(repeating: "-", count: 96) + "\n",
            attributes: [.font: mono, .foregroundColor: NSColor.tertiaryLabelColor]
        ))
        for row in rows {
            out.append(NSAttributedString(string: line(for: row) + "\n", attributes: [.font: mono]))
        }
        return out
    }

    private static func headerLine() -> String {
        pad("NAME", 28) + pad("VENDOR", 22) + pad("FORMAT", 8) + pad("VERSION", 12) + pad("CATEGORY", 16) + pad("SIZE", 10)
    }

    private static func line(for row: Row) -> String {
        pad(row.name, 28) + pad(row.vendor, 22) + pad(row.format, 8) + pad(row.version, 12) + pad(row.category, 16) + pad(row.size, 10)
    }

    private static func pad(_ value: String, _ width: Int) -> String {
        let trimmed = value.count > width ? String(value.prefix(width - 1)) + "…" : value
        return trimmed.padding(toLength: width, withPad: " ", startingAt: 0)
    }

    // MARK: - Pagination

    private static func paginate(_ text: NSAttributedString) -> Data {
        let storage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        let textRect = CGRect(
            x: inset, y: inset,
            width: pageSize.width - inset * 2,
            height: pageSize.height - inset * 2
        )

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return Data() }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }

        var drawnGlyphs = 0
        let totalGlyphs = layoutManager.numberOfGlyphs
        var pageCount = 0

        repeat {
            let container = NSTextContainer(size: textRect.size)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            let glyphRange = layoutManager.glyphRange(for: container)
            if totalGlyphs > 0 && glyphRange.length == 0 { break }

            ctx.beginPDFPage(nil)
            ctx.saveGState()
            ctx.translateBy(x: 0, y: pageSize.height)
            ctx.scaleBy(x: 1, y: -1)
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            let origin = CGPoint(x: textRect.minX, y: textRect.minY)
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
            NSGraphicsContext.restoreGraphicsState()
            ctx.restoreGState()
            ctx.endPDFPage()

            drawnGlyphs = NSMaxRange(glyphRange)
            pageCount += 1
        } while drawnGlyphs < totalGlyphs && pageCount < 500

        ctx.closePDF()
        return pdfData as Data
    }
}

import Testing
import Foundation
import PDFKit
@testable import Pluginventory

@Suite("PluginInventoryPDF Tests")
struct PluginInventoryPDFTests {

    private func makeRows(_ count: Int) -> [PluginInventoryPDF.Row] {
        (0..<count).map { index in
            PluginInventoryPDF.Row(
                name: "Plugin \(index)",
                vendor: "Vendor \(index % 10)",
                format: "VST3",
                version: "1.0.\(index)",
                category: "Synth",
                size: "10 MB"
            )
        }
    }

    @Test("Generates non-empty valid PDF data")
    func validPDF() throws {
        let data = PluginInventoryPDF.generate(title: "Test", rows: makeRows(5), generatedAt: Date(timeIntervalSince1970: 0))
        #expect(!data.isEmpty)
        let header = String(decoding: data.prefix(5), as: UTF8.self)
        #expect(header == "%PDF-")
        let doc = try #require(PDFDocument(data: data))
        #expect(doc.pageCount >= 1)
    }

    @Test("Paginates a large inventory across multiple pages")
    func multiPage() throws {
        let data = PluginInventoryPDF.generate(title: "Test", rows: makeRows(400), generatedAt: Date(timeIntervalSince1970: 0))
        let doc = try #require(PDFDocument(data: data))
        #expect(doc.pageCount > 1)
    }

    @Test("Empty inventory still produces a valid PDF")
    func emptyInventory() throws {
        let data = PluginInventoryPDF.generate(title: "Test", rows: [], generatedAt: Date(timeIntervalSince1970: 0))
        let doc = try #require(PDFDocument(data: data))
        #expect(doc.pageCount >= 1)
    }
}

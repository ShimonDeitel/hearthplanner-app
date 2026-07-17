import Foundation
import UIKit

/// Renders attendance reports to CSV and PDF files in the temporary directory,
/// entirely on device.
enum ReportExporter {

    static func writeCSV(reports: [AttendanceReport], fileName: String) -> URL? {
        let csv = SchoolMath.csv(for: reports)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("csv")
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func writePDF(reports: [AttendanceReport], fileName: String) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Hearth Attendance and Hours Report",
            kCGPDFContextCreator as String: "Hearth - Homeschool Planner"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let margin: CGFloat = 54
        let contentWidth = pageRect.width - margin * 2

        let titleFont = UIFont(name: "Georgia-Bold", size: 22) ?? .boldSystemFont(ofSize: 22)
        let headingFont = UIFont(name: "Georgia-Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
        let bodyFont = UIFont.systemFont(ofSize: 12)
        let smallFont = UIFont.systemFont(ofSize: 10)
        let ink = UIColor(red: 0.16, green: 0.14, blue: 0.10, alpha: 1)
        let forest = UIColor(red: 0.12, green: 0.26, blue: 0.18, alpha: 1)
        let honey = UIColor(red: 0.78, green: 0.55, blue: 0.20, alpha: 1)

        let data = renderer.pdfData { context in
            var y: CGFloat = 0

            func startPage() {
                context.beginPage()
                y = margin
                // Header band
                forest.setFill()
                context.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: 8))
            }

            func ensureRoom(_ needed: CGFloat) {
                if y + needed > pageRect.height - margin {
                    startPage()
                }
            }

            func draw(_ text: String, font: UIFont, color: UIColor, x: CGFloat, width: CGFloat, spacingAfter: CGFloat = 6) {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let bounds = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: attributes,
                    context: nil)
                ensureRoom(bounds.height + spacingAfter)
                (text as NSString).draw(
                    with: CGRect(x: x, y: y, width: width, height: bounds.height),
                    options: [.usesLineFragmentOrigin],
                    attributes: attributes,
                    context: nil)
                y += bounds.height + spacingAfter
            }

            startPage()
            draw("Hearth", font: titleFont, color: forest, x: margin, width: contentWidth, spacingAfter: 2)
            draw("Attendance and Hours Report", font: headingFont, color: honey, x: margin, width: contentWidth, spacingAfter: 4)
            let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
            draw("Generated \(stamp). Records kept with Hearth - Homeschool Planner.", font: smallFont, color: .gray, x: margin, width: contentWidth, spacingAfter: 18)

            for report in reports {
                ensureRoom(120)
                // Student heading
                draw("\(report.kidName)\(report.gradeLevel.isEmpty ? "" : "  (Grade \(report.gradeLevel))")",
                     font: headingFont, color: ink, x: margin, width: contentWidth, spacingAfter: 2)
                draw("Period: \(report.rangeLabel)", font: bodyFont, color: .darkGray, x: margin, width: contentWidth, spacingAfter: 8)

                // Summary line
                let summary = String(
                    format: "Days attended: %d of %d required        Total instruction: %.2f hours",
                    report.daysAttended, report.requiredDays, report.totalHours)
                draw(summary, font: bodyFont, color: ink, x: margin, width: contentWidth, spacingAfter: 10)

                // Subject table header
                ensureRoom(24)
                honey.withAlphaComponent(0.18).setFill()
                context.fill(CGRect(x: margin, y: y - 2, width: contentWidth, height: 20))
                let subjectColWidth = contentWidth * 0.7
                let hoursX = margin + subjectColWidth
                let savedY = y
                draw("Subject", font: .boldSystemFont(ofSize: 11), color: forest, x: margin + 6, width: subjectColWidth - 12, spacingAfter: 8)
                let afterHeaderY = y
                y = savedY
                draw("Hours", font: .boldSystemFont(ofSize: 11), color: forest, x: hoursX, width: contentWidth * 0.3 - 6, spacingAfter: 8)
                y = max(y, afterHeaderY)

                if report.subjects.isEmpty {
                    draw("No completed lessons in this period.", font: bodyFont, color: .gray, x: margin + 6, width: contentWidth - 12, spacingAfter: 14)
                }
                for subject in report.subjects {
                    ensureRoom(18)
                    let rowY = y
                    draw(subject.subjectName, font: bodyFont, color: ink, x: margin + 6, width: subjectColWidth - 12, spacingAfter: 5)
                    let afterRowY = y
                    y = rowY
                    draw(String(format: "%.2f", subject.hours), font: bodyFont, color: ink, x: hoursX, width: contentWidth * 0.3 - 6, spacingAfter: 5)
                    y = max(y, afterRowY)
                }
                y += 16
            }

            // Signature block
            ensureRoom(80)
            y += 12
            UIColor.lightGray.setFill()
            context.fill(CGRect(x: margin, y: y, width: 220, height: 1))
            y += 6
            draw("Parent or guardian signature", font: smallFont, color: .gray, x: margin, width: contentWidth, spacingAfter: 2)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

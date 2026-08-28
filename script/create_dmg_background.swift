import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: create_dmg_background.swift <output.png>\n".utf8))
    exit(2)
}

let size = NSSize(width: 760, height: 520)
let image = NSImage(size: size)
image.lockFocus()

NSColor(calibratedWhite: 0.975, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

func drawCentered(_ text: String, top: CGFloat, font: NSFont, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let textSize = attributed.size()
    attributed.draw(at: NSPoint(
        x: (size.width - textSize.width) / 2,
        y: size.height - top - textSize.height
    ))
}

drawCentered(
    "安装 Rokid 无线投屏助手",
    top: 42,
    font: .systemFont(ofSize: 30, weight: .bold),
    color: NSColor(calibratedWhite: 0.16, alpha: 1)
)
drawCentered(
    "将左侧 App 拖到右侧“应用程序”文件夹",
    top: 88,
    font: .systemFont(ofSize: 18, weight: .medium),
    color: NSColor(calibratedWhite: 0.52, alpha: 1)
)

let arrowColor = NSColor(calibratedRed: 0.02, green: 0.56, blue: 0.94, alpha: 1)
let centerY = size.height - 292
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 292, y: centerY - 7))
arrow.line(to: NSPoint(x: 424, y: centerY - 7))
arrow.line(to: NSPoint(x: 424, y: centerY - 32))
arrow.line(to: NSPoint(x: 478, y: centerY))
arrow.line(to: NSPoint(x: 424, y: centerY + 32))
arrow.line(to: NSPoint(x: 424, y: centerY + 7))
arrow.line(to: NSPoint(x: 292, y: centerY + 7))
arrow.close()
arrowColor.setFill()
arrow.fill()

drawCentered(
    "若未显示右侧文件夹：按 ⇧⌘A 打开“应用程序”",
    top: 132,
    font: .systemFont(ofSize: 15, weight: .semibold),
    color: NSColor(calibratedWhite: 0.48, alpha: 1)
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to render DMG background\n".utf8))
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)

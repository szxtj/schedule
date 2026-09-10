import AppKit

let inputPath = "/Users/justinxie/.gemini/antigravity/brain/8fbc4d35-f8f2-48f1-abed-1f2b5ffb5c91/app_icon_1789031617803.jpg"
guard let sourceImage = NSImage(contentsOfFile: inputPath),
      let tiff = sourceImage.tiffRepresentation,
      let sourceRep = NSBitmapImageRep(data: tiff) else {
    print("Failed to load source image")
    exit(1)
}

// 目标图标正方形区域 (截取中心 squircle: 186, 186, 652, 652)
let cropRect = NSRect(x: 186, y: 186, width: 652, height: 652)
guard let cgImage = sourceRep.cgImage?.cropping(to: cropRect) else {
    print("Failed to crop CGImage")
    exit(1)
}

// 创建 1024x1024 带有透明通道与圆角抗锯齿的高清母图
let masterSize = CGSize(width: 1024, height: 1024)
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: 1024,
    height: 1024,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create CGContext")
    exit(1)
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.interpolationQuality = .high

// 绘制 macOS 标准圆角矩形遮罩 (标准 cornerRadius 约为 22.37% * 1024 = 229)
let iconBounds = CGRect(x: 24, y: 24, width: 976, height: 976)
let cornerRadius: CGFloat = 218.0
let path = CGPath(roundedRect: iconBounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

context.addPath(path)
context.clip()
context.draw(cgImage, in: iconBounds)

guard let masterCGImage = context.makeImage() else {
    print("Failed to generate master image")
    exit(1)
}

// 保存 master 1024 png
let masterRep = NSBitmapImageRep(cgImage: masterCGImage)
guard let pngData = masterRep.representation(using: .png, properties: [:]) else {
    print("Failed to encode PNG")
    exit(1)
}

let outputDir = "/Users/justinxie/Projects/schedule/assets/icons"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
let masterPath = "\(outputDir)/app_icon_1024.png"
try? pngData.write(to: URL(fileURLWithPath: masterPath))
print("Saved master icon: \(masterPath)")

// 生成 macOS appiconset 各尺寸
let macSizes: [String: Int] = [
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024
]

let macAppIconDir = "/Users/justinxie/Projects/schedule/macos/Runner/Assets.xcassets/AppIcon.appiconset"

for (fileName, size) in macSizes {
    let destCtx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    destCtx.interpolationQuality = .high
    destCtx.draw(masterCGImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    if let resizedCG = destCtx.makeImage() {
        let rep = NSBitmapImageRep(cgImage: resizedCG)
        if let data = rep.representation(using: .png, properties: [:]) {
            let destPath = "\(macAppIconDir)/\(fileName)"
            try? data.write(to: URL(fileURLWithPath: destPath))
            print("Generated macOS icon: \(fileName) (\(size)x\(size))")
        }
    }
}

// 生成 Android mipmap 图标
let androidSizes: [String: Int] = [
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192
]

let androidResDir = "/Users/justinxie/Projects/schedule/android/app/src/main/res"

for (folder, size) in androidSizes {
    let destCtx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    destCtx.interpolationQuality = .high
    destCtx.draw(masterCGImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    if let resizedCG = destCtx.makeImage() {
        let rep = NSBitmapImageRep(cgImage: resizedCG)
        if let data = rep.representation(using: .png, properties: [:]) {
            let destFolder = "\(androidResDir)/\(folder)"
            try? FileManager.default.createDirectory(atPath: destFolder, withIntermediateDirectories: true)
            let destPath = "\(destFolder)/ic_launcher.png"
            try? data.write(to: URL(fileURLWithPath: destPath))
            print("Generated Android icon: \(folder)/ic_launcher.png (\(size)x\(size))")
        }
    }
}

print("All icons successfully generated!")


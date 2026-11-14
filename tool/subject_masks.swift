// Writes one grayscale PNG mask per foreground subject that macOS's Vision
// framework finds in a picture: <out_dir>/<prefix>_<n>.png
//
//   swift subject_masks.swift <image> <out_dir> <prefix>
import AppKit
import CoreImage
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write("usage: subject_masks <image> <out_dir> <prefix>\n".data(using: .utf8)!)
    exit(2)
}
let imageURL = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let prefix = args[3]

guard let nsImage = NSImage(contentsOf: imageURL),
      let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write("cannot read image\n".data(using: .utf8)!)
    exit(1)
}

let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try handler.perform([request])
guard let observation = request.results?.first else {
    print("no subjects")
    exit(0)
}

let context = CIContext()
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
print("instances: \(observation.allInstances.count)")
for instance in observation.allInstances {
    let buffer = try observation.generateScaledMaskForImage(forInstances: IndexSet(integer: instance), from: handler)
    let ciImage = CIImage(cvPixelBuffer: buffer)
    let outURL = outDir.appendingPathComponent("\(prefix)_\(instance).png")
    try context.writePNGRepresentation(
        of: ciImage, to: outURL, format: .L8, colorSpace: CGColorSpace(name: CGColorSpace.linearGray)!)
    print("wrote \(outURL.lastPathComponent) \(Int(ciImage.extent.width))x\(Int(ciImage.extent.height))")
}

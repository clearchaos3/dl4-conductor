// Removes the background from a product photo using Apple's Vision foreground-instance mask
// (the same "lift subject" tech as Preview), returning a transparent PNG cropped to the pedal.
// Usage: swift tools/cutout.swift in.png out.png
import Foundation
import Vision
import CoreImage
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: cutout in out"); exit(1) }
guard let img = NSImage(contentsOfFile: args[1]),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("load fail: \(args[1])"); exit(1) }

let req = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(cgImage: cg, options: [:])
do {
    try handler.perform([req])
    guard let res = req.results?.first else { print("NO-SUBJECT \(args[1])"); exit(2) }
    let buf = try res.generateMaskedImage(ofInstances: res.allInstances, from: handler, croppedToInstancesExtent: true)
    let ci = CIImage(cvPixelBuffer: buf)
    guard let out = CIContext().createCGImage(ci, from: ci.extent) else { print("render fail"); exit(3) }
    try NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
    print("cutout \(args[2])  \(out.width)x\(out.height)")
} catch { print("ERR \(args[1]): \(error)"); exit(4) }

import CryptoKit
import Foundation

// Verify both the signed inventory and every file in the package before release.
guard CommandLine.arguments.count == 2 else { fatalError("Usage: swift scripts/verify.swift PACKAGE") }
let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let package = URL(fileURLWithPath: CommandLine.arguments[1])
let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: repository.appendingPathComponent("publisher.json"))) as! [String: String]
let inventory = try Data(contentsOf: package.appendingPathComponent("SHA256SUMS"))
let signatureText = try String(contentsOf: package.appendingPathComponent("SIGNATURE.ed25519"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
guard let publicBytes = Data(base64Encoded: metadata["publicKey"]!),
      let signature = Data(base64Encoded: signatureText),
      let text = String(data: inventory, encoding: .utf8), text.hasSuffix("\n") else { fatalError("Invalid package metadata") }
var message = Data("duckpad-extension-signature-v1\n".utf8); message.append(inventory)
let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicBytes)
guard key.isValidSignature(signature, for: message) else { fatalError("Invalid publisher signature") }
var names = Set<String>()
for line in text.split(separator: "\n") {
    let fields = line.components(separatedBy: "  ")
    guard fields.count == 2, fields[0].count == 64,
          fields[0].allSatisfy({ "0123456789abcdef".contains($0) }),
          !fields[1].isEmpty, !fields[1].contains("/"), !fields[1].contains("\\"),
          ![".", "..", "SHA256SUMS", "SIGNATURE.ed25519"].contains(fields[1]),
          names.insert(fields[1]).inserted else { fatalError("Invalid inventory") }
    let file = package.appendingPathComponent(fields[1])
    let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else { fatalError("Unsafe package file") }
    let digest = SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
    guard digest == fields[0] else { fatalError("Checksum mismatch: \(fields[1])") }
}
let actual = Set(try FileManager.default.contentsOfDirectory(atPath: package.path))
guard actual == names.union(["SHA256SUMS", "SIGNATURE.ed25519"]) else { fatalError("Uninventoried files") }
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: package.appendingPathComponent("plugin.json"))) as! [String: Any]
guard let publisher = manifest["publisher"] as? [String: String],
      publisher["id"] == metadata["id"], publisher["keyID"] == metadata["keyID"],
      manifest["id"] as? String == "com.duckpad.plantuml" else { fatalError("Publisher/manifest mismatch") }
print("Verified PlantUML signature and \(names.count) package files")

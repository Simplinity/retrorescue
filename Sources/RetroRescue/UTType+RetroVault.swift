import UniformTypeIdentifiers

extension UTType {
    /// The .retrovault bundle document type
    static let retroVault = UTType(
        exportedAs: "com.simplinity.retrorescue.vault",
        conformingTo: .package
    )
}

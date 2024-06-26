/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import SwiftDocC
import Foundation

extension Docc {
    /// Merge a list of documentation archives into a combined archive.
    public struct Merge: ParsableCommand {
        public init() {}
        
        public static var configuration = CommandConfiguration(
            abstract: "Merge a list of documentation archives into a combined archive."
        )
        
        private static let archivePathExtension = "doccarchive"
        private static let catalogPathExtension = "docc"
        
        // The file manager used to validate the input and output directories.
        //
        // Provided as a static variable to allow for using a different file manager in unit tests.
        static var _fileManager: FileManagerProtocol = FileManager.default
        
        // Note:
        // The order of the option groups in this file is reflected in the 'docc merge --help' output.
        
        // MARK: - Inputs & outputs
        
        @OptionGroup(title: "Inputs & outputs")
        var inputsAndOutputs: InputAndOutputOptions
        struct InputAndOutputOptions: ParsableArguments {
            @Argument(
                help: ArgumentHelp(
                    "A list of paths to '.\(Merge.archivePathExtension)' documentation archive directories to combine into a combined archive.",
                    valueName: "archive-path"),
                transform: URL.init(fileURLWithPath:))
            var archives: [URL]
            
            @Option(
                help: ArgumentHelp(
                    "Path to a '.\(Merge.catalogPathExtension)' documentation catalog directory with content for the landing page.",
                    valueName: "catalog-path"),
                transform: URL.init(fileURLWithPath:))
            var landingPageCatalog: URL?
            
            @Option(
                name: [.customLong("output-path"), .customShort("o")],
                help: "The location where the documentation compiler writes the combined documentation archive.",
                transform: URL.init(fileURLWithPath:)
            )
            var providedOutputURL: URL?
            
            var outputURL: URL!
            
            mutating func validate() throws {
                let fileManager = Docc.Merge._fileManager
                
                guard !archives.isEmpty else {
                    throw ValidationError("Require at least one documentation archive to merge.")
                }
                // Validate that the input archives exists and have the expected path extension
                for archive in archives {
                    switch archive.pathExtension.lowercased() {
                    case Merge.archivePathExtension:
                        break // The expected path extension
                    case "":
                        throw ValidationError("Missing '\(Merge.archivePathExtension)' path extension for archive '\(archive.path)'")
                    default:
                        throw ValidationError("Path extension '\(archive.pathExtension)' is not '\(Merge.archivePathExtension)' for archive '\(archive.path)'")
                    }
                    guard fileManager.directoryExists(atPath: archive.path) else {
                        throw ValidationError("No directory exists at '\(archive.path)'")
                    }
                }
                
                // Validate that the input catalog exist and have the expected path extension
                if let catalog = landingPageCatalog {
                    switch catalog.pathExtension.lowercased() {
                    case Merge.catalogPathExtension:
                        break // The expected path extension
                    case "":
                        throw ValidationError("Missing '\(Merge.catalogPathExtension)' path extension for catalog '\(catalog.path)'")
                    default:
                        throw ValidationError("Path extension '\(catalog.pathExtension)' is not '\(Merge.catalogPathExtension)' for catalog '\(catalog.path)'")
                    }
                    guard fileManager.directoryExists(atPath: catalog.path) else {
                        throw ValidationError("No directory exists at '\(catalog.path)'")
                    }
                }
                
                // Validate that the directory above the output location exist so that the merge command doesn't need to create intermediate directories.
                if let outputParent = providedOutputURL?.deletingLastPathComponent() {
                    // Verify that the intermediate directories exist for the output location.
                    guard fileManager.directoryExists(atPath: outputParent.path) else {
                        throw ValidationError("Missing intermediate directory at '\(outputParent.path)' for output path")
                    }
                }
                outputURL = providedOutputURL ?? URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("Combined.\(Merge.archivePathExtension)", isDirectory: true)
            }
        }
        
        public var archives: [URL] {
            get { inputsAndOutputs.archives }
            set { inputsAndOutputs.archives = newValue}
        }
        public var landingPageCatalog: URL? {
            get { inputsAndOutputs.landingPageCatalog }
            set { inputsAndOutputs.landingPageCatalog = newValue}
        }
        public var outputURL: URL {
            inputsAndOutputs.outputURL
        }
        
        public mutating func run() throws {
            // Initialize a `ConvertAction` from the current options in the `Convert` command.
            var convertAction = MergeAction(archives: archives, landingPageCatalog: landingPageCatalog, outputURL: outputURL, fileManager: Self._fileManager)
            
            // Perform the conversion and print any warnings or errors found
            try convertAction.performAndHandleResult()
        }
        
    }
}

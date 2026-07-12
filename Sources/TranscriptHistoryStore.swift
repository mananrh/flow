import Foundation
import CoreData

/// A lightweight record representing a single completed dictation for the user-facing
/// Transcript History feature. Unlike the internal `PipelineHistoryStore` (which stores
/// debug-level detail and caps at 20 entries), this store retains all dictations
/// indefinitely and exposes only user-relevant fields.
struct TranscriptRecord: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let rawTranscript: String
    let cleanTranscript: String
    let appName: String?
    let windowTitle: String?
    let bundleIdentifier: String?
    let audioFileName: String?

    var displayTranscript: String {
        cleanTranscript.isEmpty ? rawTranscript : cleanTranscript
    }
}

// MARK: - CoreData Store

final class TranscriptHistoryStore {
    private let container: NSPersistentContainer
    private let isStoreLoaded: Bool

    init() {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "TranscriptHistory", managedObjectModel: model)

        var storeURL: URL?
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appName = AppName.displayName
            let baseURL = appSupport.appendingPathComponent(appName, isDirectory: true)
            try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            storeURL = baseURL.appendingPathComponent("TranscriptHistory.sqlite")
        }

        if let storeURL {
            let description = NSPersistentStoreDescription(url: storeURL)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [description]
        } else {
            container.persistentStoreDescriptions = [NSPersistentStoreDescription()]
        }

        if Self.loadPersistentStoresSynchronously(container: container) == nil {
            isStoreLoaded = true
        } else {
            if let storeURL {
                Self.destroySQLiteStoreFiles(at: storeURL)
                let coordinator = container.persistentStoreCoordinator
                for store in coordinator.persistentStores {
                    try? coordinator.remove(store)
                }
                let recoveryDescription = NSPersistentStoreDescription(url: storeURL)
                recoveryDescription.shouldMigrateStoreAutomatically = true
                recoveryDescription.shouldInferMappingModelAutomatically = true
                container.persistentStoreDescriptions = [recoveryDescription]
            }

            if Self.loadPersistentStoresSynchronously(container: container) == nil {
                isStoreLoaded = true
            } else {
                let coordinator = container.persistentStoreCoordinator
                for store in coordinator.persistentStores {
                    try? coordinator.remove(store)
                }
                let description = NSPersistentStoreDescription()
                description.type = NSInMemoryStoreType
                container.persistentStoreDescriptions = [description]
                isStoreLoaded = Self.loadPersistentStoresSynchronously(container: container) == nil
            }
        }
    }

    // MARK: - Public API

    func loadAll() -> [TranscriptRecord] {
        guard isStoreLoaded else { return [] }
        var result: [TranscriptRecord] = []
        container.viewContext.performAndWait {
            let request = transcriptRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            guard let entities = try? container.viewContext.fetch(request) else { return }
            result = entities.map(Self.makeRecord(from:))
        }
        return result
    }

    func search(query: String) -> [TranscriptRecord] {
        guard isStoreLoaded else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return loadAll() }

        var result: [TranscriptRecord] = []
        container.viewContext.performAndWait {
            let request = transcriptRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.predicate = NSPredicate(
                format: "cleanTranscript CONTAINS[cd] %@ OR rawTranscript CONTAINS[cd] %@ OR appName CONTAINS[cd] %@",
                trimmed, trimmed, trimmed
            )
            guard let entities = try? container.viewContext.fetch(request) else { return }
            result = entities.map(Self.makeRecord(from:))
        }
        return result
    }

    func append(_ record: TranscriptRecord) throws {
        guard isStoreLoaded else { return }
        var thrownError: Error?
        container.viewContext.performAndWait {
            do {
                let entity = TranscriptHistoryEntry(context: container.viewContext)
                entity.id = record.id
                entity.timestamp = record.timestamp
                entity.rawTranscript = record.rawTranscript
                entity.cleanTranscript = record.cleanTranscript
                entity.appName = record.appName
                entity.windowTitle = record.windowTitle
                entity.bundleIdentifier = record.bundleIdentifier
                entity.audioFileName = record.audioFileName
                try saveContext()
            } catch {
                thrownError = error
            }
        }
        if let thrownError { throw thrownError }
    }

    func delete(id: UUID) throws {
        guard isStoreLoaded else { return }
        var thrownError: Error?
        container.viewContext.performAndWait {
            do {
                let request = transcriptRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                guard let entity = try container.viewContext.fetch(request).first else { return }
                container.viewContext.delete(entity)
                try saveContext()
            } catch {
                thrownError = error
            }
        }
        if let thrownError { throw thrownError }
    }

    func clearAll() throws {
        guard isStoreLoaded else { return }
        var thrownError: Error?
        container.viewContext.performAndWait {
            do {
                let request = transcriptRequest()
                guard let entities = try? container.viewContext.fetch(request) else { return }
                for entity in entities {
                    container.viewContext.delete(entity)
                }
                try saveContext()
            } catch {
                thrownError = error
            }
        }
        if let thrownError { throw thrownError }
    }

    func count() -> Int {
        guard isStoreLoaded else { return 0 }
        var result = 0
        container.viewContext.performAndWait {
            let request = transcriptRequest()
            result = (try? container.viewContext.count(for: request)) ?? 0
        }
        return result
    }

    // MARK: - Private Helpers

    private func saveContext() throws {
        guard container.viewContext.hasChanges else { return }
        do {
            try container.viewContext.save()
        } catch {
            container.viewContext.rollback()
            throw error
        }
    }

    private func transcriptRequest() -> NSFetchRequest<TranscriptHistoryEntry> {
        NSFetchRequest<TranscriptHistoryEntry>(entityName: "TranscriptHistoryEntry")
    }

    private static func loadPersistentStoresSynchronously(container: NSPersistentContainer) -> Error? {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var capturedError: Error?
        var remainingCompletions = max(1, container.persistentStoreDescriptions.count)

        container.loadPersistentStores { _, error in
            lock.lock()
            if capturedError == nil, let error {
                capturedError = error
            }
            remainingCompletions -= 1
            let shouldSignal = remainingCompletions <= 0
            lock.unlock()
            if shouldSignal {
                semaphore.signal()
            }
        }

        semaphore.wait()
        return capturedError
    }

    private static func destroySQLiteStoreFiles(at storeURL: URL) {
        let basePath = storeURL.path
        for path in [basePath, basePath + "-wal", basePath + "-shm"] {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private static func makeRecord(from entity: TranscriptHistoryEntry) -> TranscriptRecord {
        TranscriptRecord(
            id: entity.id,
            timestamp: entity.timestamp ?? Date(),
            rawTranscript: entity.rawTranscript ?? "",
            cleanTranscript: entity.cleanTranscript ?? "",
            appName: entity.appName,
            windowTitle: entity.windowTitle,
            bundleIdentifier: entity.bundleIdentifier,
            audioFileName: entity.audioFileName
        )
    }

    // MARK: - CoreData Model

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "TranscriptHistoryEntry"
        entity.managedObjectClassName = NSStringFromClass(TranscriptHistoryEntry.self)

        entity.properties = [
            makeAttribute(name: "id", type: .UUIDAttributeType, isOptional: false),
            makeAttribute(name: "timestamp", type: .dateAttributeType, isOptional: false),
            makeAttribute(name: "rawTranscript", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "cleanTranscript", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "appName", type: .stringAttributeType, isOptional: true),
            makeAttribute(name: "windowTitle", type: .stringAttributeType, isOptional: true),
            makeAttribute(name: "bundleIdentifier", type: .stringAttributeType, isOptional: true),
            makeAttribute(name: "audioFileName", type: .stringAttributeType, isOptional: true),
        ]

        model.entities = [entity]
        return model
    }

    private static func makeAttribute(
        name: String,
        type: NSAttributeType,
        isOptional: Bool,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        attribute.defaultValue = defaultValue
        return attribute
    }
}

// MARK: - CoreData Managed Object

@objc(TranscriptHistoryEntry)
final class TranscriptHistoryEntry: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var timestamp: Date?
    @NSManaged var rawTranscript: String?
    @NSManaged var cleanTranscript: String?
    @NSManaged var appName: String?
    @NSManaged var windowTitle: String?
    @NSManaged var bundleIdentifier: String?
    @NSManaged var audioFileName: String?
}

import CoreData
import Foundation

enum VoiceBankError: Error, Equatable {
    case storeUnavailable
}

struct VoiceBankStats: Equatable {
    let count: Int
    let totalDurationMs: Int
}

/// Core Data metadata store for banked samples. Owns its own SQLite file,
/// fully independent of PipelineHistoryStore and its 20-entry trim.
final class VoiceBankStore {
    private let container: NSPersistentContainer
    private let isLoaded: Bool

    /// - Parameter storeURL: on-disk SQLite location, or nil for in-memory.
    init(storeURL: URL?) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "VoiceBank", managedObjectModel: model)

        let description: NSPersistentStoreDescription
        if let storeURL {
            try? FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            description = NSPersistentStoreDescription(url: storeURL)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        } else {
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
        }
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        semaphore.wait()
        isLoaded = (loadError == nil)
    }

    func insert(_ sample: VoiceSample) throws {
        guard isLoaded else { throw VoiceBankError.storeUnavailable }
        var thrown: Error?
        container.viewContext.performAndWait {
            let entity = VoiceSampleEntry(context: container.viewContext)
            entity.id = sample.id
            entity.createdAt = sample.createdAt
            entity.audioFileName = sample.audioFileName
            entity.transcript = sample.transcript
            entity.durationMs = Int64(sample.durationMs)
            entity.sampleRate = Int64(sample.sampleRate)
            entity.wordCount = Int64(sample.wordCount)
            entity.appBundleId = sample.appBundleId
            do { try container.viewContext.save() }
            catch { thrown = error; container.viewContext.rollback() }
        }
        if let thrown { throw thrown }
    }

    func allSamples() -> [VoiceSample] {
        guard isLoaded else { return [] }
        var result: [VoiceSample] = []
        container.viewContext.performAndWait {
            let request = NSFetchRequest<VoiceSampleEntry>(entityName: "VoiceSampleEntry")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            guard let entities = try? container.viewContext.fetch(request) else { return }
            result = entities.map(Self.makeSample(from:))
        }
        return result
    }

    func stats() -> VoiceBankStats {
        let all = allSamples()
        return VoiceBankStats(
            count: all.count,
            totalDurationMs: all.reduce(0) { $0 + $1.durationMs }
        )
    }

    /// Deletes one sample, returning its audio file name so the caller can
    /// remove the WAV. Returns nil if no such row exists.
    func delete(id: UUID) throws -> String? {
        guard isLoaded else { return nil }
        var removed: String?
        var thrown: Error?
        container.viewContext.performAndWait {
            let request = NSFetchRequest<VoiceSampleEntry>(entityName: "VoiceSampleEntry")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            do {
                guard let entity = try container.viewContext.fetch(request).first else { return }
                removed = entity.audioFileName
                container.viewContext.delete(entity)
                try container.viewContext.save()
            } catch { thrown = error; container.viewContext.rollback() }
        }
        if let thrown { throw thrown }
        return removed
    }

    /// Deletes every sample, returning all audio file names to remove.
    func deleteAll() throws -> [String] {
        guard isLoaded else { return [] }
        var removed: [String] = []
        var thrown: Error?
        container.viewContext.performAndWait {
            let request = NSFetchRequest<VoiceSampleEntry>(entityName: "VoiceSampleEntry")
            do {
                let entities = try container.viewContext.fetch(request)
                removed = entities.compactMap(\.audioFileName)
                for entity in entities { container.viewContext.delete(entity) }
                try container.viewContext.save()
            } catch { thrown = error; container.viewContext.rollback() }
        }
        if let thrown { throw thrown }
        return removed
    }

    private static func makeSample(from entity: VoiceSampleEntry) -> VoiceSample {
        VoiceSample(
            id: entity.id,
            createdAt: entity.createdAt ?? Date(),
            audioFileName: entity.audioFileName ?? "",
            transcript: entity.transcript ?? "",
            durationMs: Int(entity.durationMs),
            sampleRate: Int(entity.sampleRate),
            wordCount: Int(entity.wordCount),
            appBundleId: entity.appBundleId
        )
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "VoiceSampleEntry"
        entity.managedObjectClassName = NSStringFromClass(VoiceSampleEntry.self)

        func attribute(_ name: String, _ type: NSAttributeType, optional: Bool) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            return a
        }

        entity.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("createdAt", .dateAttributeType, optional: false),
            attribute("audioFileName", .stringAttributeType, optional: false),
            attribute("transcript", .stringAttributeType, optional: false),
            attribute("durationMs", .integer64AttributeType, optional: false),
            attribute("sampleRate", .integer64AttributeType, optional: false),
            attribute("wordCount", .integer64AttributeType, optional: false),
            attribute("appBundleId", .stringAttributeType, optional: true),
        ]
        model.entities = [entity]
        return model
    }
}

@objc(VoiceSampleEntry)
final class VoiceSampleEntry: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var createdAt: Date?
    @NSManaged var audioFileName: String?
    @NSManaged var transcript: String?
    @NSManaged var durationMs: Int64
    @NSManaged var sampleRate: Int64
    @NSManaged var wordCount: Int64
    @NSManaged var appBundleId: String?
}

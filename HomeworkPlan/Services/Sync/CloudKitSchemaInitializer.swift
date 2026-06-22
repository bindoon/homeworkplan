#if DEBUG
import CoreData
import CloudKit

enum CloudKitSchemaInitializer {
    private static let flagKey = "cloudKitSchemaInitialized"
    private static let containerIdentifier = "iCloud.app.homeworkplan.HomeworkPlan"

    static func initializeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeworkPlanSchemaInit.sqlite")

        let description = NSPersistentStoreDescription(url: storeURL)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: containerIdentifier
        )

        let model = NSManagedObjectModel()
        let container = NSPersistentCloudKitContainer(name: "HomeworkPlanSchemaInit", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError {
            print("CloudKit schema init store load failed: \(loadError)")
            return
        }

        do {
            try container.initializeCloudKitSchema(options: [])
            UserDefaults.standard.set(true, forKey: flagKey)
        } catch {
            print("CloudKit schema initialization failed: \(error)")
        }
    }
}
#endif

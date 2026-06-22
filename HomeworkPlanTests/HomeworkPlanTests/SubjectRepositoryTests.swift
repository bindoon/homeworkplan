import SwiftData
import XCTest
@testable import HomeworkPlan

@MainActor
final class SubjectRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: SubjectRepository!

    override func setUpWithError() throws {
        let schema = Schema([HomeworkTask.self, Subject.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repository = SubjectRepository(context: context)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
    }

    func testCreateCustomSubject_persistsWithNormalizedName() throws {
        let subject = try repository.create(name: "奥数", emoji: "🧮")
        XCTAssertEqual(subject.normalizedName, "奥数")
    }

    func testCreateDuplicateName_throwsOrReturnsExisting() throws {
        _ = try repository.create(name: "钢琴", emoji: "🎹")
        XCTAssertThrowsError(try repository.create(name: "钢琴", emoji: "🎹")) { error in
            XCTAssertTrue(error is SubjectError)
        }
    }

    func testDeleteDefaultSubject_forbidden() throws {
        let subject = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        context.insert(subject)
        try context.save()

        XCTAssertThrowsError(try repository.delete(id: subject.id)) { error in
            guard case SubjectError.cannotDeleteDefault = error else {
                return XCTFail("Expected cannotDeleteDefault")
            }
        }
    }

    func testDeleteCustomSubject_succeeds() throws {
        let subject = try repository.create(name: "钢琴", emoji: "🎹")
        try repository.delete(id: subject.id)
        let fetched = try repository.fetch(id: subject.id)
        XCTAssertNil(fetched)
    }
}

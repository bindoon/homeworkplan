import AVFoundation
import Speech
import XCTest
@testable import HomeworkPlan

final class MockSpeechAuthorizationProvider: SpeechAuthorizationProviding {
    var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var mockRecordPermission: AVAudioApplication.recordPermission = .undetermined
    var grantRecordPermission = true

    func speechAuthorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        speechStatus
    }

    func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        if speechStatus == .notDetermined {
            speechStatus = .authorized
        }
        return speechStatus
    }

    func recordPermission() -> AVAudioApplication.recordPermission {
        mockRecordPermission
    }

    func requestRecordPermission() async -> Bool {
        if mockRecordPermission == .undetermined {
            mockRecordPermission = grantRecordPermission ? .granted : .denied
        }
        return mockRecordPermission == .granted
    }
}

@MainActor
final class SpeechInputServiceTests: XCTestCase {
    func testPermissionDeniedMarksUnavailable() {
        let provider = MockSpeechAuthorizationProvider()
        provider.speechStatus = .denied
        provider.mockRecordPermission = .granted

        let service = SpeechInputService(authorizationProvider: provider)
        service.refreshAvailability()

        XCTAssertFalse(service.isAvailable)
        XCTAssertEqual(service.permissionStatus, .denied)
    }

    func testMicrophoneDeniedMarksUnavailable() {
        let provider = MockSpeechAuthorizationProvider()
        provider.speechStatus = .authorized
        provider.mockRecordPermission = .denied

        let service = SpeechInputService(authorizationProvider: provider)
        service.refreshAvailability()

        XCTAssertFalse(service.isAvailable)
    }

    func testStartRecordingWithoutPermissionThrows() async {
        let provider = MockSpeechAuthorizationProvider()
        provider.speechStatus = .denied
        provider.mockRecordPermission = .denied

        let service = SpeechInputService(authorizationProvider: provider)
        service.refreshAvailability()

        do {
            try await service.startRecording()
            XCTFail("Expected permissionDenied")
        } catch let error as SpeechInputError {
            XCTAssertEqual(error, .permissionDenied)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStopRecordingWhenNotRecordingReturnsEmpty() {
        let service = SpeechInputService(authorizationProvider: MockSpeechAuthorizationProvider())
        XCTAssertEqual(service.stopRecording(), "")
        XCTAssertFalse(service.isRecording)
    }

    func testPermissionErrorMessagesAreUserFacing() {
        XCTAssertEqual(
            SpeechInputError.permissionDenied.errorDescription,
            "未获得麦克风或语音识别权限，请使用文字输入"
        )
        XCTAssertEqual(
            SpeechInputError.recognizerUnavailable.errorDescription,
            "当前设备不支持中文语音识别"
        )
    }
}

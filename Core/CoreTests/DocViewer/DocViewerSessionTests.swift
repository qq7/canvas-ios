//
// Copyright (C) 2018-present Instructure, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import XCTest
@testable import Core
import TestsFoundation

class DocViewerSessionTests: CoreTestCase {
    class MockTask: URLSessionDataTask {
        var cancelled = false
        override func cancel() { cancelled = true }
        override func resume() {}
    }
    class MockURLSession: URLSession {
        var handler: ((Data?, URLResponse?, Error?) -> Void)?
        override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
            handler = completionHandler
            return MockTask()
        }
        override func invalidateAndCancel() {}
    }

    let noFollowSession = NoFollowRedirect.session
    override func tearDown() {
        super.tearDown()
        NoFollowRedirect.session = noFollowSession
    }

    func testRedirect() {
        let expectation = XCTestExpectation(description: "handler called")
        let url = URL(string: "/")!
        (NoFollowRedirect.session.delegate as? NoFollowRedirect)?.urlSession(
            NoFollowRedirect.session,
            task: MockTask(),
            willPerformHTTPRedirection: HTTPURLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
            newRequest: URLRequest(url: url)
        ) { request in
            XCTAssertNil(request)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.01)
    }

    func testCancel() {
        let session = DocViewerSession {}
        let mockTask = MockTask()
        session.task = mockTask
        session.cancel()
        XCTAssertTrue(mockTask.cancelled)
    }

    func testLoad() {
        let session = DocViewerSession {}
        let networkMock = MockURLSession()
        session.api = api
        NoFollowRedirect.session = networkMock
        session.load(url: URL(string: "/")!, accessToken: "a")
        XCTAssertNotNil(networkMock.handler)

        let response = HTTPURLResponse(url: URL(string: "/")!, statusCode: 301, httpVersion: nil, headerFields: [
            "Location": "https://doc.viewer/1/session1/view?query",
        ])
        networkMock.handler?(nil, response, nil)
        XCTAssertEqual(session.sessionURL, URL(string: "https://doc.viewer/1/session1"))
    }

    func testLoadFailure() {
        let session = DocViewerSession {}
        let networkMock = MockURLSession()
        NoFollowRedirect.session = networkMock
        session.load(url: URL(string: "/")!, accessToken: "a")
        XCTAssertNotNil(networkMock.handler)

        let error = APIDocViewerError.noData
        networkMock.handler?(nil, nil, error)
        XCTAssertNotNil(session.error)
        XCTAssertNil(session.sessionURL)
    }

    func testLoadMetadata() {
        let notified = expectation(description: "notified")
        let sessionURL = URL(string: "https://doc.viewer/1/session1")!
        let metadata = APIDocViewerMetadata.make()
        let session = DocViewerSession { notified.fulfill() }
        session.api = api
        api.mock(GetDocViewerMetadataRequest(path: sessionURL.absoluteString), value: metadata)
        session.loadMetadata(sessionURL: sessionURL)
        wait(for: [notified], timeout: 1)
        XCTAssertNil(session.error)
        XCTAssertEqual(session.metadata, metadata)
        XCTAssertEqual(session.remoteURL, URL(string: "download", relativeTo: sessionURL))
    }

    func testLoadMetadataFailure() {
        let notified = expectation(description: "notified")
        let sessionURL = URL(string: "https://doc.viewer/1/session1")!
        let session = DocViewerSession { notified.fulfill() }
        session.api = api
        api.mock(GetDocViewerMetadataRequest(path: sessionURL.absoluteString), error: APIDocViewerError.noData)
        session.loadMetadata(sessionURL: sessionURL)
        wait(for: [notified], timeout: 1)
        XCTAssertNotNil(session.error)
        XCTAssertNil(session.metadata)
        XCTAssertNil(session.remoteURL)
    }

    func testLoadAnnotations() {
        let session = DocViewerSession { XCTFail("Must not notify") }
        session.api = api
        session.metadata = .make()
        api.mock(GetDocViewerAnnotationsRequest(sessionID: ""), value: APIDocViewerAnnotations(data: [.make()]))
        session.loadAnnotations()
        XCTAssertEqual(session.annotations?.count, 1)
    }

    func testLoadAnnotationsAfterDoc() {
        let notified = expectation(description: "notified")
        let session = DocViewerSession { notified.fulfill() }
        session.api = api
        session.metadata = .make()
        session.localURL = URL(string: "download")
        session.loadAnnotations()
        wait(for: [notified], timeout: 1)
        XCTAssertEqual(session.annotations?.count, 0)
    }

    func testLoadAnnotationsAfterError() {
        let notified = expectation(description: "notified")
        let session = DocViewerSession { notified.fulfill() }
        session.api = api
        session.metadata = .make()
        session.error = APIDocViewerError.noData
        session.loadAnnotations()
        wait(for: [notified], timeout: 1)
        XCTAssertEqual(session.annotations?.count, 0)
    }

    func testLoadAnnotationsWithoutMeta() {
        let session = DocViewerSession {}
        session.loadAnnotations()
        XCTAssertEqual(session.annotations?.count, 0)
    }

    func testLoadDocument() {
        let downloadURL = URL(string: "download")!
        let tempURL = Bundle(for: DocViewerSessionTests.self).url(forResource: "instructure", withExtension: "pdf")!
        let notified = expectation(description: "notified")
        let session = DocViewerSession { notified.fulfill() }
        session.annotations = []
        session.api = api
        api.mockDownload(downloadURL, value: tempURL)
        session.loadDocument(downloadURL: downloadURL)
        XCTAssertEqual(session.remoteURL, downloadURL)
        wait(for: [notified], timeout: 1)
        XCTAssertNotNil(session.localURL)
    }

    func testLoadDocumentFailure() {
        let downloadURL = URL(string: "download")!
        let session = DocViewerSession { XCTFail("Must not notify without annotations set") }
        session.api = api
        api.mockDownload(downloadURL, error: APIDocViewerError.noData)
        session.loadDocument(downloadURL: downloadURL)
        XCTAssertEqual(session.remoteURL, downloadURL)
        XCTAssertNotNil(session.error)
    }
}

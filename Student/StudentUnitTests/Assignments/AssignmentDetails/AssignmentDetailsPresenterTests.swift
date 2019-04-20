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
@testable import Student
@testable import Core
import SafariServices
import TestsFoundation

class AssignmentDetailsPresenterTests: PersistenceTestCase {

    var resultingError: NSError?
    var resultingAssignment: AssignmentDetailsViewModel?
    var resultingBaseURL: URL?
    var resultingSubtitle: String?
    var resultingBackgroundColor: UIColor?
    var resultingSubmissionTypes: [SubmissionType]?
    var presenter: AssignmentDetailsPresenter!
    var expectation = XCTestExpectation(description: "expectation")
    var resultingButtonTitle: String?
    var navigationController: UINavigationController?
    var presentedViewController: UIViewController?
    var dismissedCount = 0
    let fileUploader = MockFileUploader()

    override func setUp() {
        super.setUp()
        expectation = XCTestExpectation(description: "expectation")
        presenter = AssignmentDetailsPresenter(env: env, view: self, courseID: "1", assignmentID: "1", fragment: "target")
        presenter.fileUploader = fileUploader
    }

    func testLoadCourse() {
        //  given
        Assignment.make()
        let c = Course.make()
        Color.make(["canvasContextID": c.canvasContextID])

        presenter.viewIsReady()
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(resultingSubtitle, c.name)
        XCTAssertEqual(resultingBackgroundColor, UIColor.red)
    }

    func testLoadAssignment() {
        //  given
        Course.make()
        let expected = Assignment.make([ "submission": Submission.make() ])

        //  when
        presenter.viewIsReady()
        wait(for: [expectation], timeout: 1)
        //  then
        XCTAssert(resultingAssignment as! Assignment === expected)
        XCTAssertEqual(presenter!.userID!, expected.submission!.userID)
    }

    func testBaseURLWithNilFragment() {
        let expected = URL(string: "https://canvas.instructure.com/courses/1/assignments/1")!
        Assignment.make(["htmlURL": expected])
        Course.make()
        presenter = AssignmentDetailsPresenter(env: env, view: self, courseID: "1", assignmentID: "1", fragment: nil)

        presenter.viewIsReady()
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(resultingBaseURL, expected)
    }

    func testBaseURLWithFragment() {
        let url = URL(string: "https://canvas.instructure.com/courses/1/assignments/1")!
        let fragment = "fragment"
        Assignment.make(["htmlURL": url])
        Course.make()
        let expected = URL(string: "https://canvas.instructure.com/courses/1/assignments/1#fragment")!

        presenter = AssignmentDetailsPresenter(env: env, view: self, courseID: "1", assignmentID: "1", fragment: fragment)

        presenter.viewIsReady()
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(resultingBaseURL?.absoluteString, expected.absoluteString)
    }

    func testBaseURLWithEmptyFragment() {
        let expected = URL(string: "https://canvas.instructure.com/courses/1/assignments/1")!
        let fragment = ""
        Assignment.make(["htmlURL": expected])
        Course.make()
        presenter = AssignmentDetailsPresenter(env: env, view: self, courseID: "1", assignmentID: "1", fragment: fragment)

        presenter.viewIsReady()
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(resultingBaseURL?.absoluteString, expected.absoluteString)
    }

    func testUseCaseFetchesData() {
        //  given
        Course.make()
        let expected = Assignment.make()

        presenter.viewIsReady()
        wait(for: [expectation], timeout: 1)

        //  then
        XCTAssertEqual(resultingAssignment?.name, expected.name)
    }

    func testRoutesToSubmission() {
        Course.make()
        Assignment.make([ "id": "1", "submission": Submission.make([ "userID": "2" ]) ])

        presenter.viewIsReady()
        wait(for: [expectation], timeout: 1)

        let router = env.router as? TestRouter

        presenter.routeToSubmission(view: UIViewController())
        XCTAssertEqual(router?.calls.last?.0, .parse("/courses/1/assignments/1/submissions/2"))
    }

    func testRoute() {
        let url = URL(string: "somewhere")!
        let controller = UIViewController()
        let router = env.router as? TestRouter
        XCTAssertTrue(presenter.route(to: url, from: controller))
        XCTAssertEqual(router?.calls.last?.0, .parse(url))
    }

    func testRouteFile() {
        let url = URL(string: "/course/1/files/2")!
        let controller = UIViewController()
        let router = env.router as? TestRouter
        XCTAssertTrue(presenter.route(to: url, from: controller))
        XCTAssertEqual(router?.calls.last?.0, .parse("/course/1/files/2?courseID=1&assignmentID=1"))
    }

    func testAssignmentAsAssignmentDetailsViewModel() {
        let assignment: AssignmentDetailsViewModel = Assignment.make([
            "submission": Submission.make(["scoreRaw": 100, "grade": "A"]),
        ])
        XCTAssertEqual(assignment.viewableScore, 100)
        XCTAssertEqual(assignment.viewableGrade, "A")
    }

    func testShowSubmitAssignmentButton() {
        //  given
        let a = Assignment.make([
            "submission": Submission.make(["workflowStateRaw": "unsubmitted"]),
        ])
        a.unlockAt = Date().addDays(-1)
        a.lockAt = Date().addDays(1)
        a.lockedForUser = false
        a.submissionTypes = [.online_upload]

        let c = Course.make(["enrollments": Set([Enrollment.make()])])

        //  when
        presenter.showSubmitAssignmentButton(assignment: a, course: c)

        //  then
        XCTAssertEqual(resultingButtonTitle, "Submit Assignment")
    }

    func testShowSubmitAssignmentButtonMultipleAttempts() {
        //  given
        let a = Assignment.make([
            "submission": Submission.make(["workflowStateRaw": "submitted"]),
        ])
        a.unlockAt = Date().addDays(-1)
        a.lockAt = Date().addDays(1)
        a.lockedForUser = false
        a.submissionTypes = [.online_upload]

        let c = Course.make(["enrollments": Set([Enrollment.make()])])

        //  when
        presenter.showSubmitAssignmentButton(assignment: a, course: c)

        //  then
        XCTAssertEqual(resultingButtonTitle, "Resubmit Assignment")
    }

    func testShowSubmitAssignmentButtonExternalTool() {
        let a = Assignment.make()
        a.submissionTypes = [.external_tool]

        let c = Course.make(["enrollments": Set([Enrollment.make()])])

        presenter.showSubmitAssignmentButton(assignment: a, course: c)
        XCTAssertEqual(resultingButtonTitle, "Launch External Tool")
    }

    func testSubmitOnlineUpload() {
        Assignment.make(["id": "1"])
        presenter.submit(.online_upload, from: UIViewController())
        let nav = presentedViewController as? UINavigationController
        let filePicker = nav?.topViewController as? FilePickerViewController
        XCTAssertNotNil(filePicker)
    }

    func testSubmitOnlineURL() {
        Assignment.make(["id": "1"])

        presenter.submit(.online_url, from: UIViewController())

        XCTAssert(router.lastRoutedTo(.assignmentUrlSubmission(courseID: "1", assignmentID: "1", userID: "")))
    }

    func testSubmitAssignmentAutomaticallyDoesOnlySubmissionType() {
        let assignment = Assignment.make(["id": "1"])
        assignment.submissionTypes = [.online_text_entry]

        let expectation = BlockExpectation(description: "main queue") {
            return self.router.lastRoutedTo(.assignmentTextSubmission(courseID: assignment.courseID, assignmentID: "1", userID: ""))
        }

        presenter.viewIsReady()
        let viewController = UIViewController()
        presenter.submitAssignment(from: viewController)

        wait(for: [expectation], timeout: 5)
    }

    func testSubmitAssignmentSendsBackSupportedSubmissionTypes() {
        let assignment = Assignment.make(["id": "1"])
        assignment.submissionTypes = [.online_upload, .online_url]

        presenter.viewIsReady()
        let viewController = UIViewController()
        presenter.submitAssignment(from: viewController)

        XCTAssertEqual(resultingSubmissionTypes, [.online_upload, .online_url])
    }

    func testViewFileSubmission() {
        Assignment.make(["id": "1"])

        presenter.viewFileSubmission(from: UIViewController())

        let nav = presentedViewController as? UINavigationController
        let filePicker = nav?.topViewController as? FilePickerViewController
        XCTAssertNotNil(filePicker)
    }

    func testExternalToolSubmission() {
        Assignment.make(["id": "1", "courseID": "1"])
        let request = GetSessionlessLaunchURLRequest(context: ContextModel(.course, id: "1"), id: nil, url: nil, assignmentID: "1", moduleItemID: nil, launchType: .assessment)
        api.mock(request, value: APIGetSessionlessLaunchResponse(id: "", name: "", url: URL(string: "https://instructure.com")!))
        let openedSFSafariViewController = XCTestExpectation(description: "opened")
        presenter.submit(.external_tool, from: UIViewController()) {
            openedSFSafariViewController.fulfill()
        }
        wait(for: [openedSFSafariViewController], timeout: 1)
        XCTAssert(router.viewControllerCalls[0].0 is SFSafariViewController)
    }

    func testAddFilePicker() {
        let filePicker = FilePickerViewController.create()
        let url = URL(fileURLWithPath: "/file.txt")
        presenter.add(filePicker, url: url)
        XCTAssertEqual(presenter.files.count, 1)
    }

    func testCancelFilePicker() {
        let filePicker = FilePickerViewController.create()
        let url = URL(fileURLWithPath: "/file.txt")
        presenter.add(filePicker, url: url)
        presenter.cancel(filePicker)
        XCTAssertEqual(presenter.files.count, 0)
        XCTAssertEqual(dismissedCount, 1)
        XCTAssertEqual(fileUploader.cancels.count, 1)
    }

    func testSubmitFilePicker() {
        let filePicker = FilePickerViewController.create()
        let url = URL(fileURLWithPath: "/file.txt")
        presenter.add(filePicker, url: url)
        presenter.submit(filePicker)
        XCTAssertEqual(dismissedCount, 1)
        XCTAssertEqual(fileUploader.uploads.count, 1)
    }

    func testCanSubmitFilePicker() {
        let filePicker = FilePickerViewController.create()
        XCTAssertFalse(presenter.canSubmit(filePicker))
        let url = URL(fileURLWithPath: "/file.txt")
        presenter.add(filePicker, url: url)
        XCTAssertTrue(presenter.canSubmit(filePicker))
    }
}

extension AssignmentDetailsPresenterTests: AssignmentDetailsViewProtocol {
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        completion?()
        presentedViewController = viewControllerToPresent
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        completion?()
        dismissedCount += 1
    }

    func showSubmitAssignmentButton(title: String?) {
        resultingButtonTitle = title
    }

    func chooseSubmissionType(_ types: [SubmissionType]) {
        resultingSubmissionTypes = types
    }

    func update(assignment: AssignmentDetailsViewModel, baseURL: URL?) {
        resultingAssignment = assignment
        resultingBaseURL = baseURL
        expectation.fulfill()
    }

    func showError(_ error: Error) {
        resultingError = error as NSError
    }

    func updateNavBar(subtitle: String?, backgroundColor: UIColor?) {
        resultingSubtitle = subtitle
        resultingBackgroundColor = backgroundColor
    }
}

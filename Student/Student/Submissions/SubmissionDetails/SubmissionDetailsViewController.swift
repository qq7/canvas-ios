//
// Copyright (C) 2018-present Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit
import Core

class SubmissionDetailsViewController: UIViewController, SubmissionDetailsViewProtocol {
    var color: UIColor?
    var presenter: SubmissionDetailsPresenter?
    var titleSubtitleView = TitleSubtitleView.create()
    var contentViewController: UIViewController?
    var drawerContentViewController: UIViewController?
    var env: AppEnvironment?

    @IBOutlet weak var contentView: UIView?
    @IBOutlet weak var drawer: Drawer?
    @IBOutlet weak var emptyView: SubmissionDetailsEmptyView?
    @IBOutlet weak var pickerButton: DynamicButton?
    @IBOutlet weak var pickerButtonArrow: IconView?
    @IBOutlet weak var pickerButtonDivider: DividerView?
    @IBOutlet weak var picker: UIPickerView?

    static func create(env: AppEnvironment = .shared, context: Context, assignmentID: String, userID: String) -> SubmissionDetailsViewController {
        let controller = loadFromStoryboard()
        controller.presenter = SubmissionDetailsPresenter(env: env, view: controller, context: context, assignmentID: assignmentID, userID: userID)
        controller.env = env
        return controller
    }

    override func viewDidLoad() {
        setupTitleViewInNavbar(title: NSLocalizedString("Submission", bundle: .student, comment: ""))
        drawer?.tabs?.addTarget(self, action: #selector(drawerTabChanged), for: .valueChanged)
        picker?.dataSource = self
        picker?.delegate = self
        presenter?.viewIsReady()
    }

    func reload() {
        guard let presenter = presenter, let assignment = presenter.currentAssignment else {
            return
        }
        picker?.reloadAllComponents()

        let submission = presenter.currentSubmission

        let isSubmitted = submission?.workflowState != .unsubmitted
        contentView?.isHidden = !isSubmitted && !assignment.isExternalToolAssignment
        drawer?.fileCount = submission?.attachments?.count ?? 0
        emptyView?.isHidden = isSubmitted || assignment.isExternalToolAssignment
        emptyView?.dueText = assignment.assignmentDueByText
        pickerButton?.isHidden = !isSubmitted
        if let submittedAt = submission?.submittedAt {
            pickerButton?.setTitle(DateFormatter.localizedString(from: submittedAt, dateStyle: .medium, timeStyle: .short), for: .normal)
        }
        pickerButton?.isEnabled = presenter.submissions.count > 1
        pickerButtonArrow?.isHidden = !isSubmitted || presenter.submissions.count <= 1
        pickerButtonDivider?.isHidden = !isSubmitted
        if presenter.submissions.count <= 1 || assignment.isExternalToolAssignment {
            picker?.isHidden = true
        }
    }

    func reloadNavBar() {
        guard let assignment = presenter?.assignment.first, let course = presenter?.course.first else {
            return
        }
        self.updateNavBar(subtitle: assignment.name, color: course.color)
    }

    func embed(_ controller: UIViewController?) {
        if let old = contentViewController {
            navigationItem.rightBarButtonItems = []
            old.unembed()
        }

        contentViewController = controller
        guard let contentView = contentView, let controller = contentViewController else { return }

        embed(controller, in: contentView)
    }

    func embedInDrawer(_ controller: UIViewController?) {
        if let old = drawerContentViewController {
            old.unembed()
        }

        drawerContentViewController = controller
        guard let contentView = drawer?.contentView, let controller = drawerContentViewController else { return }

        embed(controller, in: contentView)
    }

    @IBAction func drawerTabChanged(_ sender: UISegmentedControl) {
        presenter?.select(drawerTab: Drawer.Tab(rawValue: sender.selectedSegmentIndex))
        if let drawer = drawer, drawer.height == 0 {
            drawer.moveTo(height: drawer.midDrawerHeight, velocity: 1)
        }
    }

    @IBAction func pickerButtonTapped(_ sender: Any) {
        picker?.isHidden = picker?.isHidden == false
        if picker?.isHidden == true {
            pickerButton?.tintColor = .named(.textDark)
            pickerButtonArrow?.tintColor = .named(.textDark)
            pickerButtonArrow?.image = .icon(.miniArrowDown, .solid)
        } else {
            pickerButton?.tintColor = Brand.shared.buttonPrimaryBackground
            pickerButtonArrow?.tintColor = Brand.shared.buttonPrimaryBackground
            pickerButtonArrow?.image = .icon(.miniArrowUp, .solid)
        }
    }
}

extension SubmissionDetailsViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return presenter?.submissions.count ?? 0
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard let submittedAt = presenter?.submissions[row]?.submittedAt else {
            return NSLocalizedString("No Submission Date", bundle: .student, comment: "")
        }
        return DateFormatter.localizedString(from: submittedAt, dateStyle: .medium, timeStyle: .short)
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let attempt = presenter?.submissions[row]?.attempt else { return }
        presenter?.select(attempt: attempt)
    }
}

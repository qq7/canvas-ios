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

// https://canvas.instructure.com/doc/api/submissions.html#Submission
public struct APISubmission: Codable, Equatable {
    let id: ID
    let assignment_id: ID
    let user_id: ID
    let body: String?
    let grade: String?
    let score: Double?
    let submission_type: SubmissionType?
    let submitted_at: Date?
    let late: Bool
    let excused: Bool?
    let missing: Bool
    let workflow_state: SubmissionWorkflowState
    let attempt: Int?
    let attachments: [APIFile]?
    let discussion_entries: [APIDiscussionEntry]?
    let preview_url: URL?
    let url: URL?
    let media_comment: APIMediaComment?

    // late policies
    let late_policy_status: LatePolicyStatus?
    let points_deducted: Double?

    let submission_comments: [APISubmissionComment]? // include[]=submission_comments
    let submission_history: [APISubmission]? // include[]=submission_history
    var user: APISubmissionUser? // include[]=user
}

public struct APISubmissionUser: Codable, Equatable {
    let id: String
    let name: String?
    let short_name: String
    let avatar_url: URL?
}

// https://canvas.instructure.com/doc/api/submissions.html#SubmissionComment
public struct APISubmissionComment: Codable, Equatable {
    let id: String
    let author_id: String
    let author_name: String
    let author: APISubmissionCommentAuthor
    let comment: String
    let created_at: Date
    let edited_at: Date?
    let media_comment: APISubmissionCommentMedia?
}

public struct APISubmissionCommentAuthor: Codable, Equatable {
    let id: String
    let display_name: String
    let avatar_image_url: URL?
    let html_url: URL
}

public struct APISubmissionCommentMedia: Codable, Equatable {
    let url: URL
    let media_id: String
    let media_type: MediaCommentType
    let display_name: String?
}

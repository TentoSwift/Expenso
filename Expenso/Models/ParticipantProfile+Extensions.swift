//
//  ParticipantProfile+Extensions.swift
//  Expenso
//

import Foundation
import CoreData
import SwiftUI

extension ParticipantProfile {
    /// 安定識別子。常に CK userRecordName と同じ。
    var profileID: String { recordName ?? "" }

    var displayNameOrEmpty: String { displayName ?? "" }
    var displayColorHex: String { colorHex ?? "#8E8E93" }
}

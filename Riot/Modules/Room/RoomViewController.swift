// 
// Copyright 2022 New Vector Ltd
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

import UIKit

extension RoomViewController {
    open override func mention(_ roomMember: MXRoomMember) {
        guard #available(iOS 15.0, *),
              let inputToolbar = inputToolbarView as? RoomInputToolbarView,
              let permalink = URL(string: MXTools.permalinkToUser(withUserId: roomMember.userId)) else {
            super.mention(roomMember)
            return
        }

        let newAttributedString = NSMutableAttributedString(attributedString: inputToolbar.attributedTextMessage)

        if inputToolbar.attributedTextMessage.length > 0 {
            newAttributedString.append(StringPillsUtils.mentionPill(withRoomMember: roomMember,
                                                                    andUrl: permalink,
                                                                    isCurrentUser: false))
            let empty = NSAttributedString(string: " ",
                                           attributes: [.font: inputToolbar.textDefaultFont ?? ThemeService.shared().theme.fonts.body])
            newAttributedString.append(empty)
        } else if roomMember.userId == self.mainSession.myUser.userId {
            let selfMentionString = NSAttributedString(string: "/me",
                                                       attributes: [.font: inputToolbar.textDefaultFont ?? ThemeService.shared().theme.fonts.body])
            newAttributedString.append(selfMentionString)
        } else {
            newAttributedString.append(StringPillsUtils.mentionPill(withRoomMember: roomMember,
                                                                    andUrl: permalink,
                                                                    isCurrentUser: false))
            let colon = NSAttributedString(string: ": ",
                                           attributes: [.font: inputToolbar.textDefaultFont ?? ThemeService.shared().theme.fonts.body])
            newAttributedString.append(colon)
        }

        inputToolbar.attributedTextMessage = newAttributedString
        inputToolbar.becomeFirstResponder()
    }

    @objc func sendAttributedTextMessage(_ attributedTextMsg: NSAttributedString) {
        let eventModified = self.roomDataSource.event(withEventId: customizedRoomDataSource?.selectedEventId)
        self.setupRoomDataSource { roomDataSource in
            guard let roomDataSource = roomDataSource as? RoomDataSource else { return }

            if self.inputToolbar?.sendMode == RoomInputToolbarViewSendModeReply, let eventModified = eventModified {
                roomDataSource.sendReply(to: eventModified,
                                         withAttributedTextMessage: attributedTextMsg) { response in
                    switch response {
                    case .success:
                        break
                    case .failure:
                        MXLog.error("[RoomViewController] sendAttributedTextMessage failed while updating event: \(eventModified.eventId ?? "N/A")")
                    }
                }
            } else if self.inputToolbar?.sendMode == RoomInputToolbarViewSendModeEdit, let eventModified = eventModified {
                roomDataSource.replaceAttributedTextMessage(
                    for: eventModified,
                    withAttributedTextMessage: attributedTextMsg,
                    success: { _ in
                        //
                    },
                    failure: { _ in
                        MXLog.error("[RoomViewController] sendAttributedTextMessage failed while updating event: \(eventModified.eventId ?? "N/A")")
                })
            } else {
                roomDataSource.sendAttributedTextMessage(attributedTextMsg) { response in
                    switch response {
                    case .success:
                        break
                    case .failure:
                        MXLog.error("[RoomViewController] sendAttributedTextMessage failed")
                    }
                }
            }

            if self.customizedRoomDataSource?.selectedEventId != nil {
                self.cancelEventSelection()
            }
        }
    }
}

private extension RoomViewController {
    var inputToolbar: RoomInputToolbarView? {
        return self.inputToolbarView as? RoomInputToolbarView
    }
}

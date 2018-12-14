import Foundation
import Messages

class MessagesViewController: MSMessagesAppViewController {
  @IBAction func sendMessage() {
    self.activeConversation?.sendText("Hello, extension!", completionHandler: nil)
  }
}



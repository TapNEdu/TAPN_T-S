import Foundation
import CoreNFC
import SwiftUI

final class NFCManager: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    static let shared = NFCManager()

    var onTag: ((String) -> Void)?

    private var session: NFCNDEFReaderSession?

    func beginScan(simulated: Bool = false) {
        #if targetEnvironment(simulator)
        simulateTag()
        #else
        if simulated {
            simulateTag()
            return
        }

        guard NFCNDEFReaderSession.readingAvailable else {
            print("NFC not supported or missing entitlement")
            return
        }

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold your iPhone near your TAP-IN tag."
        session?.begin()
        print("NFC scanning started")
        #endif
    }

    private func simulateTag() {
        print("Simulating tag scan...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Simulated tag detected")
            self.onTag?("Simulated")
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("NFC session invalidated:", error.localizedDescription)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("NDEF messages found:", messages)
        DispatchQueue.main.async {
            self.onTag?("Detected")
        }
    }
}

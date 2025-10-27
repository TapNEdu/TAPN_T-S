import Foundation
import CoreNFC
import SwiftUI



final class NFCManager: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    static let shared = NFCManager()

    var onTag: ((String) -> Void)?
    var onWriteComplete: ((Bool, String?) -> Void)?

    private var session: NFCNDEFReaderSession?
    private var isWriting = false
    private var dataToWrite: String?

    func beginScan(simulated: Bool = false) {
        print("📖 READING: Starting NFC read scan...")
        isWriting = false
        
        #if targetEnvironment(simulator)
        print("📱 Running in simulator - using simulation")
        simulateTag()
        #else
        if simulated {
            print("📱 Using simulation mode")
            simulateTag()
            return
        }

        guard NFCNDEFReaderSession.readingAvailable else {
            print("❌ NFC not supported or missing entitlement")
            return
        }

        print("📖 READING: Starting real NFC read scan")
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near your TAP-IN tag."
        print("📖 READING: About to call session.begin()...")
        session?.begin()
        print("📖 READING: NFC read scanning started - session should be active now")
        #endif
    }

    private func simulateTag() {
        print("🎭 Simulating tag scan...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("✅ Simulated tag detected")

            // Try to get the first active class from AppState for simulation
            // Otherwise use a placeholder UUID
            let simulatedClassID: String
            if let firstClass = AppState.shared.classes.first(where: { $0.isActive }) {
                simulatedClassID = firstClass.id.uuidString
                print("📝 Simulated class ID from active class: \(simulatedClassID)")
            } else if let firstClass = AppState.shared.classes.first {
                simulatedClassID = firstClass.id.uuidString
                print("📝 Simulated class ID from first class: \(simulatedClassID)")
            } else {
                // Fallback to a valid UUID format
                simulatedClassID = "00000000-0000-0000-0000-000000000000"
                print("📝 Simulated class ID (placeholder): \(simulatedClassID)")
            }

            self.onTag?(simulatedClassID)
        }
    }

    
    // MARK: - NFC Writing Functions
    
    func writeToTag(data: String, simulated: Bool = false) {
        print("📝 WRITING: Starting NFC write operation with data: \(data)")
        isWriting = true
        dataToWrite = data
        
        #if targetEnvironment(simulator)
        simulateWrite(data: data)
        #else
        if simulated {
            simulateWrite(data: data)
            return
        }
        
        guard NFCNDEFReaderSession.readingAvailable else {
            print("❌ WRITING: NFC not supported or missing entitlement")
            DispatchQueue.main.async {
                self.onWriteComplete?(false, "NFC not supported")
            }
            return
        }
        
        print("📝 WRITING: Creating NFC write session...")
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the NFC tag to write data."
        session?.begin()
        print("📝 WRITING: NFC writing started - hold phone near writable NFC tag")
        print("📝 WRITING: Session created, waiting for tag detection...")
        #endif
    }
    
    private func simulateWrite(data: String) {
        print("Simulating tag write with data: \(data)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Simulated write completed")
            self.onWriteComplete?(true, "Write simulated successfully")
        }
    }
    
    // MARK: - NFC Delegate Methods
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if isWriting {
            print("📝 WRITING: NFC write session invalidated:", error.localizedDescription)
        } else {
            print("📖 READING: NFC read session invalidated:", error.localizedDescription)
        }
        
        // Check if it's a user cancellation (not an error)
        if let nfcError = error as? NFCReaderError {
            switch nfcError.code {
            case .readerSessionInvalidationErrorUserCanceled:
                print("User canceled NFC session")
            default:
                print("NFC error:", nfcError.localizedDescription)
            }
        }
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        if isWriting {
            print("📝 WRITING: NFC write session became active")
        } else {
            print("📖 READING: NFC read session became active")
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("🚨 didDetectNDEFs CALLED! 📖 READING: NDEF messages found:", messages)
        
        // Extract the class ID from the message
        var classID = "UNKNOWN"
        
        for message in messages {
            for record in message.records {
                if let payload = String(data: record.payload, encoding: .utf8) {
                    let cleanPayload = payload.trimmingCharacters(in: .controlCharacters)
                    print("📖 READING: Raw payload:", cleanPayload)
                    
                    // Check if it's a TAPN URI format
                    if cleanPayload.hasPrefix("tapn://class/") {
                        classID = String(cleanPayload.dropFirst("tapn://class/".count))
                        print("📖 READING: Class ID extracted from URI:", classID)
                    } else {
                        // Fallback: use the payload directly
                        classID = cleanPayload
                        print("📖 READING: Class ID extracted directly:", classID)
                    }
                    break
                }
            }
        }
        
        session.alertMessage = "Tag detected!"
        session.invalidate()
        
        DispatchQueue.main.async {
            self.onTag?(classID)
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        print("🚨 didDetect tags CALLED! with \(tags.count) tags")
        
        guard let tag = tags.first else {
            print("❌ No NFC tag detected")
            session.alertMessage = "No NFC tag detected. Try again."
            return
        }
        
        print("📱 Connecting to tag...")
        session.connect(to: tag) { error in
            if let error = error {
                print("❌ Connection failed: \(error.localizedDescription)")
                session.alertMessage = "Connection failed: \(error.localizedDescription)"
                session.invalidate()
                if self.isWriting {
                    DispatchQueue.main.async {
                        self.onWriteComplete?(false, error.localizedDescription)
                    }
                }
                return
            }
            
            print("✅ Connected to tag successfully")
            
            if self.isWriting {
                // WRITE MODE: Write data to tag
                self.writeToConnectedTag(tag: tag, session: session)
            } else {
                // READ MODE: Read data from tag
                self.readFromConnectedTag(tag: tag, session: session)
            }
        }
    }
    
    private func writeToConnectedTag(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        guard let dataToWrite = self.dataToWrite else {
            print("❌ WRITING: No data to write")
            session.alertMessage = "No data to write"
            session.invalidate()
            DispatchQueue.main.async {
                self.onWriteComplete?(false, "No data to write")
            }
            return
        }
        
        print("📝 Writing data: \(dataToWrite)")
        // Create a URI record that can be read by didDetectNDEFs
        let uriString = "tapn://class/\(dataToWrite)"
        let uriData = uriString.data(using: .utf8) ?? Data()
        let record = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: "U".data(using: .utf8)!, // URI type
            identifier: Data(),
            payload: uriData
        )
        
        let message = NFCNDEFMessage(records: [record])
        
        tag.writeNDEF(message) { error in
            if let error = error {
                print("❌ Write failed: \(error.localizedDescription)")
                session.alertMessage = "Write failed: \(error.localizedDescription)"
                session.invalidate()
                DispatchQueue.main.async {
                    self.onWriteComplete?(false, error.localizedDescription)
                }
            } else {
                print("✅ Write successful!")
                session.alertMessage = "Write successful!"
                session.invalidate()
                DispatchQueue.main.async {
                    self.onWriteComplete?(true, nil)
                }
            }
        }
    }
    
    private func readFromConnectedTag(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        print("📖 Reading from connected tag...")
        
        tag.readNDEF { message, error in
            if let error = error {
                print("❌ Read failed: \(error.localizedDescription)")
                session.alertMessage = "Read failed: \(error.localizedDescription)"
                session.invalidate()
                return
            }
            
            guard let message = message else {
                print("❌ No NDEF message found")
                session.alertMessage = "No NDEF message found"
                session.invalidate()
                return
            }
            
            print("📖 READ: NDEF message found:", message)
            
            // Extract the class ID from the message
            var classID = "UNKNOWN"
            
            for record in message.records {
                if let payload = String(data: record.payload, encoding: .utf8) {
                    let cleanPayload = payload.trimmingCharacters(in: .controlCharacters)
                    print("📖 READING: Raw payload:", cleanPayload)
                    
                    // Check if it's a TAPN URI format
                    if cleanPayload.hasPrefix("tapn://class/") {
                        classID = String(cleanPayload.dropFirst("tapn://class/".count))
                        print("📖 READING: Class ID extracted from URI:", classID)
                    } else {
                        // Fallback: use the payload directly
                        classID = cleanPayload
                        print("📖 READING: Class ID extracted directly:", classID)
                    }
                    break
                }
            }
            
            session.alertMessage = "Tag detected!"
            session.invalidate()
            
            DispatchQueue.main.async {
                self.onTag?(classID)
            }
        }
    }
    
}

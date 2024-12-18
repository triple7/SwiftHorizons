//
//  Untitled.swift
//  SwiftHorizons
//
//  Created by Yuma decaux on 8/12/2024.
//

import Foundation


extension SwiftHorizons: URLSessionDelegate {

    /** request returned data check
     */
    private func requestIsValid(error: Error?, response: URLResponse?, url: URL? = nil) -> Bool {
        var gotError = false
        if error != nil {
            self.sysLog.append(HorizonsSyslog(log: .RequestError, message: error!.localizedDescription))
            gotError = true
        }
        if (response as? HTTPURLResponse) == nil {
            self.sysLog.append(HorizonsSyslog(log: .RequestError, message: "response timed out"))
            gotError = true
        }
        let urlResponse = (response as! HTTPURLResponse)
        if urlResponse.statusCode != 200 {
            let error = NSError(domain: "com.error", code: urlResponse.statusCode)
            self.sysLog.append(HorizonsSyslog(log: .RequestError, message: error.localizedDescription))
            gotError = true
        }
        if !gotError {
            let message = url != nil ? url!.absoluteString : "data"
            self.sysLog.append(HorizonsSyslog(log: .OK, message: "\(message) downloaded"))
        }
        return !gotError
    }

    
    /** Wraps the full target list batch odwnload
     */
    public func downloadBatch(type: EphemType = .VECTORS, notify: Bool = true) {
        self.isProcessingBatch = true
        let tobatch = self.batch
        self.batch.removeAll()
        let batchCount = tobatch.count
        getBatchTargets(objects: tobatch, type: type, notify: notify, completion: { success in
            self.isProcessingBatch = false
            let msg = success ? "all \(batchCount) ephemerides downloaded" : "one or more failures, check logs"
            let log:HorizonsError = success ? .OK : .RequestError
            self.sysLog.append(HorizonsSyslog(log: log, message: msg))
        })
    }
    
    
    public      func getBatchTargets( objects: [HorizonsBatchObject], type: EphemType, notify: Bool=true, completion: @escaping (Bool)->Void ) {
        let serialQueue = DispatchQueue(label: "HorizonsDownloadQueue")
        
        var remainingObjects = objects
        
        // Create a recursive function to handle the download
        func downloadNextObject() {
            guard !remainingObjects.isEmpty else {
                // All objects have been downloaded, call the completion handler
                if notify {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: completedNotification, object: nil)
                    }
                }
                completion(true)
                return
            }
            
            let object = remainingObjects.removeFirst()
            var request = HorizonsRequest(target: object, parameters: type.defaultParameters)
            self.configureBatch(request: &request)
            
            let operation = DownloadOperation(session: URLSession.shared, dataTaskURL: request.getURL(), completionHandler: { (data, response, error) in
                if self.requestIsValid(error: error, response: response) {
                    let text = String(decoding: data!, as: UTF8.self)
                    if text.contains("No ephemeris for target"){
                        let result = self.rectifyDate(text)
                        if result == "FUTURE" {
                            self.sysLog.append(HorizonsSyslog(log: .FUTURE, message: "ephemerus is historical"))
                            if self.batch.isEmpty {
                                if notify {
                                    NotificationCenter.default.post(name: resetToEarthNotification, object: nil)
                                }
                            }
                        }
                    }
                    
                    let target = self.parseSingleTarget(name: object.name, id: object.id, objectType: object.objectType, parameters: request.parameters, text: text, type: type, notify)
                    self.targets[object.id] = target
                    self.downloaded.append(object)
                    self.sysLog.append(HorizonsSyslog(log: .OK, message: "ephemerus  \(object.id) \(object.type.id) downloaded"))
                    if notify {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: bodyLoadNotification, object: target)
                        }
                    }
                    
                    // Call the recursive function to download the next object
                    serialQueue.async {
                        if !self.batch.isEmpty {
                            for object in self.batch {
                                remainingObjects.insert(object, at: 0)
                            }
                        }
                        downloadNextObject()
                    }
                }
            })
            
            // Add the operation to the serial queue to execute it serially
            serialQueue.async {
                operation.start()
            }
        }

        // Add the operation to the serial queue to execute it serially
        serialQueue.async {
            downloadNextObject()
        }
                }
    
    public func getTarget(object: HorizonsBatchObject, type: EphemType, _ closure: @escaping (Bool)-> Void) {
        /** Gets a single target
         Adds a target into the targets dictionary and adds a response type for further processing
         Params:
         objectId: Horizons standard batch object
         type: ephemerus request type
         closure: whether async request is completed
         */
        let request = HorizonsRequest(target: object, parameters: type.defaultParameters)
        let configuration = URLSessionConfiguration.ephemeral
    let queue = OperationQueue.main
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        
        let task = session.dataTask(with: request.getURL()) { [weak self] data, response, error in
            if error != nil {
                self?.sysLog.append(HorizonsSyslog(log: .RequestError, message: error!.localizedDescription))
                closure(false)
                return
            }
            guard let response = response as? HTTPURLResponse else {
                self?.sysLog.append(HorizonsSyslog(log: .RequestError, message: "response timed out"))
                closure(false)
                return
            }
            if response.statusCode != 200 {
                let error = NSError(domain: "com.error", code: response.statusCode)
                self?.sysLog.append(HorizonsSyslog(log: .RequestError, message: error.localizedDescription))
                closure(false)
            }

            let text = String(decoding: data!, as: UTF8.self)
            let target = self?.parseSingleTarget(name: object.name, id: object.id, objectType: object.objectType, parameters: request.parameters, text: text, type: type)
            self?.targets[object.id] = target
            self?.sysLog.append(HorizonsSyslog(log: .OK, message: "ephemerus downloaded"))
        closure(true)
            return
    }
    task.resume()
    }

    fileprivate func rectifyDate(_ output: String)->String{
        var result = ""
        do{
            let pattern = try NSRegularExpression(pattern: "[0-9]+-[A-Za-z]+-[0-9]+ [0-9]+:[0-9]+", options: [])
            let match = pattern.firstMatch(in: output, options: [], range: NSRange(location: 0, length: output.count))?.range
            result = String(output[Range(match!, in: output)!])
        }catch{
            print("Error getting regular expression")
        }
        let dateFormat = DateFormatter()
        dateFormat.locale = Locale(identifier: "en_US_POSIX")
        dateFormat.timeZone = TimeZone(abbreviation: "UTC")
        dateFormat.dateFormat = "yyyy-MMM-dd HH:mm"
        let TimeNow = dateFormat.date(from: result)!
        let previous = Calendar.current.date(byAdding: .minute, value: -1, to: TimeNow)!
        let prev = dateFormat.string(from: previous)
        
        // check if date is in the future
        guard Date().timeIntervalSince(TimeNow) > 0 else {
            return "FUTURE"
        }
        return prev + ";" + result
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        expectedContentLength = Int(response.expectedContentLength)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer += data.count
        let percentageDownloaded = Float(buffer) / Float(expectedContentLength!)
           progress =  percentageDownloaded
    }

   
}

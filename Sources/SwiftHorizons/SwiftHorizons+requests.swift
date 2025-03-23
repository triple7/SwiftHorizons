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
    private func requestIsValid(message: String, error: Error?, response: URLResponse?) -> Bool {
        var gotError = false
        if error != nil {
            self.sysLog.append(HorizonsSyslog(log: .RequestError, message: error!.localizedDescription))
            gotError = true
        }
        if (response as? HTTPURLResponse) == nil {
            self.sysLog.append(HorizonsSyslog(log: .RequestError, message: "response timed out"))
            gotError = true
        }
        if let response = response {
            let urlResponse = (response as! HTTPURLResponse)
            if urlResponse.statusCode != 200 {
                let error = NSError(domain: "com.error", code: urlResponse.statusCode)
                self.sysLog.append(HorizonsSyslog(log: .RequestError, message: error.localizedDescription))
                gotError = true
            }
        } else {
            self.sysLog.append(HorizonsSyslog(log: .RequestError, message: "response timed out"))
            gotError = true
        }
        if !gotError {
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
            var request = HorizonsRequest(target: object, parameters: type.defaultParameters())
            if object.startTime == nil {
                // We are just taking the closest time to now
                self.configureBatch(request: &request)
            }
            let operation = DownloadOperation(session: URLSession.shared, dataTaskURL: request.getURL(stop: self.sampleTimeDays), completionHandler: { (data, response, error) in
                if self.requestIsValid(message: object.name, error: error, response: response) {
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
                    }else{
                        let target = self.parseSingleTarget(name: object.name, id: object.id, objectType: object.objectType, parent: object.parent, parameters: request.parameters, text: text, type: type, notify)
                        self.targets[object.id] = target
                        self.downloaded.append(object)
                        self.sysLog.append(HorizonsSyslog(log: .OK, message: "ephemerus  \(object.id) \(object.type.id) downloaded"))
                        if notify {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: bodyLoadNotification, object: (target, remainingObjects.count))
                            }
                        }
                    }
                    // Call the recursive function to download the next object
                    serialQueue.async {
                        if !self.batch.isEmpty {
                            for object in self.batch {
                                remainingObjects.insert(object, at: 0)
                            }
                            self.batch.removeAll()
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

    
    
    public func getBatchElements(objects: [HorizonsBatchObject], completion: @escaping ([String: TargetProperties]) -> Void) {
        print("getBatchElements: \(objects.count) targets")
        var remainingObjects = objects
        var elements = [String: TargetProperties]()

        func downloadNextObject() {
            guard !remainingObjects.isEmpty else {
                DispatchQueue.main.async {
                    completion(elements)
                }
                return
            }

            let object = remainingObjects.removeFirst()
            var request = HorizonsRequest(target: object, parameters: EphemType.ELEMENTS.defaultParameters(object.parentId!))
            if object.startTime == nil {
                // We are just taking the closest time to now
                self.configureBatch(request: &request)
            }

            let operation = DownloadOperation(
                
                session: URLSession.shared,
                dataTaskURL: request.getElementUrl(),
                completionHandler: { (data, response, error) in
                    if self.requestIsValid(message: object.name, error: error, response: response),
                       let data = data {
                        let text = String(decoding: data, as: UTF8.self)
                        let result = try! JSONDecoder().decode(HorizonsReturnJson.self, from: text.data(using: .utf8)!).result

                        let elementBlocks = self.getElementBlock(text: result)
                        if elementBlocks.last!.contains("No ephemeris for") {
                            let rectified = self.extractNewDate(text: elementBlocks.last!)
                            var newTarget = object
                            newTarget.setTime(start: rectified.start, stop: rectified.stop)
                            remainingObjects.insert(newTarget, at: 0)
                        } else {
                            let parsed = self.parseElements(result: text)
                            elements[String(object.id)] = parsed
                        }
                    }

                    // Continue with the next download
                    downloadNextObject()
                })

            // Start the download (which runs its own async network task)
            operation.start()
        }

        // Start downloading the first object
        downloadNextObject()
    }

    public func getMbList(_ closure: @escaping ([MB])-> Void) {
        /** Gets the updated list of MBs
         Params:
         closure: whether async request is completed
         */
        let request = HorizonsRequest()
        let configuration = URLSessionConfiguration.ephemeral
    let queue = OperationQueue.main
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        let task = session.dataTask(with: request.getMbRequestUrl()) { [weak self] data, response, error in
            if self!.requestIsValid(message: "MB list: ", error: error, response: response) {
                let mbList = try! JSONDecoder().decode(MBList.self, from: data!)
                let MBs = self!.parseMBList(payload: mbList)
                self?.sysLog.append(HorizonsSyslog(log: .OK, message: "MB list downloaded"))
                closure(MBs)
                return
            }
        }
    task.resume()
    }

    public func getTarget(object: HorizonsBatchObject, type: EphemType, _ closure: @escaping (Bool)-> Void) {
        /** Gets a single target
         Adds a target into the targets dictionary and adds a response type for further processing
         Params:
         objectId: Horizons standard batch object
         type: ephemerus request type
         closure: whether async request is completed
         */
        let request = HorizonsRequest(target: object, parameters: type.defaultParameters())
        let configuration = URLSessionConfiguration.ephemeral
    let queue = OperationQueue.main
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        
        let task = session.dataTask(with: request.getURL(stop: self.sampleTimeDays)) { [weak self] data, response, error in
            if self!.requestIsValid(message: "request \(type.id)", error: error, response: response) {
                let text = String(decoding: data!, as: UTF8.self)
                let target = self?.parseSingleTarget(name: object.name, id: object.id, objectType: object.objectType, parent: object.parent, parameters: request.parameters, text: text, type: type)
                self?.targets[object.id] = target
                self?.sysLog.append(HorizonsSyslog(log: .OK, message: "ephemerus downloaded"))
                closure(true)
                return
            }
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

import Foundation
import CoreLocation

public enum HorizonsError:Error {
    case NoSuchObject
    case noConnection
    case FUTURE
    case RequestError
    case OK
}

public struct HorizonsSyslog:CustomStringConvertible {
    let log:HorizonsError
    let message:String
    let timecode:String
    
    init( log: HorizonsError, message: String) {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy--MM-dd hh:mm:ss"
        self.timecode = dateFormatter.string(from: date)

        self.log = log
                  self.message = message
    }
    
    public var description:String {
        return "\(log): \(message)"
    }
}

public class SwiftHorizons:NSObject {
    /** Model holding all Horizons target network related processes including Url requests and returned data storage
     
     Horizons does not allow multiple requests or batch requests unless they are downloaded as a single file or emailed.
     For batch processing of objects, this class serially retrieves targets, and defaults to the sun, planets and satellites.
     properties:
     * targets: dictionary of targets with id as key and parameters as value
     * bufferlength: progressive size of download
     * progress: progress in percentage of download for a target
     * expectedContentLength: size in kbytes of data
     */
    public var targets:[String: HorizonsTarget]
    private lazy var batch:[HorizonsBatchObject] = {
        return [HorizonsBatchObject]()
    }()
    private lazy var downloaded:[HorizonsBatchObject] = {
        return [HorizonsBatchObject]()
    }()
    private var buffer:Int!
    public var progress:Float?
    private var expectedContentLength:Int?
    public var sysLog:[HorizonsSyslog]!
    public var location:CLLocation?
    private var retries:[HorizonsBatchObject: Int]
    private let maxRetries:Int = 3
    
    
    public override init() {
        self.targets = [String: HorizonsTarget]()
        self.buffer = 0
        self.sysLog = [HorizonsSyslog]()
         retries = [HorizonsBatchObject: Int]()
    }
    
    public func updateLocation( _ location: CLLocation) {
        self.location = location
    }
    
    public func addToBatch( _ batch: [HorizonsBatchObject]) {
        // Injects batch items at the start
        for object in batch {
            if !downloaded.contains(object) && !batch.contains(object) {
                self.batch.insert(object, at: 0)
            }
        }
    }
    
    public func printLogs() {
        for log in sysLog {
            print(log.description)
        }
    }

}

 extension SwiftHorizons: URLSessionDelegate {

     /** request returned data check
      */
     private func requestIsValid(error: Error?, response: URLResponse?, url: URL? = nil) -> Bool {
         var gotError = false
         if error != nil {
             print(error!.localizedDescription)
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

     public      func getBatchTargets( objects: [HorizonsBatchObject], type: EphemType, _ notify: Bool=true, completion: @escaping (Bool)->Void ) {
         let serialQueue = DispatchQueue(label: "HorizonsDownloadQueue")
         
         var remainingObjects = objects
         
         // Create a recursive function to handle the download
         func downloadNextObject() {
             guard !remainingObjects.isEmpty else {
                 // All objects have been downloaded, call the completion handler
                 if notify {
                     NotificationCenter.default.post(name: completedNotification, object: nil)
                 }
                 completion(true)
                 return
             }
         }
             
             let object = remainingObjects.removeFirst()
             let request = HorizonsRequest(target: object, parameters: type.defaultParameters)
             
         print("getting object: \(object)")
             let operation = DownloadOperation(session: URLSession.shared, dataTaskURL: request.getURL(), completionHandler: { (data, response, error) in
                 if self.requestIsValid(error: error, response: response) {
                     print("Good request")
                     let text = String(decoding: data!, as: UTF8.self)
                     print(text)
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
                     
                     let target = self.parseSingleTarget(id: object.id, parameters: request.parameters, text: text, type: type, notify)
                     self.targets[object.id] = target
                     self.sysLog.append(HorizonsSyslog(log: .OK, message: "ephemerus downloaded"))
                                                if notify {
                                 NotificationCenter.default.post(name: remainingNotification, object: (objects.count - 1))
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
             })

                     // Add the operation to the serial queue to execute it serially
                     serialQueue.async {
                         operation.start()
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
             let target = self?.parseSingleTarget(id: object.id, parameters: request.parameters, text: text, type: type)
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

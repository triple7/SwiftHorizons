import Foundation
import CoreLocation

public enum HorizonsError:Error {
    case NoSuchObject
    case RequestError
    case DataCorrupted
    case Ok
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
    private var buffer:Int!
    public var progress:Float?
    private var expectedContentLength:Int?
    public var sysLog:[HorizonsSyslog]!
    public var location:CLLocation?
    
    public override init() {
        self.targets = [String: HorizonsTarget]()
        self.buffer = 0
        self.sysLog = [HorizonsSyslog]()
    }
    
    public func updateLocation( _ locaiton: CLLocation) {
        self.location = locaiton
    }
    
    public func addToBatch( _ batch: [HorizonsBatchObject]) {
        // Injects batch items at the start
        self.batch = batch + self.batch
    }
    
    public func printLogs() {
        for log in sysLog {
            print(log.description)
        }
    }

}

 extension SwiftHorizons: URLSessionDelegate {

     public      func getBatchTargets( objects: [HorizonsBatchObject], type: EphemType, _ notifications: Bool=false, completion: @escaping (Bool)->Void ) {
         let serialQueue = DispatchQueue(label: "HorizonsDownloadQueue")
         
         var remainingObjects = objects
         
         // Create a recursive function to handle the download
         func downloadNextObject() {
             guard !remainingObjects.isEmpty else {
                 // All objects have been downloaded, call the completion handler
                 completion(true)
                 return
             }
         }
             
             let object = remainingObjects.removeFirst()
             let request = HorizonsRequest(target: object, parameters: type.defaultParameters)
             
             let operation = DownloadOperation(session: URLSession.shared, dataTaskURL: request.getURL(), completionHandler: { (data, response, error) in
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
                     let text = String(decoding: data!, as: UTF8.self)
                     let target = self.parseSingleTarget(id: object.id, parameters: request.parameters, text: text, type: type)
                     self.targets[object.id] = target
                     self.sysLog.append(HorizonsSyslog(log: .Ok, message: "ephemerus downloaded"))
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
             self?.sysLog.append(HorizonsSyslog(log: .Ok, message: "ephemerus downloaded"))
         closure(true)
             return
     }
     task.resume()
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

import Foundation

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
    private var buffer:Int!
    public var progress:Float?
    private var expectedContentLength:Int?
    public var sysLog:[HorizonsSyslog]!
    
    public override init() {
        self.targets = [String: HorizonsTarget]()
        self.buffer = 0
        self.sysLog = [HorizonsSyslog]()
    }
    
}

 extension SwiftHorizons: URLSessionDelegate {

     public      func getBatchTargets( objects: inout [String], type: EphemType, closure: @escaping (Bool)->Void ) {
         let serialGroup = DispatchGroup()
         while !objects.isEmpty {
             let targetID = objects.removeFirst()
             serialGroup.enter()
             getTarget(objectID: targetID, type: type, { success in
                 serialGroup.leave()
             })
         }
         serialGroup.notify(queue: .main) {
             
         }
     }
     
     public func getTarget(objectID: String, type: EphemType, _ closure: @escaping (Bool)-> Void) {
         /** Gets a single target
          Adds a target into the targets dictionary and adds a response type for further processing
          Params:
          objectId: Horizons standard object id
          type: ephemerus request type
          closure: whether request was successful
          */
         let request = HorizonsRequest(target: objectID, parameters: type.defaultParameters)
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
             let target = self?.parseSingleTarget(id: objectID, parameters: request.parameters, text: text, type: type)
             self?.targets[objectID] = target
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

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
     * firstTimeSamplingJD: uses local time snapshot for calculating new celestial positions
     * bufferlength: progressive size of download
     * progress: progress in percentage of download for a target
     * expectedContentLength: size in kbytes of data
     */
    public var targets:[String: HorizonsTarget]
    internal var firstTimeSamplingJD = true
    internal var snapShotToday:Date?
    internal var snapShotJDStart:Double?
    internal var local:CLLocation?

    
    internal lazy var batch:[HorizonsBatchObject] = {
        return [HorizonsBatchObject]()
    }()
    internal lazy var downloaded:[HorizonsBatchObject] = {
        return [HorizonsBatchObject]()
    }()
    internal var buffer:Int!
    public var progress:Float?
    internal var expectedContentLength:Int?
    
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

    
    public func configureBatch(request: inout HorizonsRequest,local: CLLocation){
        self.local = local
        let dateFormat = DateFormatter()
        dateFormat.timeZone = TimeZone(abbreviation: "UTC")
        dateFormat.dateFormat = "yyyy-MMM-dd HH:mm" //automatically converts from utc
        let TimeNow = getTDBtime(date: Date())
        
        let previous = Calendar.current.date(byAdding: .hour, value: 24, to: TimeNow)!
        let prevString = (Parameters.StartDate.format(dateFormat.string(from: previous))).components(separatedBy: "\n").first!
        
        request.setParameter(name: hp.STOP_TIME.id, value: "\(prevString)")
        request.setParameter(name: hp.START_TIME.id, value: Parameters.EndDate.format(dateFormat.string(from: TimeNow)).components(separatedBy: "\n").first!)
        // convert altitude from iOS in meters to km in Horizons
        let convertedAltitude = local.altitude/1000
        
        request.setParameter(name: hp.SITE_COORD.id, value: "\(local.coordinate.longitude),\(local.coordinate.latitude),\(convertedAltitude)")
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

 

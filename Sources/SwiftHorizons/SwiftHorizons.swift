import Foundation
import CoreLocation

public enum HorizonsError:Error {
    case NoSuchObject
    case noConnection
    case FUTURE
    case RequestError
    case OK
    case Warning
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
//        print("Horizons: \(log) \(message)")
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
    
    internal lazy var dateFormat:DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy-MMM-dd HH:mm" //automatically converts from utc
        return dateFormatter
    }()

    
    internal lazy var batch:[HorizonsBatchObject] = {
        return [HorizonsBatchObject]()
    }()
    internal lazy var downloaded:[HorizonsBatchObject] = {
        return [HorizonsBatchObject]()
    }()
    internal var isProcessingBatch = false
    internal var buffer:Int!
    public var progress:Float?
    internal var expectedContentLength:Int?
    
    public var sysLog:[HorizonsSyslog]!
    public var location:CLLocation?
    public var sampleTimeDays:Int = 1 // sample time is measured in days
    private var retries:[HorizonsBatchObject: Int]
    private let maxRetries:Int = 3
    
    
    public override init() {
        self.targets = [String: HorizonsTarget]()
        self.buffer = 0
        self.sysLog = [HorizonsSyslog]()
        retries = [HorizonsBatchObject: Int]()
    }

    public func convertToHorizonsDateFormat(date: Date) -> String {
        return dateFormat.string(from: date)
    }
    
    public func convertToHorizonsDateFormat(timestamp: String) -> String {
        let date = dateFormat.date(from: timestamp)!
        return dateFormat.string(from: date)
    }

    public func configureBatch(request: inout HorizonsRequest){

        let dateFormat = DateFormatter()
        dateFormat.timeZone = TimeZone(abbreviation: "UTC")
        dateFormat.dateFormat = "yyyy-MMM-dd HH:mm" //automatically converts from utc

        // Get current TDB time
        let currentTDBTime = getTDBtime(date: Date())
//        print("SwiftHorizons: Sampling data for \(self.sampleTimeDays) days")
        
        let stopTime = Calendar.current.date(byAdding: .day, value: self.sampleTimeDays, to: currentTDBTime)!
        
//        print("SwiftHorizons: currentTDBTime \(currentTDBTime)")
//        print("SwiftHorizons: stopTime \(stopTime)")
        
        // Format dates
        let stopTimeString = Parameters.EndDate
            .format(dateFormat.string(from: stopTime))
            .components(separatedBy: "\n")
            .first ?? ""
        
        let startTimeString = Parameters.StartDate
            .format(dateFormat.string(from: currentTDBTime))
            .components(separatedBy: "\n")
            .first ?? ""

//        print("SwiftHorizons: startTimeString: \(startTimeString)")
//        print("SwiftHorizons: stopTimeString: \(stopTimeString) ")
        
        request.setParameter(name: hp.STOP_TIME.id, value: stopTimeString)
        request.setParameter(name: hp.START_TIME.id, value: startTimeString)

        // convert altitude from iOS in meters to km in Horizons
        if let localCoordinate = local {
            let convertedAltitude = localCoordinate.altitude/1000
            
            request.setParameter(name: hp.SITE_COORD.id, value: "\(local!.coordinate.longitude),\(local!.coordinate.latitude),\(convertedAltitude)")
        }
    }

    public func getLocal() -> CLLocation {
        return self.local!
    }
    
    
    public func updateLocation( _ location: CLLocation?) {
        print("Updating location")
        self.local = location
    }
    
    public func addToBatch( _ objects: [HorizonsBatchObject], reorder: Bool = true) {
        // Injects batch items at the start
        for object in objects {
//            print(
//                "Adding \(object.name) parent \(object.parent) \(object.id)"
//            )
            if !downloaded.contains(object) && !batch.contains(object) {
                if reorder {
                    self.batch.insert(object, at: 0)
                } else {
                    self.batch.append(object)
                }
            }
        }
        if !isProcessingBatch {
            downloadBatch()
        }
    }
    
    public func printLogs() {
        for log in sysLog {
            print(log.description)
        }
    }

    public func addSyslog(message: String, logType: HorizonsError) {
        self.sysLog.append(HorizonsSyslog(log: logType, message: message))
    }
}

 

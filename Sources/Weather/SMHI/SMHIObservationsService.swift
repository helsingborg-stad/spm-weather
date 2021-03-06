//
//  File.swift
//  
//
//  Created by Tomas Green on 2021-10-01.
//

// https://opendata.smhi.se/apidocs/metobs/index.html
import Foundation
import Combine
import CoreLocation

let baseUrlString = "https://opendata-download-metobs.smhi.se/api/version/1.0"
let baseUrl = URL(string: baseUrlString)!

/// Errors for various failrues occuring though the SMHI Observations api
public enum SMHIObservationsErrors: Error {
    case unknown
    case missingResource
    case missingPeriod
    case missingPeriodData
    case missingStation
    case invalidNumberOfRowsInCSV
    case invalidStationDataInCSV
    case invalidPeriodDataInCSV
    case invalidParameterDataInCSV
    case invalidDateInCSV
}

/// Ussed for keeping track what of what field is being processed when decoding a CVS
enum CurrentlyProcessingCSVField {
    case station
    case parameter
    case period
    case data
}
/// Stores cancellables
var cancellables = Set<AnyCancellable>()

/// Calls upon the [SMHI Meterological Observaion API](https://opendata.smhi.se/apidocs/metobs/index.html)
public struct SMHIObservations {
    /// Describes a link to a resource
    public struct Link : Codable,Equatable {
        /// The relationship
        public let rel: String
        /// The resource value type, for example "application/json"
        public let type: String
        /// The resource URL
        public let href: URL
    }
    /// Describes a rsource in the METOBS api
    public struct Resource: Codable, Equatable {
        /// Describes a geographical bounding box
        public struct GeoBox: Codable, Equatable {
            /// Minimum latitude
            public let minLatitude:Double
            /// Minimum longitude
            public let minLongitude:Double
            /// Maximum latitude
            public let maxLatitude:Double
            /// Maximum longirude
            public let maxLongitude:Double
        }
        /// Geographical bounding box of the resrouce
        public let geoBox:GeoBox
        /// The key for the resource, typically an int
        public let key:String
        /// Last update
        public let updated:Date
        /// The name of the resource
        public let title:String
        /// Summary, or descripting of the values the resource holds
        public let summary:String
        /// Links to related assets
        public let link: [Link]
        /// Fetch-publisher of the first available json link
        public var jsonPublisher: AnyPublisher<Parameter,Error>  {
            guard let l = link.first(where: { $0.type == "application/json"}) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return URLSession.shared.dataTaskPublisher(for: l.href)
                .tryMap {$0.data}
                .decode(type: Parameter.self, decoder: decoder)
                .eraseToAnyPublisher()
        }
    }
    /// The root of the api
    public struct Service : Codable, Equatable {
        /// The key or version used when fetching api values
        public let key:String
        /// Last updated
        public let updated:Date
        /// The title of the service
        public let title:String
        /// Further description of the service
        public let summary:String
        /// Links to related assets
        public let link: [Link]
        /// Service resources
        public let resource: [Resource]
        /// Fetch-publusher using the `baseUrlString` to call upon the api
        public static var jsonPublisher: AnyPublisher<Service,Error>  {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            guard let url = URL(string: "\(baseUrlString).json") else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            return URLSession.shared.dataTaskPublisher(for: url)
                .tryMap {$0.data}
                .decode(type: Service.self, decoder: decoder)
                .eraseToAnyPublisher()
        }
    }
    /// Describes a weather station
    public struct Station : Codable, Equatable {
        /// The name of the station
        public let name: String
        /// The station owner, for exampel "SMHI"
        public let owner: String
        /// The station owner category, for example "SMHI"
        public let ownerCategory: String
        /// The station id
        public let id: Int
        /// Height above sea level (probably meters?)
        public let height: Double
        /// The center latitude of the station
        public let latitude: Double
        /// The center longitude of the station
        public let longitude: Double
        /// Describes whether or not the station is active
        public let active: Bool
        /// Active from data
        public let from: Date
        /// Active to data
        public let to: Date
        /// The key for the station, typically a string representation of the id
        public let key: String
        /// Last updated
        public let updated: Date
        /// Usually the same as the resource title
        public let title: String
        /// A summary for the station
        public let summary: String
        /// Links to related assets
        public let link: [Link]
        /// Fetch-publisher of the first available json link.
        public var jsonPublisher: AnyPublisher<StationParameter,Error>  {
            guard let l = link.first(where: { $0.type == "application/json"}) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return URLSession.shared.dataTaskPublisher(for: l.href)
                .tryMap {$0.data}
                .decode(type: StationParameter.self, decoder: decoder)
                .eraseToAnyPublisher()
        }
        /// `CLLocation` representation of the station coordinates
        public var location:CLLocation {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
    }
    /// Describes a meterological parameter
    public struct Parameter : Codable, Equatable {
        /// The key for the parameter
        public let key:String
        /// Last updated
        public let updated:Date
        /// Title describing the parameter
        public let title:String
        /// Futher description of the parameter properties
        public let summary:String
        /// The type of expected value
        public let valueType:String
        /// Available stations
        public let station:[Station]
        /// Station sets
        public let stationSet:[StationSet]?
        /// Returns the closest station by geolocation
        /// - Parameters:
        ///   - latitude: desired latitude
        ///   - longitude: desired longitude
        /// - Returns: closest station provided location
        public func closestStationFor(latitude:Double, longitude:Double) -> Station? {
            let loc = CLLocation(latitude: latitude, longitude: longitude)
            return station.filter { $0.active == true }.min(by: { loc.distance(from: $0.location) < loc.distance(from: $1.location) })
        }
        /// Returns a fetch publisher for a paremter with key
        /// - Parameter key: the key of the parameter
        /// - Returns: network-publisher
        public func publisher(for key:String) -> AnyPublisher<Parameter,Error>  {
            let u = baseUrl.appendingPathComponent("parameter").appendingPathComponent("\(key).json")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return URLSession.shared.dataTaskPublisher(for: u)
                .tryMap {$0.data}
                .decode(type: Parameter.self, decoder: decoder)
                .eraseToAnyPublisher()
        }
    }
    /// Describes a set of stations with related data summary
    public struct StationSet:Codable,Equatable {
        /// The key for the station set
        public let key:String
        /// Last updated
        public let updated:Date
        /// The title of the station set
        public let title:String
        /// Further description of the station set
        public let summary:String
        /// Links to related assets
        public let link:[Link]
    }
    /// Describes the position of a station parameter
    public struct Position: Codable, Equatable {
        /// Data availabity start
        public let from:Date
        /// Data availabity end
        public let to:Date
        /// Height above sea level (meters?)
        public let height:Double
        /// The latitude of the station parameter
        public let latitude:Double
        /// The longitude of the station parameter
        public let longitude:Double
        /// `CLLocation` representation of the coordinates
        public var location:CLLocation {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
    }
    /// Describes a period for data
    public struct Period: Codable, Equatable {
        /// The key for the period, used to fetch data from the api
        public let key:String
        /// Last updated
        public let updated:Date
        /// The title for the period
        public let title:String
        /// Further description of the period
        public let summary:String
        /// Links to related assets
        public let link:[Link]
        /// Fech-publisher for the first available json link
        public var jsonPublisher: AnyPublisher<PeriodDetails,Error>  {
            guard let l = link.first(where: { $0.type == "application/json"}) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return URLSession.shared.dataTaskPublisher(for: l.href)
                .tryMap {$0.data}
                .decode(type: PeriodDetails.self, decoder: decoder)
                .eraseToAnyPublisher()
        }
    }
    /// Details about a period.
    public struct PeriodDetails: Codable, Equatable {
        /// The key of te period details
        public let key:String
        /// Last updated
        public let updated:Date
        /// The title of the period details
        public let title:String
        /// Further description of the period details
        public let summary:String
        /// First availble data
        public let from:Date
        /// Most recent availble data
        public let to:Date
        /// Links to related assets
        public let link:[Link]
        /// Fetch-publisher of the first available json link.
        public let data:[PeriodData]
    }
    /// Describes the link to the actual parameter data
    public struct PeriodData: Codable, Equatable {
        /// The key for the data
        public let key:String?
        /// Last updated
        public let updated:Date
        /// The title of the data
        public let title:String
        /// Further description of the data
        public let summary:String
        /// Links to related assets
        public let link: [Link]
        /// Fetch-publisher of the first available json link.
        public var jsonPublisher: AnyPublisher<Value,Error>  {
            guard let l = link.first(where: { $0.type == "application/json"}) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return URLSession.shared.dataTaskPublisher(for: l.href)
                .map { $0.data }
                .decode(type: Value.self, decoder: decoder)
            
                .eraseToAnyPublisher()
        }
        /// Returns an appropriate fetch-publisher depending on avaiable link data, either JSON or CSV.
        public var fetchPublisher : AnyPublisher<Value,Error>  {
            if link.contains(where: { $0.type == "application/json"}) {
                return jsonPublisher
            }
            if link.contains(where: { $0.type == "text/plain"}) {
                return csvPublisher
            }
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        /// Fetch-publisher of the first available csv link.
        public var csvPublisher: AnyPublisher<Value,Error>  {
            guard let l = link.first(where: { $0.type == "text/plain"}) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            return URLSession.shared.dataTaskPublisher(for: l.href)
                .map { $0.data }
                .tryMap({ d -> String in
                    guard let str = String(data: d, encoding: .utf8) else { throw URLError(.cannotDecodeContentData)}
                    return str
                })
                .tryMap({ string in
                    try SMHIObservations.process(csv: string,link:l)
                })
                .eraseToAnyPublisher()
        }
    }
    /// Describes a stations parameter
    public struct StationParameter: Codable, Equatable {
        /// The parameter key
        public let key:String
        /// Last updated
        public let updated:Date
        /// The title of the parameter
        public let title:String
        /// The owner of the station
        public let owner:String
        /// The owner category of the station
        public let ownerCategory:String
        /// Whether or not the parameter/station is active
        public let active:Bool
        /// Further description of the parameter/station
        public let summary:String
        /// Data availability start
        public let from:Date
        /// Data availability end
        public let to:Date
        /// The position of the parameter/station
        public let position:[Position]
        /// The available pariods for the parameter/station
        public let period:[Period]
        /// Links to related assets
        public let link:[Link]
    }
    /// The value form a stations parameter period
    public struct Value: Codable, Equatable {
        /// Meterological data
        public struct ValueData: Codable, Equatable {
            /// Date of data
            public let date:Date
            /// The actual value
            public let value:String
            /// The quality of the data, either G (green), Y (yellow), R (red)
            public let quality:String
        }
        /// The related parameter
        public struct ValueParameter: Codable, Equatable {
            /// The parameter key
            public let key:String
            /// The parameter name
            public let name:String
            /// Summary further descirbing the parameter
            public let summary:String
            /// Unit of measure
            public let unit:String
        }
        /// The related station
        public struct ValueStation: Codable, Equatable {
            /// The station key
            public let key:String
            /// The station name
            public let name:String
            /// The owner of the station
            public let owner:String
            /// The owner category of the station
            public let ownerCategory:String
            /// Height above sea level (probably meters?)
            public let height:Double
        }
        /// The realted period
        public struct ValuePeriod: Codable, Equatable {
            /// The period key
            public let key:String
            /// Period start
            public let from:Date
            /// Period end
            public let to:Date
            /// Further description of the period
            public let summary:String
            /// How often samples are taken, for example every 15 minutes
            public let sampling:String
        }
        /// The data
        public let value:[ValueData]
        /// Last updated
        public let updated:Date
        /// Related parameter
        public let parameter:ValueParameter
        /// Related station
        public let station:ValueStation
        /// Related period
        public let period:ValuePeriod
        /// Value positions
        public let position:[Position]
        /// Links to related assets
        public let link:[Link]
    }
    /// Processes a csv and returns a value object
    /// - Parameters:
    ///   - string: the csv string
    ///   - link: the originating link
    /// - Returns: processed value
    public static func process(csv string:String,link:Link) throws -> Value {
        var processing:CurrentlyProcessingCSVField?
        var final = [Value.ValueData]()
        let measurements = string.split(separator: "\n")
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        var station:Value.ValueStation?
        var parameter:Value.ValueParameter?
        var period:Value.ValuePeriod?
        var position:Position?
        for row in measurements {
            if processing == nil && row.contains("Stationsnamn") {
                debugPrint(row)
                processing = .station
                continue
            } else if processing == .station && row.starts(with: "Parameternamn") {
                debugPrint(row)
                processing = .parameter
                continue
            } else if processing == .parameter && row.starts(with: "Tidsperiod") {
                debugPrint(row)
                processing = .period
                continue
            } else if processing == .period && row.starts(with: "Datum") {
                debugPrint(row)
                processing = .data
                continue
            }
            if processing == .station {
                let stationData = row.split(separator: ";")
                debugPrint(stationData)
                guard stationData.count >= 3, let height = Double(stationData[2]) else { throw SMHIObservationsErrors.invalidStationDataInCSV }
                station = Value.ValueStation(key: String(stationData[1]), name: String(stationData[0]), owner: "", ownerCategory: "", height: height)
            } else if processing == .parameter {
                let parameterData = row.split(separator: ";")
                debugPrint(parameterData)
                guard parameterData.count >= 3 else { throw SMHIObservationsErrors.invalidParameterDataInCSV }
                parameter = Value.ValueParameter(key: "", name: String(parameterData[0]), summary: String(parameterData[1]), unit: String(parameterData[2]))
            } else if processing == .period {
                let periodData = row.split(separator: ";")
                debugPrint(periodData)
                guard periodData.count >= 5, let latitude = Double(periodData[3]), let longitude = Double(periodData[4]), let periodHeight = Double(periodData[2]) else {
                    continue
                }
                guard let from = df.date(from: String(periodData[0]+"Z")), let to = df.date(from: String(periodData[1])+"Z") else {
                    continue
                }
                period = Value.ValuePeriod(key: "", from: from, to: to, summary: "", sampling: "")
                position = Position(from: from, to: to, height: periodHeight, latitude: latitude, longitude: longitude)
            } else if processing == .data {
                let values = row.split(separator: ";")
                guard values.count >= 4 else {
                    debugPrint("invalid number of columns: \(values.count)")
                    continue
                }
                let dateString = "\(values[0]) \(values[1])Z"
                guard let date = df.date(from: dateString) else {
                    debugPrint("invalid date: \(dateString)")
                    continue
                }
                final.append(Value.ValueData(date: date, value: String(values[2]), quality:String(values[3])))
            }
        }
        guard let sta = station else {
            throw SMHIObservationsErrors.invalidStationDataInCSV
        }
        guard let par = parameter  else {
            throw SMHIObservationsErrors.invalidParameterDataInCSV
        }
        guard let per = period else {
            throw SMHIObservationsErrors.invalidPeriodDataInCSV
        }
        guard let pos = position else {
            throw SMHIObservationsErrors.invalidPeriodDataInCSV
        }
        return Value.init(value: final, updated: per.to, parameter: par, station: sta, period: per, position: [pos], link: [link])
    }
    // Holds the descriptions for meterological conditions
    public struct ConditionCodeDescription {
        /// Shared instance
        static let shared = ConditionCodeDescription()
        /// Dictionary of keys and values
        private let dict:[String:String]
        /// Subscript returning the description of a code/`key`
        static subscript(key: String) -> String? {
            get {
                shared.dict[key]
            }
        }
        /// Initializes the `dict`
        private init() {
            var dict = [String:String]()
            dict["0"] = "Molnens utveckling har icke kunnat observeras eller icke observerats"
            dict["1"] = "Moln har uppl??sts helt eller avtagit i utstr??ckning, i m??ktighet eller i t??thet"
            dict["2"] = "Molnhimlen i stort sett of??r??ndrad"
            dict["3"] = "Moln har bildats eller tilltagit i utstr??ckning, i m??ktighet eller i t??thet"
            dict["4"] = "Sikten nedsatt av brandr??k eller fabriksr??k"
            dict["5"] = "Torrdis (solr??k)"
            dict["6"] = "Stoft sv??var i luften, men uppvirvlas ej av vinden vid observationsterminen ."
            dict["7"] = "Stoft eller sand uppvirvlas av vinden men ingen utpr??glad sandvirvel och ingen sandstorm inom synh??ll"
            dict["8"] = "Utpr??glad stoft- eller sandvirvel vid obsterminen eller under senaste timmen meningen sandstorm"
            dict["9"] = "Sandstorm under senaste timmen eller inom synh??ll vid obs-terminen"
            dict["10"] = "Fuktdis med sikt 1-10 km"
            dict["11"] = "L??g dimma i bankar p?? stationen, skiktets m??ktighet ??verstiger ej 2 m p?? land eller 10 m till sj??ss"
            dict["12"] = "Mer eller mindre sammanh??ngande l??g dimma p?? stationen, skiktets m??ktighet ??verstiger ej 2 m p?? land eller 10 m till sj??ss"
            dict["13"] = "Kornblixt"
            dict["14"] = "Nederb??rd inom synh??ll, som ej n??r marken eller havsytan (fallstrimmor)"
            dict["15"] = "Nederb??rd, som n??r marken eller havsytaninom synh??ll p?? ett avst??nd st??rre ??n 5 km fr??n stationen"
            dict["16"] = "Nederb??rd, som n??r marken eller havsytan inom synh??ll p?? ett avst??nd mindre ??n 5 km, men ej p?? stationen"
            dict["17"] = "??ska vid observationsterminen men ingen nederb??rd p?? stationen"
            dict["18"] = "Utpr??glade starka vindbyar p?? stationen eller inom synh??ll vid obs-terminen eller under senaste timmen"
            dict["19"] = "Skydrag eller tromb p?? stationen eller inom synh??ll vid obs-terminen eller under senaste timmen"
            dict["20"] = "Duggregn eller kornsn?? under senaste timmen men ej vid observationsterterminen"
            dict["21"] = "Regn under senaste timmen men ej vid observationsterterminen"
            dict["22"] = "Sn??fall under senaste timmen men ej vid observationsterterminen"
            dict["23"] = "Sn??blandat regn eller iskorn under senaste timmen men ej vid observationsterterminen"
            dict["24"] = "Underkylt regn eller duggregn under senaste timmen men ej vid observationsterterminen"
            dict["25"] = "Regnskura runder senaste timmen men ej vid observationsterterminen"
            dict["26"] = "Byar av sn?? eller sn??blandat regn under senaste timmen men ej vid observationsterterminen"
            dict["27"] = "Byar av hagel med eller utan regn under senaste timmen men ej vid observationsterterminen"
            dict["28"] = "Dimma under senaste timmen men ej vid observationsterterminen"
            dict["29"] = "??ska (med eller utan nederb??rd) under senaste timmen men ej vid observationsterterminen"
            dict["30"] = "L??tt eller m??ttlig sandstorm har avtagit istyrka under senaste timmen"
            dict["31"] = "L??tt eller m??ttlig sandstorm utan m??rkbar f??r??ndring under senaste timmen"
            dict["32"] = "L??tt eller m??ttlig sandstorm har b??rjat eller tilltagit i styrka under senaste timmen"
            dict["33"] = "Kraftig sandstorm har avtagit i styrka under senaste timmen"
            dict["34"] = "Kraftig sandstorm utan m??rkbar f??r??ndring under senaste timmen"
            dict["35"] = "Kraftig sandstorm har b??rjat eller tilltagit i styrka under senaste timmen"
            dict["36"] = "L??gt och l??tt eller m??ttligt sn??drev"
            dict["37"] = "L??gt men t??tt sn??drev"
            dict["38"] = "H??gt men l??tt eller m??ttligt sn??drev"
            dict["39"] = "H??gt och t??tt sn??drev"
            dict["40"] = "Dimma inom synh??ll vid observationsterminen, n??ende ??ver ??gonh??jd (dock ej dimma p?? stationen under senaste timmen) (VV ?10)"
            dict["41"] = "Dimma i bankar p?? stationen (VV< 10)"
            dict["42"] = "Dimma, med skymt av himlen, har blivit l??ttare under senaste timmen"
            dict["43"] = "Dimma, utan skymt av himlen, har blivit l??ttare under senaste timmen"
            dict["44"] = "Dimma, med skymt av himlen, of??r??ndrad under senaste timmen"
            dict["45"] = "Dimma, utan skymt av himlen, of??r??ndrad under senaste timmen"
            dict["46"] = "Dimma, med skymt av himlen, har b??rjat eller t??tnat under senaste timmen"
            dict["47"] = "Dimma, utan skymt av himlen, har b??rjat eller t??tnat under senaste timmen"
            dict["48"] = "Underkyld dimma, med skymt av himlen"
            dict["49"] = "Underkyld dimma, utan skymt av himlen"
            dict["50"] = "L??tt duggregn med avbrott"
            dict["51"] = "L??tt duggregn, ih??llande"
            dict["52"] = "M??ttligt duggregn med avbrott"
            dict["53"] = "M??ttligt duggregn, ih??llande"
            dict["54"] = "T??tt duggregn med avbrott"
            dict["55"] = "T??tt duggregn, ih??llande"
            dict["56"] = "L??tt underkylt duggregn"
            dict["57"] = "M??ttligt eller t??tt underkylt duggregn"
            dict["58"] = "L??tt duggregn tillsammans med regn"
            dict["59"] = "M??ttligt eller t??tt duggregn tillsammans med regn"
            dict["60"] = "L??tt regn med avbrott"
            dict["61"] = "L??tt regn, ih??llande"
            dict["62"] = "M??ttligt regn med avbrott"
            dict["63"] = "M??ttligt regn, ih??llande"
            dict["64"] = "Starkt regn med avbrott"
            dict["65"] = "Starkt regn ih??llande"
            dict["66"] = "L??tt underkylt regn"
            dict["67"] = "M??ttligt eller starkt underkylt regn"
            dict["68"] = "L??tt regn eller duggregn tillsammans med sn??"
            dict["69"] = "M??ttligt eller starkt regn eller duggregn tillsammans med sn??"
            dict["70"] = "L??tt sn??fall med avbrott"
            dict["71"] = "L??tt sn??fall, ih??llande"
            dict["72"] = "M??ttligt sn??fall med avbrott"
            dict["73"] = "M??ttligt sn??fall, ih??llande"
            dict["74"] = "T??tt sn??fall med avbrott"
            dict["75"] = "T??tt sn??fall, ih??llande"
            dict["76"] = "Isn??lar (med el. utan dimma)"
            dict["77"] = "Kornsn?? (med el. utan dimma)"
            dict["78"] = "Enstaka sn??stj??rnor (med el. utan dimma)"
            dict["79"] = "Iskorn"
            dict["80"] = "L??tta regnskurar"
            dict["81"] = "M??ttliga eller kraftiga regnskurar"
            dict["82"] = "Mycket kraftiga regnskurar (skyfall)"
            dict["83"] = "L??tt sn??blandat regn i byar"
            dict["84"] = "M??ttligt eller kraftigt sn??blandat regn i byar"
            dict["85"] = "L??tta sn??byar"
            dict["86"] = "M??ttliga eller kraftiga sn??byar"
            dict["87"] = "L??tta byar av sm??hagel eller sn??hagel (trindsn??) med eller utan regn eller sn??blandat regn"
            dict["88"] = "M??ttliga eller kraftiga byar av sm??hagel eller sn??hagel (trindsn??) med eller utan regn eller sn??blandat regn"
            dict["89"] = "L??tta byar av ishagel med eller utan regn eller sn??blandat regn, utan ??ska"
            dict["90"] = "M??ttliga eller kraftiga byar av ishagel med eller utan regn eller sn??blandat regn, utan ??ska"
            dict["91"] = "L??tt regn vid observationsterminen, ??skv??der under senaste timmen men ej vid observationsterminen"
            dict["92"] = "M??ttligt el. starkt regn vid observationsterminen, ??skv??der under senaste timmen men ej vid observationsterminen"
            dict["93"] = "L??tt sn??fall, sn??blandat regn eller hagel vid observationsterminen, ??skv??der under senaste timmen men ej vid observationsterminen"
            dict["94"] = "M??ttligt el. starkt sn??fall, sn??blandat regn eller hagel vid observationsterminen, ??skv??der under senaste timmen men ej vid observationsterminen"
            dict["95"] = "Svagt eller m??ttligt ??skv??der vid observationsterminen utan hagel men med regn eller sn??"
            dict["96"] = "Svagt eller m??ttligt ??skv??der vid observationsterminen med hagel"
            dict["97"] = "Kraftigt ??skv??der vid observationsterminen utan hagel men med regn eller sn??"
            dict["98"] = "Kraftigt ??skv??der vid observationsterminen med sandstorm"
            dict["99"] = "Kraftigt ??skv??der vid observationsterminen med hagel"
            dict["100"] = "Inget signifikant v??der observerat"
            dict["101"] = "Moln har uppl??sts helt eller avtagit i utstr??ckning, i m??ktighet eller i t??thet, under senste timmen"
            dict["102"] = "Molnhimlen i stort sett of??r??ndrad under senste timmen"
            dict["103"] = "Moln har bildats eller tilltagit i utstr??ckning, i m??ktighet eller i t??thet, under senste timmen"
            dict["104"] = "Dis eller r??k, eller stoft som ??r spritt i luften, sikt st??rre eller lika med 1 km"
            dict["105"] = "Dis eller r??k, eller stoft som ??r spritt i luften, sikt mindre ??n 1 km"
            dict["110"] = "Fuktdis med sikt 1-10 km"
            dict["111"] = "Isn??lar"
            dict["112"] = "Blixt p?? avst??nd"
            dict["118"] = "Utpr??glade starka vindbyar"
            dict["120"] = "Dimma"
            dict["121"] = "Nederb??rd"
            dict["122"] = "Duggregn eller kornsn??"
            dict["123"] = "Regn"
            dict["124"] = "Sn??fall"
            dict["125"] = "Underkylt duggregn eller regn"
            dict["126"] = "??skv??der (med eller utan nederb??rd)"
            dict["127"] = "Sn??drev eller sandstorm"
            dict["128"] = "Sn??drev eller sandstorm, sikt st??rre eller lika med 1 km"
            dict["129"] = "Sn??drev eller sandstorm, sikt mindre ??n 1 km"
            dict["130"] = "Dimma"
            dict["131"] = "Dimma i bankar p?? stationen"
            dict["132"] = "Dimma, har blivit l??ttare under senaste timmen"
            dict["133"] = "Dimma, of??r??ndrad under senaste timmen"
            dict["134"] = "Dimma, har b??rjat eller t??tnat under senaste timmen"
            dict["135"] = "Underkyld dimma"
            dict["140"] = "Nederb??rd"
            dict["141"] = "L??tt eller m??ttlig nederb??rd"
            dict["142"] = "Kraftig nederb??rd"
            dict["143"] = "Flytande nederb??rd, l??tt eller m??ttlig"
            dict["144"] = "Flytande nederb??rd, kraftig"
            dict["145"] = "Fast nederb??rd, l??tt eller m??ttlig"
            dict["146"] = "Fast nederb??rd, kraftig"
            dict["147"] = "L??tt eller m??ttlig underkyld nederb??rd"
            dict["148"] = "Kraftig underkyld nederb??rd"
            dict["150"] = "Duggregn"
            dict["151"] = "L??tt duggregn"
            dict["152"] = "M??ttligt duggregn"
            dict["153"] = "T??tt duggregn"
            dict["154"] = "L??tt underkylt duggregn"
            dict["155"] = "M??ttligt underkylt duggregn"
            dict["156"] = "T??tt duggregn"
            dict["157"] = "L??tt duggregn tillsammans med regn"
            dict["158"] = "M??ttligt eller t??tt duggregn tillsammans med regn"
            dict["160"] = "Regn"
            dict["161"] = "L??tt regn"
            dict["162"] = "M??ttligt regn"
            dict["163"] = "Starkt regn"
            dict["164"] = "L??tt underkylt regn"
            dict["165"] = "M??ttligt underkylt regn"
            dict["166"] = "Starkt underkylt regn"
            dict["167"] = "L??tt regn eller duggregn tillsammans med sn??"
            dict["168"] = "M??ttligt eller starkt regn eller duggregn tillsammans med sn??"
            dict["170"] = "Sn??fall"
            dict["171"] = "L??tt sn??fall"
            dict["172"] = "M??ttligt sn??fall"
            dict["173"] = "T??tt sn??fall"
            dict["174"] = "L??tt sm??hagel"
            dict["175"] = "M??ttligt sm??hagel"
            dict["176"] = "Kraftigt sm??hagel"
            dict["177"] = "Kornsn??"
            dict["178"] = "Isn??lar"
            dict["180"] = "Regnskurar"
            dict["181"] = "L??tta regnskurar"
            dict["182"] = "M??ttliga regnskurar"
            dict["183"] = "Kraftiga regnskurar"
            dict["184"] = "Mycket kraftiga regnskurar (skyfall)"
            dict["185"] = "L??tta sn??byar"
            dict["186"] = "M??ttliga sn??byar"
            dict["187"] = "Kraftiga sn??byar"
            dict["189"] = "Hagel"
            dict["190"] = "??skv??der"
            dict["191"] = "Svagt eller m??ttligt ??skv??der utan nederb??rd"
            dict["192"] = "Svagt eller m??ttligt ??skv??der med regnskurar eller sn??byar"
            dict["193"] = "Svagt eller m??ttligt ??skv??der med hagel"
            dict["194"] = "Kraftigt ??skv??der utan nederb??rd"
            dict["195"] = "Kraftigt ??skv??der med regnskurar eller sn??byar"
            dict["196"] = "Kraftigt ??skv??der med hagel"
            dict["199"] = "Tromb eller Tornado"
            dict["204"] = "Vulkanaska som spridits h??gt upp i luften"
            dict["206"] = "Tjockt stoftdis, sikt mindre ??n 1 km"
            dict["207"] = "Vattenst??nk vid station pga bl??st"
            dict["208"] = "Drivande stoft (eller sand)"
            dict["209"] = "Kraftig stoft- eller sandstorm p?? avst??nd (Haboob)"
            dict["210"] = "Sn??dis"
            dict["211"] = "Sn??storm eller kraftigt sn??drev som ger extremt d??lig sikt"
            dict["213"] = "Blixt mellan moln och marken"
            dict["217"] = "??ska utan regnskur"
            dict["219"] = "Tromb eller tornado (f??r??dande) vid stationen eller inom synh??ll under den senaste timmen"
            dict["220"] = "Avlagring av vulkanaska"
            dict["221"] = "Avlagring av stoft eller sand"
            dict["222"] = "Dagg"
            dict["223"] = "Utf??llning av bl??t sn??"
            dict["224"] = "L??tt eller m??ttlig dimfrost"
            dict["225"] = "Kraftig dimfrost"
            dict["226"] = "Rimfrost"
            dict["227"] = "Kraftig isbel??ggning pga underkyld nederb??rd"
            dict["228"] = "Isskorpa"
            dict["230"] = "Stoft- eller sandstorm med temperatur under fryspunkten"
            dict["239"] = "Kraftigt sn??drev och/eller sn??fall"
            dict["241"] = "Dimma till havs"
            dict["242"] = "Dimma i dalg??ng"
            dict["243"] = "Sj??r??k i Arktis eller vid Antarktis"
            dict["244"] = "Advektionsdimma (??ver vatten)"
            dict["245"] = "Advektionsdimma (??ver land)"
            dict["246"] = "Dimma ??ver is eller sn??"
            dict["247"] = "T??t dimma, sikt 60-90 m"
            dict["248"] = "T??t dimma, sikt 30-60 m"
            dict["249"] = "T??t dimma, sikt mindre ??n 30 m"
            dict["250"] = "Duggregn, intensitet mindre ??n 0,10 mm/timme"
            dict["251"] = "Duggregn, intensitet 0,10-0,19 mm/timme"
            dict["252"] = "Duggregn, intensitet 0,20-0,39 mm/timme"
            dict["253"] = "Duggregn, intensitet 0,40-0,79 mm/timme"
            dict["254"] = "Duggregn, intensitet 0,80-1,59 mm/timme"
            dict["255"] = "Duggregn, intensitet 1,60-3,19 mm/timme"
            dict["256"] = "Duggregn, intensitet 3,20-6,39 mm/timme"
            dict["257"] = "Duggregn, intensitet st??rre ??n 6,40 mm/timme"
            dict["259"] = "Duggregn och sn??fall"
            dict["260"] = "Regn, intensitet mindre ??n 1,0 mm/timme"
            dict["261"] = "Regn, intensitet 1,0-1,9 mm/timme"
            dict["262"] = "Regn, intensitet 2,0-3,9 mm/timme"
            dict["263"] = "Regn, intensitet 4,0-7,9 mm/timme"
            dict["264"] = "Regn, intensitet 8,0-15,9 mm/timme"
            dict["265"] = "Regn, intensitet 16,0-31,9 mm/timme"
            dict["266"] = "Regn, intensitet 32,0-63,9 mm/timme"
            dict["267"] = "Regn, intensitet st??rre ??n 64,0 mm/timme"
            dict["270"] = "Sn??, intensitet mindre ??n 1,0 cm/timme"
            dict["271"] = "Sn??, intensitet 1,0-1,9 cm/timme"
            dict["272"] = "Sn??, intensitet 2,0-3,9 cm/timme"
            dict["273"] = "Sn??, intensitet 4,0-7,9 cm/timme"
            dict["274"] = "Sn??, intensitet 8,0-15,9 cm/timme"
            dict["275"] = "Sn??, intensitet 16,0-31,9 cm/timme"
            dict["276"] = "Sn??, intensitet 32,0-63,9 cm/timme"
            dict["277"] = "Sn??, intensitet st??rre ??n 64,0 cm/timme"
            dict["278"] = "Sn??fall eller isn??lar fr??n en klar himmel"
            dict["279"] = "Frysande bl??tsn??"
            dict["280"] = "Regn"
            dict["281"] = "Underkylt regn"
            dict["282"] = "Sn??blandat regn"
            dict["283"] = "Sn??fall"
            dict["284"] = "Sm??hagel eller sn??hagel"
            dict["285"] = "Sm??hagel eller sn??hagel tillsammans med regn"
            dict["286"] = "Sm??hagel eller sn??hagel tillsammans med sn??blandat regn"
            dict["287"] = "Sm??hagel eller sn??hagel tillsammans med sn??"
            dict["288"] = "Hagel"
            dict["289"] = "Hagel tillsammans med regn"
            dict["290"] = "Hagel tillsammans med sn??blandat regn"
            dict["291"] = "Hagel tillsammans med sn??"
            dict["292"] = "Skurar eller ??ska till havs"
            dict["293"] = "Skurar eller ??ska ??ver berg"
            dict["508"] = "Inga signifikanta fenomen att rapportera, r??dande och gammalt v??der utel??mnas"
            dict["509"] = "Ingen observation, data ej tillg??ngligt, r??dande och gammalt v??der utel??mnas"
            dict["510"] = "R??dande och gammalt v??der saknas men f??rv??ntades."
            dict["511"] = "Saknat v??rde"
            self.dict = dict
        }
    }
    /// Returns a `Value` publisher for a specific station,parameter and period
    /// - Parameters:
    ///   - station: the selected station
    ///   - key: the selected parameter key
    ///   - period: the selected period
    /// - Returns: `Value` publisher
    public static func publisher(forStation station:String, parameter key:String, period:String)  -> AnyPublisher<Value,Error> {
        return Service.jsonPublisher
            .tryMap({ p -> Resource  in
                guard let r = p.resource.first(where: { $0.key == key }) else {
                    throw SMHIObservationsErrors.missingResource
                }
                return r
            })
            .flatMap { $0.jsonPublisher }
            .tryMap { p -> Station in
                guard let s = p.station.first(where: { $0.active == true && $0.name.lowercased().contains(station)}) else {
                    throw SMHIObservationsErrors.missingStation
                }
                return s
            }
            .flatMap { $0.jsonPublisher }
            .tryMap { pd -> Period in
                guard let v = pd.period.first(where: { $0.key == period }) else {
                    throw SMHIObservationsErrors.missingPeriod
                }
                return v
            }
            .flatMap { $0.jsonPublisher }
            .tryMap { d -> PeriodData in
                guard let f = d.data.first else {
                    throw SMHIObservationsErrors.missingPeriodData
                }
                return f
            }
            .flatMap { $0.fetchPublisher}
            .eraseToAnyPublisher()
    }
    /// Returns a `Value` publisher for the closes station to given location, a parameter and a period.
    /// - Parameters:
    ///   - latitude: the latitude of the desired position
    ///   - longitude: the longitude of the desired position
    ///   - key: the selected parameter key
    ///   - period: the selected period
    /// - Returns: `Value` publisher
    public static func publisher(latitude:Double, longitude:Double, parameter key:String, period:String) -> AnyPublisher<Value,Error> {
        return Service.jsonPublisher
            .tryMap({ p -> Resource  in
                guard let r = p.resource.first(where: { $0.key == key }) else {
                    throw SMHIObservationsErrors.missingResource
                }
                return r
            })
            .flatMap { $0.jsonPublisher }
            .tryMap { p -> Station in
                guard let s = p.closestStationFor(latitude: latitude, longitude: longitude) else {
                    throw SMHIObservationsErrors.missingStation
                }
                return s
            }
            .flatMap { $0.jsonPublisher }
            .tryMap { pd -> Period in
                guard let v = pd.period.first(where: { $0.key == period }) else {
                    throw SMHIObservationsErrors.missingPeriod
                }
                return v
            }
            .flatMap { $0.jsonPublisher }
            .tryMap { d -> PeriodData in
                guard let f = d.data.first else {
                    throw SMHIObservationsErrors.missingPeriodData
                }
                return f
            }
            .flatMap { $0.fetchPublisher}
            .eraseToAnyPublisher()
    }
    /// Returns the `Service.jsonPublisher`
    public static var publisher:AnyPublisher<Service,Error> {
        return Service.jsonPublisher
    }
}

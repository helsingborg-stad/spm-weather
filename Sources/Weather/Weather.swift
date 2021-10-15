import Combine
import Foundation
import CoreLocation
import AutomatedFetcher

public protocol WeatherService {
    func fetch(using coordinates:Weather.Coordinates) -> AnyPublisher<[WeatherData],Error>
}
public class Weather : ObservableObject {
    public struct Coordinates: Codable, Equatable, Hashable {
        public let latitude:Double
        public let longitude:Double
        public init(latitude:Double, longitude:Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }
    private var automatedFetcher:AutomatedFetcher<[WeatherData]>
    private var dataSubject = CurrentValueSubject<[WeatherData],Never>([])
    public let latest:AnyPublisher<[WeatherData],Never>
    public var service:WeatherService? {
        didSet {
            if fetchAutomatically {
                self.fetch()
            }
        }
    }
    private var publishers = Set<AnyCancellable>()
    public var coordinates:Coordinates? {
        didSet {
            if oldValue != coordinates {
                fetch()
            }
        }
    }
    @Published public var fetchAutomatically:Bool {
        didSet { automatedFetcher.isOn = fetchAutomatically }
    }
    @Published public private(set) var previewData:Bool = false
    public init(service:WeatherService?, coordinates:Coordinates? = nil, fetchAutomatically:Bool = true, previewData:Bool = false) {
        self.previewData = previewData
        self.fetchAutomatically = fetchAutomatically
        self.coordinates = coordinates
        self.latest = dataSubject.eraseToAnyPublisher()
        self.service = service
        self.automatedFetcher = AutomatedFetcher<[WeatherData]>(dataSubject, isOn: fetchAutomatically)
        automatedFetcher.triggered.sink { [weak self] in
            self?.fetch()
        }.store(in: &publishers)
        if fetchAutomatically {
            fetch()
        }
    }
    public func fetch(force:Bool = false) {
        if previewData {
            dataSubject.send(Self.previewData)
            return
        }
        if force == false && automatedFetcher.shouldFetch && dataSubject.value.isEmpty == false {
            return
        }
        guard let coordinates = coordinates else {
            return
        }
        guard let service = service else {
            return
        }
        automatedFetcher.started()
        var p:AnyCancellable?
        p = service.fetch(using: coordinates).receive(on: DispatchQueue.main).sink { [weak self] completion in
            if case .failure(let error) = completion {
                debugPrint(error)
            }
            self?.automatedFetcher.failed()
        } receiveValue: { [weak self] data in
            self?.dataSubject.send(data.sorted(by: { $0.dateTimeRepresentation < $1.dateTimeRepresentation }))
            self?.automatedFetcher.completed()
            if let p = p {
                self?.publishers.remove(p)
            }
        }
        if let p = p {
            publishers.insert(p)
        }
    }
    public func closest(to date:Date? = nil) -> AnyPublisher<WeatherData?,Never> {
        return dataSubject.map { data in
            let date = date ?? Date()
            return data.sorted { w1, w2 in
                abs(w1.dateTimeRepresentation.timeIntervalSince(date)) < abs(w2.dateTimeRepresentation.timeIntervalSince(date))
            }.first
        }.eraseToAnyPublisher()
    }
    public func betweenDates(from: Date, to:Date) -> [WeatherData] {
        return dataSubject.value.filter { $0.dateTimeRepresentation >= from && $0.dateTimeRepresentation <= to }
    }
    public static let previewData: [WeatherData] = [
        .init(dateTimeRepresentation: Date().addingTimeInterval(60),
              airPressure: 1018,
              airTemperature: 20.1,
              airTemperatureFeelsLike: 24,
              horizontalVisibility: 49.2,
              windDirection: 173,
              windSpeed: 5.7,
              windGustSpeed: 9.2,
              relativeHumidity: 71,
              thunderProbability: 1,
              totalCloudCover: 6,
              lowLevelCloudCover: 2,
              mediumLevelCloudCover: 0,
              highLevelCloudCover: 5,
              minPrecipitation: 0,
              maxPrecipitation: 0,
              frozenPrecipitationPercentage: 0,
              meanPrecipitationIntensity: 0,
              medianPrecipitationIntensity: 0,
              precipitationCategory: .none,
              symbol: .variableCloudiness,
              latitude: 56.0014127,
              longitude: 12.7416203)
    ]
    public static let previewInstance:Weather = Weather(service: nil, previewData: true)
    
    /// Get the heat index adusted temperature
    /// - Parameters:
    ///   - t: temperature
    ///   - r: humidity
    /// - Returns: heat index adjusted temperature
    public static func heatIndexAdjustedTemperature(temperature t:Double, humidity r:Double) -> Double {
        /// https://en.wikipedia.org/wiki/Heat_index
        if t < 27 || r < 40 {
            return t
        }
        let c1:Double = -8.78469475556
        let c2:Double = 1.61139411
        let c3:Double = 2.33854883889
        let c4:Double = -0.14611605
        let c5:Double = -0.012308094
        let c6:Double = -0.0164248277778
        let c7:Double = 0.002211732
        let c8:Double = 0.00072546
        let c9:Double = -0.000003582
        return c1 + (c2 * t) + (c3 * r) + (c4 * t * r + c5 * pow(t,2)) + (c6 * pow(r,2)) + (c7 * pow(t,2) * r) + (c8 * t * pow(r,2)) + (c9 * pow(t,2) * pow(r,2))
    }

    /// Get the effective temperature, ie windchill temperature
    /// - Parameters:
    ///   - t: temperature in celcius
    ///   - v: wind speed in meters per second
    /// - Returns: wind chill temperature
    /// - Note
    /// Information found at https://www.smhi.se/kunskapsbanken/meteorologi/vindens-kyleffekt-1.259
    public static func windChillAdjustedTemperature(temperature t:Double, wind v:Double) -> Double {
        if t > 10 || t < -40 || v < 2 || v > 35{
            return t
        }
        return 13.12 + 0.6215 * t - 13.956 * pow(v, 0.16) + 0.48669 * t * pow(v, 0.16)
    }


    /// Calculates the dew point
    /// - Parameters:
    ///   - humidity: relative humidity (1 to 100)
    ///   - temperature: temperature in celcius
    /// - Returns: the dew point adjusted temperature
    /// - Note:
    /// Information found at https://github.com/malexer/meteocalc/blob/master/meteocalc/dewpoint.py
    public static func dewPointAdjustedTemperature(humidity:Double, temperature:Double) -> Double {
        let bpos = 17.368
        let cpos = 238.88
        let bneg = 17.966
        let cneg = 247.15

        let b = temperature > 0 ? bpos : bneg
        let c = temperature > 0 ? cpos : cneg

        let pa = humidity / 100 * pow(M_E, b * temperature / (c + temperature))

        return c * log(pa) / (b - log(pa))
    }

    //public func calculateDewPointAlternate1(humidity:Double,temperature:Double) -> Double {
    //    /// https://stackoverflow.com/questions/27288021/formula-to-calculate-dew-point-from-temperature-and-humidity
    //    return (temperature - (14.55 + 0.114 * temperature) * (1 - (0.01 * humidity)) - pow(((2.5 + 0.007 * temperature) * (1 - (0.01 * humidity))),3) - (15.9 + 0.117 * temperature) * pow((1 - (0.01 * humidity)), 14))
    //}
    //
    //public func calculateDewPointAlternate2(humidity:Double,temperature:Double) -> Double {
    //    /// https://gist.github.com/sourceperl/45587ea99ff123745428
    //    let A = 17.27
    //    let B = 237.7
    //    let alpha = ((A * temperature) / (B + temperature)) + log(humidity/100.0)
    //    return (B * alpha) / (A - alpha)
    //}

}


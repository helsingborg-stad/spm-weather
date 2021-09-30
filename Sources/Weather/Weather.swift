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
}


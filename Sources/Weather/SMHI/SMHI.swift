import Foundation
import Combine
import UIKit
import CoreLocation

enum SMHIError : Error {
    case badURL
}
public typealias SMHIForecastPublisher = AnyPublisher<[WeatherData],Error>
public class SMHI : WeatherService {
    public init () {
        
    }
    func url(_ lon:Double,_ lat:Double) -> URL? {
        return URL(string: "https://opendata-download-metfcst.smhi.se/api/category/pmp3g/version/2/geotype/point/lon/\(String(format: "%.6f", lon))/lat/\(String(format: "%.6f", lat))/data.json")
    }
    public func fetch(using coordinates:Weather.Coordinates) -> AnyPublisher<[WeatherData],Error> {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        decoder.dateDecodingStrategy = .formatted(formatter)
        guard let url = self.url(coordinates.longitude,coordinates.latitude) else {
            return Fail(error: SMHIError.badURL).eraseToAnyPublisher()
        }
        return URLSession.shared.dataTaskPublisher(for: url)
            .map {$0.data}
            .decode(type: SMHIWeather.self, decoder: decoder)
            .map({ w in
                var arr = [WeatherData]()
                for t in w.timeSeries {
                    do {
                        let d = try t.weatherDataRepresentation(using: coordinates)
                        arr.append(d)
                    } catch {
                        print(error)
                    }
                    
                }
                return arr
            })
            .eraseToAnyPublisher()
    }
}

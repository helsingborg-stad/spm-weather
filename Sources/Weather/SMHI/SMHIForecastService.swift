import Foundation
import Combine
import CoreLocation

public class SMHIForecastService : WeatherService {
    public init () {
        
    }
    func url(_ lat:Double,_ lon:Double) -> URL? {
        return URL(string: "https://opendata-download-metfcst.smhi.se/api/category/pmp3g/version/2/geotype/point/lon/\(String(format: "%.6f", lon))/lat/\(String(format: "%.6f", lat))/data.json")
    }
    public func fetch(using coordinates:Weather.Coordinates) -> AnyPublisher<[WeatherData],Error> {
        return fetchPublisher(latitude: coordinates.latitude, longitude: coordinates.longitude)
            .tryMap({ w in
                var arr = [WeatherData]()
                for t in w.timeSeries {
                    let d = try t.weatherDataRepresentation(using: coordinates)
                    arr.append(d)
                }
                return arr
            })
            .eraseToAnyPublisher()
    }
    public func fetchPublisher(latitude:Double, longitude:Double) -> AnyPublisher<SMHIForecast,Error> {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        decoder.dateDecodingStrategy = .formatted(formatter)
        guard let url = self.url(latitude,longitude) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        return URLSession.shared.dataTaskPublisher(for: url)
            .map {$0.data}
            .decode(type: SMHIForecast.self, decoder: decoder)
            .eraseToAnyPublisher()
    }
}

public enum SMHIWeatherDataMissingError : Error {
    case airPressure
    case airTemperature
    case horizontalVisibility
    case windDirection
    case windSpeed
    case relativeHumidity
    case thunderProbability
    case totalCloudCover
    case lowLevelCloudCover
    case mediumLevelCloudCover
    case highLevelCloudCover
    case windGustSpeed
    case minPrecipitation
    case maxPrecipitation
    case frozenPrecipitationPercentage
    case precipitationCategory
    case meanPrecipitationIntensity
    case medianPrecipitationIntensity
    case weatherSymbol
}
public struct SMHIForecast : Codable {
    public struct TimeSeries : Codable {
        public let validTime:Date
        public let parameters:[Parameter]
        public struct Parameter : Codable {
            public enum Name:String, Codable {
                case airPressure = "msl"
                case airTemperature = "t"
                case horizontalVisibility = "vis"
                case windDirection = "wd"
                case windSpeed = "ws"
                case relativeHumidity = "r"
                case thunderProbability = "tstm"
                case totalCloudCover = "tcc_mean"
                case lowLevelCloudCover = "lcc_mean"
                case mediumLevelCloudCover = "mcc_mean"
                case highLevelCloudCover = "hcc_mean"
                case windGustSpeed = "gust"
                case minPrecipitation = "pmin"
                case maxPrecipitation = "pmax"
                case frozenPrecipitationPercentage = "spp"
                case precipitationCategory = "pcat"
                case meanPrecipitationIntensity = "pmean"
                case medianPrecipitationIntensity = "pmedian"
                case weatherSymbol = "Wsymb2"
            }
            let name:Name
            let levelType:String
            let level:Int
            let unit:String
            let values:[Double]
            var suffix:String? {
                switch unit {
                case "percent": return "%"
                case "kg/m2/h": return "mm/h"
                case "octas": return "%"
                case "hPa": return "hPa"
                case "Cel": return "°"
                case "km": return "km"
                case "degree": return ""
                case "m/s": return "m/s"
                default: return nil
                }
            }
            var value:Any? {
                guard let val = values.first else {
                    return nil
                }
                switch self.name {
                case .airPressure: return val
                case .airTemperature: return val
                case .horizontalVisibility: return val
                case .windDirection: return val
                case .windSpeed: return val
                case .relativeHumidity: return Int(val)
                case .thunderProbability: return Int(val)
                case .totalCloudCover: return Int(val)
                case .lowLevelCloudCover: return Int(val)
                case .mediumLevelCloudCover: return Int(val)
                case .highLevelCloudCover: return Int(val)
                case .windGustSpeed: return val
                case .minPrecipitation: return val
                case .maxPrecipitation: return val
                case .frozenPrecipitationPercentage: return Int(val) == Int(-9) ? Int(0) : Int(val)
                case .precipitationCategory: return Int(val)
                case .meanPrecipitationIntensity: return val
                case .medianPrecipitationIntensity: return val
                case .weatherSymbol: return Int(val)
                }
            }
        }
        public var temperatureFeelsLike:Double? {
            guard let t = parameter(.airTemperature)?.value as? Double else {
                return nil
            }
            guard let v = parameter(.windSpeed)?.values.first,let r = parameter(.relativeHumidity)?.values.first else {
                return t
            }
            return Weather.windChillAdjustedTemperature(temperature: Weather.heatIndexAdjustedTemperature(temperature: t, humidity: r), wind: v)
        }
        public var heatIndex:Double? {
            guard let t = parameter(.airTemperature)?.value as? Double, let r = parameter(.relativeHumidity)?.values.first else {
                return nil
            }
            return Weather.heatIndexAdjustedTemperature(temperature: t, humidity: r)
        }
        public var effectiveTemperature:Double? {
            guard let t = parameter(.airTemperature)?.value as? Double,let v = parameter(.windSpeed)?.values.first else {
                return nil
            }
            return Weather.windChillAdjustedTemperature(temperature: t, wind: v)
        }
        public func parameter(_ parameter:Parameter.Name) -> Parameter? {
            parameters.first { param in param.name == parameter }
        }
        var symbol:WeatherSymbol? {
            guard let s = self.parameter(.weatherSymbol)?.value as? Int else {
                return nil
            }
            switch s {
            case 1: return WeatherSymbol.clearSky
            case 2: return WeatherSymbol.nearlyClearSky
            case 3: return WeatherSymbol.variableCloudiness
            case 4: return WeatherSymbol.halfclearSky
            case 5: return WeatherSymbol.cloudySky
            case 6: return WeatherSymbol.overcast
            case 7: return WeatherSymbol.fog
            case 8: return WeatherSymbol.lightRainShowers
            case 9: return WeatherSymbol.moderateRainShowers
            case 10: return WeatherSymbol.heavyRainShowers
            case 11: return WeatherSymbol.thunderstorm
            case 12: return WeatherSymbol.lightSleetShowers
            case 13: return WeatherSymbol.moderateSleetShowers
            case 14: return WeatherSymbol.heavySleetShowers
            case 15: return WeatherSymbol.lightSnowShowers
            case 16: return WeatherSymbol.moderateSnowShowers
            case 17: return WeatherSymbol.heavySnowShowers
            case 18: return WeatherSymbol.lightRain
            case 19: return WeatherSymbol.moderateRain
            case 20: return WeatherSymbol.heavyRain
            case 21: return WeatherSymbol.thunder
            case 22: return WeatherSymbol.lightSleet
            case 23: return WeatherSymbol.moderateSleet
            case 24: return WeatherSymbol.heavySleet
            case 25: return WeatherSymbol.lightSnowfall
            case 26: return WeatherSymbol.moderateSnowfall
            case 27: return WeatherSymbol.heavySnowfall
            default: return nil
            }
        }
        var precipitation:WeatherPrecipitation {
            guard let s = self.parameter(.precipitationCategory)?.value as? Int else {
                return WeatherPrecipitation.none
            }
            switch s {
            case 0: return WeatherPrecipitation.none
            case 1: return WeatherPrecipitation.snow
            case 2: return WeatherPrecipitation.snowAndRain
            case 3: return WeatherPrecipitation.rain
            case 4: return WeatherPrecipitation.drizzle
            case 5: return WeatherPrecipitation.freezingRain
            case 6: return WeatherPrecipitation.freezingDrizzle
            default: return WeatherPrecipitation.none
            }
        }
        func weatherDataRepresentation(using coordinates:Weather.Coordinates) throws -> WeatherData  {
            guard let airPressure = self.parameter(.airPressure)?.value as? Double else { throw SMHIWeatherDataMissingError.airPressure }
            guard let airTemperature = self.parameter(.airTemperature)?.value as? Double else { throw SMHIWeatherDataMissingError.airTemperature }
            guard let horizontalVisibility = self.parameter(.horizontalVisibility)?.value as? Double else { throw SMHIWeatherDataMissingError.horizontalVisibility }
            guard let windDirection = self.parameter(.windDirection)?.value as? Double else { throw SMHIWeatherDataMissingError.windDirection }
            guard let windSpeed = self.parameter(.windSpeed)?.value as? Double else { throw SMHIWeatherDataMissingError.windSpeed }
            guard let windGustSpeed = self.parameter(.windGustSpeed)?.value as? Double else { throw SMHIWeatherDataMissingError.windGustSpeed }
            guard let relativeHumidity = self.parameter(.relativeHumidity)?.value as? Int else { throw SMHIWeatherDataMissingError.relativeHumidity }
            guard let thunderProbability = self.parameter(.thunderProbability)?.value as? Int else { throw SMHIWeatherDataMissingError.thunderProbability }
            guard let totalCloudCover = self.parameter(.totalCloudCover)?.value as? Int else { throw SMHIWeatherDataMissingError.totalCloudCover }
            guard let lowLevelCloudCover = self.parameter(.lowLevelCloudCover)?.value as? Int else { throw SMHIWeatherDataMissingError.lowLevelCloudCover }
            guard let mediumLevelCloudCover = self.parameter(.mediumLevelCloudCover)?.value as? Int else { throw SMHIWeatherDataMissingError.mediumLevelCloudCover }
            guard let highLevelCloudCover = self.parameter(.highLevelCloudCover)?.value as? Int else { throw SMHIWeatherDataMissingError.highLevelCloudCover }
            guard let minPrecipitation = self.parameter(.minPrecipitation)?.value as? Double else { throw SMHIWeatherDataMissingError.minPrecipitation }
            guard let maxPrecipitation = self.parameter(.maxPrecipitation)?.value as? Double else { throw SMHIWeatherDataMissingError.maxPrecipitation }
            guard let frozenPrecipitationPercentage = self.parameter(.frozenPrecipitationPercentage)?.value as? Int else { throw SMHIWeatherDataMissingError.frozenPrecipitationPercentage }
            guard let meanPrecipitationIntensity = self.parameter(.meanPrecipitationIntensity)?.value as? Double else { throw SMHIWeatherDataMissingError.meanPrecipitationIntensity }
            guard let medianPrecipitationIntensity = self.parameter(.medianPrecipitationIntensity)?.value as? Double else { throw SMHIWeatherDataMissingError.medianPrecipitationIntensity }
            guard let s = symbol else { throw SMHIWeatherDataMissingError.weatherSymbol }
            guard let feelsLike = temperatureFeelsLike else { throw SMHIWeatherDataMissingError.weatherSymbol }

            return WeatherData(
                dateTimeRepresentation: validTime,
                airPressure: airPressure,
                airTemperature: airTemperature,
                airTemperatureFeelsLike: feelsLike,
                horizontalVisibility: horizontalVisibility,
                windDirection: windDirection,
                windSpeed: windSpeed,
                windGustSpeed: windGustSpeed,
                relativeHumidity: relativeHumidity,
                thunderProbability: thunderProbability,
                totalCloudCover: totalCloudCover,
                lowLevelCloudCover: lowLevelCloudCover,
                mediumLevelCloudCover: mediumLevelCloudCover,
                highLevelCloudCover: highLevelCloudCover,
                minPrecipitation: minPrecipitation,
                maxPrecipitation: maxPrecipitation,
                frozenPrecipitationPercentage: frozenPrecipitationPercentage,
                meanPrecipitationIntensity: meanPrecipitationIntensity,
                medianPrecipitationIntensity: medianPrecipitationIntensity,
                precipitationCategory: precipitation,
                symbol: s,
                latitude: coordinates.latitude,
                longitude: coordinates.longitude
            )
        }
    }
    public struct Geometry : Codable {
        let type:String
        let coordinates:[[Double]]
    }
    public let approvedTime:String
    public let referenceTime:String
    public let geometry:Geometry
    public let timeSeries: [TimeSeries]
}

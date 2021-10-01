//
//  File.swift
//  
//
//  Created by Tomas Green on 2021-06-11.
//

import Foundation

fileprivate func getHeatIndex(temperature t:Double,humidity r:Double) -> Double {
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
fileprivate func getEffectiveTemperature(temperature t:Double,wind v:Double) -> Double {
    /// https://www.smhi.se/kunskapsbanken/meteorologi/vindens-kyleffekt-1.259
    //Observera att formeln inte ska användas för vindhastigheter under 2 m/s eller över 35 m/s för temperaturer över +10°C eller under -40°C.
    if t > 10 || t < -40 || v < 2 || v > 35{
        return t
    }
    return 13.12 + 0.6215 * t - 13.956 * pow(v, 0.16) + 0.48669 * t * pow(v, 0.16)
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
public struct SMHIWeather : Codable {
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
            return getEffectiveTemperature(temperature: getHeatIndex(temperature: t, humidity: r), wind: v)
        }
        public var heatIndex:Double? {
            guard let t = parameter(.airTemperature)?.value as? Double, let r = parameter(.relativeHumidity)?.values.first else {
                return nil
            }
            return getHeatIndex(temperature: t, humidity: r)
        }
        public var effectiveTemperature:Double? {
            guard let t = parameter(.airTemperature)?.value as? Double,let v = parameter(.windSpeed)?.values.first else {
                return nil
            }
            return getEffectiveTemperature(temperature: t, wind: v)
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
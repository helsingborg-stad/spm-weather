//
//  File.swift
//  
//
//  Created by Tomas Green on 2021-08-10.
//

import Foundation

public enum WeatherSymbol : String, Equatable {
    case clearSky
    case nearlyClearSky
    case variableCloudiness
    case halfclearSky
    case cloudySky
    case overcast
    case fog
    case lightRainShowers
    case moderateRainShowers
    case heavyRainShowers
    case thunderstorm
    case lightSleetShowers
    case moderateSleetShowers
    case heavySleetShowers
    case lightSnowShowers
    case moderateSnowShowers
    case heavySnowShowers
    case lightRain
    case moderateRain
    case heavyRain
    case thunder
    case lightSleet
    case moderateSleet
    case heavySleet
    case lightSnowfall
    case moderateSnowfall
    case heavySnowfall
    public var emoji:String {
        switch self {
        case .clearSky: return "☀️"
        case .nearlyClearSky: return "🌤"
        case .variableCloudiness: return "⛅️"
        case .halfclearSky: return "⛅️"
        case .cloudySky: return "🌥"
        case .overcast: return "☁️"
        case .fog: return "🌫"
        case .lightRainShowers: return "🌧"
        case .moderateRainShowers: return "🌧"
        case .heavyRainShowers: return "💧"
        case .thunderstorm: return "⛈"
        case .lightSleetShowers: return "🌨"
        case .moderateSleetShowers: return "🌨"
        case .heavySleetShowers: return "💧"
        case .lightSnowShowers: return "🌧"
        case .moderateSnowShowers: return "🌧"
        case .heavySnowShowers: return "🌧"
        case .lightRain: return "🌧"
        case .moderateRain: return "🌧"
        case .heavyRain: return "🌧"
        case .thunder: return "⚡️"
        case .lightSleet: return "🌨"
        case .moderateSleet: return "🌨"
        case .heavySleet: return "🌨"
        case .lightSnowfall: return "🌨"
        case .moderateSnowfall: return "🌨"
        case .heavySnowfall: return "❄️"
        }
    }
    public var sfSymbol:String {
        switch self {
        case .clearSky: return "sub.max.fill"
        case .nearlyClearSky: return "cloud.sun.fill"
        case .variableCloudiness: return "cloud.sun.fill"
        case .halfclearSky: return "cloud.sun.fill"
        case .cloudySky: return "cloud.fill"
        case .overcast: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .lightRainShowers: return "cloud.drizzle.fill"
        case .moderateRainShowers: return "cloud.rain.fill"
        case .heavyRainShowers: return "cloud.heavyrain.fill"
        case .thunderstorm: return "cloud.bolt.fill"
        case .lightSleetShowers: return "cloud.sleet.fill"
        case .moderateSleetShowers: return "cloud.sleet.fill"
        case .heavySleetShowers: return "cloud.sleet.fill"
        case .lightSnowShowers: return "cloud.snow.fill"
        case .moderateSnowShowers: return "cloud.snow.fill"
        case .heavySnowShowers: return "cloud.snow.fill"
        case .lightRain: return "cloud.rain.fill"
        case .moderateRain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .thunder: return "cloud.sun.bolt.fill"
        case .lightSleet: return "cloud.sleet.fill"
        case .moderateSleet: return "cloud.sleet.fill"
        case .heavySleet: return "cloud.sleet.fill"
        case .lightSnowfall: return "cloud.snow.fill"
        case .moderateSnowfall: return "cloud.snow.fill"
        case .heavySnowfall: return "snow"
        }
    }
}
public enum WeatherPrecipitation : String, Equatable {
    case none
    case snow
    case snowAndRain
    case rain
    case drizzle
    case freezingRain
    case freezingDrizzle
    public var emoji:String {
        switch self {
        case .none: return ""
        case .snow: return "❄️"
        case .snowAndRain: return "❄️"
        case .rain: return "💧"
        case .drizzle: return "💧"
        case .freezingRain: return "💧"
        case .freezingDrizzle: return "💧"
        }
    }
}
public struct WeatherData : Equatable,Identifiable {
    public struct Value {
        var value:Any
        var unit:String?
    }
    public var id:String {
        "weather-at-\(dateTimeRepresentation)"
    }
    public let isForcast:Bool
    public let dateTimeRepresentation:Date
    public let airPressure:Double
    public let airTemperature:Double
    public let airTemperatureFeelsLike:Double
    public let horizontalVisibility:Double
    
    public let windDirection:Double
    public let windSpeed:Double
    public let windGustSpeed:Double
    
    public let relativeHumidity:Int
    public let thunderProbability:Int
    
    public let totalCloudCover:Int
    public let lowLevelCloudCover:Int
    public let mediumLevelCloudCover:Int
    public let highLevelCloudCover:Int
    
    public let minPrecipitation:Double
    public let maxPrecipitation:Double
    public let frozenPrecipitationPercentage:Int
    
    public let meanPrecipitationIntensity:Double
    public let medianPrecipitationIntensity:Double
    
    public let precipitationCategory:WeatherPrecipitation
    public let symbol:WeatherSymbol
    public let latitude:Double
    public let longitude:Double
    public init(
        isForcast:Bool = true,
        
        dateTimeRepresentation:Date,
        airPressure:Double,
        airTemperature:Double,
        airTemperatureFeelsLike:Double,
        horizontalVisibility:Double,
        
        windDirection:Double,
        windSpeed:Double,
        windGustSpeed:Double,
        
        relativeHumidity:Int,
        thunderProbability:Int,
        
        totalCloudCover:Int,
        lowLevelCloudCover:Int,
        mediumLevelCloudCover:Int,
        highLevelCloudCover:Int,
        
        minPrecipitation:Double,
        maxPrecipitation:Double,
        frozenPrecipitationPercentage:Int,
        
        meanPrecipitationIntensity:Double,
        medianPrecipitationIntensity:Double,
        
        precipitationCategory:WeatherPrecipitation,
        symbol:WeatherSymbol,
        latitude: Double,
        longitude: Double) {
            self.isForcast = isForcast
            self.dateTimeRepresentation = dateTimeRepresentation
            self.airPressure = airPressure
            self.airTemperature = airTemperature
            self.airTemperatureFeelsLike = airTemperatureFeelsLike
            self.horizontalVisibility = horizontalVisibility
            
            self.windDirection = windDirection
            self.windSpeed = windSpeed
            self.windGustSpeed = windGustSpeed
            
            self.relativeHumidity = relativeHumidity
            self.thunderProbability = thunderProbability
            
            self.totalCloudCover = totalCloudCover
            self.lowLevelCloudCover = lowLevelCloudCover
            self.mediumLevelCloudCover = mediumLevelCloudCover
            self.highLevelCloudCover = highLevelCloudCover
            
            self.minPrecipitation = minPrecipitation
            self.maxPrecipitation = maxPrecipitation
            self.frozenPrecipitationPercentage = frozenPrecipitationPercentage
            
            self.meanPrecipitationIntensity = meanPrecipitationIntensity
            self.medianPrecipitationIntensity = medianPrecipitationIntensity
            
            self.precipitationCategory = precipitationCategory
            self.symbol = symbol
            self.latitude = latitude
            self.longitude = longitude
        }
}

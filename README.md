# Weather

Weather privides a common interface that supplies weather data form any service implementing the `WeatherService` protocol. 

## Usage
```swift
let weather = Weather(service:MyWeatherService())
weather.closest().sink { data in 
    print(data?.symbol.emoji)
}.store(in: &publishers)
weather.coordinates = .init(latitude: 56.046411, longitude: 12.694454) 
```

## TODO

- [_] add list of services
- [_] code-documentation
- [_] write tests
- [_] complete package documentation

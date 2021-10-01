import XCTest
import Combine
@testable import Weather

final class WeatherTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    @available(iOS 14.0, *) func testObservation() {
        let expectation = XCTestExpectation(description: "Fetch SMHI data")
        SMHIObservations.publisher(forStation: "karlstad", parameter: "1", period: "latest-hour").sink(receiveCompletion: { compl in
            switch compl {
            case .failure(let error):
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            case .finished:debugPrint("finished")
            }
        }, receiveValue: { val in
            guard let value = val.value.first else {
                XCTFail("no values")
                expectation.fulfill()
                return
            }
            if val.parameter.key == "13", let str = SMHIWeatherConditionCodes[value.value] {
                debugPrint(str)
            } else if val.parameter.key == "1" {
                debugPrint(value.value + "°")
            }
            expectation.fulfill()
        }).store(in: &self.cancellables)
        wait(for: [expectation], timeout: 10.0)
    }
    func testObservations() {
        let expectation = XCTestExpectation(description: "Fetch SMHI realtime data")
        SMHI().fetchRealtimeData().sink { compl in
            switch compl {
            case .failure(let error):
                XCTFail(error.localizedDescription)
                expectation.fulfill()
            case .finished:
                debugPrint("finished fetchRealtimeData")
            }
        } receiveValue: { data in
            data.resource.first(where: { $0.key == "13" })?.fetchPublisher.sink { compl in
                switch compl {
                case .failure(let error):
                    debugPrint(error)
                    XCTFail(error.localizedDescription)
                    expectation.fulfill()
                case .finished:
                    debugPrint("finished fetch stations")
                }
            } receiveValue: { param in
                guard let s = param.station.filter({ $0.active }) .first(where: { $0.name.lowercased().contains("karlstad")}) else {
                    XCTFail("no station")
                    expectation.fulfill()
                    return
                }
                s.fetchPublisher.sink(receiveCompletion: { compl in
                    switch compl {
                    case .failure(let error):
                        XCTFail(error.localizedDescription)
                        expectation.fulfill()
                    case .finished:
                        debugPrint("finished fetch station details")
                    }
                }, receiveValue: { details in
                    guard let d = details.period.first(where: { $0.key == "latest-hour"}) else {
                        XCTFail("no hour?")
                        expectation.fulfill()
                        return
                    }
                    d.fetchPublisher.sink(receiveCompletion: { compl in
                        switch compl {
                        case .failure(let error):
                            XCTFail(error.localizedDescription)
                            expectation.fulfill()
                        case .finished:
                            debugPrint("finished latest-hour")
                        }
                    }, receiveValue: { periodDetails in
                        guard let pd = periodDetails.data.first else {
                            XCTFail("no periodDetails?")
                            return
                        }
                        pd.fetchPublisher.sink(receiveCompletion: { compl in
                            switch compl {
                            case .failure(let error):
                                XCTFail(error.localizedDescription)
                                expectation.fulfill()
                            case .finished:debugPrint("finished")
                            }
                        }, receiveValue: { val in
                            guard let value = val.value.first else {
                                XCTFail("no values")
                                expectation.fulfill()
                                return
                            }
                            if val.parameter.key == "13", let str = SMHIWeatherConditionCodes[value.value] {
                                debugPrint(str)
                            } else if val.parameter.key == "1" {
                                debugPrint(value.value + "°")
                            }
                            expectation.fulfill()
                        }).store(in: &self.cancellables)
                    }).store(in: &self.cancellables)
                }).store(in: &self.cancellables)
            }.store(in: &self.cancellables)
        }.store(in: &self.cancellables)
        wait(for: [expectation], timeout: 10.0)
    }
    func testForeacast() {
        let expectation = XCTestExpectation(description: "Fetch SMHI realtime data")
        
        SMHI().fetch(using: .init(latitude: 56.0014127, longitude: 12.7416203)).sink { err in
            XCTFail(String(describing: err))
        } receiveValue: { w in

            expectation.fulfill()
        }.store(in: &cancellables)

        
        wait(for: [expectation], timeout: 10.0)
    }
}

//
//  File.swift
//  
//
//  Created by Tomas Green on 2021-10-01.
//

// https://opendata.smhi.se/apidocs/metobs/index.html
import Foundation
import Combine

struct SMHIObservations {
    @available(iOS 14.0, *) static func publisher(forStation station:String, parameter key:String, period:String)  -> AnyPublisher<Value,Error> {
        return Root.fetchPublisher
            .flatMap { $0.resource.first(where: { $0.key == key }).publisher }
            .flatMap { $0.fetchPublisher }
            .flatMap { $0.station.first(where: { $0.active == true && $0.name.lowercased().contains(station)}).publisher }
            .flatMap { $0.fetchPublisher }
            .flatMap { $0.period.first(where: { $0.key == period }).publisher }
            .flatMap { $0.fetchPublisher }
            .flatMap { $0.data.first.publisher }
            .flatMap { $0.fetchPublisher }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    struct Link : Codable,Equatable {
        let rel: String
        let type: String
        let href: URL
    }
    struct Resource: Codable, Equatable {
        struct GeoBox: Codable, Equatable {
            let minLatitude:Double
            let minLongitude:Double
            let maxLatitude:Double
            let maxLongitude:Double
        }
        let geoBox:GeoBox
        let key:String
        let updated:Date
        let title:String
        let summary:String
        let link: [Link]
        var fetchPublisher: AnyPublisher<SMHIObservations.Parameter,Error>  {
            guard let l = link.first(where: { $0.type == "application/json"}) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return URLSession.shared.dataTaskPublisher(for: l.href)
                .tryMap {$0.data}
                .decode(type: SMHIObservations.Parameter.self, decoder: decoder)
                .eraseToAnyPublisher()
        }
    }
    struct Root : Codable, Equatable {
        let key:String
        let updated:Date
        let title:String
        let summary:String
        let link: [Link]
        let resource: [Resource]
        static var fetchPublisher: AnyPublisher<Root,Error>  {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            guard let url = URL(string: "https://opendata-download-metobs.smhi.se/api/version/latest.json") else {
                return Fail(error: SMHIError.badURL).eraseToAnyPublisher()
            }
            return URLSession.shared.dataTaskPublisher(for: url)
                .tryMap {$0.data}
                .decode(type: Root.self, decoder: decoder)
                .eraseToAnyPublisher()
        }
    }
    struct Station : Codable, Equatable {
        let name: String
        let owner: String
        let ownerCategory: String
        let id: Double
        let height: Double
        let latitude: Double
        let longitude: Double
        let active: Bool
        let from: Date
        let to: Date
        let key: String
        let updated: Date
        let title: String
        let summary: String
        let link: [Link]
        var fetchPublisher: AnyPublisher<SMHIObservations.ParamaterDetails,Error>  {
            guard let l = link.first(where: { $0.type == "application/json"}) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return URLSession.shared.dataTaskPublisher(for: l.href)
                .tryMap {$0.data}
                .decode(type: SMHIObservations.ParamaterDetails.self, decoder: decoder)
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    struct Parameter : Codable, Equatable {
        let key:String
        let updated:Date
        let title:String
        let summary:String
        let valueType:String
        let station:[Station]
        let stationSet:[StationSet]?
    }
    struct StationSet:Codable,Equatable {
        let key:String
        let updated:Date
        let title:String
        let summary:String
        let link:[Link]
    }
    struct Position: Codable, Equatable {
        let from:Double
        let to:Double
        let height:Double
        let latitude:Double
        let longitude:Double
    }
    struct Period: Codable, Equatable {
        let key:String
        let updated:Date
        let title:String
        let summary:String
        let link:[Link]
        var fetchPublisher: AnyPublisher<SMHIObservations.PeriodDetails,Error>  {
            guard let l = link.first(where: { $0.type == "application/json"}) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return URLSession.shared.dataTaskPublisher(for: l.href)
                .tryMap {$0.data}
                .decode(type: SMHIObservations.PeriodDetails.self, decoder: decoder)
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    struct PeriodDetails: Codable, Equatable {
        let key:String
        let updated:Date
        let title:String
        let summary:String
        let from:Date
        let to:Date
        let link:[Link]
        let data:[PeriodData]
    }
    struct PeriodData: Codable, Equatable {
        let key:String?
        let updated:Date
        let title:String
        let summary:String
        let link: [Link]
        var fetchPublisher: AnyPublisher<SMHIObservations.Value,Error>  {
            guard let l = link.first(where: { $0.type == "application/json"}) else {
                return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return URLSession.shared.dataTaskPublisher(for: l.href)
                .map { $0.data }
                .decode(type: SMHIObservations.Value.self, decoder: decoder)
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    struct ParamaterDetails: Codable, Equatable {
        let key:String
        let updated:Date
        let title:String
        let owner:String
        let ownerCategory:String
        let active:Bool
        let summary:String
        let from:Int
        let to:Int
        let position:[Position]
        let period:[Period]
        let link:[Link]
    }

    struct Value: Codable, Equatable {
        struct ValueData: Codable, Equatable {
            let date:Date
            let value:String
            let quality:String
        }
        struct ValueParameter: Codable, Equatable {
            let key:String
            let name:String
            let summary:String
            let unit:String
        }
        struct ValueStation: Codable, Equatable {
            let key:String
            let name:String
            let owner:String
            let ownerCategory:String
            let height:Double
        }
        struct ValuePeriod: Codable, Equatable {
            let key:String
            let from:Date
            let to:Date
            let summary:String
            let sampling:String
        }
        let value:[ValueData]
        let updated:Date
        let parameter:ValueParameter
        let station:ValueStation
        let period:ValuePeriod
        let position:[Position]
        let link:[Link]
    }
}
struct SMHIWeatherConditionCodes {
    static let shared = SMHIWeatherConditionCodes()
    private let dict:[String:String]
    static subscript(key: String) -> String? {
        get {
            shared.dict[key]
        }
    }
    private init() {
        var dict = [String:String]()
        dict["0"] = "Molnens utveckling har icke kunnat observeras eller icke observerats"
        dict["1"] = "Moln har upplösts helt eller avtagit i utsträckning, i mäktighet eller i täthet"
        dict["2"] = "Molnhimlen i stort sett oförändrad"
        dict["3"] = "Moln har bildats eller tilltagit i utsträckning, i mäktighet eller i täthet"
        dict["4"] = "Sikten nedsatt av brandrök eller fabriksrök"
        dict["5"] = "Torrdis (solrök)"
        dict["6"] = "Stoft svävar i luften, men uppvirvlas ej av vinden vid observationsterminen ."
        dict["7"] = "Stoft eller sand uppvirvlas av vinden men ingen utpräglad sandvirvel och ingen sandstorm inom synhåll"
        dict["8"] = "Utpräglad stoft- eller sandvirvel vid obsterminen eller under senaste timmen meningen sandstorm"
        dict["9"] = "Sandstorm under senaste timmen eller inom synhåll vid obs-terminen"
        dict["10"] = "Fuktdis med sikt 1-10 km"
        dict["11"] = "Låg dimma i bankar på stationen, skiktets mäktighet överstiger ej 2 m på land eller 10 m till sjöss"
        dict["12"] = "Mer eller mindre sammanhängande låg dimma på stationen, skiktets mäktighet överstiger ej 2 m på land eller 10 m till sjöss"
        dict["13"] = "Kornblixt"
        dict["14"] = "Nederbörd inom synhåll, som ej når marken eller havsytan (fallstrimmor)"
        dict["15"] = "Nederbörd, som når marken eller havsytaninom synhåll på ett avstånd större än 5 km från stationen"
        dict["16"] = "Nederbörd, som når marken eller havsytan inom synhåll på ett avstånd mindre än 5 km, men ej på stationen"
        dict["17"] = "Åska vid observationsterminen men ingen nederbörd på stationen"
        dict["18"] = "Utpräglade starka vindbyar på stationen eller inom synhåll vid obs-terminen eller under senaste timmen"
        dict["19"] = "Skydrag eller tromb på stationen eller inom synhåll vid obs-terminen eller under senaste timmen"
        dict["20"] = "Duggregn eller kornsnö under senaste timmen men ej vid observationsterterminen"
        dict["21"] = "Regn under senaste timmen men ej vid observationsterterminen"
        dict["22"] = "Snöfall under senaste timmen men ej vid observationsterterminen"
        dict["23"] = "Snöblandat regn eller iskorn under senaste timmen men ej vid observationsterterminen"
        dict["24"] = "Underkylt regn eller duggregn under senaste timmen men ej vid observationsterterminen"
        dict["25"] = "Regnskura runder senaste timmen men ej vid observationsterterminen"
        dict["26"] = "Byar av snö eller snöblandat regn under senaste timmen men ej vid observationsterterminen"
        dict["27"] = "Byar av hagel med eller utan regn under senaste timmen men ej vid observationsterterminen"
        dict["28"] = "Dimma under senaste timmen men ej vid observationsterterminen"
        dict["29"] = "Åska (med eller utan nederbörd) under senaste timmen men ej vid observationsterterminen"
        dict["30"] = "Lätt eller måttlig sandstorm har avtagit istyrka under senaste timmen"
        dict["31"] = "Lätt eller måttlig sandstorm utan märkbar förändring under senaste timmen"
        dict["32"] = "Lätt eller måttlig sandstorm har börjat eller tilltagit i styrka under senaste timmen"
        dict["33"] = "Kraftig sandstorm har avtagit i styrka under senaste timmen"
        dict["34"] = "Kraftig sandstorm utan märkbar förändring under senaste timmen"
        dict["35"] = "Kraftig sandstorm har börjat eller tilltagit i styrka under senaste timmen"
        dict["36"] = "Lågt och lätt eller måttligt snödrev"
        dict["37"] = "Lågt men tätt snödrev"
        dict["38"] = "Högt men lätt eller måttligt snödrev"
        dict["39"] = "Högt och tätt snödrev"
        dict["40"] = "Dimma inom synhåll vid observationsterminen, nående över ögonhöjd (dock ej dimma på stationen under senaste timmen) (VV ?10)"
        dict["41"] = "Dimma i bankar på stationen (VV< 10)"
        dict["42"] = "Dimma, med skymt av himlen, har blivit lättare under senaste timmen"
        dict["43"] = "Dimma, utan skymt av himlen, har blivit lättare under senaste timmen"
        dict["44"] = "Dimma, med skymt av himlen, oförändrad under senaste timmen"
        dict["45"] = "Dimma, utan skymt av himlen, oförändrad under senaste timmen"
        dict["46"] = "Dimma, med skymt av himlen, har börjat eller tätnat under senaste timmen"
        dict["47"] = "Dimma, utan skymt av himlen, har börjat eller tätnat under senaste timmen"
        dict["48"] = "Underkyld dimma, med skymt av himlen"
        dict["49"] = "Underkyld dimma, utan skymt av himlen"
        dict["50"] = "Lätt duggregn med avbrott"
        dict["51"] = "Lätt duggregn, ihållande"
        dict["52"] = "Måttligt duggregn med avbrott"
        dict["53"] = "Måttligt duggregn, ihållande"
        dict["54"] = "Tätt duggregn med avbrott"
        dict["55"] = "Tätt duggregn, ihållande"
        dict["56"] = "Lätt underkylt duggregn"
        dict["57"] = "Måttligt eller tätt underkylt duggregn"
        dict["58"] = "Lätt duggregn tillsammans med regn"
        dict["59"] = "Måttligt eller tätt duggregn tillsammans med regn"
        dict["60"] = "Lätt regn med avbrott"
        dict["61"] = "Lätt regn, ihållande"
        dict["62"] = "Måttligt regn med avbrott"
        dict["63"] = "Måttligt regn, ihållande"
        dict["64"] = "Starkt regn med avbrott"
        dict["65"] = "Starkt regn ihållande"
        dict["66"] = "Lätt underkylt regn"
        dict["67"] = "Måttligt eller starkt underkylt regn"
        dict["68"] = "Lätt regn eller duggregn tillsammans med snö"
        dict["69"] = "Måttligt eller starkt regn eller duggregn tillsammans med snö"
        dict["70"] = "Lätt snöfall med avbrott"
        dict["71"] = "Lätt snöfall, ihållande"
        dict["72"] = "Måttligt snöfall med avbrott"
        dict["73"] = "Måttligt snöfall, ihållande"
        dict["74"] = "Tätt snöfall med avbrott"
        dict["75"] = "Tätt snöfall, ihållande"
        dict["76"] = "Isnålar (med el. utan dimma)"
        dict["77"] = "Kornsnö (med el. utan dimma)"
        dict["78"] = "Enstaka snöstjärnor (med el. utan dimma)"
        dict["79"] = "Iskorn"
        dict["80"] = "Lätta regnskurar"
        dict["81"] = "Måttliga eller kraftiga regnskurar"
        dict["82"] = "Mycket kraftiga regnskurar (skyfall)"
        dict["83"] = "Lätt snöblandat regn i byar"
        dict["84"] = "Måttligt eller kraftigt snöblandat regn i byar"
        dict["85"] = "Lätta snöbyar"
        dict["86"] = "Måttliga eller kraftiga snöbyar"
        dict["87"] = "Lätta byar av småhagel eller snöhagel (trindsnö) med eller utan regn eller snöblandat regn"
        dict["88"] = "Måttliga eller kraftiga byar av småhagel eller snöhagel (trindsnö) med eller utan regn eller snöblandat regn"
        dict["89"] = "Lätta byar av ishagel med eller utan regn eller snöblandat regn, utan åska"
        dict["90"] = "Måttliga eller kraftiga byar av ishagel med eller utan regn eller snöblandat regn, utan åska"
        dict["91"] = "Lätt regn vid observationsterminen, åskväder under senaste timmen men ej vid observationsterminen"
        dict["92"] = "Måttligt el. starkt regn vid observationsterminen, åskväder under senaste timmen men ej vid observationsterminen"
        dict["93"] = "Lätt snöfall, snöblandat regn eller hagel vid observationsterminen, åskväder under senaste timmen men ej vid observationsterminen"
        dict["94"] = "Måttligt el. starkt snöfall, snöblandat regn eller hagel vid observationsterminen, åskväder under senaste timmen men ej vid observationsterminen"
        dict["95"] = "Svagt eller måttligt åskväder vid observationsterminen utan hagel men med regn eller snö"
        dict["96"] = "Svagt eller måttligt åskväder vid observationsterminen med hagel"
        dict["97"] = "Kraftigt åskväder vid observationsterminen utan hagel men med regn eller snö"
        dict["98"] = "Kraftigt åskväder vid observationsterminen med sandstorm"
        dict["99"] = "Kraftigt åskväder vid observationsterminen med hagel"
        dict["100"] = "Inget signifikant väder observerat"
        dict["101"] = "Moln har upplösts helt eller avtagit i utsträckning, i mäktighet eller i täthet, under senste timmen"
        dict["102"] = "Molnhimlen i stort sett oförändrad under senste timmen"
        dict["103"] = "Moln har bildats eller tilltagit i utsträckning, i mäktighet eller i täthet, under senste timmen"
        dict["104"] = "Dis eller rök, eller stoft som är spritt i luften, sikt större eller lika med 1 km"
        dict["105"] = "Dis eller rök, eller stoft som är spritt i luften, sikt mindre än 1 km"
        dict["110"] = "Fuktdis med sikt 1-10 km"
        dict["111"] = "Isnålar"
        dict["112"] = "Blixt på avstånd"
        dict["118"] = "Utpräglade starka vindbyar"
        dict["120"] = "Dimma"
        dict["121"] = "Nederbörd"
        dict["122"] = "Duggregn eller kornsnö"
        dict["123"] = "Regn"
        dict["124"] = "Snöfall"
        dict["125"] = "Underkylt duggregn eller regn"
        dict["126"] = "Åskväder (med eller utan nederbörd)"
        dict["127"] = "Snödrev eller sandstorm"
        dict["128"] = "Snödrev eller sandstorm, sikt större eller lika med 1 km"
        dict["129"] = "Snödrev eller sandstorm, sikt mindre än 1 km"
        dict["130"] = "Dimma"
        dict["131"] = "Dimma i bankar på stationen"
        dict["132"] = "Dimma, har blivit lättare under senaste timmen"
        dict["133"] = "Dimma, oförändrad under senaste timmen"
        dict["134"] = "Dimma, har börjat eller tätnat under senaste timmen"
        dict["135"] = "Underkyld dimma"
        dict["140"] = "Nederbörd"
        dict["141"] = "Lätt eller måttlig nederbörd"
        dict["142"] = "Kraftig nederbörd"
        dict["143"] = "Flytande nederbörd, lätt eller måttlig"
        dict["144"] = "Flytande nederbörd, kraftig"
        dict["145"] = "Fast nederbörd, lätt eller måttlig"
        dict["146"] = "Fast nederbörd, kraftig"
        dict["147"] = "Lätt eller måttlig underkyld nederbörd"
        dict["148"] = "Kraftig underkyld nederbörd"
        dict["150"] = "Duggregn"
        dict["151"] = "Lätt duggregn"
        dict["152"] = "Måttligt duggregn"
        dict["153"] = "Tätt duggregn"
        dict["154"] = "Lätt underkylt duggregn"
        dict["155"] = "Måttligt underkylt duggregn"
        dict["156"] = "Tätt duggregn"
        dict["157"] = "Lätt duggregn tillsammans med regn"
        dict["158"] = "Måttligt eller tätt duggregn tillsammans med regn"
        dict["160"] = "Regn"
        dict["161"] = "Lätt regn"
        dict["162"] = "Måttligt regn"
        dict["163"] = "Starkt regn"
        dict["164"] = "Lätt underkylt regn"
        dict["165"] = "Måttligt underkylt regn"
        dict["166"] = "Starkt underkylt regn"
        dict["167"] = "Lätt regn eller duggregn tillsammans med snö"
        dict["168"] = "Måttligt eller starkt regn eller duggregn tillsammans med snö"
        dict["170"] = "Snöfall"
        dict["171"] = "Lätt snöfall"
        dict["172"] = "Måttligt snöfall"
        dict["173"] = "Tätt snöfall"
        dict["174"] = "Lätt småhagel"
        dict["175"] = "Måttligt småhagel"
        dict["176"] = "Kraftigt småhagel"
        dict["177"] = "Kornsnö"
        dict["178"] = "Isnålar"
        dict["180"] = "Regnskurar"
        dict["181"] = "Lätta regnskurar"
        dict["182"] = "Måttliga regnskurar"
        dict["183"] = "Kraftiga regnskurar"
        dict["184"] = "Mycket kraftiga regnskurar (skyfall)"
        dict["185"] = "Lätta snöbyar"
        dict["186"] = "Måttliga snöbyar"
        dict["187"] = "Kraftiga snöbyar"
        dict["189"] = "Hagel"
        dict["190"] = "Åskväder"
        dict["191"] = "Svagt eller måttligt åskväder utan nederbörd"
        dict["192"] = "Svagt eller måttligt åskväder med regnskurar eller snöbyar"
        dict["193"] = "Svagt eller måttligt åskväder med hagel"
        dict["194"] = "Kraftigt åskväder utan nederbörd"
        dict["195"] = "Kraftigt åskväder med regnskurar eller snöbyar"
        dict["196"] = "Kraftigt åskväder med hagel"
        dict["199"] = "Tromb eller Tornado"
        dict["204"] = "Vulkanaska som spridits högt upp i luften"
        dict["206"] = "Tjockt stoftdis, sikt mindre än 1 km"
        dict["207"] = "Vattenstänk vid station pga blåst"
        dict["208"] = "Drivande stoft (eller sand)"
        dict["209"] = "Kraftig stoft- eller sandstorm på avstånd (Haboob)"
        dict["210"] = "Snödis"
        dict["211"] = "Snöstorm eller kraftigt snödrev som ger extremt dålig sikt"
        dict["213"] = "Blixt mellan moln och marken"
        dict["217"] = "Åska utan regnskur"
        dict["219"] = "Tromb eller tornado (förödande) vid stationen eller inom synhåll under den senaste timmen"
        dict["220"] = "Avlagring av vulkanaska"
        dict["221"] = "Avlagring av stoft eller sand"
        dict["222"] = "Dagg"
        dict["223"] = "Utfällning av blöt snö"
        dict["224"] = "Lätt eller måttlig dimfrost"
        dict["225"] = "Kraftig dimfrost"
        dict["226"] = "Rimfrost"
        dict["227"] = "Kraftig isbeläggning pga underkyld nederbörd"
        dict["228"] = "Isskorpa"
        dict["230"] = "Stoft- eller sandstorm med temperatur under fryspunkten"
        dict["239"] = "Kraftigt snödrev och/eller snöfall"
        dict["241"] = "Dimma till havs"
        dict["242"] = "Dimma i dalgång"
        dict["243"] = "Sjörök i Arktis eller vid Antarktis"
        dict["244"] = "Advektionsdimma (över vatten)"
        dict["245"] = "Advektionsdimma (över land)"
        dict["246"] = "Dimma över is eller snö"
        dict["247"] = "Tät dimma, sikt 60-90 m"
        dict["248"] = "Tät dimma, sikt 30-60 m"
        dict["249"] = "Tät dimma, sikt mindre än 30 m"
        dict["250"] = "Duggregn, intensitet mindre än 0,10 mm/timme"
        dict["251"] = "Duggregn, intensitet 0,10-0,19 mm/timme"
        dict["252"] = "Duggregn, intensitet 0,20-0,39 mm/timme"
        dict["253"] = "Duggregn, intensitet 0,40-0,79 mm/timme"
        dict["254"] = "Duggregn, intensitet 0,80-1,59 mm/timme"
        dict["255"] = "Duggregn, intensitet 1,60-3,19 mm/timme"
        dict["256"] = "Duggregn, intensitet 3,20-6,39 mm/timme"
        dict["257"] = "Duggregn, intensitet större än 6,40 mm/timme"
        dict["259"] = "Duggregn och snöfall"
        dict["260"] = "Regn, intensitet mindre än 1,0 mm/timme"
        dict["261"] = "Regn, intensitet 1,0-1,9 mm/timme"
        dict["262"] = "Regn, intensitet 2,0-3,9 mm/timme"
        dict["263"] = "Regn, intensitet 4,0-7,9 mm/timme"
        dict["264"] = "Regn, intensitet 8,0-15,9 mm/timme"
        dict["265"] = "Regn, intensitet 16,0-31,9 mm/timme"
        dict["266"] = "Regn, intensitet 32,0-63,9 mm/timme"
        dict["267"] = "Regn, intensitet större än 64,0 mm/timme"
        dict["270"] = "Snö, intensitet mindre än 1,0 cm/timme"
        dict["271"] = "Snö, intensitet 1,0-1,9 cm/timme"
        dict["272"] = "Snö, intensitet 2,0-3,9 cm/timme"
        dict["273"] = "Snö, intensitet 4,0-7,9 cm/timme"
        dict["274"] = "Snö, intensitet 8,0-15,9 cm/timme"
        dict["275"] = "Snö, intensitet 16,0-31,9 cm/timme"
        dict["276"] = "Snö, intensitet 32,0-63,9 cm/timme"
        dict["277"] = "Snö, intensitet större än 64,0 cm/timme"
        dict["278"] = "Snöfall eller isnålar från en klar himmel"
        dict["279"] = "Frysande blötsnö"
        dict["280"] = "Regn"
        dict["281"] = "Underkylt regn"
        dict["282"] = "Snöblandat regn"
        dict["283"] = "Snöfall"
        dict["284"] = "Småhagel eller snöhagel"
        dict["285"] = "Småhagel eller snöhagel tillsammans med regn"
        dict["286"] = "Småhagel eller snöhagel tillsammans med snöblandat regn"
        dict["287"] = "Småhagel eller snöhagel tillsammans med snö"
        dict["288"] = "Hagel"
        dict["289"] = "Hagel tillsammans med regn"
        dict["290"] = "Hagel tillsammans med snöblandat regn"
        dict["291"] = "Hagel tillsammans med snö"
        dict["292"] = "Skurar eller åska till havs"
        dict["293"] = "Skurar eller åska över berg"
        dict["508"] = "Inga signifikanta fenomen att rapportera, rådande och gammalt väder utelämnas"
        dict["509"] = "Ingen observation, data ej tillgängligt, rådande och gammalt väder utelämnas"
        dict["510"] = "Rådande och gammalt väder saknas men förväntades."
        dict["511"] = "Saknat värde"
        self.dict = dict
    }
}

import Foundation

enum CuisineGroup: String, CaseIterable, Hashable, Identifiable {
    case italian = "Italian"
    case mexican = "Mexican"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case indian = "Indian"
    case thai = "Thai"
    case korean = "Korean"
    case vietnamese = "Vietnamese"
    case french = "French"
    case spanish = "Spanish"
    case greek = "Greek"
    case turkish = "Turkish"
    case lebanese = "Lebanese"
    case persian = "Persian"
    case moroccan = "Moroccan"
    case ethiopian = "Ethiopian"
    case egyptian = "Egyptian"
    case westAfrican = "West African"
    case southAfrican = "South African"
    case caribbean = "Caribbean"
    case jamaican = "Jamaican"
    case brazilian = "Brazilian"
    case peruvian = "Peruvian"
    case argentine = "Argentine"
    case american = "American"
    case southernAmerican = "Southern American"
    case cajunCreole = "Cajun/Creole"
    case texMex = "Tex-Mex"
    case german = "German"
    case british = "British"
    case irish = "Irish"
    case polish = "Polish"
    case russian = "Russian"
    case ukrainian = "Ukrainian"
    case scandinavian = "Scandinavian"
    case filipino = "Filipino"
    case indonesian = "Indonesian"
    case malaysian = "Malaysian"
    case singaporean = "Singaporean"
    case pakistani = "Pakistani"
    case bangladeshi = "Bangladeshi"
    case sriLankan = "Sri Lankan"
    case nepalese = "Nepalese"
    case afghan = "Afghan"
    case israeli = "Israeli"
    case middleEastern = "Middle Eastern"
    case hawaiian = "Hawaiian"
    case australian = "Australian"
    case other = "Other"

    var id: String { rawValue }
    var title: String { rawValue }

    static func group(for dish: DishReference) -> CuisineGroup {
        let cuisineMetadata = [dish.cuisine]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for rule in rules where rule.matches(cuisineMetadata) {
            return rule.group
        }

        let metadata = ([dish.region] + dish.countries)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for rule in rules where rule.matches(metadata) {
            return rule.group
        }

        return .other
    }

    private static let rules: [Rule] = [
        Rule(.cajunCreole, ["cajun", "creole"]),
        Rule(.texMex, ["tex mex", "tex-mex", "texmex"]),
        Rule(.southernAmerican, ["southern american", "southern u s", "american south", "lowcountry", "soul food", "appalachian"]),
        Rule(.hawaiian, ["hawaiian", "hawaii"]),
        Rule(.italian, ["italian", "roman", "sicilian", "neapolitan", "tuscan", "venetian", "lazio", "italy"]),
        Rule(.mexican, ["mexican", "oaxacan", "yucatecan", "sinaloan", "jaliscan", "marisqueria", "marisquerias", "mexico"]),
        Rule(.chinese, ["chinese", "cantonese", "sichuan", "szechuan", "hunan", "shanghainese", "beijing", "hong kong", "china"]),
        Rule(.japanese, ["japanese", "okinawan", "kyoto", "tokyo", "japan"]),
        Rule(.indian, ["indian", "south indian", "north indian", "bengali indian", "goan", "gujarati", "punjabi", "tamil", "kerala", "india"]),
        Rule(.thai, ["thai", "northern thai", "southern thai", "isan", "isaan", "bangkok", "thailand"]),
        Rule(.korean, ["korean", "korea", "south korea"]),
        Rule(.vietnamese, ["vietnamese", "viet", "vietnam"]),
        Rule(.french, ["french", "provencal", "provence", "brittany", "france"]),
        Rule(.spanish, ["spanish", "basque", "catalan", "galician", "andalusian", "spain"]),
        Rule(.greek, ["greek", "greece"]),
        Rule(.turkish, ["turkish", "turkey", "anatolian"]),
        Rule(.lebanese, ["lebanese", "lebanon"]),
        Rule(.persian, ["persian", "iranian", "iran"]),
        Rule(.moroccan, ["moroccan", "morocco"]),
        Rule(.ethiopian, ["ethiopian", "ethiopia"]),
        Rule(.egyptian, ["egyptian", "egypt"]),
        Rule(.westAfrican, ["west african", "nigerian", "ghanaian", "senegalese", "gambian", "cameroonian", "ivorian", "malian", "nigeria", "ghana", "senegal", "gambia", "cameroon", "ivory coast", "cote d ivoire", "mali"]),
        Rule(.southAfrican, ["south african", "south africa"]),
        Rule(.jamaican, ["jamaican", "jamaica"]),
        Rule(.caribbean, ["caribbean", "haitian", "trinidadian", "tobagonian", "cuban", "dominican", "puerto rican", "haiti", "trinidad", "tobago", "cuba", "dominican republic", "puerto rico"]),
        Rule(.brazilian, ["brazilian", "brazil"]),
        Rule(.peruvian, ["peruvian", "peru"]),
        Rule(.argentine, ["argentine", "argentinian", "argentina"]),
        Rule(.german, ["german", "austrian", "swiss", "bavarian", "alpine", "germany", "austria", "switzerland"]),
        Rule(.british, ["british", "english", "scottish", "welsh", "united kingdom", "england", "scotland", "wales"]),
        Rule(.irish, ["irish", "ireland"]),
        Rule(.polish, ["polish", "poland"]),
        Rule(.russian, ["russian", "russia"]),
        Rule(.ukrainian, ["ukrainian", "ukraine"]),
        Rule(.scandinavian, ["scandinavian", "swedish", "norwegian", "danish", "finnish", "icelandic", "sweden", "norway", "denmark", "finland", "iceland"]),
        Rule(.filipino, ["filipino", "philippine", "philippines"]),
        Rule(.indonesian, ["indonesian", "indonesia", "balinese", "javanese", "sumatran"]),
        Rule(.malaysian, ["malaysian", "malaysia"]),
        Rule(.singaporean, ["singaporean", "singapore"]),
        Rule(.pakistani, ["pakistani", "pakistan"]),
        Rule(.bangladeshi, ["bangladeshi", "bangladesh"]),
        Rule(.sriLankan, ["sri lankan", "sri-lankan", "sri lanka"]),
        Rule(.nepalese, ["nepalese", "nepali", "nepal"]),
        Rule(.afghan, ["afghan", "afghanistan"]),
        Rule(.israeli, ["israeli", "israel"]),
        Rule(.middleEastern, ["middle eastern", "arabian", "arabian peninsula", "levantine", "yemeni", "palestinian", "iraqi", "syrian", "jordanian", "gulf", "saudi", "omani", "emirati", "kuwaiti", "bahraini", "qatari", "yemen", "palestine", "iraq", "syria", "jordan", "saudi arabia", "oman", "united arab emirates", "kuwait", "bahrain", "qatar"]),
        Rule(.australian, ["australian", "australia"]),
        Rule(.american, ["american", "new england", "californian", "midwestern", "united states", "usa", "u s"])
    ]

    private struct Rule {
        let group: CuisineGroup
        private let phrases: [Phrase]

        init(_ group: CuisineGroup, _ phrases: [String]) {
            self.group = group
            self.phrases = phrases.map { Phrase($0) }
        }

        func matches(_ metadata: [String]) -> Bool {
            metadata.contains { value in
                let normalizedValue = value.discoveryNormalizedText
                let compactValue = normalizedValue.replacingOccurrences(of: " ", with: "")

                return phrases.contains { phrase in
                    normalizedValue.contains(phrase.normalized)
                        || compactValue.contains(phrase.compact)
                }
            }
        }

        private struct Phrase {
            let normalized: String
            let compact: String

            init(_ value: String) {
                self.normalized = value.discoveryNormalizedText
                self.compact = normalized.replacingOccurrences(of: " ", with: "")
            }
        }
    }
}

extension DishReference {
    var cuisineGroup: CuisineGroup {
        CuisineGroup.group(for: self)
    }

    var discoveryCardCuisineLabel: String {
        trimmedNonEmpty(cuisine) ?? trimmedNonEmpty(region) ?? CuisineGroup.other.title
    }

    var detailCuisineLabel: String? {
        trimmedNonEmpty(cuisine)
    }

    var formattedGeography: String {
        let cleanCountries = countries.compactMap(trimmedNonEmpty)
        let cleanRegion = trimmedNonEmpty(region)
        var pieces: [String] = []

        if !cleanCountries.isEmpty {
            pieces.append(cleanCountries.joined(separator: ", "))
        }

        if let cleanRegion,
           !cleanCountries.contains(where: { $0.discoveryNormalizedText == cleanRegion.discoveryNormalizedText }) {
            pieces.append(cleanRegion)
        }

        return pieces.joined(separator: " · ")
    }

    private func trimmedNonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    var discoveryNormalizedText: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

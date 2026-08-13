import Foundation

struct DishReference: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let alternateNames: [String]
    let countries: [String]
    let region: String
    let continent: String?
    let cuisine: String
    let category: String
    let familiarity: String
    let restaurantAccessibility: String?
    let shortDescription: String
    let longDescription: String
    let descriptionTags: [String]
    let dietaryTags: [String]
    let searchKeywords: [String]
    let originNote: String?
    let relatedDishes: [String]
    let contentStatus: String
    let createdAt: Date

    var searchableText: String {
        [
            name,
            alternateNames.joined(separator: " "),
            countries.joined(separator: " "),
            region,
            continent ?? "",
            cuisine,
            category,
            shortDescription,
            longDescription,
            descriptionTags.joined(separator: " "),
            dietaryTags.joined(separator: " "),
            searchKeywords.joined(separator: " ")
        ]
        .joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case alternateNames = "alternate_names"
        case countries
        case region
        case continent
        case cuisine
        case category
        case familiarity
        case restaurantAccessibility = "restaurant_accessibility"
        case shortDescription = "short_description"
        case longDescription = "long_description"
        case descriptionTags = "description_tags"
        case dietaryTags = "dietary_tags"
        case searchKeywords = "search_keywords"
        case originNote = "origin_note"
        case relatedDishes = "related_dishes"
        case contentStatus = "content_status"
        case createdAt = "created_at"
    }
}

#if DEBUG
extension DishReference {
    static let previewKimchiJjigaeID = UUID(uuidString: "3E923679-0E1F-4A77-99CC-5C76B5B53D8C") ?? UUID()
    static let previewCacioPepeID = UUID(uuidString: "D2E90E5E-0C33-4EDB-BF06-BD985C86F36A") ?? UUID()
    static let previewAguachileID = UUID(uuidString: "0D6E927D-F40F-4F32-AE34-B9F7D5D59737") ?? UUID()
    static let previewKhaoSoiID = UUID(uuidString: "9E41D42E-8C5B-4B5B-9E46-C34D4987C4F7") ?? UUID()
    static let previewMandiID = UUID(uuidString: "2B862681-5BB4-4F88-A8EC-20DEAD2D5001") ?? UUID()
    static let previewJollofRiceID = UUID(uuidString: "4D8DC05E-4343-4E50-81BA-2C0977C8D102") ?? UUID()
    static let previewFeijoadaID = UUID(uuidString: "9E4B68DA-B08A-4D52-BC5B-5EB394D4E103") ?? UUID()
    static let previewKasespatzleID = UUID(uuidString: "57D07F41-D142-4B4E-92B9-C7C32B911004") ?? UUID()
    static let previewDolmaID = UUID(uuidString: "A12C48A5-3F6B-4A0E-8C4D-14ED96B6A105") ?? UUID()
    static let previewNasiLemakID = UUID(uuidString: "6B1B5869-4F76-4A19-8C83-E6F6BD836106") ?? UUID()
    static let previewHangiID = UUID(uuidString: "8AE8E7D0-3430-4B61-8B7F-D17724629107") ?? UUID()
    static let previewShakingBeefID = UUID(uuidString: "6F5B23FE-5379-4AEC-AF3E-20F0C7A8F108") ?? UUID()

    static let previewCatalog: [DishReference] = [
        DishReference(
            id: previewKimchiJjigaeID,
            name: "Kimchi Jjigae",
            alternateNames: ["Kimchi stew"],
            countries: ["Korea"],
            region: "East Asia",
            continent: "Asia",
            cuisine: "Korean",
            category: "Stew",
            familiarity: "Familiar",
            restaurantAccessibility: "Common at Korean restaurants",
            shortDescription: "A hot, tangy stew built around aged kimchi, tofu, aromatics, and often pork or tuna.",
            longDescription: "Kimchi jjigae turns mature kimchi into a deep, sour, savory stew. The broth is usually spicy and comforting, with tofu and scallions softening the edge of the fermented cabbage.",
            descriptionTags: ["Spicy", "Tangy", "Comforting"],
            dietaryTags: ["Can be vegetarian"],
            searchKeywords: ["kimchi", "stew", "tofu", "Korean soup"],
            originNote: "A home-style Korean dish often made when kimchi has ripened past its freshest stage.",
            relatedDishes: ["Khao Soi"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_000)
        ),
        DishReference(
            id: previewCacioPepeID,
            name: "Cacio e Pepe",
            alternateNames: ["Cheese and pepper pasta"],
            countries: ["Italy"],
            region: "Europe",
            continent: "Europe",
            cuisine: "Roman",
            category: "Pasta",
            familiarity: "Familiar",
            restaurantAccessibility: "Common at Italian restaurants",
            shortDescription: "A Roman pasta where Pecorino Romano and black pepper emulsify into a glossy sauce.",
            longDescription: "Cacio e pepe is minimal but exacting: hot pasta water, grated Pecorino Romano, and cracked pepper come together around long pasta into a sharp, creamy coating.",
            descriptionTags: ["Peppery", "Cheesy", "Silky"],
            dietaryTags: ["Vegetarian"],
            searchKeywords: ["pasta", "pecorino", "Roman", "black pepper"],
            originNote: "Closely associated with Rome and Lazio's sheep-milk cheese traditions.",
            relatedDishes: ["Kimchi Jjigae"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_100)
        ),
        DishReference(
            id: previewAguachileID,
            name: "Aguachile",
            alternateNames: ["Shrimp aguachile"],
            countries: ["Mexico"],
            region: "North America",
            continent: "North America",
            cuisine: "Mexican",
            category: "Seafood",
            familiarity: "Discover",
            restaurantAccessibility: "Medium; common at marisquerias and seafood restaurants",
            shortDescription: "Raw shrimp cured quickly in lime and chile, served bright, cold, and sharply seasoned.",
            longDescription: "Aguachile is direct and vivid: seafood meets lime juice, fresh chile, cucumber, onion, and herbs. It lands lighter than many ceviches while still carrying serious heat.",
            descriptionTags: ["Bright", "Spicy", "Refreshing"],
            dietaryTags: ["Often contains seafood"],
            searchKeywords: ["shrimp", "lime", "ceviche", "mariscos"],
            originNote: "Often linked to Sinaloa and the seafood cooking of Mexico's Pacific coast.",
            relatedDishes: ["Cacio e Pepe"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_200)
        ),
        DishReference(
            id: previewKhaoSoiID,
            name: "Khao Soi",
            alternateNames: ["Chiang Mai curry noodles"],
            countries: ["Thailand"],
            region: "Southeast Asia",
            continent: "Asia",
            cuisine: "Northern Thai",
            category: "Noodles",
            familiarity: "Moderate",
            restaurantAccessibility: "High; available at many Thai restaurants",
            shortDescription: "Curry noodle soup with tender noodles, crunchy fried noodles, pickles, shallots, and lime.",
            longDescription: "Khao soi layers a coconut-rich curry broth with egg noodles and a crisp noodle crown. Pickled mustard greens, shallots, chile oil, and lime keep each bite lively.",
            descriptionTags: ["Curry", "Creamy", "Crunchy"],
            dietaryTags: ["Often contains meat", "Varies by preparation", "Contains gluten"],
            searchKeywords: ["curry", "noodles", "Thai", "coconut", "Chiang Mai"],
            originNote: "Associated with Northern Thailand, especially Chiang Mai, with influences from regional trade routes.",
            relatedDishes: ["Kimchi Jjigae", "Aguachile"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_300)
        ),
        DishReference(
            id: previewMandiID,
            name: "Mandi",
            alternateNames: ["Yemeni mandi"],
            countries: ["Yemen"],
            region: "Arabian Peninsula",
            continent: "Asia",
            cuisine: "Yemeni",
            category: "Rice dish",
            familiarity: "Moderate",
            restaurantAccessibility: "Medium; available at some Yemeni and Gulf restaurants",
            shortDescription: "Fragrant rice served with slow-cooked meat, warm spices, and a smoky depth from traditional oven cooking.",
            longDescription: "Mandi centers on spiced rice and tender meat, often lamb or chicken, cooked so the grains stay separate and perfumed. The best versions balance gentle heat, rendered juices, and smoke.",
            descriptionTags: ["Aromatic", "Smoky", "Savory"],
            dietaryTags: ["Contains meat"],
            searchKeywords: ["rice", "Yemeni", "lamb", "chicken", "Arabian"],
            originNote: "Closely associated with Yemen and the southern Arabian Peninsula.",
            relatedDishes: ["Khao Soi"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_400)
        ),
        DishReference(
            id: previewJollofRiceID,
            name: "Jollof Rice",
            alternateNames: ["Jollof"],
            countries: ["Nigeria", "Ghana", "Senegal"],
            region: "West Africa",
            continent: "Africa",
            cuisine: "West African",
            category: "Rice dish",
            familiarity: "Moderate",
            restaurantAccessibility: "Medium; available at many West African restaurants",
            shortDescription: "Tomato-rich rice cooked with aromatics, chile, and stock until every grain is deeply seasoned.",
            longDescription: "Jollof rice is a broad West African family of seasoned rice dishes. Tomato, onion, pepper, and stock drive the flavor, with regional versions varying in heat, smoke, and sides.",
            descriptionTags: ["Tomato-rich", "Spiced", "Celebratory"],
            dietaryTags: ["Varies by preparation"],
            searchKeywords: ["rice", "tomato", "party rice", "Nigeria", "Ghana", "Senegal"],
            originNote: "Connected to rice traditions across West Africa, with many national and regional versions.",
            relatedDishes: ["Mandi"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_500)
        ),
        DishReference(
            id: previewFeijoadaID,
            name: "Feijoada",
            alternateNames: ["Brazilian black bean stew"],
            countries: ["Brazil"],
            region: "South America",
            continent: "South America",
            cuisine: "Brazilian",
            category: "Stew",
            familiarity: "Moderate",
            restaurantAccessibility: "Medium; available at Brazilian restaurants",
            shortDescription: "A hearty black bean stew usually cooked with pork, sausage, and savory aromatics.",
            longDescription: "Feijoada builds depth from black beans, smoked meats, and slow cooking. It is often served with rice, greens, orange, and farofa for contrast.",
            descriptionTags: ["Hearty", "Smoky", "Savory"],
            dietaryTags: ["Often contains meat"],
            searchKeywords: ["beans", "stew", "pork", "Brazil"],
            originNote: "A Brazilian staple with many household and regional variations.",
            relatedDishes: ["Jollof Rice"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_600)
        ),
        DishReference(
            id: previewKasespatzleID,
            name: "Käsespätzle",
            alternateNames: ["Kase spatzle", "Cheese spaetzle"],
            countries: ["Germany", "Austria", "Switzerland"],
            region: "Europe",
            continent: "Europe",
            cuisine: "Alpine",
            category: "Noodles",
            familiarity: "Discover",
            restaurantAccessibility: "Low; usually found at specialty Alpine or German restaurants",
            shortDescription: "Soft egg noodles folded with melted cheese and often finished with crisp onions.",
            longDescription: "Käsespätzle is rich, direct comfort food: tender small noodles, mountain cheeses, and browned onions layered into a satisfying dish.",
            descriptionTags: ["Cheesy", "Comforting", "Rich"],
            dietaryTags: ["Vegetarian", "Contains gluten"],
            searchKeywords: ["spaetzle", "cheese", "noodles", "Alpine", "German"],
            originNote: "Associated with Alpine regions across German-speaking Central Europe.",
            relatedDishes: ["Cacio e Pepe"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_700)
        ),
        DishReference(
            id: previewDolmaID,
            name: "Dolma",
            alternateNames: ["Stuffed grape leaves", "Dolmades"],
            countries: ["Turkey", "Armenia", "Azerbaijan", "Greece", "Lebanon"],
            region: "Eastern Mediterranean",
            continent: "Asia",
            cuisine: "Turkish",
            category: "Stuffed dish",
            familiarity: "Familiar",
            restaurantAccessibility: "High; common at Turkish and Mediterranean restaurants",
            shortDescription: "Vegetables or grape leaves stuffed with rice, herbs, spices, and sometimes meat.",
            longDescription: "Dolma covers many stuffed dishes across the eastern Mediterranean and nearby regions. Fillings can be bright and herb-heavy or richer with meat and warm spices.",
            descriptionTags: ["Herby", "Stuffed", "Tangy"],
            dietaryTags: ["Varies by preparation"],
            searchKeywords: ["grape leaves", "stuffed", "rice", "Mediterranean"],
            originNote: "A shared regional dish family with many local names and preparations.",
            relatedDishes: ["Mandi"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_800)
        ),
        DishReference(
            id: previewNasiLemakID,
            name: "Nasi Lemak",
            alternateNames: ["Coconut rice with sambal"],
            countries: ["Malaysia", "Singapore"],
            region: "Southeast Asia",
            continent: "Asia",
            cuisine: "Malaysian",
            category: "Rice dish",
            familiarity: "Moderate",
            restaurantAccessibility: "High; available at many Malaysian restaurants",
            shortDescription: "Coconut rice served with sambal, cucumber, peanuts, egg, and often anchovies or fried chicken.",
            longDescription: "Nasi lemak balances fragrant coconut rice with chile sambal, crunch, freshness, and savory accompaniments. It can be breakfast, lunch, or a full plate meal.",
            descriptionTags: ["Coconut", "Spicy", "Fragrant"],
            dietaryTags: ["Often contains seafood", "Varies by preparation"],
            searchKeywords: ["coconut rice", "sambal", "Malaysia", "Singapore"],
            originNote: "Strongly associated with Malaysia while also common in Singapore.",
            relatedDishes: ["Khao Soi"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_900)
        ),
        DishReference(
            id: previewHangiID,
            name: "Hangi",
            alternateNames: ["Māori earth oven feast"],
            countries: ["New Zealand"],
            region: "Oceania",
            continent: "Oceania",
            cuisine: "Māori",
            category: "Feast",
            familiarity: "Discover",
            restaurantAccessibility: "Low; usually requires specialty events or cultural venues",
            shortDescription: "Meat, vegetables, and starches cooked slowly in an earth oven for smoky, tender results.",
            longDescription: "Hangi is a traditional Māori cooking method using heated stones buried in a pit oven. The food cooks gently with steam, smoke, and earth-driven heat.",
            descriptionTags: ["Smoky", "Tender", "Earthy"],
            dietaryTags: ["Varies by preparation"],
            searchKeywords: ["earth oven", "New Zealand", "Māori", "feast"],
            originNote: "A Māori cooking tradition from Aotearoa New Zealand.",
            relatedDishes: [],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_001_000)
        ),
        DishReference(
            id: previewShakingBeefID,
            name: "Vietnamese Shaking Beef",
            alternateNames: ["Bò lúc lắc", "Bo luc lac"],
            countries: ["Vietnam", "United States", "France"],
            region: "Southeast Asia",
            continent: "Asia",
            cuisine: "Vietnamese",
            category: "Stir-fry",
            familiarity: "Familiar",
            restaurantAccessibility: "High; common at Vietnamese restaurants",
            shortDescription: "Seared cubes of beef tossed quickly with garlic, pepper, onion, and a bright dipping sauce.",
            longDescription: "Vietnamese shaking beef gets its name from the quick tossing motion in the pan. The dish is savory, peppery, and often balanced by lime, salt, and fresh vegetables.",
            descriptionTags: ["Peppery", "Savory", "Bright"],
            dietaryTags: ["Contains meat"],
            searchKeywords: ["beef", "bo luc lac", "Vietnamese", "stir fry"],
            originNote: "A Vietnamese restaurant favorite with French-influenced beef cookery.",
            relatedDishes: ["Aguachile"],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_001_100)
        )
    ]
}
#endif

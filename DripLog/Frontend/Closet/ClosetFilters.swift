
import Foundation

// MARK: - ClosetFilterSection

enum ClosetFilterSection: Hashable {
    case rating
    case categories
    case weather
    case occasion
    case colors
    case custom
    case visibility
}

// MARK: - ClosetCategoryGroup

enum ClosetCategoryGroup: String, CaseIterable, Identifiable {
    case tops
    case bottoms
    case outerwear
    case shoes
    case accessories

    var id: String { rawValue }

    var title: String { rawValue }

    var items: [String] {
        switch self {
        case .tops:
            return ["t-shirt", "zip-up", "tank top", "crop top", "button-up", "hoodie", "long-sleeve", "sweater", "polo", "cardigan", "flannel", "blouse"]
        case .bottoms:
            return ["jeans", "shorts", "leggings", "trousers", "joggers", "skirt", "dress pants", "cargos", "sweatpants", "slacks", "jorts", "dress"]
        case .outerwear:
            return ["coat", "trench coat", "jacket", "fur coat", "cardigan", "blazer", "puffer jacket", "leather jacket", "windbreaker", "overcoat", "zip-up", "sweater"]
        case .shoes:
            return ["running shoes", "boots", "sandals", "dress shoes", "loafers", "high heels", "slides", "sneakers"]
        case .accessories:
            return ["hat", "scarf", "glasses", "watch", "handbag", "necklace", "earrings", "belt", "bracelet", "rings", "gloves", "sunglasses"]
        }
    }
}

// MARK: - ClosetFilters

struct ClosetFilters {
    var rating: Int?
    var topCategories: Set<String> = []
    var bottomCategories: Set<String> = []
    var outerwearCategories: Set<String> = []
    var shoesCategories: Set<String> = []
    var accessoriesCategories: Set<String> = []
    var weather: Set<String> = []
    var occasion: Set<String> = []
    var colors: Set<String> = []
    var custom: Set<String> = []

    static let weatherOptions  = ["sunny", "cold", "rainy", "snowy", "humid", "warm", "hot", "windy"]
    static let occasionOptions = ["casual", "formal", "biz-casual", "semi-formal", "going out", "outdoors", "date night", "concert", "at home", "professional", "beach", "special event"]
    static let colorOptions    = ["black", "white", "gray", "brown", "blue", "green", "red", "pink", "purple", "yellow", "orange", "tan"]

    var customSuggestions: [String] {
        ["vintage", "streetwear", "minimal", "layered", "gym", "cozy", "monochrome", "silver jewelry", "gold jewelry", "baggy"]
    }

    init() {}

    init(tags: [String]) {
        for tag in tags {
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased  = normalized.lowercased()

            if Self.weatherOptions.contains(lowercased) {
                weather.insert(lowercased)
            } else if Self.occasionOptions.contains(lowercased) {
                occasion.insert(lowercased)
            } else if Self.colorOptions.contains(lowercased) {
                colors.insert(lowercased)
            } else if ClosetCategoryGroup.tops.items.contains(lowercased) {
                topCategories.insert(lowercased)
            } else if ClosetCategoryGroup.bottoms.items.contains(lowercased) {
                bottomCategories.insert(lowercased)
            } else if ClosetCategoryGroup.outerwear.items.contains(lowercased) {
                outerwearCategories.insert(lowercased)
            } else if ClosetCategoryGroup.shoes.items.contains(lowercased) {
                shoesCategories.insert(lowercased)
            } else if ClosetCategoryGroup.accessories.items.contains(lowercased) {
                accessoriesCategories.insert(lowercased)
            } else {
                custom.insert(normalized)
            }
        }
    }

    init(metadata: OutfitMetadata) {
        topCategories        = Set(metadata.categories.filter { ClosetCategoryGroup.tops.items.contains($0.lowercased()) }.map { $0.lowercased() })
        bottomCategories     = Set(metadata.categories.filter { ClosetCategoryGroup.bottoms.items.contains($0.lowercased()) }.map { $0.lowercased() })
        outerwearCategories  = Set(metadata.categories.filter { ClosetCategoryGroup.outerwear.items.contains($0.lowercased()) }.map { $0.lowercased() })
        shoesCategories      = Set(metadata.categories.filter { ClosetCategoryGroup.shoes.items.contains($0.lowercased()) }.map { $0.lowercased() })
        accessoriesCategories = Set(metadata.categories.filter { ClosetCategoryGroup.accessories.items.contains($0.lowercased()) }.map { $0.lowercased() })
        weather  = Set(metadata.weather.map { $0.lowercased() })
        occasion = Set(metadata.occasion.map { $0.lowercased() })
        colors   = Set(metadata.colors.map { $0.lowercased() })
        custom   = Set(metadata.customTags)
    }

    // MARK: Computed helpers

    var hasActiveSelections: Bool {
        rating != nil ||
        categorySelectionCount > 0 ||
        !weather.isEmpty ||
        !occasion.isEmpty ||
        !colors.isEmpty ||
        !custom.isEmpty
    }

    var categorySelectionCount: Int {
        topCategories.count +
        bottomCategories.count +
        outerwearCategories.count +
        shoesCategories.count +
        accessoriesCategories.count
    }

    var weatherNormalized: Set<String>  { Set(weather.map  { $0.lowercased() }) }
    var occasionNormalized: Set<String> { Set(occasion.map { $0.lowercased() }) }
    var colorsNormalized: Set<String>   { Set(colors.map   { $0.lowercased() }) }
    var customNormalized: Set<String>   { Set(custom.map   { $0.lowercased() }) }

    var combinedTags: [String] {
        var orderedTags: [String] = []
        orderedTags.append(contentsOf: ClosetCategoryGroup.tops.items.filter        { topCategories.contains($0) })
        orderedTags.append(contentsOf: ClosetCategoryGroup.bottoms.items.filter     { bottomCategories.contains($0) })
        orderedTags.append(contentsOf: ClosetCategoryGroup.outerwear.items.filter   { outerwearCategories.contains($0) })
        orderedTags.append(contentsOf: ClosetCategoryGroup.shoes.items.filter       { shoesCategories.contains($0) })
        orderedTags.append(contentsOf: ClosetCategoryGroup.accessories.items.filter { accessoriesCategories.contains($0) })
        orderedTags.append(contentsOf: Self.weatherOptions.filter  { weather.contains($0) })
        orderedTags.append(contentsOf: Self.occasionOptions.filter { occasion.contains($0) })
        orderedTags.append(contentsOf: Self.colorOptions.filter    { colors.contains($0) })
        orderedTags.append(contentsOf: custom.sorted())
        return Array(NSOrderedSet(array: orderedTags)) as? [String] ?? orderedTags
    }

    var metadata: OutfitMetadata {
        OutfitMetadata(
            customTags:  custom.sorted(),
            categories:  selectedCategories,
            weather:     Self.weatherOptions.filter  { weather.contains($0) },
            occasion:    Self.occasionOptions.filter { occasion.contains($0) },
            colors:      Self.colorOptions.filter    { colors.contains($0) }
        )
    }

    var selectedCategories: [String] {
        var orderedCategories: [String] = []
        orderedCategories.append(contentsOf: ClosetCategoryGroup.tops.items.filter        { topCategories.contains($0) })
        orderedCategories.append(contentsOf: ClosetCategoryGroup.bottoms.items.filter     { bottomCategories.contains($0) })
        orderedCategories.append(contentsOf: ClosetCategoryGroup.outerwear.items.filter   { outerwearCategories.contains($0) })
        orderedCategories.append(contentsOf: ClosetCategoryGroup.shoes.items.filter       { shoesCategories.contains($0) })
        orderedCategories.append(contentsOf: ClosetCategoryGroup.accessories.items.filter { accessoriesCategories.contains($0) })
        return Array(NSOrderedSet(array: orderedCategories)) as? [String] ?? orderedCategories
    }

    func categoryMatches(tags: Set<String>) -> Bool {
        let groups: [Set<String>] = [
            Set(topCategories.map        { $0.lowercased() }),
            Set(bottomCategories.map     { $0.lowercased() }),
            Set(outerwearCategories.map  { $0.lowercased() }),
            Set(shoesCategories.map      { $0.lowercased() }),
            Set(accessoriesCategories.map { $0.lowercased() })
        ]
        return groups.allSatisfy { selection in
            selection.isEmpty || !tags.isDisjoint(with: selection)
        }
    }

    mutating func clearCategories() {
        topCategories.removeAll()
        bottomCategories.removeAll()
        outerwearCategories.removeAll()
        shoesCategories.removeAll()
        accessoriesCategories.removeAll()
    }
}
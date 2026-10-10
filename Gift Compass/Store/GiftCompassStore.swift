import SwiftUI
import UIKit
import PhotosUI
import Foundation

@MainActor
final class GiftCompassStore: ObservableObject {
    @Published var people: [GiftPerson] {
        didSet {
            savePeople()
            if UserDefaults.standard.bool(forKey: NotificationManager.settingKey) {
                Task { await NotificationManager.schedule(for: people) }
            }
        }
    }
    @Published var myWishlist: [String] {
        didSet { saveMyWishlist() }
    }
    @Published var collections: [GiftCollection] = SampleData.collections
    @Published var activityLog: [String] = []
    private let peopleKey = "giftCompass.people.v1"
    private let myWishlistKey = "giftCompass.myWishlist.v1"

    init() {
        if
            let data = UserDefaults.standard.data(forKey: peopleKey),
            let stored = try? JSONDecoder().decode([StoredPerson].self, from: data)
        {
            self.people = stored.map(\.person)
        } else {
            self.people = []
        }
        self.myWishlist = UserDefaults.standard.stringArray(forKey: myWishlistKey) ?? []
    }

    var allIdeas: [GiftIdea] {
        people.flatMap(\.ideas)
    }

    var allGifts: [GiftRecord] {
        people.flatMap(\.gifts)
    }

    var perfectIdeasCount: Int {
        allIdeas.filter { $0.status == "Perfect" }.count
    }

    var noRepeatGiftsCount: Int {
        allGifts.filter(\.doNotRepeat).count
    }

    var averageBudget: Double {
        let values = allIdeas.map(\.numericPrice).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var firstPerson: GiftPerson? {
        people.first
    }

    func addPerson(name: String, birthday: Date, relationship: String, favoriteColor: String, notes: String, brandsText: String = "", sizesText: String = "", imageData: Data? = nil) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"

        let tint = color(for: favoriteColor)
        let personID = UUID()
        let person = GiftPerson(
            id: personID,
            name: cleanName,
            relationship: relationship,
            birthday: formatter.string(from: birthday),
            tint: tint,
            tintKey: ColorToken.key(for: favoriteColor),
            imageFileName: ImageStorage.save(imageData, id: personID),
            gifts: [],
            ideas: [],
            wishes: [],
            brands: parseBrands(brandsText),
            sizes: parseSizes(sizesText),
            dreamGifts: notes.isEmpty ? [] : [notes],
            relationshipTimeline: [TimelineMoment(year: "\(Calendar.current.component(.year, from: Date()))", title: "Added to Gift for You")],
            birthdayDate: birthday
        )
        people.insert(person, at: 0)
        activityLog.insert("Added \(cleanName)", at: 0)
    }

    func addGift(personID: UUID, title: String, store: String, price: String, category: String, occasion: String, reaction: String, imageData: Data? = nil) {
        guard let index = people.firstIndex(where: { $0.id == personID }) else { return }
        let calendarYear = Calendar.current.component(.year, from: Date())
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let giftID = UUID()
        let gift = GiftRecord(
            id: giftID,
            year: "\(calendarYear)",
            title: cleanTitle,
            price: price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "$0" : price,
            store: store.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Saved locally" : store,
            occasion: occasion,
            reaction: reaction,
            comment: "Added from Quick Add.",
            score: reaction == "Loved it" ? 5 : reaction == "Never again" ? 1 : 3,
            doNotRepeat: reaction == "Never again",
            symbol: SampleData.categorySymbol(category),
            tint: SampleData.categoryTint(category),
            tintKey: ColorToken.key(forCategory: category),
            imageFileName: ImageStorage.save(imageData, id: giftID),
            category: category,
            createdAt: Date()
        )
        people[index].gifts.insert(gift, at: 0)
        activityLog.insert("Added \(cleanTitle) for \(people[index].name)", at: 0)
    }

    func addWish(personID: UUID, title: String) {
        guard let index = people.firstIndex(where: { $0.id == personID }) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        people[index].wishes.insert(cleanTitle, at: 0)
        activityLog.insert("Added wish \(cleanTitle)", at: 0)
    }

    func addIdea(personID: UUID, title: String, price: String, store: String, reason: String, status: String, category: String, imageData: Data? = nil) {
        guard let index = people.firstIndex(where: { $0.id == personID }) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let value = numericPrice(from: price) ?? 50
        let ideaID = UUID()
        let idea = GiftIdea(
            id: ideaID,
            title: cleanTitle,
            price: price.isEmpty ? "$\(Int(value))" : price,
            numericPrice: value,
            store: store.isEmpty ? "Saved locally" : store,
            reason: reason.isEmpty ? "Matches saved preferences." : reason,
            tags: [category, status],
            status: status,
            symbol: "sparkles",
            tint: status == "Perfect" ? GCColor.gold : status == "Great" ? GCColor.success : GCColor.accent,
            tintKey: status == "Perfect" ? "gold" : status == "Great" ? "success" : "accent",
            imageFileName: ImageStorage.save(imageData, id: ideaID),
            category: category,
            createdAt: Date()
        )
        people[index].ideas.insert(idea, at: 0)
        activityLog.insert("Added idea \(cleanTitle)", at: 0)
    }

    func updateIdea(personID: UUID, ideaID: UUID, title: String, price: String, store: String, reason: String, status: String, category: String, replacementImageData: Data?, removeImage: Bool) {
        guard
            let personIndex = people.firstIndex(where: { $0.id == personID }),
            let ideaIndex = people[personIndex].ideas.firstIndex(where: { $0.id == ideaID })
        else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let previous = people[personIndex].ideas[ideaIndex]
        var imageFileName = previous.imageFileName
        if removeImage {
            ImageStorage.delete(previous.imageFileName)
            imageFileName = nil
        }
        if let replacementImageData {
            ImageStorage.delete(previous.imageFileName)
            imageFileName = ImageStorage.save(replacementImageData, id: ideaID)
        }

        let value = numericPrice(from: price) ?? previous.numericPrice
        people[personIndex].ideas[ideaIndex] = GiftIdea(
            id: ideaID,
            title: cleanTitle,
            price: price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "$\(Int(value))" : price,
            numericPrice: value,
            store: store.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Saved locally" : store,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Saved for \(people[personIndex].name)." : reason,
            tags: [category, status],
            status: status,
            symbol: previous.symbol,
            tint: status == "Perfect" ? GCColor.gold : status == "Great" ? GCColor.success : GCColor.accent,
            tintKey: status == "Perfect" ? "gold" : status == "Great" ? "success" : "accent",
            imageFileName: imageFileName,
            category: category,
            createdAt: previous.createdAt
        )
        activityLog.insert("Updated idea \(cleanTitle)", at: 0)
    }

    func deleteIdea(personID: UUID, ideaID: UUID) {
        guard
            let personIndex = people.firstIndex(where: { $0.id == personID }),
            let ideaIndex = people[personIndex].ideas.firstIndex(where: { $0.id == ideaID })
        else { return }

        let removed = people[personIndex].ideas.remove(at: ideaIndex)
        ImageStorage.delete(removed.imageFileName)
        activityLog.insert("Removed idea \(removed.title)", at: 0)
    }

    func updatePerson(personID: UUID, name: String, birthday: Date, relationship: String, favoriteColor: String, notes: String, brandsText: String, sizesText: String, replacementImageData: Data?, removeImage: Bool) {
        guard let index = people.firstIndex(where: { $0.id == personID }) else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let previous = people[index]
        var imageFileName = previous.imageFileName
        if removeImage {
            ImageStorage.delete(previous.imageFileName)
            imageFileName = nil
        }
        if let replacementImageData {
            ImageStorage.delete(previous.imageFileName)
            imageFileName = ImageStorage.save(replacementImageData, id: personID)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        people[index] = GiftPerson(
            id: previous.id,
            name: cleanName,
            relationship: relationship,
            birthday: formatter.string(from: birthday),
            tint: color(for: favoriteColor),
            tintKey: ColorToken.key(for: favoriteColor),
            imageFileName: imageFileName,
            gifts: previous.gifts,
            ideas: previous.ideas,
            wishes: previous.wishes,
            brands: parseBrands(brandsText),
            sizes: parseSizes(sizesText),
            dreamGifts: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [notes],
            relationshipTimeline: previous.relationshipTimeline,
            birthdayDate: birthday
        )
        activityLog.insert("Updated \(cleanName)", at: 0)
    }

    func deletePerson(personID: UUID) {
        guard let index = people.firstIndex(where: { $0.id == personID }) else { return }
        let person = people.remove(at: index)
        ImageStorage.delete(person.imageFileName)
        person.gifts.forEach { ImageStorage.delete($0.imageFileName) }
        person.ideas.forEach { ImageStorage.delete($0.imageFileName) }
        activityLog.insert("Removed \(person.name)", at: 0)
    }

    func updateGift(personID: UUID, giftID: UUID, title: String, store: String, price: String, category: String, occasion: String, reaction: String, replacementImageData: Data?, removeImage: Bool) {
        guard
            let personIndex = people.firstIndex(where: { $0.id == personID }),
            let giftIndex = people[personIndex].gifts.firstIndex(where: { $0.id == giftID })
        else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let previous = people[personIndex].gifts[giftIndex]
        var imageFileName = previous.imageFileName
        if removeImage {
            ImageStorage.delete(previous.imageFileName)
            imageFileName = nil
        }
        if let replacementImageData {
            ImageStorage.delete(previous.imageFileName)
            imageFileName = ImageStorage.save(replacementImageData, id: giftID)
        }

        people[personIndex].gifts[giftIndex] = GiftRecord(
            id: giftID,
            year: previous.year,
            title: cleanTitle,
            price: price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "$0" : price,
            store: store.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Saved locally" : store,
            occasion: occasion,
            reaction: reaction,
            comment: previous.comment,
            score: reaction == "Loved it" ? 5 : reaction == "Never again" ? 1 : 3,
            doNotRepeat: reaction == "Never again",
            symbol: SampleData.categorySymbol(category),
            tint: SampleData.categoryTint(category),
            tintKey: ColorToken.key(forCategory: category),
            imageFileName: imageFileName,
            category: category,
            createdAt: previous.createdAt
        )
        activityLog.insert("Updated gift \(cleanTitle)", at: 0)
    }

    func deleteGift(personID: UUID, giftID: UUID) {
        guard
            let personIndex = people.firstIndex(where: { $0.id == personID }),
            let giftIndex = people[personIndex].gifts.firstIndex(where: { $0.id == giftID })
        else { return }
        let removed = people[personIndex].gifts.remove(at: giftIndex)
        ImageStorage.delete(removed.imageFileName)
        activityLog.insert("Removed gift \(removed.title)", at: 0)
    }

    func updateWish(personID: UUID, index: Int, title: String) {
        guard let personIndex = people.firstIndex(where: { $0.id == personID }), people[personIndex].wishes.indices.contains(index) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        people[personIndex].wishes[index] = cleanTitle
    }

    func deleteWish(personID: UUID, index: Int) {
        guard let personIndex = people.firstIndex(where: { $0.id == personID }), people[personIndex].wishes.indices.contains(index) else { return }
        people[personIndex].wishes.remove(at: index)
    }

    func addMyWish(_ title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        myWishlist.insert(cleanTitle, at: 0)
        activityLog.insert("Added personal wish \(cleanTitle)", at: 0)
    }

    func deleteMyWish(at index: Int) {
        guard myWishlist.indices.contains(index) else { return }
        myWishlist.remove(at: index)
    }

    func updateMyWish(at index: Int, title: String) {
        guard myWishlist.indices.contains(index) else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        myWishlist[index] = cleanTitle
    }

    func resetAllData() {
        people = []
        myWishlist = []
        activityLog = []
        ImageStorage.deleteAll()
        NotificationManager.disable()
        UserDefaults.standard.set(false, forKey: NotificationManager.settingKey)
    }

    func search(_ query: String) -> [SearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return [] }

        var results: [SearchResult] = []
        for person in people {
            if person.name.localizedCaseInsensitiveContains(cleanQuery) || person.relationship.localizedCaseInsensitiveContains(cleanQuery) {
                results.append(SearchResult(title: person.name, subtitle: "Person • \(person.relationship)", symbol: "person.fill", tint: person.tint, target: .person(person.id)))
            }
            for gift in person.gifts where gift.title.localizedCaseInsensitiveContains(cleanQuery) || gift.occasion.localizedCaseInsensitiveContains(cleanQuery) {
                results.append(SearchResult(title: gift.title, subtitle: "\(person.name) • \(gift.year)", symbol: gift.symbol, tint: gift.tint, target: .gift(personID: person.id, giftID: gift.id)))
            }
            for idea in person.ideas where idea.title.localizedCaseInsensitiveContains(cleanQuery) || idea.reason.localizedCaseInsensitiveContains(cleanQuery) {
                results.append(SearchResult(title: idea.title, subtitle: "\(person.name) • \(idea.status)", symbol: idea.symbol, tint: idea.tint, target: .idea(personID: person.id, ideaID: idea.id)))
            }
            for wish in person.wishes where wish.localizedCaseInsensitiveContains(cleanQuery) {
                results.append(SearchResult(title: wish, subtitle: "\(person.name) wishlist", symbol: "heart.fill", tint: GCColor.success, target: .wishlist(person.id)))
            }
        }
        return results
    }

    func exportURL(kind: ExportKind) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Gift-for-You-\(kind.fileName)")

        let data: Data?
        switch kind {
        case .pdf:
            data = makePDFReport()
        case .csv:
            let rows = allGifts.map {
                [$0.year, $0.title, $0.price, $0.store, $0.occasion, "\($0.score)"]
                    .map(csvEscaped)
                    .joined(separator: ",")
            }
            data = ("year,title,price,store,occasion,score\n" + rows.joined(separator: "\n")).data(using: .utf8)
        case .json:
            data = try? JSONEncoder.giftForYou.encode(people.map(StoredPerson.init(person:)))
        case .backup:
            var images: [String: Data] = [:]
            for person in people {
                let names = [person.imageFileName] + person.gifts.map(\.imageFileName) + person.ideas.map(\.imageFileName)
                for name in names.compactMap({ $0 }) {
                    images[name] = ImageStorage.data(name)
                }
            }
            let archive = GiftForYouBackup(
                createdAt: Date(),
                people: people.map(StoredPerson.init(person:)),
                myWishlist: myWishlist,
                images: images
            )
            data = try? JSONEncoder.giftForYou.encode(archive)
        }

        guard let data else { return nil }
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    func importBackup(_ data: Data) throws {
        let archive: GiftForYouBackup
        do {
            archive = try JSONDecoder.giftForYou.decode(GiftForYouBackup.self, from: data)
        } catch {
            throw GiftForYouDataError.invalidBackup
        }

        guard archive.people.count <= 5_000 else { throw GiftForYouDataError.invalidBackup }
        ImageStorage.deleteAll()
        for (fileName, imageData) in archive.images {
            guard fileName.hasSuffix(".jpg"), !fileName.contains("/") else { continue }
            ImageStorage.restore(imageData, fileName: fileName)
        }
        people = archive.people.map(\.person)
        myWishlist = archive.myWishlist
        activityLog.insert("Imported backup", at: 0)
    }

    private func csvEscaped(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func makePDFReport() -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let report = """
        Gift for You
        Personal gift report

        People: \(people.count)
        Saved ideas: \(allIdeas.count)
        Gifts recorded: \(allGifts.count)
        Perfect ideas: \(perfectIdeasCount)
        Do-not-repeat gifts: \(noRepeatGiftsCount)
        Average idea budget: $\(Int(averageBudget.rounded()))

        Your data is stored locally on this device.
        """

        return renderer.pdfData { context in
            context.beginPage()
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 8
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                .foregroundColor: UIColor(GCColor.action),
                .paragraphStyle: paragraph
            ]
            report.draw(in: bounds.insetBy(dx: 54, dy: 58), withAttributes: attributes)
        }
    }

    private func color(for favoriteColor: String) -> Color {
        switch favoriteColor {
        case "Green": return GCColor.success
        case "Gold": return GCColor.gold
        case "Black": return GCColor.ink
        case "Pink": return GCColor.accent
        default: return GCColor.primary
        }
    }

    private func numericPrice(from value: String) -> Double? {
        var normalized = value.filter { $0.isNumber || $0 == "." || $0 == "," }
        if normalized.contains(".") && normalized.contains(",") {
            normalized.removeAll(where: { $0 == "," })
        } else {
            normalized = normalized.replacingOccurrences(of: ",", with: ".")
        }
        return Double(normalized)
    }

    private func parseBrands(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseSizes(_ value: String) -> [(String, String)] {
        value
            .components(separatedBy: .newlines)
            .compactMap { line in
                let pieces = line.split(separator: ":", maxSplits: 1).map(String.init)
                guard pieces.count == 2 else { return nil }
                let key = pieces[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let size = pieces[1].trimmingCharacters(in: .whitespacesAndNewlines)
                return key.isEmpty || size.isEmpty ? nil : (key, size)
            }
    }

    private func savePeople() {
        let stored = people.map(StoredPerson.init(person:))
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: peopleKey)
        }
    }

    private func saveMyWishlist() {
        UserDefaults.standard.set(myWishlist, forKey: myWishlistKey)
    }
}

enum ExportKind: String, CaseIterable {
    case pdf = "PDF"
    case csv = "CSV"
    case json = "JSON"
    case backup = "Backup"

    var subtitle: String {
        switch self {
        case .pdf: return "Beautiful report for your archive"
        case .csv: return "Open in Numbers or Excel"
        case .json: return "Portable app data"
        case .backup: return "Full local backup"
        }
    }

    var symbol: String {
        switch self {
        case .pdf: return "doc.richtext.fill"
        case .csv: return "tablecells.fill"
        case .json: return "curlybraces"
        case .backup: return "externaldrive.fill"
        }
    }

    var fileName: String {
        switch self {
        case .pdf: return "Report.pdf"
        case .csv: return "Gifts.csv"
        case .json: return "People.json"
        case .backup: return "Backup.json"
        }
    }
}

struct GiftForYouBackup: Codable {
    let createdAt: Date
    let people: [StoredPerson]
    let myWishlist: [String]
    let images: [String: Data]
}

enum GiftForYouDataError: LocalizedError {
    case invalidBackup

    var errorDescription: String? {
        "This file is not a valid Gift for You backup."
    }
}

private extension JSONEncoder {
    static var giftForYou: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var giftForYou: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let target: SearchTarget
}

enum SearchTarget {
    case person(UUID)
    case gift(personID: UUID, giftID: UUID)
    case idea(personID: UUID, ideaID: UUID)
    case wishlist(UUID)
}

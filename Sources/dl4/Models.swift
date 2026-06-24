import Foundation

/// Display names for the CC1 delay models (index = CC value).
extension DelayModel {
    static let names = [
        "Vintage Digital", "Crisscross", "Euclidean", "Dual Delay", "Pitch Echo",
        "ADT", "Ducked", "Harmony", "Heliosphere", "Transistor", "Cosmos",
        "Multi Pass", "Adriatic", "Elephant Man", "Glitch",
    ]
}

/// Display names for the CC2 reverb models (index = CC value).
enum ReverbModel {
    static let names = [
        "Room", "Searchlights", "Particle Verb", "Double Tank", "Octo", "Tile",
        "Ducking", "Plateaux", "Cave", "Plate", "Ganymede", "Chamber",
        "Hot Springs", "Hall", "Glitz", "Reverb Off",
    ]
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

import Foundation
import Testing

@testable import CineShelfCore

@Suite("Médias")
struct MediaTests {
    @Test("Sans aucun recadrage, la résolution retombe sur (50, 50, 100)")
    func cropFallsBackToNeutral() {
        let asset = MediaAsset()
        let crop = asset.crop(for: .card)

        #expect(crop.x == 50)
        #expect(crop.y == 50)
        #expect(crop.zoom == 100)
    }

    @Test("À défaut du contexte demandé, la résolution utilise le recadrage standard")
    func cropFallsBackToStandard() {
        let asset = MediaAsset()
        let standard = MediaCrop(context: .standard)
        standard.positionX = 20
        standard.positionY = 30
        standard.zoom = 150
        asset.crops = [standard]

        let crop = asset.crop(for: .hero)

        #expect(crop.x == 20)
        #expect(crop.y == 30)
        #expect(crop.zoom == 150)
    }

    @Test("Le recadrage du contexte demandé a la priorité sur le standard")
    func cropPrefersRequestedContext() {
        let asset = MediaAsset()
        let standard = MediaCrop(context: .standard)
        standard.positionX = 20
        let card = MediaCrop(context: .card)
        card.positionX = 80
        card.positionY = 10
        card.zoom = 200
        asset.crops = [standard, card]

        let crop = asset.crop(for: .card)

        #expect(crop.x == 80)
        #expect(crop.y == 10)
        #expect(crop.zoom == 200)
    }

    @Test("Un rattachement sans parent viole l'invariante")
    func attachmentWithoutOwnerIsInvalid() {
        let attachment = MediaAttachment()
        #expect(attachment.hasExactlyOneOwner == false)
    }

    @Test("Un rattachement à un seul parent respecte l'invariante")
    func attachmentWithOneOwnerIsValid() {
        let attachment = MediaAttachment(slot: .primary)
        attachment.title = Title(name: "Ran")

        #expect(attachment.hasExactlyOneOwner)
        #expect(attachment.slot == .primary)
    }

    @Test("Un rattachement à deux parents viole l'invariante")
    func attachmentWithTwoOwnersIsInvalid() {
        let attachment = MediaAttachment()
        attachment.title = Title(name: "Ran")
        attachment.person = Person(firstName: "Akira", lastName: "Kurosawa")

        #expect(attachment.hasExactlyOneOwner == false)
    }

    @Test("L'asset ne compte pas comme parent")
    func assetIsNotAnOwner() {
        let attachment = MediaAttachment()
        attachment.asset = MediaAsset()

        #expect(attachment.hasExactlyOneOwner == false)
    }
}

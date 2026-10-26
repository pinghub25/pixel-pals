import SwiftUI

/// Pick a pet, name it, and enter your birthday. Used to adopt and to edit later.
struct ProfileForm: View {
    let title: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    let onSave: (PetProfile) -> Void

    @State private var pet: PetKind
    @State private var name: String
    @State private var birthDate: Date

    init(title: LocalizedStringKey, buttonTitle: LocalizedStringKey, initial: PetProfile?, onSave: @escaping (PetProfile) -> Void) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.onSave = onSave
        let start = initial ?? .sample
        _pet = State(initialValue: start.pet)
        _name = State(initialValue: start.name)
        _birthDate = State(initialValue: start.birthDate)
    }

    private var sign: ZodiacSign { ZodiacSign(birthDate: birthDate) }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(title)
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                AnimatedPet(kind: pet)
                    .frame(width: 140, height: 140)
                    .padding(.vertical, 8)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(PetKind.allCases) { kind in
                        Button { choose(kind) } label: {
                            VStack(spacing: 4) {
                                PixelPetView(kind: kind)
                                    .frame(width: 52, height: 52)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(kind == pet ? kind.color.opacity(0.25) : .white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(kind == pet ? kind.color : .clear, lineWidth: 2)
                                    )
                                Text(kind.species)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    TextField("Pet name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    DatePicker("Your birthday", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                    HStack(spacing: 12) {
                        Text(sign.symbol)
                            .font(.largeTitle)
                            .foregroundStyle(pet.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sign.name).font(.headline)
                            Text("\(sign.elementSign) · \(sign.dates)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .card()

                Button {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    onSave(PetProfile(pet: pet, name: trimmed.isEmpty ? pet.defaultName : trimmed, birthDate: birthDate))
                } label: {
                    Text(buttonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(pet.color)
                .foregroundStyle(.black)
            }
            .padding()
        }
    }

    /// Swapping pets also swaps the default name, unless the user typed their own.
    private func choose(_ kind: PetKind) {
        if name.isEmpty || PetKind.allCases.contains(where: { $0.defaultName == name }) {
            name = kind.defaultName
        }
        pet = kind
    }
}

import SwiftUI

struct CreateMeetupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: MeetupViewModel
    @Environment(\.dismiss) var dismiss

    @State private var sport = Sport.basketball
    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var time = Date()
    @State private var location = ""
    @State private var selectedSkillLevels: Set<String> = []
    @State private var playerLimit = 6
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section("Sport") {
                    Picker("Sport", selection: $sport) {
                        ForEach(Sport.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                Section("Details") {
                    TextField("Title (e.g. Pickup Basketball)", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("When & Where") {
                    DatePicker("Date", selection: $date, in: Date()..., displayedComponents: .date)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    TextField("Location (e.g. ARC Gym)", text: $location)
                }

                Section("Skill Levels") {
                    ForEach(SkillLevel.allCases, id: \.self) { level in
                        Button(action: {
                            if selectedSkillLevels.contains(level.rawValue) {
                                selectedSkillLevels.remove(level.rawValue)
                            } else {
                                selectedSkillLevels.insert(level.rawValue)
                            }
                        }) {
                            HStack {
                                Text(level.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedSkillLevels.contains(level.rawValue) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }

                Section("Player Limit") {
                    Stepper("\(playerLimit) players", value: $playerLimit, in: 2...50)
                }
            }
            .navigationTitle("Create Meetup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task { await createMeetup() }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    private func createMeetup() async {
        isSaving = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let request = CreateMeetupRequest(
            sport: sport.rawValue,
            title: title,
            description: description,
            date: dateFormatter.string(from: date),
            time: timeFormatter.string(from: time),
            location: location,
            skillLevels: Array(selectedSkillLevels),
            playerLimit: playerLimit
        )

        let success = await viewModel.createMeetup(token: authViewModel.getToken(), request: request)
        if success {
            dismiss()
        }

        isSaving = false
    }
}

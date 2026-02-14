import SwiftUI

struct ProposalSheet: View {
    let matchId: String
    let token: String?
    let onProposed: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = true
    @State private var compatibleTimes: [String: [String]] = [:]
    @State private var sharedSports: [SharedSport] = []
    @State private var errorMessage: String?

    @State private var selectedSport = ""
    @State private var selectedDay = ""
    @State private var selectedStartHour = 9
    @State private var selectedEndHour = 10
    @State private var location = ""
    @State private var isSending = false

    private let dayOrder = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Finding compatible times...")
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                    }
                } else if sharedSports.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sportscourt")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No shared sports found")
                            .foregroundColor(.secondary)
                        Text("You and your match don't have any sports in common yet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    Form {
                        Section("Sport") {
                            Picker("Sport", selection: $selectedSport) {
                                ForEach(sharedSports, id: \.sport) { sport in
                                    Text("\(sport.sport) (\(sport.userLevel) / \(sport.partnerLevel))")
                                        .tag(sport.sport)
                                }
                            }
                        }

                        Section("Day & Time") {
                            let availableDays = dayOrder.filter { compatibleTimes[$0] != nil }
                            if availableDays.isEmpty {
                                Text("No overlapping availability found")
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("Day", selection: $selectedDay) {
                                    ForEach(availableDays, id: \.self) { day in
                                        Text(day).tag(day)
                                    }
                                }

                                if let hours = compatibleTimes[selectedDay] {
                                    let hourInts = hours.compactMap { AvailabilityHelper.parseHour($0) }.sorted()
                                    if !hourInts.isEmpty {
                                        Picker("Start", selection: $selectedStartHour) {
                                            ForEach(hourInts, id: \.self) { hour in
                                                Text(AvailabilityHelper.formatHour(hour)).tag(hour)
                                            }
                                        }
                                        Picker("End", selection: $selectedEndHour) {
                                            ForEach(hourInts.filter { $0 > selectedStartHour }, id: \.self) { hour in
                                                Text(AvailabilityHelper.formatHour(hour)).tag(hour)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Section("Location (optional)") {
                            TextField("e.g. ARC Courts, Tennis Courts", text: $location)
                        }
                    }
                }
            }
            .navigationTitle("Propose Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        Task { await sendProposal() }
                    }
                    .disabled(selectedSport.isEmpty || selectedDay.isEmpty || isSending)
                }
            }
            .task {
                await loadCompatibleTimes()
            }
        }
    }

    private func loadCompatibleTimes() async {
        guard let token = token else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        do {
            let response = try await MessageService.shared.getCompatibleTimes(token: token, matchId: matchId)
            compatibleTimes = response.compatibleTimes
            sharedSports = response.sharedSports

            // Set defaults
            if let first = sharedSports.first {
                selectedSport = first.sport
            }
            let availableDays = dayOrder.filter { compatibleTimes[$0] != nil }
            if let firstDay = availableDays.first {
                selectedDay = firstDay
                if let hours = compatibleTimes[firstDay] {
                    let hourInts = hours.compactMap { AvailabilityHelper.parseHour($0) }.sorted()
                    if let firstHour = hourInts.first {
                        selectedStartHour = firstHour
                        selectedEndHour = hourInts.first(where: { $0 > firstHour }) ?? firstHour + 1
                    }
                }
            }
        } catch {
            errorMessage = "Failed to load compatible times"
        }

        isLoading = false
    }

    private func sendProposal() async {
        guard let token = token else { return }
        isSending = true

        let request = CreateSessionRequest(
            sport: selectedSport,
            day: selectedDay,
            startHour: selectedStartHour,
            endHour: selectedEndHour,
            location: location
        )

        do {
            _ = try await MessageService.shared.createSession(token: token, matchId: matchId, request: request)
            onProposed()
            dismiss()
        } catch {
            errorMessage = "Failed to send proposal"
        }

        isSending = false
    }
}

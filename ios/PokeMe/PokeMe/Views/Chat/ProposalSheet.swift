import SwiftUI
import MapKit

// MARK: - MapKit autocomplete helper

class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .query]
        // Bias toward UC Davis campus
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.5382, longitude: -121.7617),
            latitudinalMeters: 15_000, longitudinalMeters: 15_000
        )
    }

    func search(_ query: String) {
        guard !query.isEmpty else { results = []; return }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(5))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

// MARK: - ProposalSheet

struct ProposalSheet: View {
    let matchId: String
    let token: String?
    var prefillSession: Session? = nil
    let onProposed: () -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationCompleter = LocationSearchCompleter()

    @State private var sharedSports: [SharedSport] = []
    @State private var selectedSport = Sport.tennis.rawValue
    @State private var selectedDate = Date()
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime:   Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var location = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showSportPicker = false
    @State private var skipLocationSearch = false

    // Derived values sent to the backend
    private var selectedDay: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE"
        return f.string(from: selectedDate)
    }
    private var selectedDateISO: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: selectedDate)
    }
    private var selectedStartHour: Int { Calendar.current.component(.hour, from: startTime) }
    private var selectedEndHour:   Int { Calendar.current.component(.hour, from: endTime) }

    var body: some View {
        NavigationView {
            Form {
                sportSection
                dateTimeSection
                locationSection

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.caption)
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
                    Button("Send") { Task { await sendProposal() } }
                        .disabled(isSending)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showSportPicker) {
                SportPickerSheet(sharedSports: sharedSports, selectedSport: $selectedSport)
            }
            .task { await loadSharedSports() }
        }
    }

    // MARK: - Sport

    private var sportSection: some View {
        Section("Sport") {
            Button { showSportPicker = true } label: {
                HStack {
                    Text(selectedSport).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Date & Time

    private var dateTimeSection: some View {
        Section("Day & Time") {
            DatePicker("Date", selection: $selectedDate,
                       in: Date()...,
                       displayedComponents: .date)

            DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                .onChange(of: startTime) { newVal in
                    if endTime <= newVal {
                        endTime = Calendar.current.date(byAdding: .hour, value: 1, to: newVal) ?? newVal
                    }
                }

            DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
        }
    }

    // MARK: - Location (MapKit)

    private var locationSection: some View {
        Section("Location (optional)") {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.orange)
                TextField("Search or type a location…", text: $location)
                    .onChange(of: location) { query in
                        if skipLocationSearch { skipLocationSearch = false; return }
                        locationCompleter.search(query)
                    }
                if !location.isEmpty {
                    Button {
                        location = ""
                        locationCompleter.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(locationCompleter.results, id: \.title) { result in
                Button {
                    skipLocationSearch = true
                    location = result.title
                    locationCompleter.results = []
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                            .foregroundColor(.primary)
                            .font(.subheadline)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Load shared sports

    private func loadSharedSports() async {
        if let token = token,
           let response = try? await MessageService.shared.getCompatibleTimes(token: token, matchId: matchId) {
            sharedSports = response.sharedSports
            // Only auto-select first shared sport when not pre-filling
            if prefillSession == nil, let first = sharedSports.first {
                selectedSport = first.sport
            }
        }
        // Apply prefill values after sport loading so they win
        if let s = prefillSession {
            selectedSport = s.sport
            // Use stored ISO date if available, otherwise derive from weekday name
            if let isoDate = s.date, !isoDate.isEmpty {
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                selectedDate = f.date(from: isoDate) ?? nextDate(for: s.day)
            } else {
                selectedDate = nextDate(for: s.day)
            }
            startTime = Calendar.current.date(bySettingHour: s.startHour, minute: 0, second: 0, of: Date()) ?? startTime
            endTime   = Calendar.current.date(bySettingHour: s.endHour,   minute: 0, second: 0, of: Date()) ?? endTime
            location  = s.location ?? ""
        }
    }

    private func nextDate(for dayName: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let calendar = Calendar.current
        for i in 0..<8 {
            let candidate = calendar.date(byAdding: .day, value: i, to: Date()) ?? Date()
            if formatter.string(from: candidate) == dayName { return candidate }
        }
        return Date()
    }

    // MARK: - Send

    private func sendProposal() async {
        guard let token = token else { return }
        isSending = true
        errorMessage = nil

        let request = CreateSessionRequest(
            sport: selectedSport,
            day: selectedDay,
            date: selectedDateISO,
            startHour: selectedStartHour,
            endHour: selectedEndHour,
            location: location
        )

        do {
            _ = try await MessageService.shared.createSession(token: token, matchId: matchId, request: request)
            onProposed()
            dismiss()
        } catch {
            errorMessage = "Failed to send proposal. Please try again."
        }

        isSending = false
    }
}

// MARK: - Sport Picker Sheet

private struct SportPickerSheet: View {
    let sharedSports: [SharedSport]
    @Binding var selectedSport: String
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    private var sharedNames: Set<String> { Set(sharedSports.map { $0.sport }) }

    private var filteredSports: [(name: String, isShared: Bool)] {
        let shared = sharedSports.map { ($0.sport, true) }
        let rest = Sport.allCases.map { $0.rawValue }
            .filter { !sharedNames.contains($0) }
            .map { ($0, false) }
        let all = shared + rest
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            List(filteredSports, id: \.name) { item in
                Button {
                    selectedSport = item.name
                    dismiss()
                } label: {
                    HStack {
                        Text(item.name).foregroundColor(.primary)
                        Spacer()
                        if item.isShared {
                            Text("Both play")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                        }
                        if selectedSport == item.name {
                            Image(systemName: "checkmark").foregroundColor(.orange)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search sports…")
            .navigationTitle("Select Sport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

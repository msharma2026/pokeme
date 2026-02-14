import SwiftUI

struct HourPickerSheet: View {
    @Binding var availability: [String: [String]]
    @Environment(\.dismiss) var dismiss

    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    @State private var selectedDay = "Monday"
    @State private var startHour = 9
    @State private var endHour = 11

    var body: some View {
        NavigationView {
            Form {
                Section("Day") {
                    Picker("Day", selection: $selectedDay) {
                        ForEach(days, id: \.self) { day in
                            Text(day).tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Time Range") {
                    Picker("Start", selection: $startHour) {
                        ForEach(6..<23, id: \.self) { hour in
                            Text(AvailabilityHelper.formatHour(hour)).tag(hour)
                        }
                    }

                    Picker("End", selection: $endHour) {
                        ForEach((startHour + 1)...23, id: \.self) { hour in
                            Text(AvailabilityHelper.formatHour(hour)).tag(hour)
                        }
                    }
                }

                Section {
                    Text("This adds \(AvailabilityHelper.formatHour(startHour)) - \(AvailabilityHelper.formatHour(endHour)) on \(selectedDay)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addHours()
                        dismiss()
                    }
                }
            }
            .onChange(of: startHour) { newValue in
                if endHour <= newValue {
                    endHour = min(newValue + 1, 23)
                }
            }
        }
        .presentationDetents([.height(380)])
    }

    private func addHours() {
        var daySlots = availability[selectedDay] ?? []
        for hour in startHour..<endHour {
            let hourStr = AvailabilityHelper.hourString(hour)
            if !daySlots.contains(hourStr) {
                daySlots.append(hourStr)
            }
        }
        availability[selectedDay] = daySlots
    }
}

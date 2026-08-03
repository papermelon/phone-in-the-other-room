import SwiftUI

struct WindDownScheduleView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var overrideStart = Date().addingTimeInterval(60 * 60)
    @State private var overrideEnd = Date().addingTimeInterval(90 * 60)
    @State private var overrideRole: WindDownOccurrenceRole = .additionalQuiet
    @State private var routineTitle = "A little extra quiet"
    @State private var routineStart = Date().addingTimeInterval(2 * 60 * 60)
    @State private var routineEnd = Date().addingTimeInterval(3 * 60 * 60)
    @State private var routineError: String?

    var body: some View {
        Form {
            Section {
                Text("Your usual Wind Down stays anchored to the sleep plan. Add a bounded quiet period when another part of the day needs a little room.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
            }

            Section("Saved periods") {
                if viewModel.windDownRoutines.isEmpty {
                    Text("No additional periods saved.")
                        .foregroundStyle(AppColors.muted)
                } else {
                    ForEach(viewModel.windDownRoutines) { routine in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(routine.title)
                                    .font(AppTypography.headline)
                                Text("\(routine.start.hour, specifier: "%02d"): \(routine.start.minute, specifier: "%02d")–\(routine.end.hour, specifier: "%02d"): \(routine.end.minute, specifier: "%02d")")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                            Spacer()
                            Text(routine.role == .primarySleepBookend ? "Primary" : "Additional")
                                .font(AppTypography.caption)
                                .foregroundStyle(routine.role == .primarySleepBookend ? AppColors.grass : AppColors.muted)
                        }
                    }
                }
            }

            Section("Adjust next Wind Down") {
                DatePicker("Starts", selection: $overrideStart, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Ends", selection: $overrideEnd, in: overrideStart..., displayedComponents: [.date, .hourAndMinute])
                Picker("Type", selection: $overrideRole) {
                    Text("Additional quiet").tag(WindDownOccurrenceRole.additionalQuiet)
                    Text("Primary sleep bookend").tag(WindDownOccurrenceRole.primarySleepBookend)
                }
                if let override = viewModel.nextWindDownOverride {
                    Text("Next period adjusted until \(override.interval.start.formatted(date: .abbreviated, time: .shortened)).")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                    Button("Clear next-period adjustment", role: .destructive) {
                        viewModel.clearNextWindDownOverride()
                    }
                }
                Button("Use this period once") {
                    viewModel.adjustNextWindDown(start: overrideStart, end: overrideEnd, role: overrideRole)
                }
                .buttonStyle(.borderedProminent)
                .disabled(overrideEnd <= overrideStart)
            }

            Section("Add a recurring quiet period") {
                TextField("Name", text: $routineTitle)
                DatePicker("Starts", selection: $routineStart, displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: $routineEnd, displayedComponents: .hourAndMinute)
                if let routineError {
                    Text(routineError)
                        .font(AppTypography.caption)
                        .foregroundStyle(.red)
                }
                Button("Save additional period") {
                    let calendar = Calendar.current
                    let start = WindDownClockTime(
                        hour: calendar.component(.hour, from: routineStart),
                        minute: calendar.component(.minute, from: routineStart)
                    )
                    let end = WindDownClockTime(
                        hour: calendar.component(.hour, from: routineEnd),
                        minute: calendar.component(.minute, from: routineEnd)
                    )
                    if viewModel.addAdditionalWindDown(title: routineTitle, start: start, end: end) {
                        routineError = nil
                    } else {
                        routineError = "That period overlaps another saved Wind Down. Choose a different time."
                    }
                }
                .buttonStyle(.bordered)
                .disabled(routineEnd <= routineStart)
            }
        }
        .navigationTitle("Wind Down periods")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Wind Down periods") {
    NavigationStack {
        WindDownScheduleView()
            .environmentObject(FocusRunViewModel())
    }
}

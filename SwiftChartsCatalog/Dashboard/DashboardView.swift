import SwiftUI

/// The Dashboard tab: linked charts of the café data with a shared selection and breakdown.
/// One model holds the selected day, the selected drink and the breakdown; every panel reads it, and a tap
/// on a chart or a choice in a picker writes it, so all the panels move together.
struct DashboardView: View {
    @State private var model: DashboardModel
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(model: DashboardModel = DashboardModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    // The headline keeps the height of the longest it can show, so a tap does not move the
                    // charts. At the accessibility sizes that reserve alone was taller than an iPhone's screen,
                    // so there it takes the height of the sentence shown.
                    ScreenHeadline(
                        caption: "Two cafés, four weeks",
                        message: model.headline(locale: locale),
                        reservedMessage: dynamicTypeSize.isAccessibilitySize ? nil : model.longestHeadline(locale: locale)
                    )
                    DashboardColumns()
                }
                .padding(Layout.screenPadding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
        }
        .environment(model)
        // Every change to what the panels show is said aloud: what changed, then the headline. One sentence
        // per action: the model counts actions, so Clear selection, which changes the day and the drink,
        // posts one announcement, not two that cut each other off.
        .onChange(of: model.selectionChangeCount) {
            if let change = model.lastSelectionChange {
                dashboardAnnounce(model.announcement(for: change, locale: locale))
            }
        }
        .onChange(of: model.breakdown) {
            dashboardAnnounce(model.announcement(for: .breakdown, locale: locale))
        }
    }
}

/// The breakdown and the two selections as controls, so everything a tap on a chart does can be done
/// without one.
private struct DashboardControls: View {
    @Environment(DashboardModel.self) private var model
    @Environment(\.locale) private var locale

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            // A plain picker with a visible label: the label is also what VoiceOver reads.
            LabeledControlRow(title: "Breakdown") {
                Picker("Breakdown", selection: $model.breakdown) {
                    ForEach(DashboardBreakdown.allCases) { breakdown in
                        Text(breakdown.seriesLabel).tag(breakdown)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                // A segmented picker with its label hidden has no name of its own once the row's title is
                // hidden (read on iOS: "SegmentedControl" with no label), unlike the menu pickers.
                .accessibilityLabel("Breakdown")
                .fixedSize()
            }
            LabeledControlRow(title: CafeWording.day) {
                Picker(CafeWording.day, selection: Binding(get: { model.selectedDay }, set: { model.selectDay($0) })) {
                    Text("All four weeks").tag(Date?.none)
                    ForEach(model.days, id: \.self) { day in
                        // The month and day alone: "Wednesday, March 18" wrapped to two lines in the menu
                        // button even at the default size. The summary and headline give the weekday.
                        Text(model.shortDayName(day, locale: locale))
                            .tag(Date?.some(day))
                    }
                }
                .labelsHidden()
            }
            LabeledControlRow(title: CafeWording.drink) {
                Picker(CafeWording.drink, selection: Binding(get: { model.selectedDrink }, set: { model.selectDrink($0) })) {
                    Text("All drinks").tag(String?.none)
                    ForEach(model.drinks, id: \.self) { drink in
                        Text(drink).tag(String?.some(drink))
                    }
                }
                .labelsHidden()
            }
            Button("Clear selection") {
                model.clearSelection()
            }
            .disabled(!model.hasSelection)
            Text("Tap a day on Cups per day, or a drink on Drink mix, to select it everywhere.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .disabled(model.isEmpty)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.panelPadding)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// Two columns where they fit (iPad), one otherwise (iPhone, or an iPad at a narrow split).
/// In one column Cups per day comes first, straight under the headline, so the first screen holds a chart
/// and a tap on it changes the sentence in view; the controls and the summary follow it.
private struct DashboardColumns: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                DashboardControls()
                DashboardTwoColumns()
            }
            VStack(spacing: Layout.sectionSpacing) {
                DashboardCupsPerDayPanel()
                DashboardControls()
                DashboardSummaryPanel()
                DashboardDrinkMixPanel()
                DashboardWeekdayPanel()
            }
        }
    }
}

private struct DashboardTwoColumns: View {
    var body: some View {
        // Each column's ideal width is its minimum: ViewThatFits compares ideal widths, and an unwrapped
        // subtitle ("… Shades from 160 to 260 cups.") had made a column ideally wider than half an iPad,
        // which then got one column (seen on iOS).
        HStack(alignment: .top, spacing: Layout.sectionSpacing) {
            VStack(spacing: Layout.sectionSpacing) {
                DashboardSummaryPanel()
                DashboardCupsPerDayPanel()
            }
            .frame(minWidth: DashboardLayout.minimumColumnWidth, idealWidth: DashboardLayout.minimumColumnWidth, maxWidth: .infinity)
            VStack(spacing: Layout.sectionSpacing) {
                DashboardDrinkMixPanel()
                DashboardWeekdayPanel()
            }
            .frame(minWidth: DashboardLayout.minimumColumnWidth, idealWidth: DashboardLayout.minimumColumnWidth, maxWidth: .infinity)
        }
    }
}

#Preview {
    DashboardView()
}

#Preview("A day and a drink selected") {
    let model = DashboardModel()
    model.selectDay(CafeData.day(CafeData.dashboardNoMochaOffset))
    model.selectDrink("Mocha")
    return DashboardView(model: model)
}

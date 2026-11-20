#if DEBUG
    import Accessibility
    import UIKit

    /// A tool, not a feature: with the launch argument `-dumpChartDescriptors`, the app walks its own
    /// accessibility tree every two seconds and writes every chart descriptor it finds (what the Audio
    /// Graph is given) to `chart-descriptors.txt` in its temporary folder. The tree exists only while an
    /// assistive client is attached, which `scripts/ax-dump.sh --audio-graph` provides.
    enum ChartDescriptorDump {
        static let argument = "-dumpChartDescriptors"
        static let fileName = "chart-descriptors.txt"

        static func runIfAsked(arguments: [String] = ProcessInfo.processInfo.arguments) async {
            guard arguments.contains(argument) else { return }
            let url = FileManager.default.temporaryDirectory.appending(path: fileName(arguments: arguments))
            for _ in 0 ..< 30 {
                try? await Task.sleep(for: .seconds(2))
                let text = dump()
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }

        /// `chart-descriptors.txt`, or with the screen's id in the name when one was opened at launch
        /// (`chart-descriptors-interaction-scrolling.txt`), so a batch of screens leaves one file each.
        static func fileName(arguments: [String]) -> String {
            guard let screenID = LaunchArguments(arguments).screenID ?? (LaunchArguments(arguments).opensDashboard ? LaunchArguments.dashboardID : nil)
            else { return fileName }
            return "chart-descriptors-\(screenID.replacing("/", with: "-")).txt"
        }

        static func dump() -> String {
            var lines: [String] = []
            var seen = Set<ObjectIdentifier>()
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
            var visited = 0
            for window in windows {
                walk(window, depth: 0, lines: &lines, seen: &seen, visited: &visited)
            }
            return "visited \(visited) objects\n" + lines.joined(separator: "\n") + "\n"
        }

        private static func walk(
            _ object: NSObject, depth: Int, lines: inout [String], seen: inout Set<ObjectIdentifier>, visited: inout Int
        ) {
            guard depth < 60, seen.insert(ObjectIdentifier(object)).inserted else { return }
            visited += 1
            let selector = NSSelectorFromString("accessibilityChartDescriptor")
            if object.responds(to: selector),
               let descriptor = object.value(forKey: "accessibilityChartDescriptor") as? AXChartDescriptor
            {
                lines.append("CHART on \(type(of: object)) label=\(object.accessibilityLabel ?? "nil")")
                lines.append(describe(descriptor))
            }
            var children: [NSObject] = []
            if let elements = object.accessibilityElements as? [NSObject] { children += elements }
            let count = object.accessibilityElementCount()
            if count != NSNotFound, count > 0 {
                for index in 0 ..< count {
                    if let child = object.accessibilityElement(at: index) as? NSObject { children.append(child) }
                }
            }
            if let view = object as? UIView { children += view.subviews }
            for child in children {
                walk(child, depth: depth + 1, lines: &lines, seen: &seen, visited: &visited)
            }
        }

        private static func describe(_ descriptor: AXChartDescriptor) -> String {
            var out: [String] = []
            out.append("  title: \(descriptor.title ?? "nil")")
            out.append("  summary: \(descriptor.summary ?? "nil")")
            out.append("  x axis: \(axis(descriptor.xAxis))")
            if let y = descriptor.yAxis { out.append("  y axis: \(axis(y))") }
            for axis in descriptor.additionalAxes {
                out.append("  extra axis: \(self.axis(axis))")
            }
            for series in descriptor.series {
                out.append("  series \(series.name ?? "nil") continuous=\(series.isContinuous) points=\(series.dataPoints.count)")
                for point in series.dataPoints.prefix(8) {
                    let xText = String(describing: point.xValue)
                    let yText = point.yValue.map { String(describing: $0) } ?? "nil"
                    out.append("    x=\(xText) y=\(yText) label=\(point.label ?? "nil")")
                }
            }
            return out.joined(separator: "\n")
        }

        private static func axis(_ axis: any AXDataAxisDescriptor) -> String {
            if let numeric = axis as? AXNumericDataAxisDescriptor {
                let samples = [numeric.range.lowerBound, numeric.range.upperBound].map(numeric.valueDescriptionProvider)
                return "numeric '\(numeric.title)' range \(numeric.range) ends read as \(samples)"
            }
            if let categorical = axis as? AXCategoricalDataAxisDescriptor {
                return "categorical '\(categorical.title)' \(categorical.categoryOrder.prefix(8))"
            }
            return "\(type(of: axis)) '\(axis.title)'"
        }
    }
#endif

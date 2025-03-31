import Foundation

extension Distribution {
    private var cycleDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = zulu
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }

    private var readmeFirstLine: Data { "AIS subscriber files effective date ".data(using: .isoLatin1)! }

    /**
     Reads the cycle from the README file.
     
     - Returns: The parsed cycle, or `nil` if the cycle could not be parsed.
     */

    public func readCycle() async throws -> Cycle? {
        let path = try findFile(prefix: "Read_me") ?? "README.txt"

        let lines: AsyncThrowingStream = await readFile(path: path, withProgress: { _ in }, returningLines: { _ in })
        for try await line in lines where line.starts(with: readmeFirstLine) {
            return parseCycleFrom(line)
        }
        return nil
    }

    private func parseCycleFrom(_ line: Data) -> Cycle? {
        let cycleDateData = line[readmeFirstLine.count..<(line.count - 1)]
        guard let cycleDateString = String(data: cycleDateData, encoding: .isoLatin1) else {
            return nil
        }
        guard let cycleDate = cycleDateFormatter.date(from: cycleDateString) else {
            return nil
        }

        let cycleComponents = Calendar(identifier: .gregorian).dateComponents(in: zulu, from: cycleDate)
        guard let year = cycleComponents.year else { return nil }
        guard let month = cycleComponents.month else { return nil }
        guard let day = cycleComponents.day else { return nil }

        return Cycle(year: UInt(year), month: UInt8(month), day: UInt8(day))
    }
}

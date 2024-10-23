import Foundation

actor StateParser: Parser {
    private var states: Array<State> = []
    private var seenStateCode = false
    
    func prepare(distribution: any Distribution) async throws {
        states = []
    }
    
    func parse(data: Data) throws {
        guard let line = String(data: data, encoding: .isoLatin1) else { throw ParserError.badData("Not ISO-Latin1 formatted") }

        if line.starts(with: "STATE_CODE NON_US_STATE_CODE") {
            seenStateCode = true
            return
        }
        
        if line.isEmpty { return }
        if !seenStateCode { return }
        if line.contains("rows selected") { return }
        if line[line.startIndex] == Character("-") { return }
        
        let code = line[line.startIndex...line.index(line.startIndex, offsetBy: 1)]
        let nameStart = line.index(line.startIndex, offsetBy: 60)
        let nameEnd = line.index(nameStart, offsetBy: 30)
        let name = line[nameStart...nameEnd].trimmingCharacters(in: CharacterSet.whitespaces)
        
        states.append(State(name: name, code: String(code)))
    }
    
    func finish(data: NASRData) async {
        await data.finishParsing(states: states)
    }
}

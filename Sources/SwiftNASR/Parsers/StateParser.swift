import Foundation

class StateParser: Parser {
    private var states: Array<State> = []
    private var seenStateCode = false
    
    func prepare(distribution: Distribution, callback: @escaping ((Result<Void, Swift.Error>) -> Void) = { _ in }) {
        states = []
        callback(.success(()))
    }
    
    func parse(data: Data) throws {
        guard let line = String(data: data, encoding: .ascii) else { throw ParserError.badData("Not ASCII formatted") }
        
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
    
    func finish(data: NASRData) {
        data.states = states
    }
}

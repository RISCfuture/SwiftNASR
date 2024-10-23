fileprivate let arrestingSystemDLIDOffsetRange = 3...4
// these should be labeled "DLID" but they're not

extension AirportParser {
    private var remarkTransformer: FixedWidthTransformer {
        .init([
            .recordType,                                                                // 0 record type
            .string(),                                                                  // 1 site number
            .string(nullable: .blank),                                                  // 2 state post office code
            .string(),                                                                  // 3 data element
            .string(),                                                                  // 4 remark
        ])
    }

    func parseRemarkRecord(_ values: Array<String>) throws {
        if (values[4].trimmingCharacters(in: .whitespaces).isEmpty) { return }
        let transformedValues = try remarkTransformer.applyTo(values)
        
        guard var airport = airports[transformedValues[1] as! String] else { return }
        let fieldID = String((transformedValues[3] as! String).split(separator: Character(" "))[0])
        let remark = transformedValues[4] as! String

        var remarkParsed = false
        if try tryAirportGeneralRemark(remark, &airport, fieldID) { remarkParsed = true }
        else if try tryAirportLightingRemark(remark, &airport, fieldID) { remarkParsed = true }
        else if try tryAttendanceScheduleRemark(remark, &airport, fieldID) { remarkParsed = true }
        else if try tryRunwayOrEndFieldRemark(remark, &airport, fieldID) { remarkParsed = true }
        else if try tryAirportFieldRemark(remark, &airport, fieldID) { remarkParsed = true }
        else if try tryAirportFuelRemark(remark, &airport, fieldID) { remarkParsed = true }
        if !remarkParsed { throw AirportRemarksError.unknownFieldID(fieldID, airport: airport) }

        airports[transformedValues[1] as! String] = airport
    }
    
    private func tryAirportGeneralRemark(_ remark: String, _ airport: inout Airport, _ fieldID: String) throws -> Bool {
        guard fieldID.starts(with: "A110-") || fieldID.starts(with: "A110*") else { return false }
        airport.remarks.append(.general(remark))
        
        return true
    }
    
    private func tryAirportLightingRemark(_ remark: String, _ airport: inout Airport, _ fieldID: String) throws -> Bool {
        if fieldID == "A81-APT" {
            airport.remarks.append(.field(field: .airportLightingSchedule, content: remark))
            return true
        } else if fieldID == "A81-BCN" {
            airport.remarks.append(.field(field: .beaconLightingSchedule, content: remark))
            return true
        }
        
        return false
    }
    
    private func tryAttendanceScheduleRemark(_ remark: String, _ airport: inout Airport, _ fieldID: String) throws -> Bool {
        guard attendanceScheduleFieldForID(fieldID) else { return false }
        airport.remarks.append(.field(field: .attendanceSchedule, content: remark))
        return true
    }
    
    private func tryAirportFuelRemark(_ remark: String, _ airport: inout Airport, _ combinedFieldID: String) throws -> Bool {
        let parts = combinedFieldID.split(separator: "-")
        guard parts.count == 3 else { return false }
        guard parts[0] == "A70" else { return false }
        guard let fuelType = Airport.FuelType(rawValue: String(parts[2])) else {
            throw AirportRemarksError.unknownFuelType(String(parts[2]), airport: airport)
        }
        airport.remarks.append(.fuel(field: .fuelsAvailable, fuel: fuelType, content: remark))
        
        return true
    }
    
    private func tryRunwayOrEndFieldRemark(_ remark: String, _ airport: inout Airport, _ combinedFieldID: String) throws -> Bool {
        guard let separatorIndex = combinedFieldID.firstIndex(of: Character("-")) else {
            return false
        }
        let fieldID = String(combinedFieldID[combinedFieldID.startIndex..<separatorIndex])
        let objectID = String(combinedFieldID[combinedFieldID.index(after: separatorIndex)...])
        
        if try tryArrestingSystemRemark(remark, &airport, objectID, fieldID) { return true }
        if try tryRunwayEndFieldRemark(remark, &airport, objectID, fieldID) { return true }
        if try tryRunwayEndGeneralRemark(remark, &airport, objectID, fieldID) { return true }
        if try tryRunwayFieldRemark(remark, &airport, objectID, fieldID) { return true }

        return false
    }
    
    private func tryArrestingSystemRemark(_ remark: String, _ airport: inout Airport, _ endID: String, _ fieldID: String) throws -> Bool {
        guard arrestingSystemFieldForID(fieldID) else { return false }

        let found = updateRunwayEnd(endID, inAirport: &airport) { end in
            end.remarks.append(.field(field: .arrestingSystems, content: remark))
        }
        if !found { throw AirportRemarksError.unknownRunwayEnd(endID, airport: airport) }

        return true
    }
    
    private func tryRunwayEndFieldRemark(_ remark: String, _ airport: inout Airport, _ endID: String, _ fieldID: String) throws -> Bool {
        var endUpdated = false
        let endFound = try updateRunwayEnd(endID, inAirport: &airport) { end in
            if try tryLAHSOFieldRemark(remark, &end, fieldID) { endUpdated = true }
            else if try tryControllingObjectFieldRemark(remark, &end, fieldID) { endUpdated = true }
            else {
                guard let field = runwayEndFieldForID(fieldID) else { return }
                switch field {
                    case .LAHSO:
                        preconditionFailure("NASR field defined in RunwayEnd.Field.fieldOrder but not LAHSO.Field.fieldOrder")
                    case .controllingObject:
                        preconditionFailure("NASR field defined in RunwayEnd.Field.fieldOrder but not ControllingObject.Field.fieldOrder")
                    default:
                        end.remarks.append(.field(field: field, content: remark))
                        endUpdated = true
                }
            }
        }

        if endFound && endUpdated { return true }
        else if endFound && !endUpdated { return false }
        else if runwayEndFieldForID(fieldID) != nil {
            throw AirportRemarksError.unknownRunwayEnd(endID, airport: airport)
        } else {
            return false
        }
    }
    
    private func tryLAHSOFieldRemark(_ remark: String, _ end: inout RunwayEnd, _ fieldID: String) throws -> Bool {
        guard let field = LAHSOFieldForID(fieldID) else { return false }

        if end.LAHSO == nil {
            end.remarks.append(.general(remark))
            return true
        }
        
        end.LAHSO!.remarks.append(.field(field: field, content: remark))
        return true
    }
    
    private func tryControllingObjectFieldRemark(_ remark: String, _ end: inout RunwayEnd, _ fieldID: String) throws -> Bool {
        guard let field = controllingObjectFieldForID(fieldID) else { return false }

        if end.controllingObject == nil {
            end.remarks.append(.general(remark))
            return true
        }
        
        end.controllingObject!.remarks.append(.field(field: field, content: remark))
        return true
    }
    
    private func tryRunwayEndGeneralRemark(_ remark: String, _ airport: inout Airport, _ endID: String, _ fieldID: String) throws -> Bool {
        guard fieldID == "A58" else { return false } // A58 is not defined; probably legacy

        let found = updateRunwayEnd(endID, inAirport: &airport) { end in
            end.remarks.append(.general(remark))
        }
        if !found { throw AirportRemarksError.unknownRunwayEnd(endID, airport: airport) }

        return true
    }
    
    private func tryRunwayFieldRemark(_ remark: String, _ airport: inout Airport, _ runwayID: String, _ fieldID: String) throws -> Bool {
        guard let field = runwayFieldForID(fieldID) else { return false }

        let found = updateRunway(runwayID, inAirport: &airport) { runway in
            runway.remarks.append(.field(field: field, content: remark))
        }
        if !found { throw AirportRemarksError.unknownRunway(runwayID, airport: airport) }

        return true
    }
    
    private func tryAirportFieldRemark(_ remark: String, _ airport: inout Airport, _ fieldID: String) throws -> Bool {
        if try tryAirportPersonRemark(remark, &airport, fieldID) { return true }

        guard let field = airportFieldForID(fieldID) else { return false }
        
        switch field {
            case .owner, .manager:
                preconditionFailure("NASR field defined in Airport.Field.fieldOrder but not Person.Field.fieldOrder")
            default:
                airport.remarks.append(.field(field: field, content: remark))
                return true
        }
    }
    
    private func tryAirportPersonRemark(_ remark: String, _ airport: inout Airport, _ fieldID: String) throws -> Bool {
        guard let airportField = airportFieldForID(fieldID) else { return false}
        guard let field = personFieldForID(fieldID) else { return false }
        
        switch airportField {
            case .owner:
                if airport.owner == nil {
                    airport.remarks.append(.general(remark))
                    return true
                }
                airport.owner!.remarks.append(.field(field: field, content: remark))
                return true
            case .manager:
                if airport.manager == nil {
                    airport.remarks.append(.general(remark))
                    return true
                }
                airport.manager!.remarks.append(.field(field: field, content: remark))
                return true
            default:
                preconditionFailure("Person field on Airport.Field.fieldOrder does not correspond with same field on Person.Field.fieldOrder")
        }
    }
    
    private func runwayFieldForID(_ fieldID: String) -> Runway.Field? {
        let layout = format(forRecordIdentifier: .runway)
        guard let offset = layout.fieldOffset(forID: fieldID) else { return nil }
        return Runway.Field.fieldOrder[offset]
    }

    enum RunwayEndType { case base, reciprocal }

    private func runwayEndIndexForID(_ identifier: String, inAirport airport: Airport) -> (Int, RunwayEndType)? {
        for (index, runway) in airport.runways.enumerated() {
            if runway.baseEnd.ID == identifier { return (index, .base) }
            if runway.reciprocalEnd?.ID == identifier { return (index, .reciprocal) }
        }
        return nil
    }

    @discardableResult
    private func updateRunwayEnd(_ identifier: String, inAirport airport: inout Airport, process: (inout RunwayEnd) throws -> Void) rethrows -> Bool {
        guard let (index, endType) = runwayEndIndexForID(identifier, inAirport: airport) else {
            return false
        }
        var end = switch endType {
            case .base: airport.runways[index].baseEnd
            case .reciprocal: airport.runways[index].reciprocalEnd!
        }

        try process(&end)

        switch endType {
            case .base: airport.runways[index].baseEnd = end
            case .reciprocal: airport.runways[index].reciprocalEnd = end
        }

        return true
    }

    @discardableResult
    private func updateRunway(_ identifier: String, inAirport airport: inout Airport, process: (inout Runway) throws -> Void) rethrows -> Bool {
        let strippedID = identifier.split(separator: Character(" "))[0]
        guard let index =  airport.runways.firstIndex(where: { $0.identification == strippedID }) else {
            return false
        }
        var runway = airport.runways[index]

        try process(&runway)

        airport.runways[index] = runway
        return true

    }

    private func airportFieldForID(_ fieldID: String) -> Airport.Field? {
        if fieldID == "E80A" { return .customsLandingRightsAirport } // special user fee remark
        
        let layout = format(forRecordIdentifier: .airport)
        guard let offset = layout.fieldOffset(forID: fieldID) else { return nil }
        return Airport.Field.fieldOrder[offset]
    }
    
    private func personFieldForID(_ fieldID: String) -> Airport.Person.Field? {
        let layout = format(forRecordIdentifier: .airport)
        guard let offset = layout.fieldOffset(forID: fieldID) else { return nil }
        return Airport.Person.Field.fieldOrder[offset]
    }
    
    private func runwayEndFieldForID(_ fieldID: String) -> RunwayEnd.Field? {
        let layout = format(forRecordIdentifier: .runway)
        guard let offset = layout.fieldOffset(forID: fieldID) else { return nil }
        return RunwayEnd.Field.fieldOrder[offset]
    }
    
    private func LAHSOFieldForID(_ fieldID: String) -> RunwayEnd.LAHSOPoint.Field? {
        let layout = format(forRecordIdentifier: .runway)
        guard let offset = layout.fieldOffset(forID: fieldID) else { return nil }
        return RunwayEnd.LAHSOPoint.Field.fieldOrder[offset]
    }
    
    private func controllingObjectFieldForID(_ fieldID: String) -> RunwayEnd.ControllingObject.Field? {
        let layout = format(forRecordIdentifier: .runway)
        guard let offset = layout.fieldOffset(forID: fieldID) else { return nil }
        return RunwayEnd.ControllingObject.Field.fieldOrder[offset]
    }
    
    private func attendanceScheduleFieldForID(_ fieldID: String) -> Bool {
        let layout = format(forRecordIdentifier: .attendanceSchedule)
        guard layout.fieldOffset(forID: fieldID) != nil else { return false }
        return true
    }
    
    private func arrestingSystemFieldForID(_ fieldID: String) -> Bool {
        let layout = format(forRecordIdentifier: .runwayArrestingSystem)
        guard let offset = layout.fieldOffset(forID: fieldID) else { return false }
        if arrestingSystemDLIDOffsetRange.contains(offset) { return false }
        return true
    }
}

enum AirportRemarksError: Swift.Error, CustomStringConvertible {
    case invalidGeneralRemarkSequence(airport: Airport, fieldID: String)
    case unknownFieldID(_ fieldID: String, airport: Airport)
    case invalidFieldID(_ fieldID: String, airport: Airport)
    case unknownRunway(_ runwayID: String, airport: Airport)
    case unknownRunwayEnd(_ endID: String, airport: Airport)
    case unknownFuelType(_ fuelType: String, airport: Airport)
    
    public var description: String {
        switch self {
            case let .invalidGeneralRemarkSequence(airport, fieldID):
                return "Invalid general remarks sequence for field '\(fieldID)' at '\(airport.LID)'"
            case let .unknownFieldID(fieldID, airport):
                return "Unknown field ID '\(fieldID)' at '\(airport.LID)'"
            case let .invalidFieldID(fieldID, airport):
                return "Invalid field ID '\(fieldID)' at '\(airport.LID)'"
            case let .unknownRunway(runwayID, airport):
                return "Unknown runway '\(runwayID)' at '\(airport.LID)'"
            case let .unknownRunwayEnd(endID, airport):
                return "Unknown runway end '\(endID)' at '\(airport.LID)'"
            case let .unknownFuelType(fuelType, airport):
                return "Unknown fuel type '\(fuelType)' at '\(airport.LID)'"
        }
    }
}


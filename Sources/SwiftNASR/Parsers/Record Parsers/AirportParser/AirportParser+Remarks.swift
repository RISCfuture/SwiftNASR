fileprivate let arrestingSystemDLIDOffsetRange = 3...4
// these should be labeled "DLID" but they're not

fileprivate let remarkTransformer = FixedWidthTransformer([
    .recordType,                                                                // 0 record type
    .string(),                                                                  // 1 site number
    .string(nullable: .blank),                                                  // 2 state post office code
    .string(),                                                                  // 3 data element
    .string(),                                                                  // 4 remark
])

extension AirportParser {
    func parseRemarkRecord(_ values: Array<String>) throws {
        if (values[4].trimmingCharacters(in: .whitespaces).isEmpty) { return }
        let transformedValues = try remarkTransformer.applyTo(values)
        
        guard let airport = airports[transformedValues[1] as! String] else { return }
        let fieldID = String((transformedValues[3] as! String).split(separator: Character(" "))[0])
        let remark = transformedValues[4] as! String
        
        if try tryAirportGeneralRemark(remark, airport, fieldID) { return }
        if try tryAirportLightingRemark(remark, airport, fieldID) { return }
        if try tryAttendanceScheduleRemark(remark, airport, fieldID) { return }
        if try tryRunwayOrEndFieldRemark(remark, airport, fieldID) { return }
        if try tryAirportFieldRemark(remark, airport, fieldID) { return }
        
        throw AirportRemarksError.unknownFieldID(fieldID, airport: airport)
    }
    
    private func tryAirportGeneralRemark(_ remark: String, _ airport: Airport, _ fieldID: String) throws -> Bool {
        guard fieldID.starts(with: "A110-") || fieldID.starts(with: "A110*") else { return false }
        airport.remarks.general.append(remark)
        
        return true
    }
    
    private func tryAirportLightingRemark(_ remark: String, _ airport: Airport, _ fieldID: String) throws -> Bool {
        if fieldID == "A81-APT" {
            airport.remarks.append(remark: remark, forField: .airportLightingSchedule)
            return true
        } else if fieldID == "A81-BCN" {
            airport.remarks.append(remark: remark, forField: .beaconLightingSchedule)
            return true
        }
        
        return false
    }
    
    private func tryAttendanceScheduleRemark(_ remark: String, _ airport: Airport, _ fieldID: String) throws -> Bool {
        guard attendanceScheduleFieldForID(fieldID) else { return false }
        airport.remarks.append(remark: remark, forField: .attendanceSchedule)
        return true
    }
    
    private func tryRunwayOrEndFieldRemark(_ remark: String, _ airport: Airport, _ combinedFieldID: String) throws -> Bool {
        guard let separatorIndex = combinedFieldID.firstIndex(of: Character("-")) else {
            return false
        }
        let fieldID = String(combinedFieldID[combinedFieldID.startIndex..<separatorIndex])
        let objectID = String(combinedFieldID[combinedFieldID.index(after: separatorIndex)...])
        
        if try tryArrestingSystemRemark(remark, airport, objectID, fieldID) { return true }
        if try tryRunwayEndFieldRemark(remark, airport, objectID, fieldID) { return true }
        if try tryRunwayEndGeneralRemark(remark, airport, objectID, fieldID) { return true }
        if try tryRunwayFieldRemark(remark, airport, objectID, fieldID) { return true }
        
        return false
    }
    
    private func tryArrestingSystemRemark(_ remark: String, _ airport: Airport, _ endID: String, _ fieldID: String) throws -> Bool {
        guard arrestingSystemFieldForID(fieldID) else { return false }
        guard let end = runwayEndForID(endID, inAirport: airport) else {
            throw AirportRemarksError.unknownRunwayEnd(endID, airport: airport)
        }
        end.remarks.append(remark: remark, forField: .arrestingSystems)
        return true
    }
    
    private func tryRunwayEndFieldRemark(_ remark: String, _ airport: Airport, _ endID: String, _ fieldID: String) throws -> Bool {
        if let end = runwayEndForID(endID, inAirport: airport) {
            if try tryLAHSOFieldRemark(remark, airport, end, fieldID) { return true }
            if try tryControllingObjectFieldRemark(remark, airport, end, fieldID) { return true }
            
            guard let field = runwayEndFieldForID(fieldID) else { return false }
            switch field {
                case .LAHSO:
                    preconditionFailure("NASR field defined in RunwayEnd.Field.fieldOrder but not LAHSO.Field.fieldOrder")
                case .controllingObject:
                    preconditionFailure("NASR field defined in RunwayEnd.Field.fieldOrder but not ControllingObject.Field.fieldOrder")
                default:
                    end.remarks.append(remark: remark, forField: field)
                    return true
            }
            
        } else if runwayEndFieldForID(fieldID) != nil {
            throw AirportRemarksError.unknownRunwayEnd(endID, airport: airport)
        } else {
            return false
        }
    }
    
    private func tryLAHSOFieldRemark(_ remark: String, _ airport: Airport, _ end: RunwayEnd, _ fieldID: String) throws -> Bool {
        guard let field = LAHSOFieldForID(fieldID) else { return false }
        if end.LAHSO == nil {
            end.remarks.general.append(remark)
            return true
        }
        
        end.LAHSO!.remarks.append(remark: remark, forField: field)
        return true
    }
    
    private func tryControllingObjectFieldRemark(_ remark: String, _ airport: Airport, _ end: RunwayEnd, _ fieldID: String) throws -> Bool {
        guard let field = controllingObjectFieldForID(fieldID) else { return false }
        if end.controllingObject == nil {
            end.remarks.general.append(remark)
            return true
        }
        
        end.controllingObject!.remarks.append(remark: remark, forField: field)
        return true
    }
    
    private func tryRunwayEndGeneralRemark(_ remark: String, _ airport: Airport, _ endID: String, _ fieldID: String) throws -> Bool {
        guard fieldID == "A58" else { return false } // A58 is not defined; probably legacy
        guard let end = runwayEndForID(endID, inAirport: airport) else {
            throw AirportRemarksError.unknownRunwayEnd(endID, airport: airport)
        }
        
        end.remarks.general.append(remark)
        return true
    }
    
    private func tryRunwayFieldRemark(_ remark: String, _ airport: Airport, _ runwayID: String, _ fieldID: String) throws -> Bool {
        guard let field = runwayFieldForID(fieldID) else { return false }
        guard let runway = runwayForID(runwayID, inAirport: airport) else {
            throw AirportRemarksError.unknownRunway(runwayID, airport: airport)
        }
        
        runway.remarks.append(remark: remark, forField: field)
        return true
    }
    
    private func tryAirportFieldRemark(_ remark: String, _ airport: Airport, _ fieldID: String) throws -> Bool {
        if try tryAirportPersonRemark(remark, airport, fieldID) { return true }
        
        guard let field = airportFieldForID(fieldID) else { return false }
        
        switch field {
            case .owner, .manager:
                preconditionFailure("NASR field defined in Airport.Field.fieldOrder but not Person.Field.fieldOrder")
            default:
                airport.remarks.append(remark: remark, forField: field)
                return true
        }
    }
    
    private func tryAirportPersonRemark(_ remark: String, _ airport: Airport, _ fieldID: String) throws -> Bool {
        guard let airportField = airportFieldForID(fieldID) else { return false}
        guard let field = personFieldForID(fieldID) else { return false }
        
        switch airportField {
            case .owner:
                if airport.owner == nil {
                    airport.remarks.general.append(remark)
                    return true
                }
                airport.owner!.remarks.append(remark: remark, forField: field)
                return true
            case .manager:
                if airport.manager == nil {
                    airport.remarks.general.append(remark)
                    return true
                }
                airport.manager!.remarks.append(remark: remark, forField: field)
                return true
            default:
                preconditionFailure("Person field on Airport.Field.fieldOrder does not correspond with same field on Person.Field.fieldOrder")
        }
    }
    
    private func runwayForID(_ identifier: String, inAirport airport: Airport) -> Runway? {
        let strippedID = identifier.split(separator: Character(" "))[0]
        return airport.runways.first(where: { $0.identification == strippedID })
    }
    
    private func runwayFieldForID(_ fieldID: String) -> Runway.Field? {
        let layout = format(forRecordIdentifier: .runway)
        guard let offset = layout.fieldOffset(forID: fieldID) else { return nil }
        return Runway.Field.fieldOrder[offset]
    }
    
    private func runwayEndForID(_ identifier: String, inAirport airport: Airport) -> RunwayEnd? {
        for runway in airport.runways {
            if runway.baseEnd.ID == identifier { return runway.baseEnd }
            if runway.reciprocalEnd?.ID == identifier { return runway.reciprocalEnd }
        }
        return nil
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
    
    
    public var description: String {
        switch self {
            case .invalidGeneralRemarkSequence(let airport, let fieldID):
                return "Invalid general remarks sequence for field '\(fieldID)' at '\(airport.LID)'"
            case .unknownFieldID(let fieldID, let airport):
                return "Unknown field ID '\(fieldID)' at '\(airport.LID)'"
            case .invalidFieldID(let fieldID, let airport):
                return "Invalid field ID '\(fieldID)' at '\(airport.LID)'"
            case .unknownRunway(let runwayID, let airport):
                return "Unknown runway '\(runwayID)' at '\(airport.LID)'"
            case .unknownRunwayEnd(let endID, let airport):
                return "Unknown runway end '\(endID)' at '\(airport.LID)'"
        }
    }
}


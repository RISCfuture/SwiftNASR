import Foundation

fileprivate let SAVASI_Rx = try! NSRegularExpression(pattern: #"^S(\d)([LR])$"#)
fileprivate let VASI_Rx = try! NSRegularExpression(pattern: #"^V(\d)([LR])$"#)
fileprivate let LargeVASI_Rx = try! NSRegularExpression(pattern: #"^V(\d{2})$"#)
fileprivate let PAPI_Rx = try! NSRegularExpression(pattern: #"^P(\d)([LR])$"#)
fileprivate let tricolorVASI_Rx = try! NSRegularExpression(pattern: #"^TRI([LR])$"#)
fileprivate let pulsatingVASI_Rx = try! NSRegularExpression(pattern: #"^PSI([LR])$"#)
fileprivate let panelsRx = try! NSRegularExpression(pattern: #"^PNI([LR])$"#)

extension AirportParser {
    private func parseVGSI(_ value: String) throws -> RunwayEnd.VisualGlideslopeIndicator {
        switch value {
            case "NSTD": return RunwayEnd.VisualGlideslopeIndicator(type: .nonstandard)
            case "PVT": return RunwayEnd.VisualGlideslopeIndicator(type: .private)
            case "VAS": return RunwayEnd.VisualGlideslopeIndicator(type: .nonspecificVASI)
            default:
                if let match = SAVASI_Rx.firstMatch(in: value, options: [], range: value.nsRange) {
                    guard let numberRange = Range(match.range(at: 1), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    guard let sideRange = Range(match.range(at: 2), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    guard let number = UInt(value[numberRange]) else {
                        throw Error.invalidVGSI(value)
                    }
                    let side = try Self.raw(String(value[sideRange]), toEnum: RunwayEnd.VisualGlideslopeIndicator.Side.self)
                    return RunwayEnd.VisualGlideslopeIndicator(type: .SAVASI, number: number, side: side)
                }
                else if let match = VASI_Rx.firstMatch(in: value, options: [], range: value.nsRange) {
                    guard let numberRange = Range(match.range(at: 1), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    guard let sideRange = Range(match.range(at: 2), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    guard let number = UInt(value[numberRange]) else {
                        throw Error.invalidVGSI(value)
                    }
                    let side = try Self.raw(String(value[sideRange]), toEnum: RunwayEnd.VisualGlideslopeIndicator.Side.self)
                    return RunwayEnd.VisualGlideslopeIndicator(type: .VASI, number: number, side: side)
                }
                else if let match = LargeVASI_Rx.firstMatch(in: value, options: [], range: value.nsRange) {
                    guard let numberRange = Range(match.range(at: 1), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    guard let number = UInt(value[numberRange]) else {
                        throw Error.invalidVGSI(value)
                    }
                    return RunwayEnd.VisualGlideslopeIndicator(type: .VASI, number: number, side: nil)
                }
                else if let match = PAPI_Rx.firstMatch(in: value, options: [], range: value.nsRange) {
                    guard let numberRange = Range(match.range(at: 1), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    guard let sideRange = Range(match.range(at: 2), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    guard let number = UInt(value[numberRange]) else {
                        throw Error.invalidVGSI(value)
                    }
                    let side = try Self.raw(String(value[sideRange]), toEnum: RunwayEnd.VisualGlideslopeIndicator.Side.self)
                    return RunwayEnd.VisualGlideslopeIndicator(type: .PAPI, number: number, side: side)
                }
                else if let match = tricolorVASI_Rx.firstMatch(in: value, options: [], range: value.nsRange) {
                    guard let sideRange = Range(match.range(at: 1), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    let side = try Self.raw(String(value[sideRange]), toEnum: RunwayEnd.VisualGlideslopeIndicator.Side.self)
                    return RunwayEnd.VisualGlideslopeIndicator(type: .tricolorVASI, number: nil, side: side)
                }
                else if let match = pulsatingVASI_Rx.firstMatch(in: value, options: [], range: value.nsRange) {
                    guard let sideRange = Range(match.range(at: 1), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    let side = try Self.raw(String(value[sideRange]), toEnum: RunwayEnd.VisualGlideslopeIndicator.Side.self)
                    return RunwayEnd.VisualGlideslopeIndicator(type: .pulsatingVASI, number: nil, side: side)
                }
                else if let match = panelsRx.firstMatch(in: value, options: [], range: value.nsRange) {
                    guard let sideRange = Range(match.range(at: 1), in: value) else {
                        throw Error.invalidVGSI(value)
                    }
                    let side = try Self.raw(String(value[sideRange]), toEnum: RunwayEnd.VisualGlideslopeIndicator.Side.self)
                    return RunwayEnd.VisualGlideslopeIndicator(type: .panels, number: nil, side: side)
                }
                else {
                    throw Error.invalidVGSI(value)
                }
        }
    }
    
    func parseRunwayEnd(_ values: Array<Any?>, offset1: Int, offset2: Int, airport: Airport) throws -> RunwayEnd {
        var VGSI: RunwayEnd.VisualGlideslopeIndicator? = nil
        if values[offset1 + 20] != nil {
            do {
                VGSI = try parseVGSI(values[offset1 + 20] as! String)
            } catch {
                throw FixedWidthParserError.invalidValue(values[offset1 + 20] as! String, at: offset1 + 20)
            }
        }
        
        var threshold: Location? = nil
        if values[offset1 + 6] != nil && values[offset1 + 8] != nil {
            threshold = Location(latitude: values[offset1 + 6] as! Float,
                                     longitude: values[offset1 + 8] as! Float,
                                     elevation: values[offset1 + 10] as! Float?)
        }
        var displacedThreshold: Location? = nil
        if values[offset1 + 13] != nil && values[offset1 + 15] != nil {
            displacedThreshold = Location(latitude: values[offset1 + 13] as! Float,
                                              longitude: values[offset1 + 15] as! Float,
                                              elevation: values[offset1 + 17] as! Float?)
        }
        
        var gradient = values[offset2] as! Float?
        if gradient != nil {
            switch values[offset2 + 1] as! String {
                case "UP": break
                case "DOWN": gradient! *= -1
                default: throw FixedWidthParserError.invalidValue(values[offset2] as! String, at: offset2)
            }
        }
        
        var location: Location? = nil
        if values[offset2 + 19] != nil && values[offset2 + 21] != nil {
            location = Location(latitude: values[offset2 + 19] as! Float,
                                longitude: values[offset2 + 21] as! Float,
                                elevation: nil)
        }
        
        var LAHSO: RunwayEnd.LAHSOPoint? = nil
        if values[offset2 + 16] != nil {
            LAHSO = RunwayEnd.LAHSOPoint(
                availableDistance: values[offset2 + 16] as! UInt,
                intersectingRunwayID: values[offset2 + 17] as! String?,
                definingEntity: values[offset2 + 18] as! String?,
                position: location,
                positionSource: values[offset2 + 23] as! String?,
                positionSourceDate: values[offset2 + 24] as! Date?)
        }
        
        var controllingObject: RunwayEnd.ControllingObject? = nil
        if values[offset1 + 27] != nil {
            controllingObject = RunwayEnd.ControllingObject(category: values[offset1 + 27] as! RunwayEnd.ControllingObject.Category,
                                                            markings: values[offset1 + 28] as! Array<RunwayEnd.ControllingObject.Marking>,
                                                            runwayCategory: values[offset1 + 29] as! String?,
                                                            clearanceSlope: values[offset1 + 30] as! UInt?,
                                                            heightAboveRunway: values[offset1 + 31] as! UInt?,
                                                            distanceFromRunway: values[offset1 + 32] as! UInt?,
                                                            offsetFromCenterline: values[offset1 + 33] as! Offset?)
        }
        
        return RunwayEnd(
            ID: values[offset1] as! String,
            trueHeading: values[offset1 + 1] as! UInt?,
            instrumentLandingSystem: values[offset1 + 2] as! RunwayEnd.InstrumentLandingSystem?,
            rightTraffic: values[offset1 + 3] as! Bool?,
            marking: values[offset1 + 4] as! RunwayEnd.Marking?,
            markingCondition: values[offset1 + 5] as! RunwayEnd.MarkingCondition?,
            threshold: threshold,
            thresholdCrossingHeight: values[offset1 + 11] as! UInt?,
            visualGlidepath: values[offset1 + 12] as! Float?,
            displacedThreshold: displacedThreshold,
            thresholdDisplacement: values[offset1 + 18] as! UInt?,
            touchdownZoneElevation: values[offset1 + 19] as! Float?,
            gradient: gradient,
            TORA: values[offset2 + 12] as! UInt?,
            TODA: values[offset2 + 13] as! UInt?,
            ASDA: values[offset2 + 14] as! UInt?,
            LDA: values[offset2 + 15] as! UInt?,
            LAHSO: LAHSO,
            visualGlideslopeIndicator: VGSI,
            RVRSensors: values[offset1 + 21] as! Array<RunwayEnd.RVRSensor>,
            hasRVV: values[offset1 + 22] as! Bool?,
            approachLighting: values[offset1 + 23] as! RunwayEnd.ApproachLighting?,
            hasREIL: values[offset1 + 24] as! Bool?,
            hasCenterlineLighting: values[offset1 + 25] as! Bool?,
            endTouchdownLighting: values[offset1 + 26] as! Bool?,
            controllingObject: controllingObject,
            positionSource: values[offset2 + 2] as! String?,
            positionSourceDate: values[offset2 + 3] as! Date?,
            elevationSource: values[offset2 + 4] as! String?,
            elevationSourceDate: values[offset2 + 5] as! Date?,
            displacedThresholdPositionSource: values[offset2 + 6] as! String?,
            displacedThresholdPositionSourceDate: values[offset2 + 7] as! Date?,
            displacedThresholdElevationSource: values[offset2 + 8] as! String?,
            displacedThresholdElevationSourceDate: values[offset2 + 9] as! Date?,
            touchdownZoneElevationSource: values[offset2 + 10] as! String?,
            touchdownZoneElevationSourceDate: values[offset2 + 11] as! Date?)
    }
}

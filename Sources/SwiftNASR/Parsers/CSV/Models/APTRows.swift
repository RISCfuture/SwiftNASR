import Foundation

// Helper functions for parsing CSV fields from [String] arrays

// MARK: - APT_BASE.csv Field Indices
enum APTBaseField: Int {
  case EFF_DATE = 0
  case SITE_NO = 1
  case SITE_TYPE_CODE = 2
  case STATE_CODE = 3
  case ARPT_ID = 4
  case CITY = 5
  case COUNTRY_CODE = 6
  case REGION_CODE = 7
  case ADO_CODE = 8
  case STATE_NAME = 9
  case COUNTY_NAME = 10
  case COUNTY_ASSOC_STATE = 11
  case ARPT_NAME = 12
  case OWNERSHIP_TYPE_CODE = 13
  case FACILITY_USE_CODE = 14
  case LAT_DEG = 15
  case LAT_MIN = 16
  case LAT_SEC = 17
  case LAT_HEMIS = 18
  case LAT_DECIMAL = 19
  case LONG_DEG = 20
  case LONG_MIN = 21
  case LONG_SEC = 22
  case LONG_HEMIS = 23
  case LONG_DECIMAL = 24
  case SURVEY_METHOD_CODE = 25
  case ELEV = 26
  case ELEV_METHOD_CODE = 27
  case MAG_VARN = 28
  case MAG_HEMIS = 29
  case MAG_VARN_YEAR = 30
  case TPA = 31
  case CHART_NAME = 32
  case DIST_CITY_TO_AIRPORT = 33
  case DIRECTION_CODE = 34
  case ACREAGE = 35
  case RESP_ARTCC_ID = 36
  case COMPUTER_ID = 37
  case ARTCC_NAME = 38
  case FSS_ON_ARPT_FLAG = 39
  case FSS_ID = 40
  case FSS_NAME = 41
  case PHONE_NO = 42
  case TOLL_FREE_NO = 43
  case ALT_FSS_ID = 44
  case ALT_FSS_NAME = 45
  case ALT_TOLL_FREE_NO = 46
  case NOTAM_ID = 47
  case NOTAM_FLAG = 48
  case ACTIVATION_DATE = 49
  case ARPT_STATUS = 50
  case FAR_139_TYPE_CODE = 51
  case FAR_139_CARRIER_SER_CODE = 52
  case ARFF_CERT_TYPE_DATE = 53
  case NASP_CODE = 54
  case ASP_ANLYS_DTRM_CODE = 55
  case CUST_FLAG = 56
  case LNDG_RIGHTS_FLAG = 57
  case JOINT_USE_FLAG = 58
  case MIL_LNDG_FLAG = 59
  case INSPECT_METHOD_CODE = 60
  case INSPECTOR_CODE = 61
  case LAST_INSPECTION = 62
  case LAST_INFO_RESPONSE = 63
  case FUEL_TYPES = 64
  case AIRFRAME_REPAIR_SER_CODE = 65
  case PWR_PLANT_REPAIR_SER = 66
  case BOTTLED_OXY_TYPE = 67
  case BULK_OXY_TYPE = 68
  case LGT_SKED = 69
  case BCN_LGT_SKED = 70
  case TWR_TYPE_CODE = 71
  case SEG_CIRCLE_MKR_FLAG = 72
  case BCN_LENS_COLOR = 73
  case LNDG_FEE_FLAG = 74
  case MEDICAL_USE_FLAG = 75
  case ARPT_PSN_SOURCE = 76
  case POSITION_SRC_DATE = 77
  case ARPT_ELEV_SOURCE = 78
  case ELEVATION_SRC_DATE = 79
  case CONTR_FUEL_AVBL = 80
  case TRNS_STRG_BUOY_FLAG = 81
  case TRNS_STRG_HGR_FLAG = 82
  case TRNS_STRG_TIE_FLAG = 83
  case OTHER_SERVICES = 84
  case WIND_INDCR_FLAG = 85
  case ICAO_ID = 86
  case MIN_OP_NETWORK = 87
  case USER_FEE_FLAG = 88
  case CTA = 89
}

// MARK: - APT_RWY.csv Field Indices
enum APTRunwayField: Int {
  case EFF_DATE = 0
  case SITE_NO = 1
  case SITE_TYPE_CODE = 2
  case STATE_CODE = 3
  case ARPT_ID = 4
  case CITY = 5
  case COUNTRY_CODE = 6
  case RWY_ID = 7
  case RWY_LEN = 8
  case RWY_WIDTH = 9
  case SURFACE_TYPE_CODE = 10
  case COND = 11
  case TREATMENT_CODE = 12
  case PCN = 13
  case PAVEMENT_TYPE_CODE = 14
  case SUBGRADE_STRENGTH_CODE = 15
  case TIRE_PRES_CODE = 16
  case DTRM_METHOD_CODE = 17
  case RWY_LGT_CODE = 18
  case RWY_LEN_SOURCE = 19
  case LENGTH_SOURCE_DATE = 20
  case GROSS_WT_SW = 21
  case GROSS_WT_DW = 22
  case GROSS_WT_DTW = 23
  case GROSS_WT_DDTW = 24
}

// MARK: - APT_RWY_END.csv Field Indices
enum APTRunwayEndField: Int {
  case EFF_DATE = 0
  case SITE_NO = 1
  case SITE_TYPE_CODE = 2
  case STATE_CODE = 3
  case ARPT_ID = 4
  case CITY = 5
  case COUNTRY_CODE = 6
  case RWY_ID = 7
  case RWY_END_ID = 8
  case TRUE_ALIGNMENT = 9
  case ILS_TYPE = 10
  case RIGHT_HAND_TRAFFIC_PAT_FLAG = 11
  case RWY_MARKING_TYPE_CODE = 12
  case RWY_MARKING_COND = 13
  case RWY_END_LAT_DEG = 14
  case RWY_END_LAT_MIN = 15
  case RWY_END_LAT_SEC = 16
  case RWY_END_LAT_HEMIS = 17
  case LAT_DECIMAL = 18
  case RWY_END_LONG_DEG = 19
  case RWY_END_LONG_MIN = 20
  case RWY_END_LONG_SEC = 21
  case RWY_END_LONG_HEMIS = 22
  case LONG_DECIMAL = 23
  case RWY_END_ELEV = 24
  case THR_CROSSING_HGT = 25
  case VISUAL_GLIDE_PATH_ANGLE = 26
  case DISPLACED_THR_LAT_DEG = 27
  case DISPLACED_THR_LAT_MIN = 28
  case DISPLACED_THR_LAT_SEC = 29
  case DISPLACED_THR_LAT_HEMIS = 30
  case LAT_DISPLACED_THR_DECIMAL = 31
  case DISPLACED_THR_LONG_DEG = 32
  case DISPLACED_THR_LONG_MIN = 33
  case DISPLACED_THR_LONG_SEC = 34
  case DISPLACED_THR_LONG_HEMIS = 35
  case LONG_DISPLACED_THR_DECIMAL = 36
  case DISPLACED_THR_ELEV = 37
  case DISPLACED_THR_LEN = 38
  case TDZ_ELEV = 39
  case VGSI_CODE = 40
  case RWY_VISUAL_RANGE_EQUIP_CODE = 41
  case RWY_VSBY_VALUE_EQUIP_FLAG = 42
  case APCH_LGT_SYSTEM_CODE = 43
  case RWY_END_LGTS_FLAG = 44
  case CNTRLN_LGTS_AVBL_FLAG = 45
  case TDZ_LGT_AVBL_FLAG = 46
  case OBSTN_TYPE = 47
  case OBSTN_MRKD_CODE = 48
  case FAR_PART_77_CODE = 49
  case OBSTN_CLNC_SLOPE = 50
  case OBSTN_HGT = 51
  case DIST_FROM_THR = 52
  case CNTRLN_OFFSET = 53
  case CNTRLN_DIR_CODE = 54
  case RWY_GRAD = 55
  case RWY_GRAD_DIRECTION = 56
  case RWY_END_PSN_SOURCE = 57
  case RWY_END_PSN_DATE = 58
  case RWY_END_ELEV_SOURCE = 59
  case RWY_END_ELEV_DATE = 60
  case DSPL_THR_PSN_SOURCE = 61
  case RWY_END_DSPL_THR_PSN_DATE = 62
  case DSPL_THR_ELEV_SOURCE = 63
  case RWY_END_DSPL_THR_ELEV_DATE = 64
  case TDZ_ELEV_SOURCE = 65
  case RWY_END_TDZ_ELEV_DATE = 66
  case TKOF_RUN_AVBL = 67
  case TKOF_DIST_AVBL = 68
  case ACLT_STOP_DIST_AVBL = 69
  case LNDG_DIST_AVBL = 70
  case LAHSO_ALD = 71
  case RWY_END_INTERSECT_LAHSO = 72
  case LAHSO_DESC = 73
  case LAHSO_LAT = 74
  case LAT_LAHSO_DECIMAL = 75
  case LAHSO_LONG = 76
  case LONG_LAHSO_DECIMAL = 77
  case LAHSO_PSN_SOURCE = 78
  case RWY_END_LAHSO_PSN_DATE = 79
}

// MARK: - APT_ATT.csv Field Indices
enum APTAttendanceField: Int {
  case EFF_DATE = 0
  case SITE_NO = 1
  case SITE_TYPE_CODE = 2
  case STATE_CODE = 3
  case ARPT_ID = 4
  case CITY = 5
  case COUNTRY_CODE = 6
  case SKED_SEQ_NO = 7
  case MONTH = 8
  case DAY = 9
  case HOUR = 10
}

// MARK: - APT_RMK.csv Field Indices
enum APTRemarkField: Int {
  case EFF_DATE = 0
  case SITE_NO = 1
  case SITE_TYPE_CODE = 2
  case STATE_CODE = 3
  case ARPT_ID = 4
  case CITY = 5
  case COUNTRY_CODE = 6
  case LEGACY_ELEMENT_NUMBER = 7
  case TAB_NAME = 8
  case REF_COL_NAME = 9
  case ELEMENT = 10
  case REF_COL_SEQ_NO = 11
  case REMARK = 12
}

// MARK: - APT_ARS.csv Field Indices
enum APTArrestingSystemField: Int {
  case EFF_DATE = 0
  case SITE_NO = 1
  case SITE_TYPE_CODE = 2
  case STATE_CODE = 3
  case ARPT_ID = 4
  case CITY = 5
  case COUNTRY_CODE = 6
  case RWY_ID = 7
  case RWY_END_ID = 8
  case ARREST_DEVICE_CODE = 9
}

// MARK: - APT_CON.csv Field Indices
enum APTContactField: Int {
  case EFF_DATE = 0
  case SITE_NO = 1
  case SITE_TYPE_CODE = 2
  case STATE_CODE = 3
  case ARPT_ID = 4
  case CITY = 5
  case COUNTRY_CODE = 6
  case TITLE = 7
  case NAME = 8
  case ADDRESS1 = 9
  case ADDRESS2 = 10
  case TITLE_CITY = 11
  case STATE = 12
  case ZIP_CODE = 13
  case ZIP_PLUS_FOUR = 14
  case PHONE_NO = 15
}

// Helper functions to safely extract values from CSV fields
extension Array where Element == String {
  func stringAt(_ index: Int) -> String? {
    guard index < count else { return nil }
    let value = self[index]
    return value.isEmpty ? nil : value
  }

  func intAt(_ index: Int) -> Int? {
    guard let str = stringAt(index) else { return nil }
    return Int(str)
  }

  func doubleAt(_ index: Int) -> Double? {
    guard let str = stringAt(index) else { return nil }
    return Double(str)
  }

  func boolAt(_ index: Int, trueValue: String = "Y") -> Bool {
    guard let str = stringAt(index) else { return false }
    return str == trueValue
  }
}

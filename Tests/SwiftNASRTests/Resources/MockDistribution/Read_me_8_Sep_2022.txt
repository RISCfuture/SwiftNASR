AIS subscriber files effective date September 8, 2022.

Dear Subscribers,

For the September 8, 2022 subscriber files, the files incorporate data 
published in the daily National Flight Data Digest (NFDD) through
 
    NFDD 151 dated 8/8/2022.  

The September 8, 2022 cycle is a 56 Day Major Cycle subscriber set.

By FAA policy and order, some NASR resources, generally categorized as 
"Enroute", are only updated on a 56 day charting basis. The following legacy 
text subscriber files are included in the 28 day "Change Notice" subscriber 
set, but will not contain new data: ARB, ATS, AWY, CDR, MTR, PFR, PJA, STARDP, 
and WXL. They will be the same files produced for the previous 56 day AIRAC 
cycle. The SAA AIXM 5.0 set file and the AWY AIXM 5.1 file will be updated on 
the 56 day major cycle.

AIRAC CYCLE PERIOD: 28 DAY CLARIFICATION

    We are now issuing these products on a 28 day cycle periodicity. 
    Subscriber files have previously reported according to a 56 day AIRAC 
    cycle periodicity. 

    The subscriber file sets will be posted 28 days prior to the effective 
    date. The files will contain data that is updated for that cycle and has 
    met the cutoff for entry. 

    As these subscriber files are complete snapshots of their respective 
    resource areas, any updates published in a "Change Notice" set will also 
    be included in the next 56 day major cycle set. If your business processes 
    are based on a 56 day cycle, you can continue to use the 56 day major 
    cycle products and will not be missing data.

DATUM

    The legacy text subscribe files do not cite a datum for geodetic 
    coordinates. All US coordinates information provided is currently 
    reference NAD 83.

ARTCC BOUNDARY (ARB.txt) CLARIFICATION

    Some of the ARTCC boundaries defined by the ARTCC facility are composed of 
    more than a single closed shape. Due to the format constraints and naming 
    conventions of the legacy ARB file it is not possible to publish each 
    shape separately. In these cases it is necessary to read the point 
    description text for the key phrase "TO POINT OF BEGINNING" to identify 
    where the shape returns to the beginning and forms a closed shape. This is 
    currently found in the ZMA BDRY, ZAN BDRY, ZNY HIGH, and ZOA UTA 
    boundaries. This is not a change to the file, it is only clarification of 
    the practice that has existed for years.

AIRPORT (APT.txt) RUNWAY END GRADIENT DATA

    The runway end gradient data in the apt.txt data set, element E40, 
    contained erroneous and incomplete data and should not be used for any 
    purpose. All runway end gradient data has been removed as of the April 25, 
    2019 effective date NASR Subscriber files. The runway end gradient data 
    field will publish with null values while Aeronautical Information 
    Services works to ensure all runway end gradient data can be safely 
    repopulated.

TOWER (TWR.txt) FREQUENCY SCRUB

    The frequency number and sectorization data are concatenated together for 
    output to the TWR subscriber file in TWR3 & TWR7 records. There was no set 
    delimiter between the end of a frequency number and start of the 
    sectorization data. A semicolon has been prepended to the sectorization 
    field in NASR so that the concatenated export will contain the semicolon 
    as a set delimiter between frequency number and sectorization data.

    NEW: There are almost 500 frequencies (TWR3 and TWR7 records) which 
    identify a frequency use of "RADAR" or "BASIC RADAR". These references are 
    obsolete and no longer maintained. They supported a previous process for 
    contacting ATC facilities to request RADAR service, which has been 
    replaced by other frequencies/uses currently published for these 
    facilities. These frequencies will be removed as a bulk cleanup effective 
    the November 3, 2022 AIRAC cycle. 

TOWER (TWR.txt) NUMBER OF HOURS OF DAILY OPERATION AND REGULARITY

    The TWR1 record contains two fields, both identified as element number 
    TA55, that summarize the number of daily hours (e.g 16) and weekly 
    regularity (e.g WDO). At some point, this data will be removed. The 
    previously announced date of December 31, 2020 has been delayed. When this 
    data is removed, the columns will remain in the layout, but the data will 
    be blank. This does not change the actual hours of operation data that 
    will continue to be published in the TWR2 records.

ARTCC FACILITIES (AFF.txt) RADAR RECORDS

    The AFF1 record has contained basic information on ARTCC associated 
    facilities, including the base ARTCC, CERAP, RCAG, and RADAR sites 
    (ARSR and SECRA). The RADAR site information was minimal, essentially site 
    name, state, and association to one or more ARTCCs. This information will 
    not be maintained in NASR in the future. 
    
    Effective with the 29 December 2022 cycle, AFF1 records for ARSR and SECRA 
    sites will no longer be included. 

NAVAID (NAV.txt) NAVAID MAGNETIC VARIATION AND RADIAL RESTRICTIONS

    The magnetic variation value for DME only NAVAIDs will report as null 
    (or blank) since the stand alone DME NAVAID does not provide azimuth 
    information.
    (NOTE: DME, VOT AND FM NAVAID TYPES DO NOT HAVE MAG VAR. ANY VALUE IN THIS 
    COLUMN FOR THOSE NAVAID TYPES SHOULD BE IGNORED.) 

    NAVAID radial restrictions are identified by flight inspection and are 
    published as naviad remarks. When there are restrictions on stand-alone 
    DME only NAVAIDs, the restrictions reference true north. A note has been 
    added to the NAV_rf.txt format definition explaining the radial remark 
    information, and the use of a "T" designation to indicate "true north" for 
    the radials in a DME only remark. 
    NOTE: STAND-ALONE DME RESTRICTIONS: THERE IS A NEED TO DIFFERENTIATE 
    BETWEEN RESTRICTION RADIALS AT VOR/DMES, VORTAC, AND RESTRICTION RADIALS 
    REFERENCED TO TRUE NORTH AT STAND-ALONE DMES. THE T AFTER THE RADIAL 
    REPRESENTS TRUE NORTH. 
    EX: DME UNUSBL 080T-125T BLW 10000FT)
    
LOCATION IDENTIFIER (LID.txt) CANADIAN DATA

    The LID 3 'CAN' records which contain location identifiers of Canadian
    customs points of entry, airports, meteorlogical stations and navigational 
    aids will no longer be included in the LID.txt subscriber file starting 
    with the Novemeber 3, 2022 AIRAC cycle. 
    Refer to current Canadian charts and flight information publications for 
    information within Canadian airspace.
                      
ILS (ILS.txt) PUBLISHED DISTANCES SCRUB

    The ILS subscriber file publishes many distance or measurements of 
    components relative to various positions on the runway. This is in 
    addition to actual coordinate position data. These distances were 
    originally added to support FAA Flight Inspection, who no longer use this 
    data from NASR. 
    
    Effective with the December 29, 2022 AIRAC cycle, these distances will no 
    longer be maintained in NASR. The format of the ILS.txt file will not 
    change, but the attributes in these columns will be nulled. Coordinates 
    and elevation of the equipment will remain.

    Specific attributes to be nulled:
        Localizer 
        o Dist From AER
        o Dist From Centerline
        o Dir From Centerline
        o Dist From Rwy Stop
        o Dir From Rwy Stop
        o Localizer Course Width at Threshold

        Glide Slope
        o Dist From AER
        o Dist From Centerline
        o Dir From Centerline
        o Rwy Elev Adjacent to GS

        DME
        o Dist From AER
        o Dist From Centerline
        o Dir From Centerline
        o Dist From Runway Stop

        Inner/Middle/Outer Marker
        o Dist From AER
        o Dist From Centerline
        o Dir From Centerline

NEW CSV FORMAT SUBSCRIBER PRODUCTS FOR ASSESSMENT 

    There have been requests from users internal and external for an 
    alternative to the flat text fixed length legacy subscriber files. The 
    comma delimited CSV files documented here are an attempt to meet that need. 
    The goal is to have a full complement of subscriber data coded as CSV 
    files by the end of the 2022 calendar year.  
    
    There is a DATA LAYOUT document for each resource grouping which gives 
    more in-depth detail. See the Data Layout Document for further information 
    on what data (including how it is displayed and organized) is contained in 
    each. 
    
    There is also a CSV_Readme.doc file specific for the new CSV 
    products. It highlights latest updates to these products, based on 
    feedback and usage analysis, along with organization and presentation 
    differences from the legacy .txt subscriber files. 
    
    New for September 8, 2022, an enhanced version of the CDR file with 
    additional columns. 
    
    Current CSV products available include:
    
        FREQUENCY CSV - FRQ.csv 
        AIRPORT CSV - APT_*.csv 
        NAVIGATION AID CSV - NAV_*.csv
        INSTRUMENT LANDING SYSTEM CSV - ILS_*.csv
        AIRSPACE FIXES CSV - FIX_*.csv
        HOLDING PATTERN CSV - HPF_*.csv
        PREFERRED ROUTE CSV - PFR.csv
        WEATHER REPORTING LOCATIONS CSV - WXL_*.csv
        AIR TRAFFIC CONTROL COMM CSV - ATC_*.csv
        TERMINAL COMMUNICATIONS CSV - TWR_*.csv
        MILITARY OPERATIONS CSV - MIL_OPS.csv
        CLASS AIRSPACE CSV - CLS_ARSP.csv
        CODED DEPARTURE ROUTES CSV - CDR.csv

AIXM SUBSCRIBER FILES ARE BEING PRODUCED: 

    AIXM 5.1 versions of the Navigation Aid, Airport, ASOS/AWOS, and Airway 
    subscriber files are now produced. These products can be found in the 
    "AIXM Data" section of the  NASR Subscription listing.

    The XML schema definition and FAA extensions are placed in a folder named 
    AIXM\AIXM_5.1\AIXM

    "Frequently asked questions" documents are placed in a folder named 
    AIXM\AIXM_5.1\FAQs

    Mappings of data attributes from the .txt file to the AIXM products are 
    placed in a folder named AIXM\AIXM_5.1\mappings

    The actual data files are zipped and placed in a folder named 
    AIXM\AIXM_5.1\XML-Subscriber-Files 

    NAVAID_AIXM
    The AIXM5.1 Navigation Aid subscriber file contains data also published in 
    both the NAV.txt and ILS.txt legacy subscriber files. Both the legacy 
    NAV.txt and ILS.txt products and the new AIXM product will be produced 
    concurrently.

    APT_AIXM
    The AIXM5.1 Airport subscribe file contains the data also produced in the 
    legacy APT.txt subscriber file. Both products are produced in parallel. An 
    updated Airport_DataTypes.xsd file is included in the \extension folder 
    reference documents.

    AWOS_AIXM
    The AIXM5.1 ASOS/AWOS subscribe file contains the data also produced in 
    the legacy AWOS.txt subscriber file. Both products are produced in 
    parallel.

    AWY_AIXM
    The AIXM5.1 AIRWAY subscribe file contains the data also produced in the 
    legacy AWY.txt subscriber file. Both products are produced in parallel. An 
    updated Airway_DataTypes.xsd file is included in the \extension folder 
    reference documents.
    
SPECIAL ACTIVITY AIRSPACE (SAA) 
   
    An AIXM subscriber product called Special Activity Airspace (SAA), 
    containing data for all operational Special Use Area (SUA) and 16 National 
    Security Areas in produced. It is an XML product based on Aeronautical 
    Information Exchange Model version 5.0 (AIXM5). Information on AIXM can be 
    found at http://www.aixm.aero.

    The latest XML schema definition files for the SAA subscriber product 
    can be found within the download.

    The AIXM SAA product can be found in the "AIXM Data" section of the NASR 
    Subscription listing. The subscriber data is zipped with the schema 
    information, inside a zip file named "SaaSubscriberFile.zip". 

Other Notes:

FOREIGN DATA

    These subscriber files contain limited information on non-US resources, 
    primarily for context. These should not be considered official source. 
    Refer to current Canadian charts and flight information publications for 
    information within Canadian airspace.

REMINDER: 

All of the subscriber files are available free of charge from the 
Aeronautical Data/NFDC website located at 
https://www.faa.gov/air_traffic/flight_info/aeronav/aero_data/NASR_Subscription/. 
It is not necessary to register in order to access or download the files. 
However, in order to receive email alerts when the new subscriber set becomes 
available, users must register at 
https://nfdc.faa.gov/nfdcApps/controllers/PublicSecurity/register 
There is no cost to register. Users can select all or individual files to 
download. 


Your comments or suggestions can be directed to Aeronautical Information 
Services at the following contact points:

    Telephone:  1-800-638-8972
                 
    email: 9-AMC-Aerochart@faa.gov 


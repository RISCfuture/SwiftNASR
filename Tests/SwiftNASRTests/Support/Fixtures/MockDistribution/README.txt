AIS subscriber files effective date December 3, 2020.

Dear Subscribers,

For the December 3, 2020 subscriber files, the files incorporate data 
published in the daily National Flight Data Digest (NFDD) through
 
    NFDD 212 dated 11/2/2020.  

The December 3, 2020 cycle is a 28 day "Change Notice" Cycle subscriber set.

By FAA policy and order, some NASR resources, generally categorized as 
"Enroute", are only updated on a 56 day charting basis. The following legacy 
text subscriber files are included in the 28 day "Change Notice" subscriber 
set, but will not contain new data: ARB, ATS, AWY, CDR, MTR, PFR, PJA, 
SSD, STARDP, and WXL. They will be the same files produced for the previous 56 
day AIRAC cycle. The SAA AIXM 5.0 set file and the AWY AIXM 5.1 file will be 
updated on the 56 day major cycle.

THERE IS A CHANGE THIS CYCLE WITH THE MISCELLANEOUS ACTIVITY AREA (MAA) FILE. 
This previously contained new data only on the 56 day Major Cycle dates. New 
areas have been added this cycle. In the future, this file will be produced as 
a new version every 28 days. 

CHANGE TO AIRAC CYCLE PERIOD: 28 DAY CLARIFICATION

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

AIRPORT (APT.txt) FACILITY NAME ABBREVIATION STANDARDIZATION

    Effective for the December 31, 2020 cycle, a standardization will be run 
    on facility names to implement the appropriate abbreviation as outlined in 
    FAA order JO 7340.2K. This is delayed from the November 5 cycle previously 
    stated.

TOWER (TWR.txt) FREQUENCY SCRUB

    The frequency number and sectorization data are concatenated together for 
    output to the TWR subscriber file in TWR3 & TWR7 records. There was no set 
    delimiter between the end of a frequency number and start of the 
    sectorization data. A semicolon has been prepended to the sectorization 
    field in NASR so that the concatenated export will contain the semicolon 
    as a set delimiter between frequency number and sectorization data.

TOWER (TWR.txt) NUMBER OF HOURS OF DAILY OPERATION AND REGULARITY

    The TWR1 record contains two fields, both identified as element number 
    TA55, that summarize the number of daily hours (e.g 16) and weekly 
    regularity (e.g WDO). At some point in the 2021 year, this data will be 
    removed. The previously announced date of December 31, 2020 has been 
    delayed. When this data is removed, the columns will remain in the 
    layout, but the data will be blank. This does not change the actual hours 
    of operation data that will continue to be published in the TWR2 records.

PREFERRED ROUTE (PFR.txt) EFFECTIVE HOURS

    The effective time information has been clarified. All Preferred IFR 
    Routes are in effect continuously unless otherwise noted. It is not 
    necessary to specify 0000-2359. The PFR_rf.txt subscriber file format 
    definition has been *noted with that clarification. The first new data 
    set to reflect that clarification was the September 10, 2020 cycle.

STATE CODE UPDATE - US PACIFIC DEPENDENCIES

    The state codes for a few of the US Dependencies in the Pacific Ocean 
    area have been updated to bring them consistent with the Geopolitical 
    Entities, Names, and Codes (GENC) Standard. Specifically, the new updated 
    codes are Midway Island - QM, Palmyra Atoll - XL, N Mariana Islands - MP, 
    and Wake Island - QW. The STATE code reference table (part of the 
    subscriber data set) has been updated.  The new codes are seen where 
    appropriate in the AFF, APT, ATS, AWOS, FIX, HPF, ILS, LID, NATFIX, NAV, 
    PJA, TWR, and WXL. The APT file layout/format definition file 
    (APT_rf.txt) has been updated to include these new codes where they might 
    also be used for the County Associated State.


COMING FORMAT CHANGES:

AIRWAY (AWY.txt) FORMAT CHANGE: REQUIRED NAVIGATION PERFORMANCE (RNP) VALUE

    Software changes necessary to show RNP values on airways have been 
    delayed. At the earliest, this could be available for the February 25, 
    2021 cycle. An RNP value column will be added to the AWY1 record airway 
    segments. A preview format definition is included as 
    awy_rf_eff20210225.txt. 
    
ATS ROUTE (ATS.txt) FORMAT CHANGE: REQUIRED NAVIGATION PERFORMANCE (RNP) VALUE

    Software changes necessary to show RNP values on airways have been 
    delayed. At the earliest, this could be available for the February 25, 
    2021 cycle. An RNP value column will be added to the ATS1 record route 
    segments. A preview format definition is included as 
    ats_rf_eff20210225.txt. 
    
WEATHER REPORTING STATION (WXL.txt) FORMAT CHANGE

    Software changes necessary to expand the associated city column have been 
    delayed. At the earliest, this could be available for the February 25, 
    2021 cycle. The associated city column will be expanded to 40 characters 
    to preclude the possibility of truncation. A preview format definition is 
    included as Wxl_rf_eff20210225.txt.

AIXM SUBSCRIBER FILES ARE BEING PRODUCED: 

    AIXM 5.1 versions of the Navigation Aid, Airport, ASOS/AWOS, and Airway 
    subscriber files are now produced. These products can be found in the 
    "AIXM Data" section of the  NASR Subscription listing.

    The XML schema definition and FAA extensions are placed in a folder named 
    AIXM\AIXM_5.1\AIXM

    "Frequently asked questions" documents are placed in a folder named 
    AIXM\AIXM_5.1\FAQs

    Mappings of data attributes from the .txt file to the AIXM products 
    are placed in a folder named AIXM\AIXM_5.1\mappings

    The actual data files are zipped and placed in a folder named 
    AIXM\AIXM_5.1\XML-Subscriber-Files 

NAVAID_AIXM
    The AIXM5.1 Navigation Aid subscriber file contains data also published 
    in both the NAV.txt and ILS.txt legacy subscriber files. Both the legacy 
    NAV.txt and ILS.txt products and the new AIXM product will be produced 
    concurrently.

APT_AIXM
    The AIXM5.1 Airport subscribe file contains the data also produced in the 
    legacy APT.txt subscriber file. Both products are produced in parallel. 
    An updated Airport_DataTypes.xsd file is included in the \extension folder 
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
   
    The legacy SUA.txt file is no longer produced. A subscriber product called 
    Special Activity Airspace (SAA), containing data for all operational SUA 
    and 16 National Security Areas has replaced it. The product is an XML 
    product based on Aeronautical Information Exchange Model version 5.0 
    (AIXM5). Information on AIXM can be found at http://www.aixm.aero.

    The latest XML schema definition files for the SAA subscriber product 
    can be found within the download.

    The AIXM SAA product can be found in the "AIXM Data" section of the NASR 
    Subscription listing. The subscriber data is zipped with the schema 
    information, inside a zip file named "SaaSubscriberFile.zip". 

Other Notes:

FOREIGN DATA

    These subscriber files contain limited information on non-US 
    resources, primarily for context. These should not be considered 
    official source. Refer to current Canadian charts and flight information 
    publications for information within Canadian airspace.

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


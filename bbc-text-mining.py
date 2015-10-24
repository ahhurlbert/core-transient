"""Extract text data from Breeding Bird Census pdfs"""

import os
import re
import string
from glob import glob

import pandas as pd

def convert_pdf_to_images(filename):
    """Convert a pdf to images"""
    filename = os.path.splitext(filename)[0]
    os.system("convert -density 350 -crop 0x0+0+330 {0}.pdf {0}.png".format(filename))

def ocr(filename):
    """OCR a file using tesseract"""
    filename = os.path.splitext(filename)[0]
    os.system("tesseract {0}.png {0}".format(filename))

def convert_pdfs_to_text(path):
    """Convert all PDFs in a directory to text

    Use convert to convert to images and tesseract for OCR
    
    """
    pdfs = glob(os.path.join(path, "*.pdf"))
    for pdf in pdfs:
        convert_pdf_to_images(pdf)
        
        #multi-page pdfs create multiple png files so loop over them
        pngs = glob(os.path.join(path, "*.png"))
        for png in pngs:
            ocr(png)

def cleanup_nonpara_pages(path, para_starts):
    """Remove text and png files for pages that aren't the core paragraph data"""
    for year in para_starts:
        pages  = range(para_starts[year] - 1) #pages are not zero indexed
        for page in pages:
            os.remove(os.path.join(path, "BBC{}-{}.txt".format(year, page)))
            os.remove(os.path.join(path, "BBC{}-{}.png".format(year, page)))

def combine_txt_files_by_yr(path, years):
    """Combine multiple text files into a single file for each year

    File names have the general format: BBC1988-0.txt
    
    """
    for year in years:
        with open(os.path.join(path, "bbc_combined_{}.txt".format(year)), 'w') as outfile:
            filenames = glob(os.path.join(path, "BBC{}*.txt".format(year)))
            sorted_filenames = sorted_nicely(filenames)
            for fname in sorted_filenames:
                with open(fname) as infile:
                    outfile.write(infile.read())

def sorted_nicely(l): 
    """ Sort the given iterable in the way that humans expect.

    From:
    http://stackoverflow.com/questions/2669059/how-to-sort-alpha-numeric-set-in-python
    
    """ 
    convert = lambda text: int(text) if text.isdigit() else text 
    alphanum_key = lambda key: [ convert(c) for c in re.split('([0-9]+)', key) ] 
    return sorted(l, key = alphanum_key)

def get_site(inputstring):
    """Check if line is location data and if so return location"""
    site_re = "^([0-9]{1,2})\. ([A-Z —-]{2,})"
    site_search = re.search(site_re, inputstring)
    if site_search:
        return (site_search.group(1), site_search.group(2))

def is_start_main_block(inputstring):
    """Check if line is the first line of the main block of data"""
    return inputstring.startswith("Location: ") or inputstring.startswith('Site Number: ')

def parse_block(block, site_name, site_num, year):
    """Parse a main data block from a BBC file"""
    # Cleanup difficult issues manually
    # Combination of difficult \n's and OCR mistakes
    replacements = {'Cemus': 'Census',
                    'Cov-\nerage': 'Coverage',
                    'Cov—\nerage': 'Coverage',
                    'Con-\ntinuity': 'Continuity',
                    'Conti-\nnuity': 'Continuity',
                    'Con—\ntinuity': 'Continuity',
                    'Con-\ntinnity': 'Continuity',
                    'Conti—\nnuity': 'Continuity',
                    'Description\nof Plot': 'Description of Plot',
                    'De-\nscription of Plot': 'Description of Plot',
                    'Description of\nPlot': 'Description of Plot',
                    'Descrip-\ntion of Plot': 'Description of Plot',
                    'De—\nscription of Plot': 'Description of Plot',
                    'Bobolink; 9.0 territories': 'Bobolink, 9.0 territories',
                    "37°38'N,\n121°46lW": "37°38'N,\n121°46'W",
                    'Common\nYellowthroat, 4.5, Northern Flicker, 3.0': 'Common\nYellowthroat, 4.5; Northern Flicker, 3.0',
                    'Red-bellied Woodpecker, 2.0, Carolina\nChickadee, 2.0': 'Red-bellied Woodpecker, 2.0; Carolina\nChickadee, 2.0',
                    '\nWinter 1992\n': ' ', #One header line in one file got OCR'd for some reason
                    '20.9 h; 8 Visits (8 sunrise), 8, 15, 22, 29 April; 6, 13, 20, 27\nMay.': '20.9 h; 8 Visits (8 sunrise); 8, 15, 22, 29 April; 6, 13, 20, 27\nMay.',
                    '19.3 h; 11 visits (11 sunrise;': '19.3 h; 11 visits (11 sunrise);',
                    'Foster Plantation;\n42"7’N': 'Foster Plantation;\n42°7’N',
                    'Hermit Thrush, 4.5 (18), Black-throatcd Green Warbler': 'Hermit Thrush, 4.5 (18); Black-throated Green Warbler', # Fixes both delimiter and selling of throated
                    '39"] 2‘N, 76°54’W': '39°12‘N, 76°54’W',
                    "42°“7'N, 77°45’W": "42°7'N, 77°45’W",
                    '41°4\'N, 76"7’W': "41°4'N, 76°7’W",
                    'w‘sits': 'visits',
                    'Weath-\ner': 'Weather',
                    '79513’W': '79°13’W',
                    'Continuity.': 'Continuity:',
                    'Continuity"': 'Continuity:',
                    "40°44'N,\n7 D50’W": "40°44'N,\n75°50’W",
                    "41350'N, 71°33'W": "41°50'N, 71°33'W",
                    '44°57’N, 68D41’W': '44°57’N, 68°41’W',
                    '18.8 11; 11 Visits': '18.8 h; 11 Visits',
                    "Descripn'on of Plot": "Description of Plot",
                    '41 c’42’N, 73°13’VV': '41°42’N, 73°13’VV',
                    'Northern Rough-winged Swallow. 0.5': 'Northern Rough-winged Swallow, 0.5',
                    'study-\nhours': 'study-hours',
                    'Warbling Vireo, 1.0, Northern Cardinal, 1.0': 'Warbling Vireo, 1.0; Northern Cardinal, 1.0',
                    'Wood Thrush, 3.0 (18),\nAmerican Redstart, 3.0': 'Wood Thrush, 3.0; American Redstart, 3.0',
                    'study-hrs': 'study-hours',
    }
    for replacement in replacements:
        if replacement in block:
            print("Replacing {} with {}".format(replacements[replacement], replacement))
            block = block.replace(replacement, replacements[replacement])
    p = re.compile(r'((?:Site Number|Location|Continuity|Size|Description of Plot|Edge|Topography and Elevation|Weather|Coverage|Census|Total|Visitors|Nests Found|Remarks|Other Observers|Acknowledgments)):')
    split_block = p.split(block)[1:] #discard first value; an empty string
    block_dict = {split_block[i]: split_block[i+1] for i in range(0, len(split_block), 2)}
    block_dict['SiteName'] = site_name
    block_dict['SiteNumInCensus'] = site_num * 10000 + year
    return block_dict

def parse_txt_file(infile, year):
    """Parse a BBC text file"""
    first_site = True
    recording = False
    data = dict()
    for line in infile:
        site_info = get_site(line)
        if site_info:
            print(site_info)
            if not first_site:
                data[site_num] = parse_block(main_block, site_name, site_num, year)
            first_site = False
            site_num, site_name = site_info
            site_num = int(site_num)
            recording = False
        elif is_start_main_block(line):
            main_block = ''
            recording = True
        if recording:
            if line.strip():
                main_block += line
    return(data)

def get_latlong(location):
    """Extract the latitude and longitude from the Location data"""
    regex =  """([0-9]{1,2})[ ]*[°05C]([0-9]{1,2})[ ]*[’|'|‘][0-9]{0,2}["|”]{0,1}N,[ |\\n]([0-9]{2,3})[ ]*[°05C]([0-9]{1,2})[ ]*[’|'|‘][0-9]{0,2}["|”]{0,1}[W|V|;|.]"""
    search = re.search(regex, location)
    if search:
        lat_deg, lat_min = int(search.group(1)), int(search.group(2))
        long_deg, long_min = int(search.group(3)), int(search.group(4))
        lat_decdeg = lat_deg + lat_min / 60.0
        long_decdeg = long_deg + long_min / 60.0
        return (lat_decdeg, long_decdeg)

def extract_counts(data, year):
    """Split the Census text block into species and counts"""
    census_data = data['Census']
    census_data = re.sub(r'\([^)]+\)', '', census_data) # remove parentheticals (which include ;)
    census_data = census_data.replace('territories', '')
    census_data = census_data.split(';')
    comma_decimal_re = ', ([0-9]{1,2}),([0-9])'
    period_delimiter_re = ''
    counts_data = pd.DataFrame(columns = ['siteID', 'year', 'species', 'count', 'status'])
    for record in census_data:
        if record.strip(): # Avoid occasional blank lines
            if record.count(',') == 2: # Typically a mis-OCR'd decimal in the count
                search = re.search(comma_decimal_re, record)
                if search:
                    species = record.split(',')[0]
                    count = '{}.{}'.format(search.group(1), search.group(2))
            elif record.count(',') == 0 and record.count('.') == 2: # Comma mis-OCR'd as period
                species, count = record.split('.', maxsplit=1)
            else:
                species, count = record.split(',')
            species = get_cleaned_species(species)
            counts_record = pd.DataFrame({'year': year,
                                          'siteID': data['SiteNumInCensus'],
                                          'species': [species],
                                          'count': [count.strip(' .\n')],
                                          'status': ['resident']})
            counts_data = counts_data.append(counts_record, ignore_index = True)

    if 'Visitors' in data:
        visitor_data = data['Visitors'].split(',')
        for species in visitor_data:
            species = get_cleaned_species(species)
            counts_record = pd.DataFrame({'year': year,
                                          'siteID': data['SiteNumInCensus'],
                                          'species': [species],
                                          'count': [None],
                                          'status': ['visitor']})
            counts_data = counts_data.append(counts_record, ignore_index = True)
    
    return counts_data

def get_clean_size(size_data):
    """Remove units, notes, and whitespace"""
    size = size_data.split('ha')[0]
    size = size.replace('.]', '1')
    size = size.replace('.?)', '3')
    return float(size.strip(' .\n'))

def get_cleaned_species(species):
    """Cleanup species names"""
    species = species.strip().replace('-\n', '-')
    species = species.replace('\n', ' ')
    species = species.strip()
    return species


def get_cleaned_string(string_data):
    """Do basic cleanup on string data

    1. Remove \n's
    2. Strip whitespace

    """

    string_data = string_data.strip().replace('-\n', '')
    string_data = string_data.strip().replace('—\n', '')
    string_data = string_data.replace('\n', ' ')
    string_data = string_data.replace('.?)', '.3')
    string_data = string_data.strip()
    return string_data

def clean_string_fields(site_data):
    """Do basic cleanup on simple string fields for a site"""
    string_fields = ['Description of Plot', 'Edge', 'Location', 'Remarks',
                     'SiteName', 'Weather']
    for field in string_fields:
        if field in site_data:
            site_data[field] = get_cleaned_string(site_data[field])
    return site_data

def extract_coverage(coverage):
    """Extract number of hours and number of visits from Coverage"""
    coverage = get_cleaned_string(coverage)
    extracted = dict()
    re_modern = '([0-9]{1,3}\.{0,1}[0-9]{0,2}) h; ([0-9]{1,2}) [V|v]isits(.*)'
    re_modern_no_visits = '([0-9]{1,3}\.{0,1}[0-9]{0,2}) h'
    re_1988 = '([0-9]{1,3}) [V|v]isits; ([0-9]{1,3}) study[-|—]hours;(.*)'
    re_1988_no_visits = '([0-9]{1,3}) study[-|—]hours[;. ](.*)'
    if year > 1988:
        search = re.search(re_modern, coverage)
        search_no_visits = re.search(re_modern_no_visits, coverage)
    else:
        search = re.search(re_1988, coverage)
        search_no_visits = re.search(re_1988_no_visits, coverage)
    if search:
        extracted['hours'] = float(search.group(1))
        extracted['visits'] = int(search.group(2))
        extracted['notes'] = search.group(3)
    else:
        extracted['hours'] = float(search_no_visits.group(1))
        extracted['visits'] = None
        extracted['notes'] = None
    return extracted

def extract_total(total):
    """Extract the total number of species and total territories"""
    total = get_cleaned_string(total)
    extracted = dict()
    regex = '([0-9]{1,3}) species; ([0-9]{1,4}\.{0,1}[0-9]{0,1}) (territories|territorial males) \(([^)]+)\).'
    search = re.search(regex, total)
    extracted['total_species'] = int(search.group(1))
    extracted['total_territories'] = float(search.group(2))
    extracted['total_terr_notes'] = search.group(4)
    return extracted

def extract_continuity(continuity, year):
    """Extract establishment year and number of years surveyed"""
    continuity = get_cleaned_string(continuity)
    extracted = dict()
    if 'New' in continuity:
        extracted['established'] = year
        extracted['length'] = 1
    else:
        if ';' in continuity:
            established, length = continuity.split(';')
        elif ',' in continuity:
            # some ; delimiters are mis-OCR'd as ,
            established, length = continuity.split(',')
        else:
            # pre-1989 these are just space delimited
            established, length = continuity.split(' ')
        established = established.replace('Established', '').strip()
        length = length.replace('yr.', '').replace('consecutive', '').replace('intermittent', '').strip()
        extracted['established'] = established
        extracted['length'] = length
    return extracted

def extract_site_data(site_data):
    """Extract data for a site"""
    site_data['Latitude'], site_data['Longitude'] = get_latlong(site_data['Location'])
    site_data['Size'] = get_clean_size(site_data['Size'])
    if 'Coverage' in site_data:
        site_data['Coverage'] = extract_coverage(site_data['Coverage'])
    else:
        site_data['Coverage'] = dict()
    site_data['Total'] = extract_total(site_data['Total'])
    site_data['Continuity'] = extract_continuity(site_data['Continuity'], year)
    site_data = clean_string_fields(site_data)
    return site_data

def get_sites_table(site_data):
    """Put site level data into a dataframe"""
    sites_table = pd.DataFrame({'siteID': [site_data['SiteNumInCensus']],
                                'sitename': [site_data['SiteName']],
                                'latitude': [site_data['Latitude']],
                                'longitude': [site_data['Longitude']],
                                'location': [site_data['Location']],
                                'description': [site_data['Description of Plot']]})
    return sites_table

def get_census_table(site_data, year):
    """Put census level data into a dataframe"""
    #sometimes Weather doesn't exist before 1989
    weather = site_data['Weather'] if 'Weather' in site_data else None
    census_table = pd.DataFrame({'siteID': [site_data['SiteNumInCensus']],
                                 'sitename': [site_data['SiteName']],
                                 'siteNumInCensus': [site_data['SiteNumInCensus']],
                                 'year': [year],
                                 'established': [site_data['Continuity']['established']],
                                 'ts_length': [site_data['Continuity']['length']],
                                 'cov_hours': [site_data['Coverage'].get('hours', None)],
                                 'cov_visits': [site_data['Coverage'].get('visits', None)],
                                 'cov_times': [site_data['Coverage'].get('times', None)],
                                 'cov_notes': [site_data['Coverage'].get('notes', None)],
                                 'richness': [site_data['Total']['total_species']],
                                 'territories': [site_data['Total']['total_territories']],
                                 'terr_notes': [site_data['Total']['total_terr_notes']],
                                 'weather': [weather]
                             })
    return census_table


para_starts = {1988: 4, 1989: 6, 1990: 6, 1991: 7,
               1992: 7, 1993: 7, 1994: 7, 1995: 6}
data_path = "./data/raw_datasets/BBC_pdfs/"
#convert_pdfs_to_text(data_path)
#cleanup_nonpara_pages(data_path, para_starts)
#combine_txt_files_by_yr(data_path, para_starts.keys())

counts_table = pd.DataFrame(columns = ['siteID', 'year', 'species',
                                       'count', 'status'])
site_table = pd.DataFrame(columns = ['siteID', 'sitename', 'latitude',
                                     'longitude', 'location', 'description'])
census_table = pd.DataFrame(columns = ['siteID', 'sitename', 'siteNumInCensus',
                                       'year', 'established', 'ts_length', 'cov_hours',
                                       'cov_visits', 'cov_times', 'cov_notes',
                                       'richness', 'territories', 'terr_notes',
                                       'weather'])
years = range(1988, 1996)

for year in years:
    datafile = os.path.join(data_path, "bbc_combined_{}.txt".format(year))
    with open(datafile) as infile:
        data = parse_txt_file(infile, year)
        for site in data:
            print(year, site)
            data[site] = extract_site_data(data[site])
            counts_table = counts_table.append(extract_counts(data[site], year),
                                               ignore_index=True)
            site_table = site_table.append(get_sites_table(data[site]),
                                           ignore_index=True)
            census_table = census_table.append(get_census_table(data[site], year),
                                               ignore_index=True)

site_table_simp = site_table[['sitename', 'latitude', 'longitude']]
unique_sites = site_table_simp.drop_duplicates().reset_index(drop=True)
unique_sites['siteID'] = unique_sites.index
site_table = pd.merge(unique_sites, site_table, on = ['sitename', 'latitude', 'longitude'])
site_table['siteIDfinal'] = site_table['siteID_x']
site_table['siteID'] = site_table['siteID_y']
siteID_links = site_table[['siteID', 'siteIDfinal']]
counts_table = pd.merge(counts_table, siteID_links, on = ["siteID"])
census_table = pd.merge(census_table, siteID_links, on = ["siteID"])

counts_table = counts_table[['siteIDfinal', 'year', 'species', 'count', 'status']]
site_table = site_table[['siteIDfinal', 'sitename', 'latitude',
                         'longitude', 'location', 'description']]
census_table = census_table[['siteIDfinal', 'sitename', 'siteNumInCensus',
                                       'year', 'established', 'ts_length', 'cov_hours',
                                       'cov_visits', 'cov_times', 'cov_notes',
                                       'richness', 'territories', 'terr_notes',
                                       'weather']]

#TODO:

# 1. Site numbers need to be converted to siteIDs based on lat/long/name.
#    Multiple sites share the same lat/long, so it is insufficient on it's own

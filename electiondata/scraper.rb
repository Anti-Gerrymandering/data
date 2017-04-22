require 'pathname'
require 'json'
require 'http'

class Scraper
  ELECTIONS_ENDPOINT = 'http://www.electionreturns.pa.gov/api/ElectionReturn/GetAllElections?methodName=GetAllElections'.freeze
  OFFICE_DATA_ENDPOINT = 'http://www.electionreturns.pa.gov/api/ElectionReturn/GetOfficeData?methodName=GetOfficeDetails&electiontype=G&isactive=0'.freeze

  ELECTION_IDS = {
    2016 => 54,
    2014 => 41
  }.freeze

  OFFICE_IDS = {
    us_house: 11,
    pa_senate: 12,
    pa_house: 13
  }.freeze

  AFFGEOID_PREFIXES = {
    us_house: '5001400US42',
    pa_senate: '610U400US42',
    pa_house: '620L400US42'
  }.freeze

  def self.scrape
    new.scrape
  end

  def initialize
    @election_data = {
      us_house: {},
      pa_senate: {},
      pa_house: {}
    }
  end

  def scrape
    # Fetch 2017 data for all offices
    OFFICE_IDS.each do |label, office_id|
      print '.'

      fetch_office_data(ELECTION_IDS[2016], label, office_id)
    end

    # Fetch 2014 data for PA Senate
    fetch_office_data(ELECTION_IDS[2014], :pa_senate, OFFICE_IDS[:pa_senate])

    puts

    write_files
  end

  private

  def fetch_office_data(election_id, label, office_id)
    office_data = HTTP.get(
      OFFICE_DATA_ENDPOINT,
      params: {
        officeID: office_id,
        electionid: election_id
      }
    )

    # Skip if we get an error response
    return unless office_data.status == 200

    # Drill down to the data that we actually want
    data = JSON.parse(office_data.parse)['Election'].first.last.first.values

    add_election_data(label, data)
  end

  def add_election_data(office, districts)
    districts.each do |district|
      district = district.first
      aff_geo_id = build_aff_geoid(office, district['District'].to_i.to_s)
      @election_data[office][aff_geo_id] = format_district_data(district)
    end
  end

  def format_district_data(district)
    {
      District: district['District'],
      Candidates: format_candidates(district['Candidates'])
    }
  end

  def format_candidates(candidates)
    candidates.map do |candidate|
      {
        'ElectionYear' => candidate['ElectionYear'],
        'OfficeName' => candidate['OfficeName'],
        'PartyName' => candidate['PartyName'],
        'CandidateName' => candidate['CandidateName'],
        'Votes' => candidate['Votes'],
        'Percentage' => candidate['Percentage']
      }
    end
  end

  def build_aff_geoid(office, district_id)
    # State level districts are padded to 3 digits, US House to 2
    padding = office == :us_house ? 2 : 3
    padded_district_id = district_id.rjust(padding, '0')
    AFFGEOID_PREFIXES[office] + padded_district_id
  end

  def write_files
    OFFICE_IDS.keys.each do |office|
      File.write(
        office.to_s + '_data.json',
        JSON.pretty_generate(@election_data[office])
      )
    end
  end
end

Scraper.scrape

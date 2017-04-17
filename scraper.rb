require 'pathname'
require 'json'
require 'http'

class Scraper
  ELECTIONS_ENDPOINT = 'http://www.electionreturns.pa.gov/api/ElectionReturn/GetAllElections?methodName=GetAllElections'.freeze
  OFFICE_DATA_ENDPOINT = 'http://www.electionreturns.pa.gov/api/ElectionReturn/GetOfficeData?methodName=GetOfficeDetails'.freeze

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
    fetch_elections.each do |election|
      # we only care about general and special elections
      next unless %w(G S).include?(election['ElectionType'])

      OFFICE_IDS.each do |label, office_id|
        fetch_office_data(election, label, office_id)
      end
    end

    puts

    write_files
  end

  private

  def fetch_elections
    elections_data = HTTP.get(ELECTIONS_ENDPOINT)
    # The endpoint returns a JSON string, which contains an array with a single
    # object containing the key "ElectionData" which is a string with nested
    # JSON inside.
    elections_string = JSON.parse(JSON.parse(elections_data)).first['ElectionData']
    elections = JSON.parse(elections_string)
    elections.each do |election|
      election['ElectionDate'] = Date.strptime(election['ElectionDate'], '%m/%d/%Y')
    end

    elections.sort_by { |election| election['ElectionDate'] }.reverse
  end

  def fetch_office_data(election, label, office_id)
    office_data = HTTP.get(
      OFFICE_DATA_ENDPOINT,
      params: {
        officeID: office_id,
        electionid: election['Electionid'],
        electiontype: election['ElectionType'],
        isactive: election['ISActive']
      }
    )

    print '.'

    # Skip if we get an error response
    return unless office_data.status.success?

    # Drill down to the data that we actually want
    data = JSON.parse(office_data.parse)['Election'].first.last.first.values

    add_election_data(label, data)
  end

  def add_election_data(office, districts)
    districts.each do |district|
      district = district.first
      aff_geo_id = build_aff_geoid(office, district['District'].to_i.to_s)
      @election_data[office][aff_geo_id] ||= []
      @election_data[office][aff_geo_id] << district
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
      File.write(office.to_s + '_data.json', JSON.pretty_generate(@election_data[office]))
    end
  end
end

Scraper.scrape

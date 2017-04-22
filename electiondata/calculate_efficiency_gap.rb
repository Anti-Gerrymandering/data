require 'json'

ARGV.each do |file_name|
  puts 'Processing file: ' + file_name
  election_votes = wasted_republican = wasted_democrat = republican_wins = democrat_wins = 0
  File.open(file_name) do |file|
    data = JSON.parse(file.read)

    data.values.each do |district|
      democrat_candidate = district['Candidates'].find { |c| c['PartyName'] == 'DEM' }
      republican_candidate = district['Candidates'].find { |c| c['PartyName'] == 'REP' }

      next unless democrat_candidate && republican_candidate

      republican_votes = republican_candidate['Votes'].to_i
      democrat_votes = democrat_candidate['Votes'].to_i

      district_votes = republican_votes + democrat_votes
      election_votes += district_votes
      win_threshold = district_votes / 2.0
      if republican_votes > democrat_votes
        republican_wins += 1
        wasted_republican += republican_votes - win_threshold # surplus
        wasted_democrat += democrat_votes # loser
      elsif democrat_votes > republican_votes
        democrat_wins += 1
        wasted_democrat += democrat_votes - win_threshold # surplus
        wasted_republican += republican_votes # loser
      else
        raise 'Unlikely 50/50 split'
      end
    end
  end

  if wasted_democrat > wasted_republican
    gap = wasted_democrat - wasted_republican
    winner = 'republicans'
  else
    gap = wasted_republican - wasted_democrat
    winner = 'democrats'
  end

  gap_percentage = (gap / election_votes) * 100
  puts "#{gap_percentage.round(2)}% efficiency gap favoring #{winner}"
end

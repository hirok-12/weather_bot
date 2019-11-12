desc "This task is called by the Heroku scheduler add-on"
task :update_feed => :environment do
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }

  uri = URI('http://weather.livedoor.com/forecast/webservice/json/v1?city=130010')
  weather_data = JSON.parse(Net::HTTP.get(uri))
  today = weather_data['forecasts'][0]
  push =
    "#{today['dateLabel']}#{today['date']}の天気は#{today['telop']}です。" \
    "http://weather.livedoor.com/area/forecast/1310400"

  user_ids = User.all.pluck(:line_id)
  message = {
    type: 'text',
    text: push
  }
  response = client.multicast(user_ids, message)
end

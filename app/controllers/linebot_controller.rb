# コントローラ処理
# ①LINEでメッセージが送られてきた際の返信
# ②友達登録した際のDBへのIDの登録
# ③友達解除した際のDBからのIDの削除
#
# webhook -> https://weather-bot-1205.herokuapp.com/callback
# イベント　-> 友だち追加やメッセージの送信(https://developers.line.biz/ja/reference/messaging-api/)


# [TODO]３つの処理のメソッドを切り分ける
class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'net/http'
  require 'json'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  # 参考: https://github.com/line/line-bot-sdk-ruby
  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_from(body)
    events.each { |event|
      case event
        # メッセージが送信された場合の対応
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']
          case input
          when /.*(今日|きょう).*/
            uri = URI('http://weather.livedoor.com/forecast/webservice/json/v1?city=130010')
            weather_data = JSON.parse(Net::HTTP.get(uri))
            today = weather_data['forecasts'][0]
            push =
              "#{today['dateLabel']}の天気は#{today['telop']}です。" \
               "http://weather.livedoor.com/area/forecast/1310400"
          when /.*(明日|あした).*/
            uri = URI('http://weather.livedoor.com/forecast/webservice/json/v1?city=130010')
            weather_data = JSON.parse(Net::HTTP.get(uri))
            tomorrow_forecast = weather_data['forecasts'][1]
            push =
               "#{tomorrow_forecast['dateLabel']}の天気は#{tomorrow_forecast['telop']}です。" \
               "最高気温は#{tomorrow_forecast['temperature']['max']['celsius']}度、" \
               "最低気温は#{tomorrow_forecast['temperature']['min']['celsius']}度です。" \
               "http://weather.livedoor.com/area/forecast/1310400"
          when /.*(明後日|あさって).*/
            uri = URI('http://weather.livedoor.com/forecast/webservice/json/v1?city=130010')
            weather_data = JSON.parse(Net::HTTP.get(uri))
            day_after_tomorrow_forecast = weather_data['forecasts'][2]
            push =
              "#{day_after_tomorrow_forecast['dateLabel']}の天気は#{day_after_tomorrow_forecast['telop']}です。" \
               "http://weather.livedoor.com/area/forecast/1310400"
          when /.*(アメリカ|あめりか).*/
            push =
              "隠しコマンドを良く見つけたね！アメリカの思い出が恋しいよ"
          else
            push =
              "明日の天気が知りたい場合は#{'明日orあした'}。　\n明後日の天気が知りたい場合は#{'明後日orあさって'}とテキストしてね！　 "
          end
          # テキスト以外（画像等）のメッセージが送られた場合
        else
          push = "テキスト以外はわからないよ〜(；；)"
        end
        message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)
        # LINEお友達追された場合（機能②）
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # LINEお友達解除された場合（機能③）
      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
    head :ok
  end

  private

    def client
      @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
      }
    end
end
SQLITE_PATH = File.expand_path('files/twitter.sql3')



def main

    p = $params
    out html_header("twitter")
    out '<script>' + File.read("_form_events.js") + '</script>'
    out menu(__FILE__)

	db = SQLite3::Database.new SQLITE_PATH
	db.results_as_hash = true
	out sqlite3_info(SQLITE_PATH) + br

    out "twitter manager"

    tweet
end

def tweet
    # ツイート内容
    tweet_text = "これはAPIからのテスト投稿です。"
    uri = URI(TWEET_ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, {
    'Authorization' => "Bearer #{BEARER_TOKEN}",
    'Content-Type' => 'application/json'
    })

    request.body = { text: tweet_text }.to_json
    response = http.request(request)

    if response.code.to_i == 201
        out "ツイートが成功しました!"
    else
        out "エラー: #{response.code}"
        out response.body
    end

end

main
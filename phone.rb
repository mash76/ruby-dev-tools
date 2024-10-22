
# macのfsの文字コードは UTF-8-MAC  UTF-8でsqlite3に保存、ファイルパスを通常utf8ｎに変換
class Phone
    SQLITE_PATH = File.expand_path("files/phone.sql3","")


    def main
        p = $params
        # ----------------------------------------
        out html_header("phone_prices")
        out '<script>' + File.read("_form_events.js") + '</script>'
        out menu(__FILE__)

        db = SQL3.connect_or_create(SQLITE_PATH,'')

        out "smartphone prices"
    end
end
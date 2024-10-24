
class Api_test
    SQLITE_PATH = File.expand_path('files/api_test.sql3')

    def main

        p = $params

        out html_header('api test')
        out '<script>' + File.read("_form_events.js") + '</script>'
        out menu(__FILE__)

        db = SQL3.connect_or_create(SQLITE_PATH,create_tables)
        out SQL3.info(SQLITE_PATH) + br

        upd = p[:upd].to_s

        # ----------------------------------------

        edit = p[:edit] || 'off'
        view = p[:sqlite_path] || 'health'

        ['list','manage'].each do | view_name |
            out a_tag(same_red(view_name,view),'/dev/api_test/?view=' + view_name) + spc
        end
        out br

        # サイト
        recs = sqlite2hash('select * from sites ',db)
        recs.each do |row|
            row['name'] = a_tag(row['name'], '?site=' + row['name'] )
        end
        out hash2html(recs)

        urls = sqlite2hash('select * from site_urls ',db)
        urls.each do |row|
            row['url_name'] = a_tag(row['url_name'], '?site=' + row['url_name'] )
        end
        out hash2html(urls)

        row = urls[0]
       test1(row['method'],row['url'])
    end

    def test1(method,url,body = '')
        uri = URI.parse(url)
           response = Net::HTTP.get_response(uri)
        out 'url ' + url + br #+ ' <pre>' + ENC.html(response.body) + '</pre>'
        out 'ステータスコード: ' + response.code + br
        # out 'レスポンスボディ: <pre>' + ENC.html(response.body) + '</pre>'

    end

    def create_tables

        'CREATE TABLE "sites" (
            "id"	INTEGER NOT NULL,
            "name"	TEXT NOT NULL,
            "created_at"	TEXT NOT NULL,
            "updated_at"	TEXT,
            PRIMARY KEY("id")
        );
        CREATE TABLE "site_env_var_values" (
            "site_id"	INTEGER NOT NULL,
            "env_id"	INTEGER NOT NULL,
            "var_id"	INTEGER NOT NULL,
            "value"	TEXT,
            PRIMARY KEY("var_id","env_id","site_id")
        );
        CREATE TABLE "site_envs" (
            "site_id"	INTEGER NOT NULL,
            "env_id"	INTEGER NOT NULL,
            "name"	TEXT,
            PRIMARY KEY("site_id","env_id")
        );
        CREATE TABLE "site_vars" (
            "site_id"	INTEGER NOT NULL,
            "var_id"	INTEGER NOT NULL,
            "name"	TEXT NOT NULL,
            PRIMARY KEY("site_id","var_id")
        );'


    end


end

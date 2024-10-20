require 'net/http'
require 'json'

API_PAGES = "1"
SQLITE_PATH = File.expand_path('files/books.sql3')

def main
	p = $params
	out html_header("it_books")
	out '<script>' + File.read("_form_events.js") + '</script>'
	out menu(__FILE__)

	# ----------------------------------------

	view = p[:view] || "list"

	db = SQL3.connect_or_create(SQLITE_PATH,create_table)

	out SQL3.info(SQLITE_PATH)

	books_all = sqlite2hash("select count(*) ct FROM books",db,false)
	api_all = sqlite2hash("select count(*) ct FROM api_calls",db,false)
	out sSilver("books ") + books_all[0]['ct'].to_s
	out sSilver(" api_calls ") + api_all[0]['ct'].to_s + spc

	out br

	# ナビ
	['import','stat','list','db_stat','db_renew'].each do | view_name |
		out a_tag(same_red(view_name,view) ,'/dev/it_books?view=' + view_name) + spc
	end
	out '<hr/>'

	view_db_stat(db) if view == 'db_stat'
	recreate_book_table(db) if view == 'db_renew'
	view_list(p,db) if view == 'list'
	view_stat(p,db) if view == 'stat'

	view_import(p,db) if view == 'import'

end

def view_import(p,db)

	filter = p[:filter].to_s
	show_parse_detail = p[:show_parse_detail].to_s
	pages = p[:pages].to_s
	pages = API_PAGES.to_s unless p.key?(:pages)

	out '<form id="f1" method="get" action="?">'
	out i_hidden("view","import")
	out i_text("filter",filter,40)
	out i_checkbox("show_parse_detail", show_parse_detail )+ br
	out i_text("pages",pages,10) + " pages " + br

	stats = sqlite2hash("select keyword,count(*) ct FROM api_calls GROUP by keyword",db)
	api_counts = {}
	stats.each do |row |
		api_counts[row["keyword"]] = row["ct"]
	end
	#out api_counts.inspect
	words_4_api_query.each do |w|
		if w == "*"
			out br
			next
		end
		out a_tag(sBG(w),"javascript: $('[name=filter]').val('" + w + "'); $('#f1').submit();")
		out api_counts[w].to_s + " &nbsp; "
	end
	out i_submit_trans "更新"
	out '</form>'

	if filter.length == 0
		out sRed('no filter') + br
		return
	end
	book_hashes = api_call(filter, pages, GOOGLE_API_KEY, db) if filter.length > 0
	mod_hashes = modify_results(book_hashes,show_parse_detail)
	db_insert_boos(mod_hashes,db)

end

def recreate_book_table(db)
	create_table_sql = "
		CREATE TABLE books (
			g_book_id TEXT PRIMARY KEY,
			title TEXT,
			desc TEXT,
			authors TEXT,
			publisher TEXT,
			published TEXT,
			language TEXT,
			price REAL,
			pages INTEGER,
			isbn_10 INTEGER,
			isbn_13 INTEGER,
			created TEXT,
			updated TEXT
		);"
	sqlite2hash("DROP TABLE books",db)
	out br
	sqlite2hash(create_table_sql,db)

	calls_sql = "
		CREATE TABLE api_calls (
			id INTEGER PRIMARY KEY,
			keyword TEXT,
			page INTEGER,
			url TEXT,
			result_json TEXT,
			created TEXT,
			updated TEXT
		);"
	sqlite2hash("DROP TABLE api_calls",db)
	out br
	sqlite2hash(calls_sql,db)

end

def url_amazon(isbn_10)
	return "" if isbn_10 == nil
	return "https://www.amazon.co.jp/dp/" + isbn_10.to_s
end
def url_thumb(g_book_id)
	return "" if g_book_id == nil
	return 'http://books.google.com/books/content?id=' + g_book_id + '&printsec=frontcover&img=1&zoom=5&source=gbs_api'
end

def db_insert_boos(books2,db)

	# google_id	json_link	preview	thumb	title	authors	publisher	published	lang	price	pages

	books3 = books2.dup # 参照になってしまいnullが
	books3.each do |row|

		if row['title'] == nil
			#out row.inspect
			next
		end
		row['price'] = "NULL" if row['price'] == ""

		# YYYY-MM-DD HH:ii:ss
		sql_insert = "insert into books
					(g_book_id ,title ,desc,authors ,publisher ,published ,
					language ,price ,pages,isbn_10,isbn_13,
					created,updated)
		values(
			'" << row['google_id'] << "',
			'" << row['title'].gsub("'", "''") << "',
			'" << row['desc'].gsub("'", "''") << "',
			'" << row['authors'].gsub("'", "''") << "',
			'" << row['publisher'].gsub("'", "''") << "',
			'" << row['published'] << "',
			'" << row['lang'] << "',
			" << row['price'] << ",
			'" << row['pages'] << "',
			'" << row['isbn_10'] << "',
			'" << row['isbn_13'] << "',
			'" << now_time_str << "',
			'" << now_time_str << "' )"
		#puts sql_insert
		out row['title'] + spc
		sqlite2hash(sql_insert,db)

		row['price'] = "" if row['price'] == "NULL" # よくない
	end

end

def modify_results(books,show_parse_detail)

	results = []
	books.each do |item|
		vol = item['volumeInfo']
		price = ""
		image_link = ""
		authors = ""
		publisher = ""
		published = ""
		pages = "0"
		desc = ""
		out vol['title'] + br if show_parse_detail == "1"


		if vol.key?('publishedDate') && vol['publishedDate'] != nil
			published = vol['publishedDate'].to_s
		end
		if vol.key?('description') && vol['description'] != nil
			desc = vol['description'].to_s
		end

		if vol.key?('pageCount') && vol['pageCount'] != nil
			pages = vol['pageCount'].to_s
		end

		if vol.key?('publisher') && vol['publisher'] != nil
			publisher = vol['publisher'].to_s
		end

		if vol.key?('authors')
			authors = vol['authors'].join(',')
		end

		if vol.key?('imageLinks')
			out sBlue("imageLinks exist") + br if show_parse_detail == "1"
			if vol['imageLinks'].key?('smallThumbnail')
				image_link = vol['imageLinks']['smallThumbnail'].to_s
			else
				out sRed("no smallThumbnail") + br if show_parse_detail == "1"
			end
			out vol['imageLinks']['smallThumbnail'] + br if show_parse_detail == "1"
			out sRed("no thumbnail") + br unless vol['imageLinks'].key?('thumbnail')
		else
			out sRed("no imageLinks ") + br if show_parse_detail == "1"
		end

		# volumeInfo.industryIdentifiers array
		# 	{ type : ISBN_10,  identifier =111 }
		# 	{ type : ISBN_13 , identifier = 222 }
		isbn10 = ""
		isbn13 = ""
		if vol.key?('industryIdentifiers')
			out sBlue("industryIdentifiers exist") + br if show_parse_detail == "1"
			vol['industryIdentifiers'].each do |isbn_hash|
				if isbn_hash['type'] == 'ISBN_10'
					isbn10 = isbn_hash['identifier'].to_s
				end
				if isbn_hash['type'] == 'ISBN_13'
					isbn13 = isbn_hash['identifier'].to_s
				end
			end
		else
			out sRed("no industryIdentifiers ") + br if show_parse_detail == "1"
		end

		if item.key?('saleInfo')
			sale_info = item['saleInfo']
			out sBlue("saleInfo exist") + br if show_parse_detail == "1"
			if sale_info.key?('listPrice')
				out sBlue("saleInfo.listPrice exist") + br if show_parse_detail == "1"
				if sale_info['listPrice'].key?("amount")
					out sBlue("saleInfo.listPrice.amount exist") + br if show_parse_detail == "1"
					price = sale_info['listPrice']['amount'].to_s
				else
					out sRed("no saleInfo.listPrice.amount ") + br if show_parse_detail == "1"
				end
			else
				out sRed("no saleInfo.listPrice ") + br if show_parse_detail == "1"
			end
		else
			out sRed("no saleInfo ") + br if show_parse_detail == "1"
		end

		results << {
			"google_id" => item['id'],
			"json_link" => '<a href="https://www.googleapis.com/books/v1/volumes/' + item['id'] + '">link</a>',
			"preview" => '<a href="http://books.google.co.jp/books?id=' + item['id'] + '&hl=&source=gbs_api">preview</a>',
			#"info" => '<a href="http://play.google.com/store/books/details?id=' + item['id'] + '&source=gbs_api">preview</a>',
			"title" => vol['title'],
			"desc" => desc,
			"authors"=> authors,
			'publisher' => publisher,
			'published' => published,
			'lang' => vol['language'],
			'price' => price,
			'pages' => pages,
			'isbn_10' => isbn10,
			'isbn_13' => isbn13,
		}
		out sBG('json') + spc + item.to_json.trim_spreadable + br if show_parse_detail == "1"
	   # out "<pre>" + item.inspect + "</pre>" +  br
	end
	return results
end

def api_call(query,pages, api_key, db)

	books_ary = Concurrent::Array.new
	api_calls = Concurrent::Array.new
	#books_all = []
	threads = []
	pages.to_i.times do |page|
		start_index = (page) * 40
		url_str = "https://www.googleapis.com/books/v1/volumes?q=#{URI::DEFAULT_PARSER.escape(query)}&key=#{api_key}&maxResults=40&startIndex=" + start_index.to_s

		url = URI(url_str)

		threads << Thread.new(url,page) do |url,page|
			start = Time.now
			response = Net::HTTP.get(url)
			books = JSON.parse(response)
			elapsed = (Time.now - start).round(2)
			out sBlue("url ") + url  + spc + sPink(elapsed.to_s) + spc
			if books == nil
				out sRed(" no results") + "<hr/>"
			else
				if books.key?("items")
					out books['items'].length.to_s + "<hr/>"
				else
					out sRed("book no key items")
				end
			end
			if books['items'].length == 0
				out sRed("no hits") + br
				return
			end

			api_calls << { url: url, keyword: query ,page: page ,result_json: response , result_ct: books['items'].length}
			books['items'].each do |row|
				if row['volumeInfo'].key?('title')
					out row['volumeInfo']['title'] + br #名前だけ出す
				else
					out sRed('no title ') + row.inspect + br
				end
				#books_all << row
				books_ary << row
			end
		end
	end
	threads.each(&:join)

	api_calls.each do |row|
		sqlite2hash("insert into api_calls (url,keyword,page,result_json,created,updated)
			values('" + row[:url] + "',
			'" + now_time_str + "',
			'" + row[:page].to_s + "',
			'" + row[:result_json].gsub("'", "''") + "',
			'" + now_time_str + "',
			'" + now_time_str + "')",db) ####
			db.last_insert_row_id
	end

	return books_ary
end

def word_groups

	 {
		"unix/linux" => ["unix","linux","bsd","ubuntu"],
		"c/rust/go" => ["c言語","c++","rust","go"],
		"java" => ["java","scala","kotlin","J2EE","ejb","struts","spring","tomcat","hibernate"],
		"javaScript" => ["javascript","typescript","coffee","node","backbone","react","angular","vue","ajax"],
		"PHP" => ["php","cake","zend","slim","fuel","laravel","PHP4","PHP5","PHP7","PHP8"],
		"クラウド" => ["docker","kubernetes","aws","gcp","azure"],
		"アセンブラ/マシン語" => ["アセンブラ","マシン語","6502","Z80","8086","80286","80386","pentium"],
		"ガーデンニング" => ["室内","ビザール","珍奇"],
		"ゲーム開発" => ["unity","unreal","cocos","openGL"],
		"関数型" => ["関数型","lisp","scheme","haskell"],
		"全文検索" => ["elastic","solr","全文検索","namazu"],
		"cobol/fortran" => ["cobol","fortran","pascal","delphi"],
		"ビジネス書籍 有名個人" => ["大前研一","ドラッカー","邱永漢","竹村健一"],
		"開発技法" => ["オブジェクト指向","ドメイン","クリーン","デザインパターン"],
		"開発チーム アジャイル/スクラム" => ["エクストリーム","アジャイル","スクラム"],
		"コーチング" => ["コーチング"]
	}
end

def words_4_api_query()

		["Ruby programming","ruby rails","ruby sinatra", "*",
		"python programming", "*",
		"php programming","php4","php5 programming","php7 programming","php8 programming","fuel php","laravel","zend framework","cake PHP","PHP Synfony", "*",
		"java programming","apache struts","java spring","java ejb","apache tomcat","hibernate","J2EE","scala programming","kotlin", "*",
		"COBOL","*",
		"swift programming","android programing", "*",
		"unity programming","cocos programming","unreal engine","game programming","openGL", "*",
		"ソフトウェア", "*",
		"Next ICT選書","SEC BOOKS","*",
		"javascript","node.js","react programming","typescript","coffee script","ajax","angular","vue.js","backbone.js", "*",
		"msdos","*",
		"マイコン","basic programming","X68000","*",
		"c言語","c++ プログラミング","アセンブラ","マシン語","6502","8086","80286","80386","pentium","Z80","*",
		"go programming","*",
		"perl","perl framework","perl5","perl6", "*",
		"saas","SEO","google analytics","google adwards", "*",
		"domain driven development","clean architecture","クリーンアーキテクチャ","agile development","object oriented","extreme programming","test driven", "アジャイル 開発","エクストリーム プログラミング","オブジェクト指向","スクラム開発","*",

		"haskell","関数型プログラミング","lisp programming","scheme programming","*",
		"機械学習","深層学習","opencv","chatGPT","UML","XML", "*",
		"要件定義","仕様書","IT業界","システム障害","会計システム","ERP","*",
		"unix","linux","bsd","*",
		"awk","smalltalk programming","*",
		"imode","ezweb","*",
		"日経コンピュータ","*",
		"スタートアップ","*",
		"SAP","*",
		"NoSQL","キーバリュー",
		"oreilly", "*",
		"git","slack", "*",
		"API", "*",
		"graphSQL", "*",
		"docker","kubernetes", "*",
		"全文検索", "*",
		"AWS","google GCP","Microsoft Azure", "*",
		"データベース","SQL","Oracle database","MySQL","PostgreSQL","SQLServer"]
end

def lang_lists
	["unix","linux","dos","c言語","c++","BASIC","マイコン","アセンブラ","マシン語","全文検索","ruby","rails","cobol",
	"java","scala","kotlin","J2EE","ejb","struts","spring","tomcat","hibernate",
	"typescript","coffee","node","react","angular","vue","ajax",
	"perl",
	"php","cake","zend","fuel","laravel",
	"python","深層学習","機械学習",
	"go","uml","xml",
	"要件","仕様書",
	"chatGPT","openCV","SAP",
	"docker","kubernetes","aws","gcp","azure",
	"mysql","oracle","git","API",
	"unity","unreal","cocos","openGL",
	"lisp","haskell","関数型",
	"x68000",
	"オブジェクト指向","ドメイン","クリーン","デザインパターン",
	"日経コンピュータ","スタートアップ"]
end

def view_db_stat(db)

	out '	<div class="flex-container"><div class="flex-item" > '

	out sBG('lang') + spc
	books_all = sqlite2hash("select language, count(*) ct
							FROM books GROUP BY language
							ORDER BY ct desc limit 5",db,15)
	out hash2html(books_all)

	out '</div><div class="flex-item" > '

	out sBG('import day') + spc
	books_all = sqlite2hash("select SUBSTR(created, 1, 10), count(*) ct
							FROM books GROUP BY SUBSTR(created, 1, 10)
							ORDER BY SUBSTR(created, 1, 10) DESC limit 5",db,15)
	out hash2html(books_all) + br

	out sBG('import month') + spc
	books_all = sqlite2hash("select SUBSTR(created, 1, 7), count(*) ct
							FROM books GROUP BY SUBSTR(created, 1, 7)",db,15)
	out hash2html(books_all)

	out '</div><div class="flex-item" > '

	out sBG('api_calls day') + spc
	books_all = sqlite2hash("select SUBSTR(created, 1, 10), count(*) ct
							FROM api_calls GROUP BY SUBSTR(created, 1, 10)
							ORDER BY SUBSTR(created, 1, 10) DESC limit 5",db,15)
	out hash2html(books_all) + br

	out sBG('api_calls mon') + spc
	books_all = sqlite2hash("select SUBSTR(created, 1, 7), count(*) ct
							FROM api_calls GROUP BY SUBSTR(created, 1, 7)",db,15)
	out hash2html(books_all)

	out '</div><div class="flex-item" > '

	out sBG('api_calls stat') + spc
	books_all = sqlite2hash("select  keyword,count(*) ct,min(created),max(created)
							FROM api_calls GROUP BY keyword",db,15)
	out hash2html(books_all)

	out '</div></div> '

end

def view_stat(p,db)

	word_group = p[:word_group].to_s
	# カテゴライズキーワード一覧
	word_groups.each do |key,words|
		out a_tag(sBlack(key) + sSilver(words.length.to_s) + spc,"?view=stat&word_group=" +  ENC.url(key))
	end

	return if word_group.length == 0

	# 統計するキーワード

	words_for_stat = word_groups[word_group] if word_group.length > 0

	#words_for_api_query = lang_lists
	# out sBlue('langs') + br
	# langs_sql = "select language lang,count(*) from books GROUP BY language"
	# lang_stats = sqlite2hash(langs_sql,db,20)

	# out sBlue('years') + br
	# year_sql = "select SUBSTR(published, 1, 4) year,count(*) from books GROUP BY SUBSTR(published, 1, 4)"
	# year_stats = sqlite2hash(year_sql,db,20)

	word_all_counts = {} # 単語ごとのタイトルヒット数
	word_year_pubs = {} #単語ごとの年ごと出版点数

	year_max = 0  #検索結果のyear 上限と下限のでdefault
	year_min = 5000



	# 単語数カウント、年ごとの出版点数を取得
	words_for_stat.each do | word|
		langs_sql = "select count(*) ct from books
				WHERE title like '%" + word + "%' and language='ja'"
		#out sBlue(word) + br
		langs = sqlite2hash(langs_sql,db,NO_DISP)
		word_all_counts[word] = langs[0]['ct']

		year_sql = "select SUBSTR(published, 1, 4) year,count(*) ct from books
				WHERE title like '%" + word + "%' and language='ja'
				GROUP BY SUBSTR(published, 1, 4) "
		word_years = sqlite2hash(year_sql,db,NO_DISP)
		#out hash2html(word_years)
		word_years.each do |row|
			next if row['year'] == ""
			year_max = row['year'].to_i if row['year'].to_i > year_max
			year_min = row['year'].to_i if row['year'].to_i < year_min
		end
		word_year_pubs[word] = word_years
	end

	# year  docer java  aws
	# 2003  3     5     0
	# 2004  5     6     0
	tables = []
	row = { "year" => "total"}
	words_for_stat.map { | word| row[word] = word_all_counts[word]   }
	tables << row
	for y in year_min..year_max do
		new_row = { "year" => y}
		words_for_stat.each do | word|
			new_row[word] = "0"
			word_year_pubs[word].each do |row|
				if row["year"] == y.to_s
					new_row[word] = row["ct"]
				end
			end
		end
		tables << new_row
	end
	out hash2html_book_color(tables)
end

def view_list(p,db)

		filter = p[:filter].to_s
		year_from = p[:year_from].to_s
		year_to = p[:year_to].to_s

		# キーワード一覧
		lang_lists.each do |word|
			disp = (word == filter ? sRed(word) : word)
			out a_tag(disp,"?view=list&filter=" + word ) + spc
		end

		# table全件数
        out '<form id="f1" method="post" action="?">'
        out i_hidden "view","list"
        out i_text("filter",filter,30) + br
		out "発売年" + i_text("year_from",year_from,6) + "-" + i_text("year_to",year_to,6)

		out "最近 "
		for i in [2,4,10,20,30] do
			year1 = (Time.now.year - i)
			saikin = (Time.now.year - year1).to_s
			out a_tag(saikin + "年","javascript:$('input[name=year_from]').val(" + year1.to_s + "); $('#f1').submit()") + spc
		end
		out i_submit "検索"
        out "</form>"

		out "<table><tr><td valign=top >"

		# g_book_id	title	authors	publisher	published	language	price
		sql_select = "select
			language la,published,price,pages,'' thu,'ama' ama,'' json,'' ggl,title,authors,publisher,g_book_id,isbn_10,isbn_13
			FROM books "

		sql_where =" WHERE language='ja'"
		sql_where << " and (title like '%" + filter + "%' or authors like '%" + filter + "%' or publisher like '%" + filter + "%' )" if filter.length > 0
		sql_where << " and CAST(SUBSTR(published, 1, 4) AS INTEGER) >= " + year_from if year_from.length > 0
		sql_where << " and CAST(SUBSTR(published, 1, 4) AS INTEGER) <= " + year_to if year_to.length > 0

		# substr
		stat_sql = "select SUBSTR(published, 1, 4) year,count(*)
				FROM books " + sql_where + " GROUP BY SUBSTR(published, 1, 4) ORDER BY SUBSTR(published, 1, 4) DESC "
		books = sqlite2hash(stat_sql,db,NO_DISP)
		out books.length.to_s + br
		out hash2html(books)

		out '</td><td valign=top >'

		books_sql = sql_select + sql_where
		books_sql << " order by published desc limit 2000"
		books = sqlite2hash(books_sql,db,15)
		books.each do |row|
			row['authors'] = row['authors'].trim_spreadable(10)
			row['title'] = row['title'].trim_spreadable(50)
			row['publisher'] = row['publisher'].trim_spreadable(12)
			row["thu"] = '<img height=30 src="' + url_thumb(row['g_book_id']) + '" />'
			row["json"] = '<a href="https://www.googleapis.com/books/v1/volumes/' + row['g_book_id'] + '">json</a>'
			row["ggl"] = '<a href="http://books.google.co.jp/books?id=' + row["g_book_id"] + '&hl=&source=gbs_api">ggl</a>'
			row["ama"] = (row['isbn_10'] != "") ? a_tag("ama",url_amazon(row['isbn_10'])) : "---"
			row = color_row(row,filter)
		end
		out hash2html(books)

		out '</td></tr></table>'
end

def create_table
	"
	CREATE TABLE books (
		g_book_id TEXT PRIMARY KEY,
		title TEXT,
		desc TEXT,
		authors TEXT,
		publisher TEXT,
		published TEXT,
		language TEXT,
		price REAL,
		pages INTEGER,
		isbn_10 INTEGER,
		isbn_13 INTEGER,
		created TEXT,
		updated TEXT
	);
	CREATE TABLE api_calls (
		id INTEGER PRIMARY KEY,
		keyword TEXT,
		page INTEGER,
		url TEXT,
		result_json TEXT,
		created TEXT,
		updated TEXT
	)"
end


main



=begin


		{
			"kind": "books#volume",
			"id": "y8BrPgAACAAJ",
			"etag": "Z4zNnZ2XR9k",
			"selfLink": "https://www.googleapis.com/books/v1/volumes/y8BrPgAACAAJ",
			"volumeInfo": {
				"title": "プログラミング言語Ruby",
				"authors": [
					"David Flanagan",
					"まつもとゆきひろ"
				],
				"publishedDate": "2009-01",
				"description": "まつもとゆきひろ著のRuby言語開発の決定版",
				"industryIdentifiers": [
					{
						"type": "ISBN_10",
						"identifier": "4873113946"
					},
					{
						"type": "ISBN_13",
						"identifier": "9784873113944"
					}
				],
				"readingModes": {
					"text": false,
					"image": false
				},
				"pageCount": 447,
				"printType": "BOOK",
				"categories": [
					"Object-oriented programming (Computer science)"
				],
				"maturityRating": "NOT_MATURE",
				"allowAnonLogging": false,
				"contentVersion": "preview-1.0.0",
				"imageLinks": {
					"smallThumbnail": "http://books.google.com/books/content?id=y8BrPgAACAAJ&printsec=frontcover&img=1&zoom=5&source=gbs_api",
					"thumbnail": "http://books.google.com/books/content?id=y8BrPgAACAAJ&printsec=frontcover&img=1&zoom=1&source=gbs_api"
				},
				"language": "ja",
				"previewLink": "http://books.google.co.jp/books?id=y8BrPgAACAAJ&dq=Ruby+programming&hl=&cd=1&source=gbs_api",
				"infoLink": "http://books.google.co.jp/books?id=y8BrPgAACAAJ&dq=Ruby+programming&hl=&source=gbs_api",
				"canonicalVolumeLink": "https://books.google.com/books/about/%E3%83%97%E3%83%AD%E3%82%B0%E3%83%A9%E3%83%9F%E3%83%B3%E3%82%B0%E8%A8%80%E8%AA%9ERuby.html?hl=&id=y8BrPgAACAAJ"
			},
			"saleInfo": {
				"country": "JP",
				"saleability": "NOT_FOR_SALE",
				"isEbook": false
			},
			"accessInfo": {
				"country": "JP",
				"viewability": "NO_PAGES",
				"embeddable": false,
				"publicDomain": false,
				"textToSpeechPermission": "ALLOWED",
				"epub": {
					"isAvailable": false
				},
				"pdf": {
					"isAvailable": false
				},
				"webReaderLink": "http://play.google.com/books/reader?id=y8BrPgAACAAJ&hl=&source=gbs_api",
				"accessViewStatus": "NONE",
				"quoteSharingAllowed": false
			},
			"searchInfo": {
				"textSnippet": "まつもとゆきひろ著のRuby言語開発の決定版"
			}
		},

=end

require 'net/http'
require 'json'
require 'sqlite3'
require 'uri'
require 'erb'


NO_DISP = false


def ffprobe_streams(path)
	  path_esc = path.gsub('"','\"')
    shell1 = 'ffprobe -v error -print_format json -show_streams "' + path_esc  + '"'
    json_str = run_shell(shell1)
    return false if json_str.include?('Operation timed out')
    json_raw = JSON.parse(json_str)
	return json_raw
end

def ffprobe_chapters(path)
    path_esc = path.gsub('"','\"')
    shell1 = 'ffprobe -v error -print_format json -show_chapters "'  + path_esc + '"'
    json_str = run_shell(shell1)
    return false if json_str.include?('Operation timed out')
    json_raw = JSON.parse(json_str)
	return json_raw
end

$id_index = 0

class String
  def nl2br() return self.gsub(/\n/, '<br/>') end
  def trim(length=30)
    len = self.length
    str = self.gsub(/\n/,'').gsub(/<br\/?>/i,'')[0, length]  # brと \n を除去して trim
    if len > length
      str += ".."
    end
    return str
  end

  def trim_spreadable(trim_length=30, is_html_encode = false)
    len = self.length
    str = self.gsub(/\n/,'').gsub(/<br\/?>/,'')[0, trim_length]  # brと \n を除去して trim
    return str if len <= trim_length

    $id_index += 1
    str_origin = self
    str_origin = CGI.escapeHTML(str_origin) if is_html_encode
    str_trim = str + '..'
    str = a_tag( sSilver(CGI.escapeHTML(str_trim)) , "javascript:$('#trim" + $id_index.to_s + "').css('display','block')")

    str += '<div id="trim' + $id_index.to_s + '" style="background:#f9f9f9; display:none;">' + str_origin + '</div>'

        # str += '<div id="trim' + $id_index.to_s + '" style="background:#f9f9f9; display:none;">' + CGI.escapeHTML(str_origin).nl2br + '</div>'

    return str
  end

  def split_nl() return self.split(/\n/) end
  def split_tab() return self.split(/\t/) end
end

def color_recent_time(date_str)
    # 1時間以内 12時間以内
    return sRedBG(date_str) if Time.now - Time.parse(date_str) < 3600
    return sRed(date_str) if Time.now - Time.parse(date_str) < 3600 * 12

    # 10日以上前
   return sSilver(date_str) if Time.now - Time.parse(date_str) > 3600 * 24 * 10
   date_str
end

# 文字はb
def truncate_by_width(str, max_width)
  out_str = ''
  current_width = 0
  str.each_char do |char|
      width = char.bytesize > 1 ? 2 : 1 # 2バイト以上の文字は全角
      if current_width + width > max_width
        out_str += '...'
        break
      end
      out_str << char
      current_width += width
  end
  out_str
end


module SQL3
  def self.connect_or_create(path, create_sql)

    puts "\x1b[33m" + 'sql3 conn ' + "\x1b[0m" + path
    if File.exist?(path)
      db = SQLite3::Database.new(path)
      out sGreen("SQLite3接続 ") + sSilver(path)
    else
      db = SQLite3::Database.new(path)
      out sOrange("SQLite3作成 ") + sSilver(path)
      db.execute_batch(create_sql)
      out sGreen("テーブルを作成しました")
    end
    db.results_as_hash = true
    db
  end

  def self.info(path)
    ret =  sOrange('sqlite3 ') + a_tag(sSilver(path),"/dev/sqlite?sqlite_path=" +  URI.encode_www_form_component(path) + '&view=db') + spc
    stat = File.stat(path)
    db = SQLite3::Database.new path
    tables = sqlite2hash("SELECT * FROM sqlite_master WHERE type='table' ",db,false)
    db.close
    # ret << tables.length.to_s + sSilver('tables ')
    ret << (stat.size / 1024.0 / 1024.0).round(2).to_s + sSilver("mb ") + Time.at(stat.mtime).strftime('%Y-%m-%d %H:%M:%S')
  end
end

def SQL3.info_hash(path)

  #### ファイルなければエラー
  ret = {}
  ret['file_path'] =  a_tag(path,'/dev/sqlite?sqlite_path=' +  URI.encode_www_form_component(path) + "&view=db")
  stat = File.stat(path)
  db = SQLite3::Database.new path
  tables = sqlite2hash("SELECT * FROM sqlite_master WHERE type='table' ",db,false)
  db.close
  ret['tables'] = tables.length.to_s
  ret['size'] = (stat.size / 1024.0 / 1024.0).round(2).to_s + sSilver("mb ")
  upd_date = Time.at(stat.mtime)
  ret['days'] = past_days(upd_date).to_s
  ret['updated_at'] = upd_date.strftime('%Y-%m-%d %H:%M:%S')

  ret
end

# 本日までの経過日数 (n日前更新などの表現に利用)
def past_days(date_str)
  return ((Time.now - date_str) / 86400).round(2)
end


def sqlite2hash(sql,db,sql_trim_len=30) #sqlite
  begin
    puts "\x1b[33m" + 'sql3 ' + "\x1b[0m" + sql
    out sSilver(sql.trim_spreadable(sql_trim_len)) if sql_trim_len != NO_DISP
    start = Time.now
    ret = db.execute(sql)
    time1 = (Time.now - start).round(4).to_s
    out spc + ret.length.to_s + sSilver("r") + spc + time1 + sSilver("s") if sql_trim_len != NO_DISP
    return ret
  rescue StandardError => e
    out br + sRed(e.message) + br
  ensure
    #db.close if db
  end
end

def dir_exist?(dir)
  unless Dir.exist?(dir)
      out sRed("no dir " + sSilver(dir))
      return false
  end
  return true
end


def sql2hash(sql, conn_name, trim_len = 50) # mysql
  begin
      puts "\x1b[35m" + 'mysql ' + "\x1b[0m" + sql
      out sSilver(sql.trim_spreadable(trim_len)) + spc if trim_len != NO_DISP
      results = $mysql_conns[conn_name].query(sql).to_a
      out results.length.to_s + spc + a_tag(sSilver("Edit"),"/dev/sql?conn_name=" + conn_name + "&sql_text=" + URI.encode_www_form_component(sql) ) if trim_len != NO_DISP
      return results
  rescue Mysql2::Error => e
      out br + sRed(e.message) + br
      return {}
  end
end

def hash2html_nohead(hashes,p_class = "border")
  unless hashes.is_a?(Array)
    out sRed("not array ") + __FILE__.to_s + spc + __LINE__.to_s + spc + __method__.to_s + br
    return ''
  end
  return '' if hashes.length == 0

  html = "<table class='" + p_class + "'>"

  hashes.each do |row|
      html << '<tr>'
      row.each { |key,value | html << '<td nowrap>' + value.to_s + '</td>'  }
      html << '</tr>'
  end
  html << '</table>'
  html
end



# class border セル境界線つける t_hover = 選択行を強調
def hash2html(hashes,p_class = "border")
  unless hashes.is_a?(Array)
    out sRed("not array ") + __FILE__.to_s + spc + __LINE__.to_s + spc + __method__.to_s + br
    return ''
  end
  return '' if hashes.length == 0

  html = "<table class='" + p_class + "'><tr>"
  hashes[0].each  { | key,value | html << '<th nowrap>' + key.to_s + '</th>' }
  html << '</tr>'

  hashes.each do |row|
      html << '<tr>'
      row.each { |key,value | html << '<td nowrap>' + value.to_s + '</td>'  }
      html << '</tr>'
  end
  html << '</table>'
  html
end

def hash2records(hash)
  records = []
  hash.each do |key,val|
      records << { key: key, val: val }
  end
  records
end

TIME_FMT = OpenStruct.new
TIME_FMT.YYYYMMDDHHIISS = '%Y-%m-%d %H:%M:%S'
TIME_FMT.YYYYMMDD = '%Y-%m-%d'
TIME_FMT.YYMMDD = '%y-%m-%d'
TIME_FMT.HHIISS = '%H:%M:%S'

def now_time_str(format = TIME_FMT.YYYYMMDDHHIISS)
  Time.now.strftime(format)
end

# 値ごとに色をつける 0ならsilver 5までは** 10までは **
def hash2html_book_color(hashes)
  return "" if hashes.length == 0
  html ="<table><tr>"
  hashes[0].each  { | key,value | html << '<th nowrap>' + key + '</th>' }
  html << "</tr>"
  ct = 0
  hashes.each do |row|
    ct += 1
      html << "<tr>"
      row.each do |key,value |
        td_style = ""
        if key != "year" && ct != 1
          if value == "0"
            value = sSilver(value)
          elsif value.to_i < 5
            value = sBlue(value.to_s)
            td_style = 'background: #eef;'
          elsif value.to_i < 10
            value = sWhite(value.to_s)
            td_style = 'background: #aaf;'
          elsif value.to_i < 20
            value = sWhite(value.to_s)
            td_style = 'background: #88f;'
          elsif value.to_i < 30
            value = sWhite(value.to_s)
            td_style = 'background: #00c;'
          else
            value = sWhite(value.to_s)
            td_style = 'background: #f00;'
          end
        else
          value = value.to_s
        end
        html << '<td nowrap style="' << td_style << '">' << value << '</td>'
      end
      html << '</tr>'
  end
  html << '</table>'
  html
end

def color_val(val,keyword,all = true)
  return val if keyword.length == 0
  pattern = Regexp.new('(' + Regexp.escape(keyword) + ')',Regexp::IGNORECASE)
  if all
    val = val.to_s.gsub(pattern,sRed('\1'))
  else
    val = val.to_s.sub(pattern,sRed('\1'))
  end
  val
end

def color_row(row,keyword)
  return row if keyword.length == 0
  pattern = Regexp.new('(' + Regexp.escape(keyword) + ')',Regexp::IGNORECASE)
  row.each do | key,value|
    row[key] = row[key].to_s.gsub(pattern,sRed('\1'))
  end
  row
end

def color_records(records,keyword)
  return records if records.length == 0
  records.each do | row |
    row = color_row(row,keyword)
  end
  records
end

# 列のまちまちなhashの配列をそろえる
def fill_hash_cols(hashes,colnames_ary)
  ret_hashes = []
  hashes.each do | row |
    hash1 = {}
    colnames_ary.each do |colname|
      hash1[colname] = ""
      hash1[colname] = row[colname] if row.key?(colname)
    end
    ret_hashes << hash1
  end
  ret_hashes
end
def a_tag(name,href,title ="") return '<a title="' + title + '" href="' + href + '" >' + name + '</a>' end

  def a_tag_bg(name,href,title ='') return '<a title="' + title + '" href="' + href + '" style="background:#f4f4ff;" >' + name + '</a>' end



def i_hidden(name,value) return '<input type="hidden" id="' + name + '" name="' + name + '" value="' + value + '">' end
def i_text(name,value,size=10) return '<input type="text" id="' + name + '" name="' + name + '" value="' + CGI.escapeHTML(value) + '" placeholder="' + name + '" size="' + size.to_s + '">' end
def i_checkbox(name,value) return '<label><input type="checkbox" id="' + name + '" name="' + name + '" value="1" ' + (value.to_s.length > 0 ? " checked " : "") + '>' + name + "</label>" end

def i_submit(name = "submit") return '<input type="submit" value="' + name + '">' end

def i_submit_trans(name = "submit") return '<input style="display:none;" type="submit" value="' + name + '">' end
def i_textarea(name,value,cols=120,rows=20) return '<textarea rows=' + rows.to_s + ' cols=' + cols.to_s + ' name="' + name + '">' + CGI.escapeHTML(value) + '</textarea>' end

def out_put(str)
  puts str
  out str + br
end

def out(str)
  unless str.is_a?(String)
    $out << sRedBG('not string ') + __FILE__.to_s + spc + __LINE__.to_s + spc + __method__.to_s + br
    $out << sRed(caller.first(3).join("<br/>"))
    return
  end
  str_out = str.dup.force_encoding('UTF-8') if str.encoding != 'UTF-8'
  return $out << str_out
end

def sBase(style,str) return '<span style="' << style << '">' << str << '</span>' end

def sBlack(str) return sBase('color:black;',str) end
def sWhite(str) return sBase('color:white;',str) end
def sSilver(str) return sBase('color:silver;',str) end
def sBlue(str) return sBase('color:blue;',str) end
def sGray(str) return sBase('color:gray;',str) end
def sRed(str) return sBase('color:red;',str) end
def sPink(str) return sBase('color:deeppink;',str) end
def sGreen(str) return sBase('color:green;',str) end
def sOrange(str) return sBase('color:darkorange;',str) end
def sPurple(str) return sBase('color:purple;',str) end

def s_v_margin(v_pixels)
  return '<div style="height:' + v_pixels.to_s + 'px;">&nbsp;</div>'
end

def sPinkBG(str) return sBase('color:deeppink; background:#fee;',str) end
def sRedBG(str) return sBase('color:red; background:#fee;',str) end
def sBlueBG(str) return sBase('color:blue; background:#eef;',str) end
def sOrangeBG(str) return sBase('color:darkorange; background:#fee;',str) end

def sRevRed(str) return sBase('color:white; background:red;',str) end
def sRevPink(str) return sBase('color:white; background:deeppink;',str) end
def sRevOrange(str) return sBase('color:white; background:darkorange;',str) end


def s120(str) return sBase('font-size:120%;',str) end
def s150(str) return sBase('font-size:150%;',str) end

def sBold(str) return sBase('color:#444; font-weight:bold;',str) end
def sBG(str) return sBase('color:#444;background:#eee;',str) end

def br() return "<br/>" end
def spc() return "&nbsp;" end
def spc2() return spc * 2 end
def spc3() return spc * 3 end
def nl() return "\n" end

def ajax(p)

    if p.key?("finderselect") && p['finderselect'].to_s.length > 0
        shell = 'open -R "' + URI.decode_www_form_component(p['finderselect']) + '"'
        out shell + br
        run_shell(shell)
      return true
    end
    if p['openhandbrake'].to_s.length > 0
        shell = 'open -a handbrake "' + URI.decode_www_form_component(p['openhandbrake']) + '"'
        out shell + br
        run_shell(shell)
      return true
    end
    if p['os_open'].to_s.length > 0
        shell = 'open "' + URI.decode_www_form_component(p['os_open']) + '"'
        out shell + br
        run_shell(shell)
      return true
    end
    return false
end

def run_shell(shell,trim_len = 30)
  ret = `#{shell} 2>&1 `
  out sSilver(shell.trim_spreadable(trim_len)) << spc << ret.split_nl.length.to_s if trim_len != NO_DISP
  ret
end

def array2hash(array,names_ary)
  ret = {}
  hash = names_ary.map.with_index { |name,i| ret[name]=array[i]  }
  ret
end


def date_str_to_jp_date(date_str)
  dt = DateTime.parse(date_str)
  dt_jst = dt.new_offset(Rational(9, 24))
  formatted_date = dt_jst.strftime("%Y-%m-%d %H:%M:%S")
end

def zero_silver(number)
  return sSilver(number.to_s) if number.to_s == '0'

  number.to_s

end


def menu(filename = "")
  filename = File.basename(filename).gsub(".rb","")

  html = ""
  files = `ls | egrep "\.rb" | egrep -v "(^\_|app)"`.split("\n")
  files.each do | fname|
    menu_name = fname.gsub(".rb","")
    disp = (filename == menu_name ? sRed(menu_name) : menu_name)
    html << '<a href="/dev/' << menu_name << '">' << disp << '</a> '
  end
  html << "<hr/>"
  html
end

def html_header(title)
    return '
    <html>
    <head>
        <meta http-equiv="content-language" content="ja" charset="UTF-8">
        <title>' << title << '</title>
        <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
        <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
        <style>

            body{color:#666;  font-family:sans-serif,helvetica; }
            hr{height:1px; background-color:#eee; text-decoration-style:none; }
            a:link{color:#1e90ff; text-decoration:none; }
            a:visited{color:#1e90ff; text-decoration:none; }
            a:hover{color:#1e90ff; text-decoration:none; opacity:0.6;}

            input::placeholder { color: #ccc; }

            table {border-collapse: collapse; margin-right:20px;}
            th {color:silver; text-align:left; font-weight:normal; padding-right:12px;}
            table.border td {border-bottom:1px solid silver;border-top:1px solid silver; padding-right:12px;}

            # divボックス親と子
            .flex-item {}
            .flex-container {display: flex; flex-wrap: wrap; vertical-align:top; }
            .detail{ background:#f6f6f6; border-radius:6px; padding:6px; }
        </style>
    </head>
    <body>'
end

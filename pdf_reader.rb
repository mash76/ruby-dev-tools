# imagemagick と

PDF_SQLITE_PATH = File.expand_path("files/pdf.sql3")
PDF_OUTPUT_PATH = './assets/pdf_pages'
PDF_DIR = '/Users/masatohori/Library/CloudStorage/Dropbox/scan'




def get_path_from_inode(inode)

    shell = 'find ' + PDF_DIR + ' -inum ' + inode.to_s
    ret = run_shell(shell).strip
    return ret
end

def main()

    p = $params

    db = SQLite3::Database.new PDF_SQLITE_PATH
    db.results_as_hash = true

    ret_ajax_bool = ajax(p)
    return if ret_ajax_bool # ajax実行したならそこで終了

    # PDFファイルの読み込み
    view = p[:view] || 'list'
    pdf_path = p[:path] || ''
    if view != 'list' && !p[:path]
        out sRed('no file path')
        return
    end

    pdf_ajax(p,db)

    out html_header("pdf reader")
    out '<script>' + File.read("_form_events.js") + '</script>'
    out menu __FILE__

    out sqlite3_info(PDF_SQLITE_PATH) + br

    # recent 最近使ったファイル
    recents = sqlite2hash("select * from pdf order by updated_at desc limit 15",db, false )

    out '<div id="recent_window"
    style="position:fixed; top:-8px; left: -8px; width:103%; height:103%;
            background-color: rgba(50, 50, 50, 0.6); display:none;">'

    out '<div id="recent" style="
                position:relative; top:20px;left:20px; width:93%;
                padding: 15px; background:#fff; border-radius:10px;
                opacity: 1;
                vertical-align:top;
    ">'

    out "<script>
            function toggleRecent(){
                $('#recent_window').toggle()
            }
            $(document).keydown((e) => {
                if (e.key == 'f') toggleRecent()
            })
        </script>"


    recents.each do |row|
        out a_tag(File.basename(row['file_name'].to_s), "?view=show&path=" + URI.encode_www_form_component(row['file_name'].to_s )) + spc + row['updated_at'].to_s + br
    end
    out '</div></div>'


    ['list'].each do | val |
        disp = (val == view) ? sRed(val) : val
        out a_tag(disp,'?view=' + val + '&path=' + URI.encode_www_form_component(pdf_path)) + spc
    end
    out br

    if view == 'list'
        v_list(p)
        return
    end

    out File.basename(pdf_path) + spc + a_tag('finder',"javascript:setFinderSelect('" + URI.encode_www_form_component(pdf_path) + "')")

    out (spc * 4)
    stat = File.stat(pdf_path)
    jpg_path = PDF_OUTPUT_PATH + '/' + stat.ino.to_s
    out jpg_path + spc + a_tag('finder',"javascript:setFinderSelect('" + URI.encode_www_form_component(jpg_path) + "')") + (spc * 4)

    pdf_size = stat.size
    pdf_size_str = (pdf_size / 1024.0 / 1024.0).round(2).to_s + sSilver('mb')
    out (pdf_size / 1024.0 / 1024.0).round(2).to_s + sSilver('mb') + br

    path = PDF_OUTPUT_PATH + '/' + stat.ino.to_s
    files = run_shell('find ' + PDF_OUTPUT_PATH + '/' + stat.ino.to_s + ' -type f | sort | grep thumb', NO_DISP)
    ary_thumb = files.split_nl
    #ary = ary.slice(0,15)
    thumb_size = 0
    ary_thumb.each { |val| thumb_size  += File.stat(val).size }

    real_size = 0
    files = run_shell('find ' + PDF_OUTPUT_PATH + '/' + stat.ino.to_s + ' -type f | sort | grep page',NO_DISP)
    ary_real = files.split_nl
    ary_real.each { |val| real_size += File.stat(val).size }

    out 'thumb ' + (thumb_size / 1024.0 / 1024.0).round(2).to_s + sSilver('mb') + spc
    out 'real size ' + (real_size / 1024.0 / 1024.0).round(2).to_s + sSilver('mb') + br


    ['convert','show','del'].each do | val |
        disp = (val == view) ? sRed(val) : val
        out a_tag(disp,'?view=' + val + '&path=' + URI.encode_www_form_component(pdf_path)) + spc
    end
    out br


    out '<div></div>'

    v_convert( pdf_path  ) if view == 'convert'
    v_show(p ,pdf_path,db,ary_thumb) if view == 'show'

    del(pdf_path) if view == 'del'
end

def v_list(p)

    limit_list = 500
    filter = p[:filter] || ''

    out '<form>'
    out i_hidden('view','list')
    out i_text('filter',filter)
    out i_submit_trans
    out '</form>'

    # ファイルリスト
    shell = 'find ' + PDF_DIR + ' -type f | grep -i pdf | sort '
    shell += ' | grep ' + filter if filter.length > 0
    shell += ' | head -' + limit_list.to_s
    pdfs = run_shell(shell)
    pdf_ary = pdfs.split("\n")
    out br
    pdf_ary.each do |line|
        out line.sub(PDF_DIR,'').gsub(filter,sRed(filter)) + spc
        out a_tag(sSilver('show') , '/dev/pdf_reader?view=show&path=' + URI.encode_www_form_component(line)) + spc

        # すでにdirがあれば
        ino = File.stat(line).ino
        if File.exist?(PDF_OUTPUT_PATH + '/' + ino.to_s)

            out sBlue('展開済')
        else
            out PDF_OUTPUT_PATH + '/' + ino.to_s
        end

        out br
    end

    # フォルダリスト
    out br + br
    shell = 'find ' + PDF_OUTPUT_PATH + '/* -type d'
    ret = run_shell(shell,NO_DISP)
    ary = ret.split("\n")
    ary.each do |line|
        out line + spc
        shell = 'find ' + line + ' -type f | wc -l'
        ret = run_shell(shell,NO_DISP)
        out "ret " + ret + br
    end
end

def v_show( p, pdf_path,db,ary_thumb)

    stat = File.stat(pdf_path)
    sqlite2hash("update pdf set view_count = view_count + 1 ,
            last_view_date='" + now_time_str + "',
            updated_at='" + now_time_str + "'
            where inode= " + stat.ino.to_s, db)
    info = sqlite2hash('select * from pdf where inode=' + stat.ino.to_s, db)
    json = '{}'
    json = info[0]['json'] if info.length > 0

    out File.read("pdf_reader.html")
    out '<script>
            const INO = ' +stat.ino.to_s + '
            const FILE_NAME = "' + pdf_path.rpartition('/').last + '"
            ST = ' + json + '

        </script>'





    reverse = p[:reverse] || ""
    out '<form id="f1" >'
    out i_hidden('view','show')
    out i_hidden('path',pdf_path)
    out a_tag("reverse" , "javascript:toggleReverse() ") + spc
    out a_tag("debug" , "javascript:toggleDebug() ")
    out i_submit_trans
    out '</form>'

    out '<div id="pages" class="flex-container"
            style="width:100%; " >'
    ary_thumb.each do |val|
        #out val + bx
        id = File.basename(val, ".jpg").sub('thumb_','')
        out '<div class="flex-item" id="page_div_' + id + '" >'
        out sSilver(id) + '<span type="page_label" id="page_label_' + id + '">' +  + '</span>' + br
        out '<img type="page" name="' + id + '"  id="' + id + '" width="200px"
            style="border:1px solid silver;  "
            src="' + val.sub('./assets','') + '"/>' + "\n"



        out '</div>'
    end
    out '</div>'

end

def v_convert(pdf_path )

    stat = File.stat(pdf_path)
    ino = stat.ino.to_s
    dir = PDF_OUTPUT_PATH + "/" + ino

    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

    density = 200
    max_page = 500

    threads = []
    out_put 'generate page jpg ' + br
    threads << Thread.new do
        out_put 'page start ' + now_time_str
        shell = 'magick -density ' + density.to_s + ' "' + pdf_path + '[0-' + max_page.to_s + ']" -alpha remove -background white -resize 1200 -quality 85 ' + dir + '/page_%03d.jpg'
        run_shell shell
        out br
        out_put  'page end ' + now_time_str
    end
    threads << Thread.new do
        shell = 'magick -density ' + density.to_s + ' "' + pdf_path + '[0-' + max_page.to_s + ']" -alpha remove -background white -resize 300 -quality 85 ' + dir + '/thumb_%03d.jpg'
        out_put 'thumb start ' + now_time_str
        run_shell shell
        out br
        out_put  'thumb end ' + now_time_str
    end
    threads.each(&:join)
end

def pdf_ajax(p,db)

    if p[:ajax] && p[:ajax] == 'save'
        puts 'save '
        ret = sqlite2hash('select * from pdf where inode=' + p[:ino],db)
        sql = ""
        if ret.length == 1
            sql = "update pdf set json='" + p[:json] + "', updated_at='" + now_time_str + "' where inode=" + p[:ino]

        else

            path = get_path_from_inode(p[:ino])
            sql = "insert into pdf (inode,file_name,json,created_at,updated_at) values(" + p[:ino] + ",'" + path + "','" + p[:json] + "','" + now_time_str + "','" + now_time_str + "') "
        end
        puts 'sql' + sql
        sqlite2hash(sql,db)
    end
end



main
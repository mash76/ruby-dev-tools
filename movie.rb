require "sqlite3"

# macのfsの文字コードは UTF-8-MAC  UTF-8でsqlite3に保存、ファイルパスを通常utf8ｎに変換
MOVIE_PATH = File.expand_path("../../movie")
SQLITE_PATH = File.expand_path("files/movie.sql3")
CACHE_KEY_NAME = 'movie_filename_count_cahce'

# パラメータがなければエラー
def p_requires(array)
    array.each do |key|
        unless $params.key?(key)
            out sRed("require paramss" + array.inspect)
            return false
        end
    end
    true
end

def p_exist?(key)
    $params.key?(key) && $params[key].is_a?(String) && $params[key].length > 0
end

def ajax_cout_update(db,inode)

    sql_update = "update movies
        set view_times = view_times +1,
        last_view_date = '" + now_time_str + "'
        where inode=" + inode.to_s
    sqlite2hash(sql_update,db)

    sql_select = "select * from movies where inode=" + inode.to_s
    row = sqlite2hash(sql_select,db)
    shell = 'open "' + MOVIE_PATH + row[0]['filepath'] + '"'
    puts shell
    run_shell(shell)
end

def main()

    # ----------------------------------------

    db = SQLite3::Database.new SQLITE_PATH
    db.results_as_hash = true

    # ajax ----------------------------------------

    if $params[:movie_open_inode].to_s.length > 0
        ajax_cout_update(db,$params[:movie_open_inode])
        return
    end

    # 画面描画 ----------------------------------------

    out html_header("movie")
    out '<script>' + File.read("_form_events.js") + '</script>'
    out menu(__FILE__)

    out sBG("movie path") + spc + sSilver(MOVIE_PATH) + br
    out sqlite3_info(SQLITE_PATH) + br

    p = {}
   # p_requires(["rate"])
    p_keys = [
        "mode","filter","rate","codec","exclude","go_insert","recheck_local","scan_meta",
        "mb_min","mb_max","run_update",
        "hours_back",
        "chapter_min","chapter_max","minutes_min","minutes_max",
        "framesize",
        "sort_col","sort_dir"]
    p_keys.each { |val| p[val] = "" } # 空白の値を入れる
    $params.each { |key,val| p[key] = val.to_s } # 空白の

    ret_ajax = ajax(p)
    return if ret_ajax


    # 画面制御
    mode = $params["mode"] || "list"
    go_insert = $params["go_insert"] || "" # 実際に実行 / なければdryrun

    # 検索パラメータ
    filter = $params["filter"] || ""
    codec = $params["codec"] || ""
    exclude = $params["exclude"] || ""
    rate = $params["rate"] || ""

    filter_mac = filter.to_s.encode("UTF-8-MAC", "UTF-8")
    stat = get_cache(db)

    menus = ["list","db_renew","db_import","db_stat","word_stat","chk_inode","chk_local","scan_meta"];
    menus.each do |m|
        disp = (m == mode ? sRed(m) : m)
        out a_tag(disp,'?mode=' + m) + spc
    end
    out br

    sql_stat = 'select is_local,count(*) files,round(sum(filesize) / 1024.0 / 1024.0 / 1024.0, 2) gb from movies
    group by is_local'
    ret = sqlite2hash(sql_stat,db)
    out hash2html(ret)
    out br + sBlueBG(mode) + br

    db_renew(db) if mode == "db_renew"
    v_db_import(db,go_insert) if mode == "db_import"
    v_db_stat(db) if mode == "db_stat"
    get_cache(db,true) if mode == "word_stat"
    v_chk_local(p,db) if mode == "chk_local"
    v_chk_inode(p,db) if mode == "chk_inode"
    v_scan_meta(p,db) if mode == "scan_meta"
    return unless mode == "list"


    # form
    out '<table class="border"><tr><td nowrap valign=top >'
    out filterList2HTML(wordList,stat)
    out "</td><td nowrap valign=top >"

    out '<form id="f1" >'
    out "filter " + i_text("filter",filter,40) + br
    out "rate " + i_text("rate",rate,15)

    rates = { "★" => "★","★★" => "★★","★★★" => "★★★","★★★★" => "★★★★","★★★★★" => "★★★★★","xxx" => "xxx" }
    rates.each do |key,val|
        out a_tag(key, "javascript:$('#exclude').val('#{val}★'); setVal('rate','#{val}')" ) + spc
    end
    out br + "exclude " + i_text("exclude", p["exclude"],15) + br
    out "is_local " + i_text("is_local", p["is_local"].to_s, 10) + spc
    ["local","cloud"].each do |val|
        out a_tag(val, "javascript:setVal('is_local','#{val}')" ) + spc
    end
    out br + i_checkbox("recheck_local","")

    out i_submit_trans
    out '</form>'

    # 一覧
    sql = "SELECT
            '' sel,
            is_local,minutes min,view_times view, last_view_date last_v,
            filepath,v_codec codec,width || 'x' || height fr_size ,filesize_mb mb, v_bit_rate /1024 v_rate,chapters chap,
            is_local_checked,meta_scan_date,'' sand,'' brake,
            fps, a_codec, ctime,mtime,atime,created,inode
        FROM movies  "
    where = []
    if filter.length > 0
        filters = filter.split(/\s+/)
        filters.map { |f| where << " filepath like '%" + f + "%'"  }
    end

    # where 構築
    where << " filepath like '%" + rate + "%'" if rate.length > 0
    where << " filepath not like '%" + exclude + "%'" if exclude.length > 0
    where << " is_local = '" + p["is_local"].to_s + "'" if  p["is_local"].to_s.length > 0
    sql += " where " + where.join(' and ') if where.length > 0
    sql += " ORDER BY filepath DESC LIMIT 1000"
    sql3_records = sqlite2hash(sql,db)

    if p["recheck_local"].length > 0
        recs_ = sqlite2hash(sql,db)
        check_local_and_insert(sql3_records,db)
    end

    # 結果表示
    no_file_ct = 0;
    sql3_records.each do |row|
        path = row['filepath']

        path_trim = truncate_by_width(row['filepath'],80) #ファイル名trim

        # パスとファイル名に分解して色マークして合体
        path_disp = path_trim
        matches = path_trim.scan(/.*\//)
        path = matches[0]
        fname = path_trim.slice(path.length,2000)
        # 検索ワード色つけ spc区切りで複数
        if p_exist?("filter")
            filters = filter.split(/\s+/)
            filters.each do |f|
                pattern = Regexp.new("(" + Regexp.escape(f) + ")",Regexp::IGNORECASE)
                path = path.gsub(pattern,sRed('\1'))
                fname = fname.gsub(pattern,sRed('\1'))
            end
        end
        path_disp = sOrange(path) + fname

        full_path = MOVIE_PATH + row['filepath']

        exist_str = ""
        exist_str = sRed("no-file ") unless File.exist?(full_path)
        row['view'] = zero_silver(row['view'])
        row['sel'] = a_tag(sSilver("sel"),"javascript:setFinderSelect('" + URI.encode_www_form_component(full_path) + "')")
        row['sand'] = a_tag(sSilver("sand"),"ffprobe.php?filepath=" + URI.encode_www_form_component(full_path))
        row['filepath'] = a_tag(path_disp, "javascript:movieOpenAndCountUp('" + row['inode'].to_s + "')" )
        row['is_local'] = sSilver(row['is_local']) if row['is_local'] == "local"
        # handbrake実験
        row['brake'] = a_tag(sSilver("brake"),"javascript:openWithHandbrake('"  +  URI.encode_www_form_component(full_path)  +  "')")
        unless File.exist?(full_path)
            row['filepath'] = sRevRed('no file') + ' ' + row['filepath']
            no_file_ct += 1
        end

        # atime = row['atime']
        # ctime = row['ctime']
        # mtime = row['mtime']
        # var_dump(atime)
        # row['atime'] = date('Y-m-d',atime)
        # row['ctime'] = date('Y-m-d H:i:s',ctime)
        # row['mtime'] = date('Y-m-d',mtime)
        # if (time() - atime < 86400 ) row['atime'] = sBlueBG(row['atime'])
        # if (time() - ctime < 86400 ) row['ctime'] = sBlueBG(row['ctime'])
        # if (time() - mtime < 86400 ) row['mtime'] = sBlueBG(row['mtime'])
    end

    out hash2html(sql3_records,"t_hover") + br
    out br

    out "</td></tr></table>"
end

def parse_json_stream(json)
    rec1 = {}
    rec1['streams'] = json['streams'].length.to_s
    out "stream項目数" + spc + json['streams'].length.to_s + br

    json['streams'].each do | row|
        # if (!isset($codecs[row['codec_type']])) $codecs[row['codec_type']] = []
        # if (!isset($codecs[row['codec_type']][row['codec_name']])) $codecs[row['codec_type']][row['codec_name']] = 0
        # $codecs[row['codec_type']][row['codec_name']] += 1

        if row['codec_type'] == "video"

            rec1['meta_scan_date'] = now_time_str
            rec1['v_codec'] = row['codec_name']
            rec1['v_tag'] = row['codec_tag_string']
            rec1['width'] = row['width']
            rec1['height'] = row['height']
            rec1['fps'] = row['r_frame_rate']
            rec1['duration'] = row['duration']
            rec1['minutes'] = (row['duration'].to_i / 60).round(0)
            rec1['v_bit_rate'] = row['bit_rate']
        end
        if row['codec_type'] == "audio"
            rec1['a_codec'] = row['codec_name']
            rec1['channels'] = row['channels']
            rec1['channel_layout'] = row['channel_layout']
            rec1['sample_rate'] = row['sample_rate']
            rec1['a_tag'] = row['codec_tag_string']
            rec1['a_bit_rate'] = row['bit_rate']
        end
    end
    out rec1.inspect
    rec1
end

def v_scan_meta(p,db)

    scan_limit = 1000

    out sBlue("localのファイルをffprobeでscanして" + scan_limit.to_s + "件更新します") + br
    files = sqlite2hash("select * from movies where is_local='local' and meta_scan_date is NULL limit " + scan_limit.to_s,db)
    out br
    ct = 0
    files.each do |row|
        ct += 1
        out ct.to_s + spc + row["filepath"] + br

        # ffprobe scan
        json_s = ffprobe_streams(MOVIE_PATH + row["filepath"])
        if json_s == false
            out "change to cloud " + row["filepath"] + br
            next
        end
        out spc + sOrange(json_s.to_s) + br
        upd_row = parse_json_stream(json_s)

        json_c = ffprobe_chapters(MOVIE_PATH + row["filepath"])
        upd_row['chapters'] = json_c['chapters'].length.to_s
        upd_row['meta_scan_date'] = now_time_str

        sql3_update_movie(row["inode"],upd_row,db) ###
        # update
    end
    out ct.to_s + " meta updates "
end



# inodeなどの変化をチェック まずdbからチェックしてinodeを直す
def v_chk_inode(p,db)

    # DBからファイルを検索
    out sBlue("sqlite3の動画ファイル管理データ(moviesテーブル)整合性チェック") + spc + sSilver('inode番号 filepath ctime mtime atime') + br
    sql = "select * from movies"
    sql3_files = sqlite2hash(sql,db)
    out br
    ct = 0
    ct_ok = 0
    ct_nofile = 0
    no_realfile_inodes = []
    mtime_diffs = []
    ctime_diffs = []
    atime_diffs = []
    sql3_files.each do |row|
        ct += 1
        fpath = MOVIE_PATH + row["filepath"]
        if File.exist?(fpath)
            ct_ok += 1
            if File.stat(fpath).ino == row["inode"]
                stat = File.stat(fpath)
                if stat.mtime.to_i != Time.parse(row["mtime"]).to_i
                    out sBlue('更新日違い ') + row["filepath"] + sBlue(row["mtime"]) + spc + stat.mtime.to_s + br
                    mtime_diffs << row["inode"]
                    update_edit_time(row["inode"],row["filepath"],db)
                    out br
                end
                if stat.atime.to_i != Time.parse(row["atime"]).to_i
                    out 'アクセス日違い ' + row["filepath"] + sBlue(row["atime"]) + spc + stat.atime.to_s + br
                    atime_diffs << row["inode"]
                    update_edit_time(row["inode"],row["filepath"],db)
                    out br
                end
                if stat.ctime.to_i != Time.parse(row["ctime"]).to_i
                    out sOrange('作成日日違い ') + row["filepath"] + sBlue(row["ctime"]) + spc + stat.ctime.to_s + br
                    ctime_diffs << row["inode"]
                    update_edit_time(row["inode"],row["filepath"],db)
                    out br
                end
            else
                # out br + sRed("inode num changed")
            end
        else
            # ファイルなし  inodeが存在するか(?)
            ct_nofile += 1
            no_realfile_inodes << row["inode"]
            out ct.to_s << sRed(" no-file(filename changed or deleted) ") << fpath.sub(MOVIE_PATH,'') << spc

            # inodeが保たれたままか確認
            shell = '  find ' + MOVIE_PATH + ' -inum ' + row['inode'].to_s
            ret = run_shell(shell)
            out br
            if ret.length > 0
                out (spc * 4) + '同じinode番号' + sBlue(row['inode'].to_s) + 'で発見(ファイル名変更) ' + sBlue(ret.sub(MOVIE_PATH,'')) + br

                # ファイル名更新
                sql_upd = "update movies set filepath='" + ret.sub(MOVIE_PATH,'').encode("UTF-8","UTF-8-MAC").strip + "' where inode=" + row['inode'].to_s
                sqlite2hash(sql_upd,db)
                out br
            else
                out (spc * 4) + 'inode番号' + row['inode'].to_s + 'で発見できず(削除？)' + br
                sql_upd = "delete from movies where inode=" + row['inode'].to_s
                sqlite2hash(sql_upd,db)
                out br
            end
        end
    end

    # 分析結果
    out "<hr/>"
    out 'サマリー' + br
    out "1.SQLite行をベースに検証" + br
    out "実ファイル名ok " + ct_ok.to_s + " no-real-file " + no_realfile_inodes.length.to_s + br
    out  " ctime違い " + ctime_diffs.length.to_s + br
    out  " mtime違い " + mtime_diffs.length.to_s + br
    out  " atime違い " + atime_diffs.length.to_s + br

    # 更新指定あれば更新
    if p["run_update"].length > 0
        out sRed("delete") + spc
        out "実ファイルのないdb列 " + no_realfile_inodes.length.to_s + sSilver("件 ") + br
        no_realfile_inodes.each do |inode|
            sqlite2hash("delete from movies where inode=" + inode.to_s,db)
        end
    else
        out sRed(no_realfile_inodes.length.to_s + " 件のdb行削除せず") + br
    end

    # 実ファイルでsqlite取り込み前のものを取り込み
    out br + sBG("2.実ファイルをベースに対応する行がsqliteテーブルにあるか？(filepathで判定") + br
    out sBlue("実ファイル一覧") + spc
    shell = "find " + MOVIE_PATH + " -type f | grep -v DS_Store | grep -v txt | grep -v .localized"
    files = run_shell(shell).split_nl
    out br + sBlue("dbにあるか確認") + br
    ct_db_exist = 0
    ct_db_noexist = 0
    files.each do |line|
        line2 = line.gsub(MOVIE_PATH,"")
        line3 =line2.gsub("'", "''")
        line3 = line3.encode("UTF-8","UTF-8-MAC")
        ret = sqlite2hash("select * from movies where filepath='" + line3 + "'",db,false)
        if ret.length == 1
            ct_db_exist += 1
        #    out sBlue("exist_on_sqlite")
        else
            ct_db_noexist += 1
            out sRed("no-db ") + line.sub(MOVIE_PATH,'') + br
            #insert
            row = get_movie_info_from_path(line2)
            out sSilver(row.inspect) + br
            if p["run_update"].length > 0
                out sRed("insert") + spc
                sql3_insert_movie(row,db)
            end
        end
    end
    out "dbにあったfile数 " + ct_db_exist.to_s + " なかったfile数 " + ct_db_noexist.to_s + br + br
    out a_tag("rewrite実行","?mode=chk_inode&run_update=true") + br

end

# ローカル環境
def v_chk_local(p,db)

    #sqlite2hash("update movies set is_local = null,is_local_checked = null",db)

    #今のdbないの一覧
    out sBG("1.dbのlocal/cloud確認時間統計") + br
    sql_stat = "
    SELECT SUBSTR(is_local_checked, 1, 16) AS prefix, COUNT(*)
    FROM movies GROUP BY prefix "
    sql3_files = sqlite2hash(sql_stat,db)
    out hash2html(sql3_files) + br

    # dbから一覧
    sql = 'select * from movies'
    now = Time.now
    hours_back = p['hours_back'].to_f
    hours_back = 500 if p['hours_back'] == ''
    target = now - (hours_back * 3600.0).to_i
    target_str = target.strftime("%Y-%m-%d %H:%M:%S")

    out sBG("2.n時間以上前に確認したデータを再確認&更新") + br
    hour_ary = ['0.01','0.05','0.1','0.3','0.5','0.8','1','2','5','7',
        '10','15','20','30','50','100','200','500','5000','50000','500000']
    hour_ary.each do |h|
        disp = (h == hours_back ? sRed(h) : h)
        out a_tag(disp, '?mode=chk_local&hours_back=' + h.to_s) + spc
    end

    out br + 'is_local_checked 確認が' + spc + sBG(hours_back.to_s) + spc + '時間以上前の row をリストに' + br

    sql += " where is_local_checked is null or is_local_checked < '" + target_str + "'"
    sql3_files = sqlite2hash(sql,db)
    out br

    check_local_and_insert(sql3_files,db)
end


def v_db_stat(db)

    out sBlue("最古 ")
    ret = sqlite2hash("select * from movies order by created asc limit 5 ",db)
    out hash2html(ret)
    out sBlue("最新 ")
    ret = sqlite2hash("select * from movies order by created desc limit 5",db)
    out hash2html(ret)
    out sBlue("local/cloud ")
    ret = sqlite2hash("select is_local,count(*) ct,sum(filesize) / 1024 / 1024 / 1024 gb from movies group by is_local",db)
    out hash2html(ret)
    out sBlue("ext not mp4 ")
    ret = sqlite2hash("select count(*) ct from movies where filepath not like '%mp4%' ",db)
    out hash2html(ret)
    ret = sqlite2hash("select v_codec,count(*) ct from movies group by v_codec",db)
    out hash2html(ret)
    ret = sqlite2hash("select height,count(*) ct from movies group by height",db)
    out hash2html(ret)

end


def v_db_import(db, go_insert)

    #  ゼロから全件インポート

    #  ファイル一覧
    shell = "find " + MOVIE_PATH + " -type f | grep -v DS_Store | grep -v txt | grep -v .localized"
    files = run_shell(shell).strip.split_nl
    out br
    real_filenames = []
    files.map { |line| real_filenames << line.gsub(MOVIE_PATH,"").strip }
    #out real_filenames.keys.join("<br/>")

    #  sqliteの行一覧
    records = sqlite2hash("select filepath,mtime,ctime from movies ",db)
    db_fileinfos = {}
    records.each do |row|
        if (row['mtime'] == "")
            exit(sRed('SQLite3 records mtime null ') + row['filepath'] + br )
        end
        db_fileinfos[row['filepath']] = row
    end

    # echo sBlue('<hr/>SQLiteと実ファイル差分<br/>')

    # #  sqliteにないファイル
    # $nodb_files = []
    # $mtime_change_files = []
    # foreach ($real_filenames as $line => $val){
    #     $full_path = $MOVIE_PATH . $line;
    #     $exists = true;
    #     if (!file_exists($full_path)) {
    #         $exists = false;
    #     #   echo sRed('file not exist ') . $full_path . BR;
    #     }else{
    #     #  echo sBlue('file exist ') . $full_path . BR;
    #     }
    #     if (!isset($db_fileinfos[$line])) {
    #         $nodb_files[$line] = "";
    #     }else{
    #         # sqliteに存在するが更新日が違う(db登録後に更新)

    #         $file_stat = stat($full_path);
    #         $sql3_mtime = $db_fileinfos[$line]['mtime'];
    #         $file_mtime_str = date('Y-m-d H:i:s',$file_stat['mtime']);
    #         $sql3_mtime_str = date('Y-m-d H:i:s',$sql3_mtime);

    #         if ($file_stat['mtime'] != $sql3_mtime ){
    #             $mtime_change_files[] = ["path" => jsTrimNoEnc($line,100),'sql3_mtime' =>$sql3_mtime_str,
    #                                 'file_mtime' => $file_mtime_str,
    #                                 'diff_days' => round(($file_stat['mtime'] - $sql3_mtime) / 86400, 1) ];
    #         }
    #     }
    # }
    # $dbonly_files = [];
    # foreach ($db_fileinfos as $line => $val){
    #     if (!isset($real_filenames[$line])) $dbonly_files[$line] = "";
    # }

    # echo "no-db files " . sNonZeroAlert(count($nodb_files)) . "<br/>";
    # if ($nodb_files) echo jsTrimNoEnc(implode('<br/>', array_keys($nodb_files))) . "<br/>";
    # echo "db-only records " . sNonZeroAlert(count($dbonly_files)) . "<br/>";
    # if ($dbonly_files) echo jsTrimNoEnc(implode('<br/>', array_keys($dbonly_files))) . "<br/>";
    # echo 'DB登録以降に更新 '  . sNonZeroAlert(count($mtime_change_files)) . "<br/>";
    # if ($mtime_change_files) echo asc2html($mtime_change_files,false,false) . "<br/>";
    # ?>
    # <hr/>
    # <a href="?mode=db_import&go_insert=true">以上を更新</a><br/>


    # $dBoxOnlyCt = 0;
    ct = 0
    # real_filenames.each do |line|
    #      ct += 1
    #      out $ct . spc;
    #      $shell = 'xattr -l "' . str_replace('"','\"',$fname) . '" | grep com.dropbox.attr';
    #      $ret = runShell($shell);
    #      if (trim($ret)) $dBoxOnlyCt++;
    # end
    #out "dbonly " . $dBoxOnlyCt . BR;

    #  実行なら(checkでないなら)
   # if go_insert
        #foreach ($nodb_files as $line => $val){
        ct = 0
        real_filenames.each do |line|
            ct += 1
           # next if ct >10
            row = get_movie_info_from_path(line)
            out br + row.inspect
            sql3_insert_movie(row,db)
        end
        # foreach ($dbonly_files as $line => $val){
        #     sqlExec("delete from movies where filepath='".SQLite3::escapeString($line)."'",db);
        # }
  #  end
  return
end

def sql3_insert_movie(row,db) # row = hash

    cols = row.keys.join(",")
    row.each { |key,val| row[key] = val.to_s.gsub("'", "''") }
    vals = "'" + row.values.join("','") +  "'"
    sql = "insert into movies (" + cols + ") values(" +  vals  + ")"
    sqlite2hash(sql,db);
end

def sql3_update_movie(inode,row,db) # row = hash

    cols = row.keys.join(",")
    upd_vals = []
    row.each do |key,val|
        upd_vals << key + "='" + val.to_s.gsub("'", "''") + "'"
    end
    sql = "update movies set " + upd_vals.join(",") + " where inode=" + inode.to_s
    out br + sql + br
    sqlite2hash(sql,db)
end

def check_local_and_insert(rows,db)

    out br + sBlue('start local check') + br

    max_check_files = 50
    max_queues = 10 #並行処理max
    # 存在チェック bropboxをoffにしてtimeout1秒でffprobeを試す
    threads = []
    queue = Queue.new
    movies_ary = Concurrent::Array.new
    ct = Concurrent::Hash.new
    [:all,:check,:timeout,:cloud,:local].each { |val|  ct[val] = Concurrent::AtomicFixnum.new(0) }

    all_start = Time.now
    rows.each do |row|
        ct[:all].increment
        next if ct[:all].value > max_check_files +1
        # queueの数が減るまでsleep
        while queue.size >= max_queues
            out sPink('wait ')
            sleep 0.1
        end
        queue.push(1)
        # local判定

        threads << Thread.new(row) do |row|
            full_path = MOVIE_PATH + row['filepath']
            begin
                Timeout.timeout(2) do  # 5秒のタイムアウトを設定
                    shell_ffprobe = 'ffprobe -v error -print_format json -show_chapters "' + full_path + '"'
                    start = Time.now
                    strat_str = start.strftime('%Y-%m-%d %H:%M:%S')
                    ct[:check].increment
                    ct_check = ct[:check].value
                    output = run_shell(shell_ffprobe)
                    end_time = Time.now
                    str_time = sPink("q#{queue.size} ") + strat_str + spc + (end_time - start).round(2).to_s + spc
                    #outputが30文字以下ならエラー

                    if output.include?("Operation timed out")  #  Invalid data found when processing input
                        ct[:cloud].increment
                        out br +  ct_check.to_s + sRed(" cloud ") + str_time + output.trim_spreadable(40) + spc + row["filepath"]
                        local_state = 'cloud'
                    else
                        ct[:local].increment
                        out br + ct_check.to_s + sBlue(" local ") + str_time + output.trim_spreadable(40) + row["filepath"]
                        local_state = 'local'
                    end
                    sqlite2hash("update movies set is_local='" + local_state + "',	is_local_checked='" + strat_str + "' where inode=" + row["inode"].to_s,db)
                    out a_tag(sSilver(" sel "),"javascript:setFinderSelect('"  +  URI.encode_www_form_component(full_path)  +  "')")
                    out output.trim_spreadable(30)
                    out br
                end
            rescue Timeout::Error
                ct[:timeout].increment
                out br + ct[:all].value.to_s + sRed('timeout') + spc + row["filepath"]
                out a_tag(sSilver(" sel "),"javascript:setFinderSelect('"  +  URI.encode_www_form_component(full_path)  +  "')")

            end
           # out br
            queue.pop
        end

    end
    threads.each(&:join)
    out '<hr/>' + ct.inspect + br
    out ' time ' + (Time.now - all_start).round(2).to_s
end

def get_movie_info_from_path(os_path)
    full_path = MOVIE_PATH + os_path
    if !File.exist?(full_path)
        out 'no file ' + sRed(full_path) + br
    end
    stat = File.stat(full_path.encode("UTF-8-MAC","UTF-8"));

    rec1 = {
        "inode" => stat.ino,
        "filepath" => os_path.encode("UTF-8","UTF-8-MAC"),
        "streams" => "",
        "chapters"=>"" ,
        "v_codec" =>"",
        "v_tag" => "",
        "width" => "",
        "height" => "",
        "fps" => "",
        "duration" => "",
        "minutes" => "",
        "v_bit_rate" => "",
        "a_codec" => "",
        "a_tag" => "",
        "sample_rate" => "",
        "channels" => "",
        "channel_layout" => "",
        "a_bit_rate" => "",
        "filesize" => stat.size,
        "filesize_mb" => (stat.size / 1024.0 /1024.0 ).round(1),
        "ctime" => stat.ctime,
        "mtime" => stat.mtime,
        "atime" => stat.atime,
        "created" => now_time_str
    }
end

def get_cache(db,force_recreate = false)

    stat = {}
    # データがあるか矯正更新でなければ
    out  sOrange("get cache sqlite") + spc
    sql = "select * from key_values where key='" + CACHE_KEY_NAME + "'"
    ret = sqlite2hash(sql,db)
    out br
    if ret.length == 1 && force_recreate == false
        stat = JSON.parse(ret[0]['value'])
    else

        out sBG("recreate force?") + spc + force_recreate.to_s + br
        start = Time.now
        out sBG("genetrate cache") + spc + br
        #hash作成 text保存
        words_flat = flatten_hashes(wordList)
        out words_flat.length.to_s + sSilver("words ") + br
        words_flat.each do |key_utf8,val|
            key_utf8s = key_utf8.split(/\s+/)
            out key_utf8 + spc + key_utf8s.inspect + spc
            utf8s = key_utf8s.map { |k| " filepath like '%" + k + "%' " }
            ret = sqlite2hash("select count(*) ct from movies where " + utf8s.join(" and "),db)
            stat[key_utf8] = ret[0]['ct']
            out spc + stat[key_utf8].to_s + sSilver('hit ') + br
        end

        ret = sqlite2hash("delete from key_values where key='" + CACHE_KEY_NAME + "'",db)
        out br
        sql = "insert into key_values (key,value) values('" + CACHE_KEY_NAME + "','" + stat.to_json + "')"
        out sOrange("cache write sqlite") + spc
        sqlite2hash(sql,db)
        out (Time.now - start).round(2).to_s + sSilver(" sec") + br
    end
    stat
end

# 二重カテゴリのあるhasを一つのhashに
def flatten_hashes(words)
    hash = {}
    words.each do |cate_name,hashes|
        hashes.each do |row|
            row.each do |key,vals|
                 vals.each { |val| hash[val.to_s] = "" }
            end
        end
    end
    hash
end

def filterList2HTML(words,stat)
    ret = ""
    words.each do |cate_name,hashes|
        ret << br + sBlueBG(cate_name)
        hashes.each do |row|
            row.each do |key,vals|
                 ret << br + key.to_s + spc
                 vals.each do |val|
                    ct = ""
                    ct = stat[val.to_s].to_s
                    ret << a_tag(val.to_s,"?filter=" + URI.encode_www_form_component(val.to_s)) + ct + spc
                 end
            end
        end
    end
    return ret
end

def update_edit_time(inode,filepath,db)

    stat = File.stat(MOVIE_PATH + filepath.encode("UTF-8-MAC","UTF-8"))
    sql_upd_time = "update movies set ctime='" + stat.ctime.strftime('%Y-%m-%d %H:%M:%S') + "',atime='" + stat.atime.strftime('%Y-%m-%d %H:%M:%S') + "',mtime='" + stat.mtime.strftime('%Y-%m-%d %H:%M:%S') + "' where inode=" + inode.to_s
    sqlite2hash(sql_upd_time,db)
end

def db_renew(db)

    sqlite2hash("drop table key_values",db)
    sqlite2hash('
        CREATE TABLE "key_values" (
            "key"	TEXT NOT NULL UNIQUE,
            "value"	TEXT
        ); ',db)

    sqlite2hash("drop table movies",db)
    sqlite2hash('
        CREATE TABLE "movies" (
            "inode"	INTEGER PRIMARY KEY,
            "filepath"	TEXT,
            "is_local" TEXT,
            "is_local_checked" TEXT,
            "meta_scan_date" TEXT,
            "streams"	INTEGER,
            "chapters"	INTEGER,
            "v_codec"	TEXT,
            "v_tag"	INTEGER,
            "width"	INTEGER,
            "height"	INTEGER,
            "fps"	TEXT,
            "duration"	REAL,
            "minutes"	INTEGER,
            "v_bit_rate"	INTEGER,
            "a_codec"	TEXT,
            "a_tag"	TEXT,
            "sample_rate"	INTEGER,
            "channels"	INTEGER,
            "channel_layout"	TEXT,
            "a_bit_rate"	INTEGER,
            "filesize"	INTEGER,
            "filesize_mb"	INTEGER,
            "ctime"	INTEGER,
            "mtime"	INTEGER,
            "atime"	INTEGER,
            "created"	TEXT
        ) ',db)

    sqlite2hash('CREATE UNIQUE INDEX "movies_filename_unique" ON "movies" ( "filepath" ASC )',db)
    sqlite2hash("delete from movies",db)
end

def wordList

    words = {}
    words['特筆'] = [
        "0" => ["★","★★","★★★","★★★★","★★★★★","ビリーズ"],
        "1" => ["トラック","男は","伊丹","あまちゃん","リーガル","孤独のグルメ","evangerion","gundam"],
        "2" => ["風間","弥生","今井","ero 中森","松本メイ","まな","ソファ","拘束","あいか","オーロラ","赤瀬","SILK"],
        "3" => ["堀江","箕輪"]
    ];
    words['鉄道'] = [
        "地域" => ["首都圏","鉄道 西","鉄道 北"],
            "鉄道会社" => ["メトロ","都営","西武","東急","JR"],
            "出版会社" => ["vicom","anec"],
            "電車タイプ" => ["特急","新幹線","普通","急行","バス","モノレール"],
            "タイプ" => ["道路","飛行機","鉄道"],
        ];
    words['日本映画'] = [
        "タグ" => ["やり直し","切れ","字幕なし"],
        "シリーズ" => ["渡り鳥","社長","若大将","サラリーマン"],
        "シリーズ2" => ["男はつらいよ","トラック","釣り"],
        "シリーズ3" => ["仁義なき","悪名","不良番長"],

        "監6070" => ["山本晋也","岡本喜八","今村","鈴木則文","市川崑","神代","黒澤"],
        "監8090 " => ["伊丹十三","滝田","根岸"],
    ];
    words['海外映画'] = [
        "シリーズ" => ["スタローン","シュワ","ジャッキー"],
        "監督1" => ["ウディ アレン","バーホーベン","コーエン","ジョン ウー"],
        "監督2" => ["スピルバーグ","ルーカス"],
    ];
    words['ERO'] = [
            "ero" => ["ero","村西","押し付け","ソファ",],
            "体つき" => ["ムチムチ","むっちり","巨乳","肉感", "乳"],
            "ジャンル0" => ["ギャル","熟女","地味","地方","CG","3P","4P"],
            "ジャンル" => ["OL","教師","拘束","淫語","NTR","ナース",],
            "ジャンル2" => ["緊縛","拘束",],

            "label" => ["bazooka","KMP","S級素人"],
            "熟女" => ["織田真子","西條るり","中森玲子","風間ゆみ"],
            "熟女2" => ["はるか悠","赤瀬尚子","川上ゆう","望月かな"],
            "ギャル" => ["今井夏帆","花木あのん","伊波弥生","さとう遥希","仲村ろみひ"],
            "ギャル2" => ["松本メイ","桜庭ひかり","月野りさ","西村アキホ",],
            "ギャル3" => ["諸星セイラ","千野美帆","あやみ旬果"],

            "黒ギャル" => ["愛実","桜りお","RUMIKA","JULIA"],
            "2000年代" => ["彩名杏子","夏目ナナ"],
            "ムチ1" => ["澤井芽衣",],
            "ムチ2" => ["松本菜々実","篠崎かんな",],
            "ムチ美女" => [ "小沢アリス","佐山愛","神崎詩織","成瀬心美",],
            "女優" => ["深田えいみ","尾上若葉","三上悠亜","紗倉まな","あいの詩"],
            "ロリ" => ["ゆうきせり","つぼみ",],
            "美人系" => ["寿ゆかり","椎名ゆな","明日花キララ","立花理子","藤井シェリー",],
        ];
    words['音楽'] = [
            "音楽1" => ["PSY"],
            "音楽" => ["reggae","motown","パンク","carpenters","woodstock",],
            "個人" => ["sting","santana","queen","jimi hendrix"],
            "音楽R&B" => ["rihanna","R Kelly","janet","michael","madonna"],
            "日本" => ["鈴木雅之","aska","竹内まりや","萩原健一","松田聖子"],
            "日本2" => ["もんた","ゴールデンカップス","fishmans"],
        ];
    words['ほか'] = [
            "CM" => ["ジェミニ","CM","タンスにゴン","カップヌードル","ネスカフェ"],
            "ドキュメント" => ["document"],
            "フィットネス" => ["BILLY"],
        ];
    words['アニメ'] = [
            "アニメ" => ["粘土","snoopy","moomin","anime"],
            "Pixar" => ["toy","finding","incredible","レミー","カール","walle"],
            "Illumination" => ["Illumination","sing","怪盗","ミニオン"],
            "アードマン" => ["Aardman","chicken run","ウォレス","ショーン"],
            "cartoon" => ["トムとジェリー"],
            "日本" => ["eva","gundam","cowboy bebop","lupin"],
        ];
    words['ドラマ日本'] = [
            "刑事探偵" => ["あぶない刑事","警視K","踊る大捜査線"],
            "ホーム" => ["おしん","渡る世間"],
            "60-70" => ["ガードマン","大都会","傷だらけ"],
            "クドカン" => ["マンハッタン","リーガル","タイガー","あまちゃん"],
            "ドラマ " => ["ふぞろい","岸辺","派遣","最高の離婚","リーガルV","結婚できない男"],
            "君塚良一" => ["ナニワ金融道","踊る大捜査線"],
            "時代劇" => ["仕事人","暴れん坊将軍"],
        ];
    words['ドラマ海外'] = [
            "女子" => ["satc","奥様は魔女","mylove"],
            "コメディ" => ["friends","Dharma Greg","ダーマとグレッグ","Different Strokes","monty python"],
            "男" => [ "Knight Rider","Miami Vice","west wing"],
            "刑事" => ["コロンボ","ポアロ"],
            "スパイ" => ["スパイ大作戦"],
            "SF" => [ "ビジター","DarkAngel","star gate","twilight zone"],
            "SF2" => [ "レッドドワーフ","宇宙大作戦"],
        ];
    return words
end

main



# CREATE TABLE "movies" (
# 	"inode"	INTEGER,
# 	"filepath"	TEXT,
# 	"is_local"	TEXT,
# 	"is_local_checked"	TEXT,
# 	"meta_scan_date"	TEXT,
# 	"streams"	INTEGER,
# 	"chapters"	INTEGER,
# 	"v_codec"	TEXT,
# 	"v_tag"	INTEGER,
# 	"width"	INTEGER,
# 	"height"	INTEGER,
# 	"fps"	TEXT,
# 	"duration"	REAL,
# 	"minutes"	INTEGER,
# 	"v_bit_rate"	INTEGER,
# 	"a_codec"	TEXT,
# 	"a_tag"	TEXT,
# 	"sample_rate"	INTEGER,
# 	"channels"	INTEGER,
# 	"channel_layout"	TEXT,
# 	"a_bit_rate"	INTEGER,
# 	"filesize"	INTEGER,
# 	"filesize_mb"	INTEGER,
# 	"ctime"	INTEGER,
# 	"mtime"	INTEGER,
# 	"atime"	INTEGER,
# 	"view_times"	INTEGER NOT NULL DEFAULT 0,
# 	"last_view_date"	TEXT,
# 	"created"	TEXT,
# 	PRIMARY KEY("inode")
# )
# CREATE TABLE "key_values" (
# 	"key"	TEXT NOT NULL UNIQUE,
# 	"value"	TEXT
# )
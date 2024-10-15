
def main
	p = $params

	out html_header("sqlite")
    out '<script>' + File.read("_form_events.js") + '</script>'
	out menu(__FILE__)

	# ----------------------------------------
	sqlite_path = p[:sqlite_path].to_s
	table = p[:table].to_s
	view = p[:view] || "db_list"

	# ナビ
	# ["import","list","db"].each do | view_name |
	# 	disp = view_name
	# 	disp = sRed(disp) if disp == view
	# 	out a_tag disp + spc,"/dev/sqlite?view=" + view_name
	# end
	# out br

    # ファイル一覧
    if view == "db_list"
        v_db_list()
        return
    end

	db = SQLite3::Database.new sqlite_path
	db.results_as_hash = true

    out a_tag(sBlueBG(sqlite_path),"?sqlite_path=" + sqlite_path + '&view=db') + br

    out sBlue(view) + br

    update(p,db) if p[:upd]

    # テーブル一覧
    v_db_detail(p,db,sqlite_path) if view == "db"
    # テーブル指定
    v_table(p,db,sqlite_path,table) if view == "table"
    v_row_edit(p,db,sqlite_path) if view == "row_edit"
end

def update(p,db)
    col_infos = table_cols_info(db,p['table'])
    pk_col_name = pk_col_name(col_infos)

    if p[:upd].to_s == "del_row" ###
        sql_del = 'delete from ' + p['table'] + ' where ' + pk_col_name + "='" + p[:pk] + "'"
        sqlite2hash(sql_del,db)
    end
    if p[:upd].to_s == "update" ###
        upd_sqls = []
        p[:u].each { |key,val| upd_sqls << key + "='" + val.to_s + "'" }
        sql_upd = "update " + p[:table] + " set " + upd_sqls.join(",") + " where " + pk_col_name + "=" + p[:u][pk_col_name]
        sqlite2hash(sql_upd,db)
    end

end

def v_db_list()
    db_files = run_shell("ls files/*.sql3").strip.split_nl
    out br
    dbs = []
    if db_files.length > 0
        db_files.each do |path|
            info = SQL3.info_hash(path)
            info['updated_at'] = color_recent_time(info['updated_at'].to_s)
            dbs << info
        end
        out hash2html(dbs)
    end
    return
end

def v_db_detail(p,db,sqlite_path)
    # sql実行
    sql_text = p[:sql_text].to_s
    out '<form id="f1" method="post" action="?">'
    out i_hidden("view","db")
    out i_hidden("sqlite_path",sqlite_path)
    out i_textarea("sql_text",sql_text,80,5)
    out i_submit "実行"
    out "</form>"

    if sql_text.length > 0
        rets = sqlite2hash(sql_text,db)
        out hash2html(rets)
    end

    # テーブル一覧
    tables = sqlite2hash("SELECT type,name,'' cols,'' rows,rootpage,sql FROM sqlite_master WHERE type='table' ",db,NO_DISP)
    tables.each do |row|
        sql = "select count(*) ct from " + row['name']
        row_ct = sqlite2hash(sql,db,NO_DISP)
        col_infos = table_cols_info(db,row['name'] )
        row['cols'] = col_infos.length
        row['rows'] = row_ct[0]['ct']
        row['name'] = '<a href="?sqlite_path=' + URI.encode_www_form_component(sqlite_path) + '&table=' + row['name'].to_s + '&view=table">' + row['name'] + '</a> '
        row['sql'] = row['sql'].trim_spreadable(30)
    end
    out hash2html(tables)

    indexes = sqlite2hash("SELECT type,name,rootpage,sql FROM sqlite_master WHERE type='index' ",db)
    out hash2html(indexes)

    tables2 = sqlite2hash("SELECT type,name,rootpage,sql FROM sqlite_master WHERE type='table' ",db)
    out br

    tables = sqlite2hash("SELECT type,name,'' cols,'' rows,rootpage,sql FROM sqlite_master WHERE type='table' ",db,NO_DISP)
    tables.each do |row|
        out '<pre>' + row['sql'] + '</pre>'
    end

    # tables2.each do |row|
    #     out sBlue(row['name']) + spc
    #     sql = "PRAGMA table_info(" + row['name'] + ")"
    #     info = sqlite2hash(sql,db)
    #     out hash2html(info)
    # end
end

def v_row_edit(p,db,sqlite_path)
   # out p.inspect # table pk

    # tableからpk列を取得
    col_info_rows = table_cols_info(db,p['table'])
    pk_col_name = pk_col_name(col_info_rows)
    out br
    rows_edit = sqlite2hash('select * from ' + p['table'] + ' where ' + pk_col_name + '=' + p['pk'] ,db)

    out br

    out '<form id="f1" >'
    out i_hidden("sqlite_path",sqlite_path)
    out i_hidden("upd","update")
    out i_hidden("view","table")
    out i_hidden("table",p['table'])
    out '<table>'
    rows_edit[0].each do |key,val|
        col_type = col_info_rows[key]['type']
        out '<tr><td>'
        out key + spc
        out '</td><td>'
        out sSilver(col_type) + spc
        out '</td><td>'

        if col_type == 'INTEGER'
            out i_text('u[' + key + ']', val.to_s,10)
        else
            out i_textarea('u[' + key + ']', val.to_s, 50, val.to_s.split("\n").length)
        end
        out '</td></tr>'
    end
    out '</table>'
    out i_submit
    out spc + spc
    out a_tag('del','?sqlite_path=' + sqlite_path + '&table=' + p['table'] + '&view=table&upd=del_row&pk=' + p['pk'])
    out '</form>'
end

def v_table(p,db,sqlite_path,table)

    no_limit = p[:no_limit].to_s

    out '<form id="f1" method="get" action="?">'
    out i_hidden "sqlite_path",sqlite_path
    out i_hidden "table",table
    out i_checkbox("no_limit",no_limit)
    out i_submit_trans
    out "</form><hr/>"

    out s150(sBlue(table)) + spc
    sql = "SELECT '' action_,* FROM " + table
    sql += " limit 100" unless no_limit
    data = sqlite2hash(sql,db)
    data.each do |row|
        row.each do |key,val|
            row[key] = row[key].trim_spreadable(80) if row[key].is_a?(String)
        end
        row['action_'] = a_tag("edit","?sqlite_path=" + sqlite_path + "&table=" + table + "&pk=" + row['id'].to_s + '&view=row_edit')
    end
    out hash2html(data)
end



def table_cols_info(db,table_name)
    sql = "PRAGMA table_info(" + table_name + ")"
    col_infos = sqlite2hash(sql,db,NO_DISP)
    col_info_hash = {}
    col_infos.each do |row|
        col_info_hash[row['name']] = row
    end
    col_info_hash
end

def pk_col_name(table_info_hashes)

    pk_col_name = ""
    table_info_hashes.each do |key,row|
        pk_col_name = row['name'] if row['pk'] == 1
    end
    return pk_col_name
end

main

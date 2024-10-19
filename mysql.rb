p = $params
conns = $mysql_conns

out html_header("mysql")
out '<script>' + File.read("_form_events.js") + '</script>'
out menu(__FILE__)
# ----------------------------------------
filter = p[:filter].to_s
schemas = p['schemas'] || 'all'

out '<form method="get" >'
out i_hidden("schemas",schemas)
out i_text("filter",filter,20)
out i_submit_trans "検索"
out '</form>'


out conns.length.to_s + sSilver(" schemas ")
conns.keys.each do |conn_name|
  out a_tag(conn_name, '?schemas=' + conn_name) + spc
end

out spc + 'all' + br

conns = { schemas => $mysql_conns[schemas] }  if schemas != 'all'


conns.each do |conn_name,conn|

    filter_sqlite = filter.gsub(/_/,'@_')

    out br + s150(sBlueBG(conn_name)) + br
    out sBG("TABLES") + spc
    sql_tables = "SELECT
    TABLE_NAME,TABLE_COMMENT,	TABLE_TYPE	,ENGINE ,TABLE_ROWS,DATA_LENGTH,INDEX_LENGTH,AUTO_INCREMENT	,CREATE_TIME,TABLE_COLLATION
    FROM information_schema.TABLES where TABLE_SCHEMA='" + conn_name + "' "
    if filter_sqlite.length > 0
      sql_tables += " and ( TABLE_NAME LIKE '%" + filter_sqlite + "%' ESCAPE '@' COLLATE utf8_general_ci
          OR TABLE_COMMENT LIKE '%" + filter_sqlite + "%' ESCAPE '@' COLLATE utf8_general_ci
          OR TABLE_TYPE LIKE '%" + filter_sqlite + "%' ESCAPE '@' COLLATE utf8_general_ci
          OR ENGINE LIKE '%" + filter_sqlite + "%' ESCAPE '@' COLLATE utf8_general_ci )  "
    end
    tables = sql2hash(sql_tables,conn_name)
    tables.each do |row|
      table_name = row['TABLE_NAME']
      row = color_row(row, filter_sqlite) if filter_sqlite.length > 0
      row['TABLE_NAME'] = a_tag row['TABLE_NAME'],"/dev/mysql_table?conn_name=" + conn_name + "&table_name=" + table_name
    end
    out hash2html(tables)


    out br + sBG( "COLUMNS") + spc
    sql_columns = "SELECT
    TABLE_NAME,COLUMN_NAME,COLUMN_COMMENT,	COLUMN_TYPE,COLUMN_NAME,COLUMN_DEFAULT,IS_NULLABLE,EXTRA
    FROM information_schema.COLUMNS where TABLE_SCHEMA='" + conn_name + "'  "
    if filter_sqlite.length > 0
      sql_columns += " and (COLUMN_NAME LIKE '%" + filter_sqlite + "%' ESCAPE '@'
                OR COLUMN_COMMENT LIKE '%" + filter_sqlite + "%' ESCAPE '@'
                OR COLUMN_TYPE LIKE '%" + filter_sqlite + "%' ESCAPE '@'  ) "
    end

    columns = sql2hash(sql_columns,conn_name)
    columns.each do |row|
      table_name = row['TABLE_NAME']
      row = color_row(row, filter) if filter.length > 0
      row['TABLE_NAME'] = a_tag row['TABLE_NAME'],"/dev/mysql_table?conn_name=" + conn_name + "&table_name=" + table_name
    end
    out hash2html(columns)

end
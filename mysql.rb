class Mysql

  def main
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
    conns.keys.each do |c|
      out a_tag(same_red(c,schemas) , '?schemas=' + c) + spc
    end

    out spc + a_tag('all', '?') + spc + br

    conns = { schemas => $mysql_conns[schemas] }  if schemas != 'all'


    conns.keys.each do |con|

        filter_sqlite = filter.gsub(/_/,'@_') # sqlite3のエスケープ

        out br + s150(sBlueBG(con)) + br
        out sBG("TABLES") + spc
        sel = "SELECT
        TABLE_NAME,TABLE_COMMENT,	TABLE_TYPE	,ENGINE ,TABLE_ROWS,DATA_LENGTH,INDEX_LENGTH,AUTO_INCREMENT	,CREATE_TIME,TABLE_COLLATION
        FROM information_schema.TABLES where TABLE_SCHEMA='" + con + "' "
        if filter_sqlite.length > 0
          sel += " and ( TABLE_NAME LIKE '%" + filter_sqlite + "%' ESCAPE '@' COLLATE utf8_general_ci
              OR TABLE_COMMENT LIKE '%" + filter_sqlite + "%' ESCAPE '@' COLLATE utf8_general_ci
              OR TABLE_TYPE LIKE '%" + filter_sqlite + "%' ESCAPE '@' COLLATE utf8_general_ci
              OR ENGINE LIKE '%" + filter_sqlite + "%' ESCAPE '@' COLLATE utf8_general_ci )  "
        end
        tables = sql2hash(sel,con)
        tables.each do |r|
          table_name = r['TABLE_NAME']
          r = color_row(r, filter_sqlite) if filter_sqlite.length > 0
          r['TABLE_NAME'] = a_tag(r['TABLE_NAME'],"/dev/mysql_table?con=" + con + "&table=" + table_name)
        end
        out hash2html(tables)


        out br + sBG( "COLUMNS") + spc
        sql_columns = "SELECT
        TABLE_NAME,COLUMN_NAME,COLUMN_COMMENT,	COLUMN_TYPE,COLUMN_NAME,COLUMN_DEFAULT,IS_NULLABLE,EXTRA
        FROM information_schema.COLUMNS where TABLE_SCHEMA='" + con + "'  "
        if filter_sqlite.length > 0
          sql_columns += " and (COLUMN_NAME LIKE '%" + filter_sqlite + "%' ESCAPE '@'
                    OR COLUMN_COMMENT LIKE '%" + filter_sqlite + "%' ESCAPE '@'
                    OR COLUMN_TYPE LIKE '%" + filter_sqlite + "%' ESCAPE '@'  ) "
        end

        columns = sql2hash(sql_columns,con)
        columns.each do |r|
          table_name = r['TABLE_NAME']
          r = color_row(r, filter) if filter.length > 0
          r['TABLE_NAME'] = a_tag(r['TABLE_NAME'],"/dev/mysql_table?con=" + con + "&table=" + table_name)
        end
        out hash2html(columns)

    end
  end
end
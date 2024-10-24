class Mysql_stats

      SQLITE_PATH_MYSQL = 'files/mysql.sql3'

    def main

        db = SQL3.connect_or_create(SQLITE_PATH_MYSQL,'') # todo

        p = params = $params
        conns = $mysql_conns

        $special_col_types = ["geometry","info"]

        out html_header("mysql")
        out '<script>' + File.read("_form_events.js") + '</script>'
        out menu(__FILE__)
        # ----------------------------------------
        filter = p[:filter].to_s.strip

        # 全接続ループ
        conns.each do |conn_name,conn|

            # テーブル数、列数、データ量、index量
            row_ct = sql2hash("SELECT count(*) ct FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = '" + conn_name + "' ",conn_name,false)
            col_ct = sql2hash("SELECT count(*) ct FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = '" + conn_name + "' ",conn_name,false)

            size_row = sql2hash("SELECT
                SUM(DATA_LENGTH) + SUM(INDEX_LENGTH) data_size FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = '" + conn_name + "' ",conn_name,false)
            size_str = (size_row[0]['data_size'].to_f / 1024.0 / 1024.0 ).round(1).to_s + sSilver("mb")

            out br + s150(sBlueBG(conn_name) + spc) + s120(row_ct[0]['ct'].to_s + sSilver('tbl ') + spc + col_ct[0]['ct'].to_s + sSilver('col ') + spc + size_str) + br

            out '<table><tr><td valign=top style="border:none;" >'

            #out sBG("table view index fk ") + spc
            recs = sql2hash("
                SELECT
                (SELECT count(*) ct FROM information_schema.TABLES WHERE TABLE_SCHEMA = '" + conn_name + "' and TABLE_TYPE= 'BASE TABLE' ) tables,
                (SELECT count(*) ct FROM information_schema.TABLES WHERE TABLE_SCHEMA = '" + conn_name + "' and TABLE_TYPE= 'VIEW' ) views,
                (SELECT count(*) ct FROM information_schema.TABLES WHERE TABLE_SCHEMA = '" + conn_name + "' ) tables,
                (SELECT count(*) ct FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = '" + conn_name + "' ) columns,
                (SELECT count(*) ct FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = '" + conn_name + "' ) indexes,
                (SELECT count(*) ct FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = '" + conn_name + "'
                AND REFERENCED_TABLE_NAME IS NOT NULL ) fk
                ",conn_name,15)
            out hash2html(recs)

            # 横一列
            out '</td><td valign=top style="border:none;">'

            #out sBG("data/index") + spc
            sizes = sql2hash("SELECT
            SUM(DATA_LENGTH) DATA_SUM,
            SUM(INDEX_LENGTH) INDEX_SUM
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = '" + conn_name + "'
            ",conn_name,15)
            sizes.each do |row|
                row['DATA_SUM'] = (row['DATA_SUM'].to_f / 1024.0 / 1024.0 ).round(1).to_s + sSilver("mb")
                row['INDEX_SUM'] = (row['INDEX_SUM'].to_f / 1024.0 / 1024.0 ).round(1).to_s + sSilver("mb")
            end
            out hash2html(sizes)

            out '</td><td valign=top style="border:none;">'

            #out sBG("info") + spc
            schema_info = sql2hash(" SELECT
                DEFAULT_CHARACTER_SET_NAME DEF_CHARSET,
                DEFAULT_COLLATION_NAME DEF_COLLATION,
                SQL_PATH, DEFAULT_ENCRYPTION ENCRYPT_
                FROM information_schema.SCHEMATA
                WHERE SCHEMA_NAME = '" + conn_name + "' ",conn_name,15)
            out hash2html(schema_info)

            # schema_info = sql2hash(" SELECT * FROM information_schema.SCHEMATA
            # WHERE SCHEMA_NAME = '" + conn_name + "'  ",conn_name,20)
            # out hash2html(schema_info)



            out '</td></tr></table>'

            # 下の段
            out br + '<table><tr><td valign=top style="border:none;" >'

            out sBG("col_type ") + br
            data_types = sql2hash("SELECT DATA_TYPE,count(*) ct
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = '" + conn_name + "' GROUP BY DATA_TYPE ORDER BY ct DESC;
                ",conn_name,10)
            data_types.each do |row|
                row["DATA_TYPE"] = a_tag(row["DATA_TYPE"],"/dev/mysql?filter=" + row["DATA_TYPE"])
            end
            out hash2html(data_types)

            out '</td><td valign=top style="border:none;">'

            out sBG("col_type詳細") + br
            column_types = sql2hash("SELECT
                COLUMN_TYPE,count(*) ct
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = '" + conn_name + "' GROUP BY COLUMN_TYPE ORDER BY ct DESC limit 8;
                ",conn_name,20)
            column_types.each do |row|
                row["COLUMN_TYPE"] = a_tag(row["COLUMN_TYPE"],"/dev/mysql?filter=" + row["COLUMN_TYPE"])
            end
            out hash2html(column_types)

            out '</td><td valign=top style="border:none;">'

            out sBG("rowの多いテーブル") + br
            big_row_tables = sql2hash("SELECT
                TABLE_NAME,
                TABLE_ROWS ROWS_,
                DATA_LENGTH DATA_,
                INDEX_LENGTH INDEX_
                FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = '" + conn_name + "' ORDER BY TABLE_ROWS DESC LIMIT 8 ",conn_name,20)
            big_row_tables.each do |row|
                row["TABLE_NAME"] = a_tag(row["TABLE_NAME"],"/dev/mysql?filter=" + row["TABLE_NAME"])
                row['DATA_'] = (row['DATA_'].to_f / 1024.0 / 1024.0 ).round(1).to_s + sSilver("mb")
                row['INDEX_'] = (row['INDEX_'].to_f / 1024.0 / 1024.0 ).round(1).to_s + sSilver("mb")
            end
            out hash2html(big_row_tables)

            out '</td><td valign=top style="border:none;">'

            out sBG("列の多いテーブル") + br
            many_cols_tables = sql2hash(" SELECT
            TABLE_NAME,count(*) cols
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = '" + conn_name + "'
            GROUP BY TABLE_NAME
            ORDER BY cols DESC limit 8 ",conn_name,20)
            many_cols_tables.each do |row|
                row["TABLE_NAME"] = a_tag(row["TABLE_NAME"],"/dev/mysql?filter=" + row["TABLE_NAME"])
            end
            out hash2html(many_cols_tables)

            out '</td><td valign=top style="border:none;">'

            out sBG("recent update ") + br
            data_types = sql2hash("SELECT TABLE_NAME,TABLE_TYPE,CREATE_TIME,UPDATE_TIME  FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = '" + conn_name + "' limit 3",conn_name,20)
            out hash2html(data_types)

            out '</td></tr></table>'
        end
    end
end
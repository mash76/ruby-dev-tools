class Mysql_table
    DATA_SELECT_LIMIT = 200

    def main()
        p = $params
        conns = $mysql_conns

        out html_header("table")
        out '<script>' + File.read("_form_events.js") + '</script>'
        out menu(__FILE__)

        # ----------------------------------------
        con = p[:con].to_s
        table = p[:table].to_s


        limit = 200

        if con == "" || table == ""
            out sRed("param need : connection/table")
            return
        end

        # 件数
        ct_row_all = sql2hash("select count(*) ct FROM " + table , con,false)

        out a_tag(sBlue(con), '/dev/mysql?schemas=' + con) + br
        out s150(sBlue(table)) + spc + s150(ct_row_all[0]['ct'].to_s) + br

        table_info(con,table)

        out br + sBG("columns") + spc
        columns_recs = sql2hash("SELECT
            ORDINAL_POSITION POS , COLUMN_NAME , COLUMN_TYPE  ,COLUMN_COMMENT ,
            COLUMN_KEY KEY_  ,COLUMN_DEFAULT DEF_ ,IS_NULLABLE NULL_ ,
            CHARACTER_MAXIMUM_LENGTH CHARS_, CHARACTER_OCTET_LENGTH BYTES_,
            CHARACTER_SET_NAME CHAR_SET ,COLLATION_NAME ,EXTRA
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA='" + con + "' AND TABLE_NAME='" + table + "'
            ORDER BY ORDINAL_POSITION ASC", con)
        out hash2html(columns_recs)

        fk_map() if 1==2

        indexes(con,table)

        # out br + sBG("foreign keys") + spc
        # fk_recs = sql2hash(sql_fk_parent($con,$table), $con)
        # out hash2html(fk_recs)

        out br + sBG("data") + spc + ct_row_all[0]['ct'].to_s
        out hash2html_mysql_data(table  ,p , con)
    end

    def indexes(con,table)
        out br + sBG("indexes") + spc
        recs = sql2hash("
            SELECT
                INDEX_NAME, COLUMN_NAME, SEQ_IN_INDEX, NON_UNIQUE
            FROM information_schema.STATISTICS
            WHERE
                TABLE_SCHEMA = '" + con + "'
                AND TABLE_NAME = '" + table + "'
            ", con)
        out hash2html(recs)
    end

    def table_info(con,table)
        table_info = sql2hash("select
            TABLE_TYPE, ENGINE, VERSION, ROW_FORMAT, TABLE_ROWS, AVG_ROW_LENGTH, DATA_LENGTH, MAX_DATA_LENGTH, INDEX_LENGTH, DATA_FREE, AUTO_INCREMENT, CREATE_TIME, UPDATE_TIME, CHECK_TIME, TABLE_COLLATION, CHECKSUM, CREATE_OPTIONS, TABLE_COMMENT
            from information_schema.TABLES where TABLE_SCHEMA='" + con + "' AND TABLE_NAME='" + table + "'", con)
            out hash2html(table_info)
    end

    def showFKS(table,use_tables,depth,max_depth,con)
        if depth > max_depth
            out sRed("depth-limit! max-depth " + max_depth.to_s + " now ") + depth.to_s + br
            return
        end

        if use_tables.include?(table)
        # out "already " + sSilver(table) + br
            return
        else
            out br + "check " + sRed(table) + spc + depth.to_s +  br
        end

        use_tables << table
        fk_child_recs = sql2hash(sql_fk_child(con,table), con,false)
        fk_childs = {}
        fk_child_recs.each { |row| fk_childs[row['COLUMN_NAME']] = row }
        fk_parent_recs = sql2hash(sql_fk_parent(con,table), con,false)
        fk_parents = {}
        fk_parent_recs.each { |row| fk_parents[row['REFERENCED_COLUMN_NAME']] = row }

        cols2 = sql2hash("SELECT '' FK_P,COLUMN_NAME ,'' FK_C
                from information_schema.COLUMNS WHERE TABLE_SCHEMA='" + con + "' and TABLE_NAME='" + table + "'", con,false)
        cols2.each do |row|
            row['FK_C'] = "■" if fk_childs.key?(row['COLUMN_NAME'])
            row['FK_P'] = "■" if fk_parents.key?(row['COLUMN_NAME'])
        end
        out hash2html(cols2)

        # child一覧
        fk_child_recs.each do |row|
            #out "check child " + sRed(row['TABLE_NAME']) + "." + row['COLUMN_NAME'] + br
            out "ch "
            showFKS(row['TABLE_NAME'],use_tables,depth + 1, max_depth)
        end
        # parent一覧
        fk_parent_recs.each do |row|
            #out "check parent " + sRed(row['REFERENCED_TABLE_NAME']) + "." + row['REFERENCED_COLUMN_NAME'] + br
            out "pr "
            showFKS(row['REFERENCED_TABLE_NAME'],use_tables,depth - 1, max_depth)
        end
    end

    def fk_map(con,table)


            out sBlue("FK map") + br
            use_tables = []
            showFKS(table, use_tables,0,1,con)

            fk_parent_recs = sql2hash(sql_fk_parent(con,table), con,false)
            fk_parents = {}
            fk_parent_recs.each { |row| fk_parents[row['COLUMN_NAME']] = row }

            fk_child_recs = sql2hash(sql_fk_child(con,table), con,false)
            fk_childs = {}
            fk_child_recs.each { |row| fk_childs[row['REFERENCED_COLUMN_NAME']] = row }

            out br + sBG("columns") + spc
            columns_recs = sql2hash("SELECT
                ORDINAL_POSITION POS , '' FK_PARENT, COLUMN_NAME ,'' FK_CHILD, COLUMN_TYPE , '' FKS ,
                COLUMN_KEY KEY_  ,COLUMN_DEFAULT DEF ,IS_NULLABLE IS_NULL ,
                CHARACTER_MAXIMUM_LENGTH CHAR_LEN, CHARACTER_OCTET_LENGTH BYTES_LEN,
                CHARACTER_SET_NAME CHAR_SET ,COLLATION_NAME ,EXTRA
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA='" + con + "' AND TABLE_NAME='" + table + "'
                ORDER BY ORDINAL_POSITION ASC", con)

            # fkの親と子
            columns_recs.each do  | row |
                col_name = row['COLUMN_NAME']
                if fk_parents.key?(col_name)
                    row['FK_PARENT'] = a_tag(fk_parents[col_name]['REFERENCED_TABLE_NAME'] + "." + fk_parents[col_name]['REFERENCED_COLUMN_NAME'],"?con=" + con + "&table=" + fk_parents[col_name]['REFERENCED_TABLE_NAME'])
                end
                if fk_childs.key?(col_name)
                    row['FK_CHILD'] = a_tag(fk_childs[col_name]['TABLE_NAME'] + "." + fk_childs[col_name]['COLUMN_NAME'],"?con=" + con + "&table=" + fk_childs[col_name]['TABLE_NAME'])
                end
            end
            out hash2html(columns_recs)

        # 列情報 (使いまわし用hash)
    end

    def hash2html_mysql_data2(table ,p ,p_class="" )

    end

    # 絞り込み sort 指定テーブルを一覧する sortもする
    def hash2html_mysql_data(table ,p ,p_class="",con )

        # 検索フィルタ  col_filters[]
        col_filters = p[:col_filters] || {}
        order_by = p[:order_by] || ''
        order_dir = p[:order_dir] || 'asc'

        col_datatypes = get_col_datatypes(con,table)

        #絞り込んで0件だとヘッダも出ない
        wheres = []
        if col_filters != nil
            col_filters.each do |key,val|
                wheres << (key + " like '%" + val + "%'") if val.length > 0
            end
        end
        sql_base = "select * from " + table
        col_infos = sql2hash(sql_base + " limit 1",con,false)
        sql = sql_base
        sql += " where " + wheres.join(" and ") if wheres.length > 0
        sql += " order by " + order_by + ' ' + order_dir if order_by.length > 0
        sql += " limit " + DATA_SELECT_LIMIT.to_s

        hashes = sql2hash(sql,con)

        #長い列を省略 stringのみ
        hashes.each do |row|
            row.each do |key,value |
                row[key] = row[key].trim_spreadable(30) if row[key].is_a?(String)
            end
        end

        # ヘッダー行
        html = "<table class='" + p_class + "'><tr>"
        html << '<form id="f1" action="?con=' + con + '&table=' + table + '" >'
        html << i_hidden("con",con)
        html << i_hidden("table",table)
        html << i_hidden("order_by","")
        html << i_hidden("order_dir","")

        # ヘッダ
        col_datatypes.each do |key,row|
            val = ""
            val = col_filters[key] if col_filters.key?(key)
            new_order_dir = (order_dir == 'asc') ? 'desc' : 'asc'
            html << '<th nowrap>' + a_tag(key.to_s,"
                        javascript:setVal('order_by','" + key.to_s + "','');
                                setVal('order_dir','" + new_order_dir + "')
                    ")
            html << ' ' + ((order_dir == 'asc') ? '▲' : '▼') if key.to_s == order_by
            html << br
            html << sSilver(row['DATA_TYPE']) + br
            html << i_text("col_filters[" + key + "]", val)
            html << '</th>'
        end
        html << i_submit_trans()
        html << "</form>"
        html << "</tr>"

        # 値が不正なら戻る
        unless hashes.is_a?(Array)
        out sRed("not array ") + __FILE__.to_s + " " + __LINE__.to_s + " " + __method__.to_s + br
        return html
        end
        return html if hashes.length == 0

        # データ行
        hashes.each do |row|
            html << "<tr>"
            row.each do |key,value |
                # 色かえ
                if col_filters.key?(key) && col_filters[key].length > 0
                    value = color_val(value,col_filters[key])
                end
                value = sRed("(geometry type)") if col_datatypes[key]['DATA_TYPE'] == "geometry"
                value = sRed("(blob type)") if col_datatypes[key]['DATA_TYPE'] == "blob"
                #value = value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: '?') # おきかえ
                html << '<td nowrap style="padding-left:6px;">' + value.to_s + '</td>'
            end
            html << "</tr>"
        end
        html << "</table>"
        html
    end


    def get_col_datatypes(con,table)
        ret = {}
        col_recs = sql2hash("SELECT
            COLUMN_NAME,DATA_TYPE
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA='" + con + "' AND TABLE_NAME='" + table + "' ", con,false)
        col_recs.each do |row|
            ret[row["COLUMN_NAME"]] = row
        end
        ret
    end

    def sql_fk_parent(con,table)

            " SELECT
                CONSTRAINT_NAME,
                COLUMN_NAME,
                REFERENCED_TABLE_NAME,
                REFERENCED_COLUMN_NAME
            FROM
                information_schema.KEY_COLUMN_USAGE
            WHERE
                TABLE_SCHEMA = '" + con + "'
                AND TABLE_NAME = '" + table + "'
                AND REFERENCED_TABLE_NAME IS NOT NULL "
    end

    def sql_fk_child(con,table)

        " SELECT
            CONSTRAINT_NAME,
            TABLE_NAME,
            COLUMN_NAME,
            REFERENCED_TABLE_NAME,
            REFERENCED_COLUMN_NAME
        FROM
            information_schema.KEY_COLUMN_USAGE
        WHERE
            TABLE_SCHEMA = '" + con + "'
            AND REFERENCED_TABLE_NAME = '" + table + "' "

    end
end
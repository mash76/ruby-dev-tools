require "sqlite3"
SQLITE_MEMO_PATH = 'files/memo.sql3'

def create_tables
    return "
        CREATE TABLE memos (
            id INTEGER PRIMARY KEY,
            title TEXT,
            text TEXT,
            created_at TEXT,
            updated_at TEXT
        )
    "
end


def main

    db = SQL3.connect_or_create(SQLITE_MEMO_PATH,create_tables)
    p = $params

    view = p[:view] || 'list'


    out html_header('memo')
    out '<script>' + File.read('_form_events.js') + '</script>'
    out menu(__FILE__)

    out '<script>
            function edit(id) { document.location.href = "?view=edit&id=" + id }
        </script>'

    if view == 'view_article'
        v_article(p,db,p[:id].to_s)
        return
    end

    # ----------------------------

    out SQL3.info(SQLITE_MEMO_PATH)
    out spc + a_tag('new','?view=new')

    out (spc * 20) + a_tag('db_regen','?view=db_regen')
    out br
    update(p,db) if p[:upd]

    v_new(p,db) if view == 'new'
    v_edit(p,db) if view == 'edit'
    v_list(p,db) if view == 'list'

    recreate_db(db) if view == 'db_regen'
    return
end

def recreate_db(db)

    sqlite2hash('drop tablememos', db)

    create_sql = '
    CREATE TABLE memos (
        id INTEGER PRIMARY KEY,
        title TEXT,
        text TEXT,
        created_at TEXT,
        updated_at TEXT
    ) '
    # テーブルを作成
    sqlite2hash(create_sql)
end

def v_article(p,db,article_id_str)

    sql_select = "select * from memos where id='" + article_id_str + "' "
    row = sqlite2hash(sql_select,db,false)
    out a_tag('list','?')
    out '<div ondblclick="edit(' + article_id_str.to_s + ')">'
    out s120(row[0]['title']) + '<hr/>'
    out '<pre style="margin-left:10px; margin-top:8px;" >'
    out CGI.escapeHTML(row[0]['text']) + "</pre>"
    out '</div>'

end

def v_list(p,db)

    filter = p[:filter].to_s

    # 検索
    out '<form id="f1" method="post" view="?">'
    out i_text 'filter',filter,20

    out i_submit_trans '更新'
    out '</form>'

    # タイトル一覧
    sql_select = 'SELECT * FROM memos'
    sql_select += " WHERE (title like '%" + filter + "%' or text like '%" + filter + "%') " if filter.strip != ""
    sql_select += " ORDER BY updated_at DESC"
    memos = sqlite2hash(sql_select,db)

    out '<table class="t_hover" style="width:800px;">'
    memos.each do |row|
        out '<tr
            onclick=" location.href=\'#memo' + row["id"].to_s + '\'" style="cursor:pointer;">'

        out '<td style="border-bottom:1px solid silver; white-space:nowrap;">'

        titles = row['title'].split('#')
        titles << '' if titles.length == 1
        out s120(titles[0])
        out '</td><td style=" white-space:nowrap;"> ' << s120(sSilver(titles[1])) << '</td>'
        out '<td style=" white-space:nowrap;"> ' << color_recent_time(row['updated_at']) << '</td></tr>'
    end
    out '</table>'
    out br

    # 本文ループ
    memos.each do |row|
        out '<div id="memo' + row['id'].to_s + '" ondblclick="edit(' + row['id'].to_s + ')">'

        # title
        out '<div style="border-bottom:1px solid silver;">'
        titles = row['title'].split('#')
        titles << '' if titles.length == 1
        out s120(sBG(titles[0])) << ' ' << s120(sSilver(titles[1])) << ' ' << row["updated_at"]
        out spc + a_tag('del','?view=list&upd=del&id=' + row['id'].to_s)
        out spc + a_tag('view','?view=view_article&id=' + row['id'].to_s)
        out '</div>'

        # text
        out '<pre style="margin-left:10px; margin-top:8px;">'
        out CGI.escapeHTML(row['text']) + '</pre>'

        out "</div>" + br
    end
end

def v_new(p,db)

    out '<form method="post" >'
    out i_hidden 'view','list'
    out i_hidden 'upd','new_submit'
    out i_text 'title','',80
    out br
    out i_textarea('text','',120,30)
    out i_submit '更新'
    out '</form><hr/>'

end

def v_edit(p,db)
    id = p[:id].to_s
    sql_memo_get = 'SELECT * FROM memos WHERE id=' + id + ' ORDER BY updated_at DESC'
    ret = sqlite2hash(sql_memo_get,db)
    ret.each do |row|

        row_ct = row['text'].split_nl.length

        out '<form method="post" view="?">'
        out i_hidden 'upd','edit_submit'
        out i_hidden 'view','list'
        out i_hidden 'id',id
        out i_text('title',row['title'],80)
        out br
        out i_textarea('text', row['text'], 120, row_ct)
        out i_submit '更新'
        out '</form><hr/>'
    end

end

def update(p,db)
    return unless p[:upd]

    if p[:upd] == 'del'
        del_sql = 'delete from memos where id=' + p[:id].to_s
        sqlite2hash(del_sql,db)
    end

    if p[:upd] == 'new_submit'
        ins_sql = " insert into memos (title,text,created_at,updated_at)
            values('" + p[:title].gsub("'", "''") + "','" + p[:text].gsub("'", "''") + "','" + now_time_str + "','" + now_time_str + "')"
        sqlite2hash(ins_sql,db)
    end
    if p[:upd] == 'edit_submit'
        upd_sql = " UPDATE memos set
                title='" << p[:title].gsub("'", "''") << "' ,text='" << p[:text].gsub("'", "''") << "', updated_at='"  << now_time_str << "' WHERE id=" << p[:id].to_s
        sqlite2hash(upd_sql,db)
    end
end



main

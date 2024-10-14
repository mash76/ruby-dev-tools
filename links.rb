SQLITE_PATH = File.expand_path('files/links.sql3')

def ajax_link(p,db)
    return unless p[:ajax]

    puts "ajax " + p[:ajax] + ' ' + p.inspect
    if p[:ajax] == 'add'
        href = p[:href].to_s
        name = href.gsub(/.*\/\//,'').gsub(/\/.*/,'').gsub('.com','').gsub('.jp','')
        shortcut = name
        add(p,db,name,href,shortcut)  # insert
        return
    end

    # ajax=add_cate2&cat1_id=24&cate2_name=sdds
    if p[:ajax] == 'add_cate2'
        sql_del = "insert into cate2 (cate1_id,name)
                    values('" + p[:cat1_id] + "','" + p[:cate2_name] + "')";
        sqlite2hash(sql_del, db)
        return
    end

    if p[:ajax] == 'del'
        sql_del = 'delete from links where id=' + p[:id].to_s
        sqlite2hash(sql_del, db)
        return
    end

    # link カウントアップ 遷移ごとに
    if p[:ajax] == 'count_up' && p[:id]
        sql_count_up = "update links set use_count = use_count + 1, last_use_date = '" + now_time_str + "' where id=" + p[:id].to_s
        puts 'sql ' + sql_count_up
        sqlite2hash(sql_count_up, db)
        return
    end

    #link カテゴリ変更 dropで
    if p[:ajax] == 'change_cate' && p[:cate1] && p[:cate2] && p[:id]
        sql_update = "update links set cate1='" + p[:cate1] + "' , cate2='" + p[:cate2] + "' where id=" + p[:id].to_s
        puts 'sql ' + sql_update
        sqlite2hash(sql_update, db)
        return
    end

    #ファイルやdirを開く
    if p[:ajax] == 'open' && p[:path].to_s.length > 0
        shell = 'open "$HOME/' + p[:path] + '"';
        puts 'ajax ' +  shell
        run_shell(shell)
        return
    end

    # アプリを起動
    if p[:ajax] == "runapp" && p[:path].to_s.length > 0
        shell = 'open -a "' + p[:path] + '"';
        puts 'ajax ' +  shell
        run_shell(shell)
        return
    end



end

def main

    p = $params
    out html_header('links')
    out '<script>' + File.read("_form_events.js") + '</script>'
    out menu(__FILE__)

	db = SQLite3::Database.new SQLITE_PATH
	db.results_as_hash = true
	out sqlite3_info(SQLITE_PATH) + br

    # ajax ----------------------------------------
    ajax_link(p,db)

    # ----------------------------------------


    edit = p[:edit] || 'off'
    view = p[:view] || 'links'

	['links','manage','new','apps'].each do | view_name |
		disp = view_name == view ? sRed(view_name) : view_name
		out a_tag(disp,'/dev/links?view=' + view_name) + spc
	end

    new_edit = (edit == 'on') ? 'off' : 'on'
    out a_tag('edit' ,'/dev/links?view=' + view + '&edit=' + new_edit ) + spc

    out br

    out '<table><tr><td>'

    out '<div id="drop-area" style="width:300px;height:100px;border: 2px dashed #000;">追加</div>'

    out '</td><td>' + (spc * 20) + '</td><td>'

    out '<div id="gomibako-area" style="width:200px;height:100px;border: 2px dashed #000;">ゴミ箱</div>'

    out '</td></tr></table>'

    v_apps(p,db) if view == 'apps'
    v_new(p,db) if view == 'new'
    v_links(p,db,edit) if view == 'links'
    v_manage(p,db) if view == 'manage'

end

def v_apps(p,db)

    shell = 'find /Applications /System/Applications /Users/$(whoami)/Applications -name "*.app" -maxdepth 2'
    apps = run_shell(shell).split_nl
    out br
    out apps.join(br) + br + br

    # shell = 'find /Applications /System/Applications /Users/$(whoami)/Applications -name "*.png" -maxdepth 4'
    # apps = run_shell(shell).split_nl
    # out br
    # out apps.join(br)

end


def v_new(p,db)

    name = p[:name].to_s
    href = p[:href].to_s
    shortcut = p[:shortcut].to_s

    # form
    out '<form id="f1" >'
    out i_hidden("view","new")
    out 'name ' + i_text('name',name,40) + br
    out 'href ' + i_text('href',href,85) + br
    out 'shortcut ' + i_text('shortcut',shortcut,15) + br

    out i_submit_trans
    out '</form>'

    # insert
    add(p,db,name,href,shortcut)
end

def v_manage(p,db)
    out sBlue('リンク生成') + br

    csv = p[:csv].to_s
    filter = p[:filter].to_s
    order_by = p[:order_by].to_s
    order_dir = p[:order_dir].to_s

    # csvで登録 name href shortcut
    if csv.length > 0
        out sRed('csv') + br
        rows = csv.split_nl
        out rows.length.to_s + br
        rows.each do |row|
            cols = row.split(',')
            date =  now_time_str
            sqlite2hash("insert into links
                    (cate1,cate2,name,href,shortcut,use_count,last_use_date,created_at)
                    values('none','none','" + cols[0] + "' , '" + cols[1] + "' , '" + cols[2] + "',0, '" + date + "', '" + date + "') ",db)
        end
    end

    # 削除
    del = p[:del].to_s
    if del.length > 0
        sqlite2hash('delete from links where id= ' + del,db)
    end

    out '<form id="f1" >'
    out i_hidden('view','manage')
    out 'filter ' + i_text('filter',filter,20) + br
    out 'order_by ' + i_text('order_by',order_by,20) + spc
    orders = ['id','cate1','name','shortcut','href','use_count','last_use_date','created_at']
    orders.each do |order_val|
        disp = (order_val == order_by ? sRed(order_val) : order_val)
        out a_tag(disp, "javascript:setVal('order_by','" + order_val + "')") + spc
    end

    out br
    out 'order_dir ' + i_text('order_dir',order_dir,20) + spc
    order_dirs = ['asc','desc']
    order_dirs.each do |o_dir|
        disp = (order_dir == o_dir ? sRed(o_dir) : o_dir)
        out a_tag(disp, "javascript:setVal('order_dir','" + o_dir + "')") + spc
    end

    out i_submit_trans
    out '</form>'

    # out '<form id="f1" method="post">'
    # out i_hidden("view","manage")
    # out "csv " + br + i_textarea("csv",csv,80,30)
    # out i_submit
    # out '</form>'



    # 表示
    sql_select = " select '' act,
            (select sort_order from cate1 where id=links.cate1) c1_order,
            links.*
            from links "
    if filter.length > 0
        sql_select += " where name like '%" + filter + "%'
            or href like '%" + filter + "%'
            or shortcut like '%" + filter + "%'
            or cate1 like '%" + filter + "%'
            or cate2 like '%" + filter + "%' "
    end
    order_by = 'created_at' if order_by.length == 0
    order_dir = 'desc' if order_dir.length == 0
    sql_select += ' order by ' + order_by + ' ' + order_dir + ',cate1,cate2'

    list = sqlite2hash(sql_select,db,200)
    #ショートカットを一覧に
    shortcuts = []
    list.each { |row|   shortcuts << row['shortcut'] }

    list.each do |row|
        # ショートカット数を確認
        sc = row['shortcut']
        max_dup_len = 0
        (1..sc.length).each do |i|
            str1 = sc.slice(0,i)
            matches = shortcuts.select { |sc1| sc1.slice(0,i) == str1 && sc1 != sc }
            #out str1 + spc + matches.length.to_s + br
            max_dup_len = i if matches.length > 0
        end
        #out sc + sSilver(" dup_len ") + max_dup_len.to_s + br

        row['act'] = a_tag('del','?view=manage&del=' + row['id'].to_s)
        row['act'] += spc + a_tag('upd','sqlite?sqlite_path=' + URI.encode_www_form_component(SQLITE_PATH) + '&table=links&pk=' + row['id'].to_s + '&view=row_edit')
        row['name'] ='<a target="_blank" draggable="true" sc="' + row['shortcut'] + '" href="' + row['href'] + '">' + row['name'] + '</a> '
        row['href'] = row['href'].trim_spreadable(50)

        row['last_use_date'] = color_recent_time(row['last_use_date'])
        row['created_at'] = color_recent_time(row['created_at']) if row['created_at']

        if row['shortcut'] == 'undefined'
            row['shortcut'] = sOrange(row['shortcut'])
        else
            row['shortcut'] = color_val(row['shortcut'],row['shortcut'].to_s.slice(0,max_dup_len),false)
        end
        row['cate1'] = sRed('no cate') if row['cate1'].to_s == ''
        row['cate2'] = sRed('no cate') if row['cate2'].to_s == ''
    end
    out hash2html(list)
end

def v_links(p,db,edit)

    cate1s_raw = sqlite2hash('select * from cate1 order by sort_order asc',db,false)
    cate2s_raw = sqlite2hash('select id,name,cate1_id from cate2 ',db,false)
    list = sqlite2hash('select
                    links.*,
                    (select name from cate1 where id=links.cate1) cate1_name,
                    (select name from cate2 where id=links.cate2) cate2_name
                    from links
                    order by cate1,cate2',db)
    links = {}

    # データまとめ 配列に
    list.each do |row|
        cate1 = row['cate1'] || '(no_cate1)'
        links[cate1] = {} unless links.key?(cate1)
        cate2 = row['cate2'] || '(no_cate2)'
        links[cate1][cate2] = [] unless links[cate1].key?(cate2)
        links[cate1][cate2] << row
    end
    out br
    out s120(links.length.to_s) + sSilver(' cate ')
    out s120(list.length.to_s) + sSilver(' links ')
    out br

    # 表示 cate1
    cate1s_raw.each do |cate1_row|
        cate1_id = cate1_row['id']
        out '<div>'
        unless links.key?(cate1_id)
            out sRed(' no links ' + cate1_id)
            next
        end
        out '</div>'

        next if cate1_row['is_disp'] == 0
        # 表示 サブカテ cate2 loop
        out '<table>'
        cate2s_now = cate2s_raw.select { |row| row['cate1_id'] == cate1_id  }

        ct = 0
        cate2s_now.each do |cate2_row|
            ct += 1
            cate2_id = cate2_row['id']
            style = (ct == 1) ? "border-top:1px solid silver; " : ""
            out '<tr><td style="' + style + '">'

            # cate1 表示
            if ct == 1
                if cate1_row['is_disp'] == 1
                    out '<div draggable="true" style="width:120px; " cate1_id="' + cate1_id.to_s + '" >' +
                            sBold(sGray(cate1_row['name']))

                    if edit == 'on'
                        out ' <a href="javascript:showAddCate2Form(\'' + cate1_id.to_s + '\')" style="font-size:80%; ">cate2+</a>'
                    end
                    out '</div>'
                else
                    out s150(sSilver(cate1_row['name']))
                end
            end
            out '</td><td style="' + style + ' width:120px; ">'
            out spc + spc + spc + cate2_row['name'] + spc
            out '</td><td style="' + style + ' width:1200px;">'

            #表示 個別リンク
            out '<div cate1="' + cate1_id.to_s + '" cate2="' + cate2_id.to_s + '">'
            if links[cate1_id].key?(cate2_id)
                links[cate1_id][cate2_id].each do |row|

                    # dir www app で色変える
                    name = row['name']
                    name = sGreen(name) if row['href'].include?('docs.google.com/spreadsheets')

                    name = sRed(name) if row['href'].include?('open=')
                    name = sOrange(name) if row['href'].include?('runapp=')
                    name = sBlue(name) if row['href'].include?('localhost:') or row['href'].include?('0.0.0.0:')

                    out '<a style="background:#f2f2ff;"
                            onclick="addLinkCount(' + row["id"].to_s + ')"
                            id="' + row['id'].to_s + '"
                            last_use_date="' + Time.parse(row['last_use_date']).to_i.to_s + '"
                            title="' + row['shortcut'] + '"
                            draggable="true"
                            sc="' + row['shortcut'] + '"
                            href="' + row['href'] + '">' + name + '</a>'

                    # editモードの場合
                    if edit == 'on'
                        out sSilver(row['shortcut']) ##
                        out a_tag(sPink("Edit"),"/dev/sqlite?sqlite_path=" + URI.encode_www_form_component(SQLITE_PATH) + "&table=links&pk=" + row['id'].to_s + "&view=row_edit")
                    end
                    out spc
                end
            else
                out spc * 20
            end
            out '</div>'
            out '</td></tr>'
        end
        out '</table>' + s_v_margin(6)
    end

    out File.read('links.html')
end


def add(p,db,name,href,shortcut)
    valid = true
    if name.length > 0 && href.length > 0
        if (name=='' or href == '' or shortcut == '')
            valid = false
            out sRed('new-row fail ') + p.inspect + br
        end

        # 登録
        if valid
            #既存確認
            kizon = sqlite2hash("select * from links where name ='" + name + "' or href='" + href + "' or shortcut ='" + shortcut + "'",db)
            out br
            out sRed("exist ") + hash2html(kizon) + br if kizon.length > 0

            date =  now_time_str
            sqlite2hash("insert into links (cate1,cate2,name,href,shortcut,use_count,last_use_date,created_at) values(24,36,'" + name + "' , '" + href + "' , '" + shortcut + "',0, '" + date + "', '" + date + "') ",db)

            puts 'true'
        end
    end
end



main
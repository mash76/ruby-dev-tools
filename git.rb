
# git clone https://github.com/laravel/laravel.git
# git clone https://github.com/EnterpriseQualityCoding/FizzBuzzEnterpriseEdition.git
# git clone https://github.com/facebook/react.git
# git clone https://github.com/electron/electron.git

LIST_LOG_LIMIT = 20
GIT_SHOW_SHELL = false
SQLITE_PATH_GIT = 'files/git.sql3'

def main

    p = $params

    ajax(p)

    out html_header("git")
    out '<script>' + File.read("_form_events.js") + '</script>'
    out menu(__FILE__)
    # ----------------------------------------

    db = SQL3.connect_or_create(SQLITE_PATH_GIT,create_tables)
    out SQL3.info(SQLITE_PATH_GIT)
    out br

    view = p[:view] || 'list'

    insert_git_log(db) if view == 'import'

    menus = ["list","import","db_stat","search_repo",'pull']
    menus.each do |v|
        disp = (v == view ? sRed(v) : v)
        out a_tag(disp,'?view=' + v) + spc
    end
    out br

    v_pull(db) if view == 'pull'
    v_search_repo(db) if view == 'search_repo'
    v_db_stat(db) if view == 'db_stat'
    v_repo(p,db) if view == 'repo'
    v_list(p,db) if view == "list"
end

def v_search_repo(db)

        shell ='find ~  -maxdepth 7 -type d -name ".git"  2>/dev/null'
        ret = run_shell(shell )
        out br
        out ret.nl2br
end

def v_pull(db)

    home = `echo $HOME`.strip
    threads = []
    GIT_REPOS.each do |repo |
        threads << Thread.new do
            dir = home + repo
            return unless dir_exist?(dir)
            shell_remote = 'git -C ' + dir + ' remote get-url origin'
            remote_url = run_shell(shell_remote,false)
            # thread内でchdirできない
            start = Time.now
            shell_pull = 'git -C ' + dir + ' pull'
            ret = run_shell(shell_pull,false)
            html = sBlue(dir) + br + sSilver(shell_remote) + br + sRed('remote ') + remote_url + br
            html += sSilver(shell_pull) + br + (Time.now - start).round(2).to_s + sSilver('sec') + br
            out html + ret.nl2br + br
        end
    end
    threads.each(&:join)
end

def v_db_stat(db)

    ret = sqlite2hash("select repo,count(*),max(commit_date),min(commit_date) ct from commits group by repo",db)
    out hash2html(ret)

    out br
    ret.each do |row|
        out sBlue(row['repo']) + spc
        ret = sqlite2hash("select * from commits where repo='" + row['repo'] + "' limit 5",db)
        out hash2html(ret) + br

    end
end

def insert_git_log(db)

    GIT_REPOS.each do |repo |
        home = `echo $HOME`.strip
        dir = home + repo
        return unless dir_exist?(dir)
        out dir + br
        Dir.chdir(dir) do

            commits = recent_commits(false)

            # insert
            commits.each do |row|

                # 同じrepo & hashのデータがあればそこで終了
                sql_check = "select * from commits where repo='" + File.basename(repo) + "' and hash='" + row['hash'] + "'"
                ret = sqlite2hash(sql_check, db)
                out br
                if ret.length == 1
                    out sRed('data exist break ') + row.inspect + br
                    break
                end
                sql = "insert into commits
                  (repo , hash , author , message ,commit_date,created_at)
                  values ('" + File.basename(repo) + "','" + row['hash'] + "','" + row['author'].gsub("'", "''") + "','" + row['message'].gsub("'", "''") + "','" + row['date'] + "','" + now_time_str + "') "
                sqlite2hash(sql,db)
            end

            shell = 'git log --numstat  --oneline'
            ret = run_shell(shell)
            rets = ret.split_nl

            commit_details = {}
            hash = ""

            rets.each do |log_line|
                # 10文字の英数 + 空白で始まっていたら
                puts log_line
                if log_line =~ /^([0-9a-f]{7,10})\s/
                    hash = $1
                    out hash + spc
                    commit_details[hash] = {files: 0,adds: 0,dels: 0}

                else
                    # add del filename

                    commit_details[hash][:files] += 1
                    elements = log_line.split(/\s+/)
                    commit_details[hash][:adds] += elements[0].to_i
                    commit_details[hash][:dels] += elements[1].to_i
                end
            end
            out commit_details.inspect
            commit_details.each do |commit_hash,row|
                sql = "update commits set files_ct =" + row[:files].to_s + ",add_line_ct =" + row[:adds].to_s + " , del_line_ct =" + row[:dels].to_s + " where hash='" + commit_hash + "'"
                sqlite2hash(sql,db)
            end

        end
    end

end


def v_repo(p,db)

    limit = 120
    home = `echo $HOME`.strip

    repo = p[:repo]
    view2 = p[:view2] || 'commits'

    Dir.chdir(repo) do
        out s150(sBlue(File.basename(repo))) + spc

        branche_ct = run_shell("git rev-list --count HEAD" , GIT_SHOW_SHELL) #
        out spc +  branche_ct

        repo_start_date = run_shell('git log --reverse --pretty=format:"%ad" --date=short | head -n 1' , GIT_SHOW_SHELL) #
        out spc + repo_start_date

        ["7","100"].each do | days|
            out stat_period_commit_peson(days)
        end

        out a_tag('dir' , "javascript:openFile('" + repo + "')")
    end
    out br

	["commits","stats"].each do | view2_name |
		disp = view2_name
		disp = sRed(disp) if disp == view2
		out a_tag(disp + spc,"?view=repo&view2=" + view2_name+ "&repo=" + URI.encode_www_form_component(repo) )
	end
	out br

    if view2 == 'stats'
            # 月の統計
            repo_month_stats = stats_repo_month(db,repo)
            out hash2html(repo_month_stats) + br
            # ユーザー単位の統計
            author_commit_stats = stats_author(db,repo)
            out hash2html(author_commit_stats)
    end

    if view2 == 'commits'

        Dir.chdir(repo) do
            filter = p[:filter] || ""
            limit = p[:limit] || 2000
            out '<form id="f1" method="get" action="?">'
            out i_hidden("view","repo")
            out i_hidden("repo",repo)
            out 'filter ' + i_text("filter",filter,40) + br
            out 'limit ' + i_text("limit",limit.to_s) + br
            out i_submit_trans
            out '</form>'

            sql = "select author,commit_date,files_ct fi ,add_line_ct ad ,del_line_ct dl,message,hash from commits where repo='" + File.basename(repo) + "' "
            sql += " and (author like '%" + filter + "%' or message like '%" + filter + "%' ) " if filter.length > 0
            sql += "order by commit_date desc limit " + limit.to_s
            recent_logs = sqlite2hash(sql,db)

            commit_records = recent_logs.map do |row|
                row['commit_date'] = Time.parse(row['commit_date']).strftime(TIME_FMT.YYYYMMDDHHIISS)
                row['message'] =color_val(row['message'],filter) if filter.length > 0
                row['author'] = color_val(row['author'],filter) if filter.length > 0
                row
            end
            out hash2html(commit_records)
        end
    end
end


def v_list(p,db)

    home = `echo $HOME`.strip

    out '<div class="flex-container" >'
    htmls = {}

    GIT_REPOS.each do |repo |

        dir = home + repo
        return unless dir_exist?(dir)

        html =  '<div class="flex-item" >'
        html <<  a_tag( s150(sBlueBG(File.basename(repo))) , '?view=repo&repo=' + URI.encode_www_form_component(dir)) + spc

        # トータルコミット数
        ret = sqlite2hash("select min(commit_date) start,count(*) commit_ct from commits where repo='" + File.basename(repo) + "'",db,false)
        html << s150(ret[0]['commit_ct'].to_s)

        # リモート
        remotes = run_shell('git -C ' + dir + ' remote -v' ,false)
        start = ret[0]['start']
        html <<  spc + Time.parse(start).strftime(TIME_FMT.YYYYMM) << spc

        # local branch
        # html <<  br + sBG('local branches ')
        branches = run_shell('git -C ' + dir + ' branch',false) #
        html << branches.strip.nl2br + spc
        # githubのurl
        html <<  a_tag(" site",remotes.split_nl[0].gsub("origin","").gsub("(fetch)","")).strip.gsub('.git','') + br


        # configs = run_shell("git config --list")
        # html <<  br + configs.nl2br.trim_spreadable(30)
        # html <<  br
        html <<  ' - '
        ["7","100"].each do | days|
            html <<  stat_period_commit_peson(days)
        end

        # log
        # recent_logs = recent_commits(LIST_LOG_LIMIT)

        recent_logs = sqlite2hash("select author,commit_date,files_ct fi ,add_line_ct ad ,del_line_ct dl,message,hash
                        from commits where repo='" + File.basename(repo) + "'
                        order by commit_date desc limit " + LIST_LOG_LIMIT.to_s,db,false)

        hashes = recent_logs.map do |row|
            day = Time.parse(row['commit_date'])
            day_str = day.strftime(TIME_FMT.YYMMDD)
            if Time.now - day < 86400 * 1
                day_str = sRed(day_str)
            elsif Time.now - day < 86400 * 3
                day_str = sOrange(day_str)
            elsif Time.now - day > 86400 * 100
                day_str = sSilver(day_str)
            end

            row['commit_date'] = day_str
            row['message'] =row['message'].trim_spreadable(20)
            row['author'] =row['author'].trim_spreadable(15)
            row.delete('hash')

            row
        end
        html <<  hash2html(hashes)



        # html <<  br + sBG("remote branches ")
        # branches = run_shell "git for-each-ref --sort=-committerdate refs/remotes/ --format='%(committerdate:short) %(refname:short)' | head -10"
        # r_branches = branches.split_nl
        # html <<  br
        # r_branches.each do |line|
        #     html <<  line.trim_spreadable(45) + br
        # end

        # html <<  br + sBG("tags ")
        # branches = run_shell "git tag --sort=-creatordate | head -15" #
        # html <<  br + branches.nl2br

        html <<  '</div>'
        htmls[dir] = html
    end
    htmls.each do |key,html2|
        out html2
    end
    out '</div>'


end

def stats_author(db,repo_full_path)

    author_commit_stats = sqlite2hash("select author,count(*) commit_ct,
        min(commit_date) min_year ,
        max(commit_date) max_year
        from commits
        where repo='" + File.basename(repo_full_path) + "'
        group by author
        order by max_year desc
        ",db)

    author_commit_stats

end

def stats_repo_month(db,repo_full_path)

    sql_mon_stat = "select SUBSTR(commit_date, 1, 7) yyyymm,count(*) ct from commits where repo='" + File.basename(repo_full_path) + "' group by SUBSTR(commit_date, 1, 7) "
    stats = sqlite2hash(sql_mon_stat,db)

    min_max = sqlite2hash("select min(SUBSTR(commit_date, 1, 4)) min_year ,
                        max(SUBSTR(commit_date, 1, 4)) max_year
                        from commits where repo='" + File.basename(repo_full_path) + "'",db)
    y_min = min_max[0]['min_year'].to_i
    y_max = min_max[0]['max_year'].to_i
    work_hash = {}
    (y_min..y_max).each do |year|
        work_hash[year.to_s] = {}
        (1..12).each { |mon| work_hash[year.to_s][mon.to_s.rjust(2,'0')] = 0  }
    end
    stats.each do |row|
        ct = row['ct'].to_s
        work_hash[row['yyyymm'][0,4]][row['yyyymm'][5,2]] = ct
    end
    hash = []
    (y_min..y_max).each do |year|
        row = {}
        row['year'] = year.to_s

        (1..12).each { |mon| row[mon.to_s.rjust(2,'0')] = work_hash[year.to_s][mon.to_s.rjust(2,'0')].to_s }
        hash << row
    end
    hash
end





# 現在dir変更してから呼ぶ
def recent_commits(limit = false)

    shell = "git log --oneline --pretty=format:'%an\t%ad\t%h\t%s'  --date=format:'%Y-%m-%d %H:%M:%S' "
    shell += " | head -" + limit.to_s if limit
    logs = run_shell(shell, false)

    hashes = logs.split_nl.map { |line| array2hash(line.split_tab,["author","date","hash","message"]) }
    return hashes
end

def stat_period_commit_peson(days)

    html = ""
    html << sOrange(days + 'd ')
    log_days = run_shell(' git rev-list --count --since="' + days + ' days ago" HEAD ' , GIT_SHOW_SHELL) #
    html << log_days

    log_person_days = run_shell(' git log --since="' + days + ' days ago" --pretty=format:"%aN" | sort | uniq -c | sort -nr | wc -l' , GIT_SHOW_SHELL) #
    html << sSilver('/u') + log_person_days.strip + spc

    # リスト
    # log_person_days_list = run_shell(' git log --since="' + days + ' days ago" --pretty=format:"%aN" | sort | uniq -c | sort -nr ' , GIT_SHOW_SHELL) #
    # html << br + sSilver(' list ') + log_person_days_list.nl2br

    html

end

def create_tables

    " CREATE TABLE repos (
	local_full_path	TEXT,
	repo_name	TEXT,
	remote	TEXT,
	created_at	TEXT,
	PRIMARY KEY(local_full_path)
    );

    CREATE TABLE commits (
        repo   TEXT,
        hash	TEXT,
        author TEXT,
        message TEXT,
        commit_date TEXT,
        files_ct INTEGER,
        add_line_ct INTEGER,
        del_line_ct INTEGER,
        last_view_date	TEXT,
        created_at	TEXT,
        PRIMARY KEY(repo, hash)
    );

    CREATE TABLE key_values (
        key	TEXT NOT NULL UNIQUE,
        value	TEXT
    );"

end

main
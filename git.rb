
# git clone https://github.com/laravel/laravel.git
# git clone https://github.com/EnterpriseQualityCoding/FizzBuzzEnterpriseEdition.git
# git clone https://github.com/facebook/react.git
# git clone https://github.com/electron/electron.git

LIST_LOG_LIMIT = 20
GIT_SHOW_SHELL = false
SQLITE_PATH_GIT = 'files/git3.sql3'

def create_tables

    " CREATE TABLE repos (
	local_full_path	TEXT,
	repo_name	TEXT,
	remote	TEXT,
	created_at	TEXT,
	PRIMARY KEY(local_full_path);

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

def main

    p = $params

    out html_header("git")
    out menu(__FILE__)
    # ----------------------------------------

    db = SQL3.connect_or_create(SQLITE_PATH_GIT,create_tables)
    out SQL3.info(SQLITE_PATH_GIT)
    out br

    view = p[:view] || 'list'

    insert_git_log(db) if view == 'import'

    menus = ["list","import","db_stat","local_repo"]
    menus.each do |v|
        disp = (v == view ? sRed(v) : v)
        out a_tag(disp,'?view=' + v) + spc
    end
    out br

    v_local_repo(db) if view == 'local_repo'
    v_db_stat(db) if view == 'db_stat'
    v_repo(p) if view == 'repo'
    v_list(p) if view == "list"
end

def v_local_repo(db)

        shell ='find ~ -path "./.Trash" -prune -o -maxdepth 7 -type d -name ".git" -print 2>/dev/null'

        ret = run_shell(shell )
        out br
        out ret.nl2br
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
            # git log 3件
            commits = recent_commits(false)
            #out hash2html(commits)

            # insert
            commits.each do |row|
                sql = "insert into commits
                  (repo , hash , author , message ,commit_date,created_at)
                  values ('" + File.basename(repo) + "','" + row['hash'] + "','" + row['author'].gsub("'", "''") + "','" + row['message'].gsub("'", "''") + "','" + row['date'] + "','" + now_time_str + "') "
                sqlite2hash(sql,db)
            end
        end
    end

end


def v_repo(p)

    limit = 120
    home = `echo $HOME`.strip
   p[:repo]

    Dir.chdir(p[:repo]) do
        out s150(sBlue(p[:repo])) + spc

        branche_ct = run_shell("git rev-list --count HEAD" , GIT_SHOW_SHELL) #
        out spc +  branche_ct

        repo_start_date = run_shell('git log --reverse --pretty=format:"%ad" --date=short | head -n 1' , GIT_SHOW_SHELL) #
        out spc +  repo_start_date

        ["7","100"].each do | days|
            out stat_period_commit_peson(days)
        end

        commits = recent_commits(limit)
        commit_records = commits.map do |row|
            row['date'] = Time.parse(row['date']).strftime(TIME_FMT.YYYYMMDDHHIISS)
            row['message'] =row['message'].trim_spreadable(70)
            row['author'] =row['author'].trim_spreadable(15)
            row
        end
        out hash2html_nohead(commit_records)
    end
end


def v_list(p)

    home = `echo $HOME`.strip

    out '<div class="flex-container" >'
    htmls = {}

    GIT_REPOS.each do |repo |

        dir = home + repo
        return unless dir_exist?(dir)

        html = ''
        Dir.chdir(dir) do

            html <<  '<div class="flex-item" >'

            html <<  a_tag( s150(sBlueBG(File.basename(repo))) , '?view=repo&repo=' + URI.encode_www_form_component(dir))

            remotes = run_shell("git remote -v" ,false)


            # 開始日
            repo_start_date = run_shell('git log --reverse --pretty=format:"%ad" --date=short | head -n 1' , GIT_SHOW_SHELL) #
            start = Time.parse(repo_start_date)
            years = ((Time.now - start) / (86400.0 * 365.0)).round(2).to_s
            html <<  years + sSilver('years')
            html <<  spc + start.strftime(TIME_FMT.YYYYMM)
            html <<  spc

            html <<  a_tag(" site",remotes.split_nl[0].gsub("origin","").gsub("(fetch)","")).strip + br

            # configs = run_shell("git config --list")
            # html <<  br + configs.nl2br.trim_spreadable(30)
            # html <<  br

            html <<  sBG("commits ")
            branche_ct = run_shell("git rev-list --count HEAD" , GIT_SHOW_SHELL) #
            html <<  spc +  branche_ct



            html <<  ' - '
            ["7","100"].each do | days|
                html <<  stat_period_commit_peson(days)
            end

            # log
            recent_logs = recent_commits(LIST_LOG_LIMIT)
            hashes = recent_logs.map do |row|
                day = Time.parse(row['date'])
                day_str = day.strftime(TIME_FMT.YYMMDD)
                if Time.now - day < 86400 * 1
                    day_str = sRed(day_str)
                elsif Time.now - day < 86400 * 3
                    day_str = sOrange(day_str)
                elsif Time.now - day > 86400 * 100
                    day_str = sSilver(day_str)
                end

                row['date'] = day_str
                row['message'] =row['message'].trim_spreadable(20)
                row['author'] =row['author'].trim_spreadable(15)
                row.delete('hash')

                row
            end
            html <<  hash2html_nohead(hashes)

            html <<  br + sBG("local branches ")
            branches = run_shell("git branch",false) #
            html <<  br + branches.nl2br

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
        end
        html <<  '</div>'
        htmls[dir] = html
    end
    htmls.each do |key,html2|
        out html2
    end
    out '</div>'


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


main

# git clone https://github.com/laravel/laravel.git
# git clone https://github.com/EnterpriseQualityCoding/FizzBuzzEnterpriseEdition.git
# git clone https://github.com/facebook/react.git
# git clone https://github.com/electron/electron.git

LIST_LOG_LIMIT = 20

GIT_SHOW_SHELL = false

def main

    p = $params

    out html_header("git")
    out menu(__FILE__)
    # ----------------------------------------


    view = p[:view] || 'list'

    menus = ["list","repo"]
    menus.each do |v|
        disp = (v == view ? sRed(v) : v)
        out a_tag(disp,'?view=' + v) + spc
    end
    out br

    v_repo(p) if view == 'repo'
    v_list(p) if view == "list"
end




def v_repo(p)

    limit = 40
    home = `echo $HOME`.strip
   p[:repo]

    Dir.chdir(p[:repo]) do
        out p[:repo] + spc

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
            row['desc'] =row['desc'].trim_spreadable(70)
            row['author'] =row['author'].trim_spreadable(15)
            row
        end
         out hash2html_nohead(commit_records)
    end
end


def v_list(p)

    home = `echo $HOME`.strip

    out '<div class="flex-container" >'

    GIT_REPOS.each do |repo |

        dir = home + repo
        return unless dir_exist?(dir)
        Dir.chdir(dir) do

            out '<div class="flex-item" >'

            out a_tag(sBlueBG(repo), '?view=repo&repo=' + URI.encode_www_form_component(dir))

            remotes = run_shell("git remote -v" ,false)
            # out br + remotes.nl2br
            # out br
            out a_tag(" site",remotes.split_nl[0].gsub("origin","").gsub("(fetch)","")).strip + br
            configs = run_shell("git config --list")
            out br + configs.nl2br.trim_spreadable(30)
            out br

            out sBG("commits ")
            branche_ct = run_shell("git rev-list --count HEAD" , GIT_SHOW_SHELL) #
            out spc +  branche_ct

            repo_start_date = run_shell('git log --reverse --pretty=format:"%ad" --date=short | head -n 1' , GIT_SHOW_SHELL) #
            out spc +  repo_start_date

            out ' - '
            ["7","100"].each do | days|
                out stat_period_commit_peson(days)
            end



            # log
            recent_logs = recent_commits(LIST_LOG_LIMIT)
            hashes = recent_logs.map do |row|
                row['date'] = Time.parse(row['date']).strftime(TIME_FMT.YYMMDD)
                row['desc'] =row['desc'].trim_spreadable(20)
                row['author'] =row['author'].trim_spreadable(15)
                row
            end
            out hash2html_nohead(hashes)

            out br + sBG("local branches ")
            branches = run_shell "git branch" #
            out br + branches.nl2br

            out br + sBG("remote branches ")
            branches = run_shell "git for-each-ref --sort=-committerdate refs/remotes/ --format='%(committerdate:short) %(refname:short)' | head -10" # git branch -r
            r_branches = branches.split_nl
            out br
            r_branches.each do |line|
                out line.trim_spreadable(45) + br
            end

            out br + sBG("tags ")
            branches = run_shell "git tag --sort=-creatordate | head -15" #
            out br + branches.nl2br

        end
        out '</div>'
    end
    out '</div>'


end




# 現在dir変更してから呼ぶ
def recent_commits(limit)

    logs = run_shell("git log --oneline --pretty=format:'%an\t%ad\t%h\t%s'  --date=format:'%Y-%m-%d %H:%M:%S' | head -" + limit.to_s, false)

    hashes = logs.split_nl.map { |line| array2hash(line.split_tab,["author","date","hash","desc"]) }
    return hashes
end

def stat_period_commit_peson(days)

    html = ""
    html << sOrange(days + 'day ')
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
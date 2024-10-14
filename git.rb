
# git clone https://github.com/laravel/laravel.git
# git clone https://github.com/EnterpriseQualityCoding/FizzBuzzEnterpriseEdition.git
# git clone https://github.com/facebook/react.git
# git clone https://github.com/electron/electron.git

p = params = $params

out html_header("git")
out menu(__FILE__)
# ----------------------------------------
repos = ["/git_test/react",
        "/git_test/laravel",
        "/git_test/electron",
        "/git_test/FizzBuzzEnterpriseEdition"
]

home = `echo $HOME`.strip

out '<div class="flex-container" >'


repos.each do |repo |

    dir = home + repo


    return unless dir_exist?(dir)
    Dir.chdir(dir) do

        out '<div class="flex-item" >'

        out sBlueBG(repo)
        out '<i class="material-icons">person</i>'


        remotes = run_shell("git remote -v")
        # out br + remotes.nl2br
        # out br
        out a_tag(" url",remotes.split_nl[0].gsub("origin","").gsub("(fetch)","")).strip + br
        configs = run_shell("git config --list")
        out br + configs.nl2br.trim_spreadable(30)
        out br

        out sBG("commits ")
        branches = run_shell "git rev-list --count HEAD" #
        out br + branches.nl2br

        logs = run_shell "git log --oneline --pretty=format:'%an\t%ad\t%h\t%s' --date=short | head -10" # --stat --oneline
        #logs = run_shell "git log --oneline --pretty=format:'%an\t%ad\t%h' --date=short | head -20" #
        hashes = logs.split_nl.map { |row| array2hash(row.split_tab,["author","date","hash","desc"]) }
        mashes = hashes.map do |row|
            row['desc'] =row['desc'].trim_spreadable(20)
            row['author'] =row['author'].trim_spreadable(15)
        end
        out br + hash2html(hashes)

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
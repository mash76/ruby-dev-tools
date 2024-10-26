
class Grep
    SQLITE_PATH_GIT_GREP = File.expand_path("files/git.sql3")
    GREP_SHELL_SHOW = false

    def preview_form

        '<div id="diff_preview" style="
                    font-size:70%;
                    position:fixed; top:20px;left:900px; width:600px; height:800px;
                    padding: 15px; background:#fff; border-radius:10px;
                    border: 1px solid #d0d0d0;
                    opacity: 0.9;
                    vertical-align:top;
        "></div>
        <script>
            $(document).ready(function(){
                $(document).on("mouseover", "a[preview]", function(event) {
                    event.preventDefault();
                    r_path =  $(event.target).attr("r_path")
                    repo =  $(event.target).attr("repo")
                    url = "?ajax=preview&repo=" + repo + "&r_path=" + r_path
                    $.get(url,(data)=> {
                        console.log(data)
                        $("#diff_preview").html(data)
                    })
                })
                $(document).on("click", "div#diff_preview", function(event) {
                    $("#diff_preview").hide()
                })

                $(window).resize(() => {
                    moveWin()
                })
                function moveWin(){
                    let width = $(window).width()
                    $("#diff_preview").css("left",width - 620)
                }
                moveWin()
            })
        </script> '
    end


    def ajax_grep(p)
        return unless p[:ajax]

        if p[:ajax] == 'preview'
            repo = p[:repo] || ''
            r_path = p[:r_path] || ''
            data = File.read(repo + r_path) ####
            out '<pre>' + ENC.html(data) + '</pre>'
            return true
        end

    end

    def main

        p =  $params

        ajax_result = ajax_grep(p)
        return if ajax_result

        out html_header("grep")
        out '<script>' + File.read("_form_events.js") + '</script>'
        out menu(__FILE__)
        # ----------------------------------------

        out preview_form

        path = p[:path] || GREP_PATHS[0]['path']
        path_id = 0
        GREP_PATHS.each_with_index do | hash,index |
            name = File.basename(hash['path'])
            disp = (hash['path'] == path) ? sRed(name) : name
            out a_tag(disp , "?path=" + ENC.url(hash['path'])) + spc
            path_id = index if hash['path'] == path
        end
        out br
        out s150(sBlue(File.basename(path))) + spc + sSilver(path) + br

        filter = p[:filter].to_s
        exclude = p[:exclude] || GREP_PATHS[path_id]['exclude']
        days = p[:days] || ""
        fsize = p[:fsize] || ''

        db = SQL3.connect_or_create(SQLITE_PATH_GIT_GREP,create_tables)


        ext_stat_hash = ext_stat(path,filter, exclude)
        ext_stat_hash.each do | key , val |
            next if !key || key ==""
            out a_tag(key + sSilver(val.to_s), "javascript:setVal('filter','" + key + "')")
        end
        out br
        ['packages','fixtures','scripts','compiler'].each do | key , val |
            next if !key || key ==""
            out a_tag(key + sSilver(val.to_s), "javascript:setVal('filter','" + key + "')")
        end
        out br

        # form
        out '<form id="f1" method="post" action="?">'
        out i_hidden("path",path)
        out 'filter ' + i_text("filter",filter,40) + br
        out 'exclude ' + i_text("exclude",exclude,50) + br
        out 'days ' + i_text("days",days) + spc + sSilver('days ')
        [1,3,5,10,20].each { |day| out a_tag(day.to_s, "javascript:setVal('days','" + day.to_s + "')") }
        out br
        out 'fsize ' + i_text("fsize",fsize) + spc + sSilver('size')
        ["-100","-1000","+5000","+10000","+50000"].each { |s| out a_tag(s, "javascript:setVal('fsize','" + s + "')") }
        out br
        out i_submit_trans "検索"

        out "</form><hr/>"

        #search
        shell = 'find "' + path + '" -type f '
        shell += ' -mtime -' + days if days.length > 0
        shell += ' -size ' + fsize + 'c ' if fsize.length > 0 # sizeを2回使用したら 上限下限できる
        filters = filter.strip.split(/\s+/)
        names = []
        filters.each do |f|
          # names << ' -path "*' + ENC.re(f) + '*"' if f.length > 0 #フルパスに対して()
           names << ' -name "*' + ENC.re(f) + '*"' if f.length > 0 # ファイル名のみに対して
        end
        shell += names.join('  ')
        shell += ' | sed s@' + ENC.re(path) + '@@g ' # rootパスまでを除去

        filters.each do |f|
            shell += ' | grep -i "' + ENC.re(f) + '"' if f.length > 0 # フルパスに対して
        end

        excludes = exclude.strip.split(/\s+/)
        excludes.each do |e|
            shell += ' | grep -iv "' + ENC.re(e) + '"' if e.length > 0
        end

        files_str = run_shell(shell ,200)
        files = files_str.split_nl
        out br

        out '<table><tr><td valign=top >'
        out top_dir_files(path)
        out '</td><td valign=top >'
        out dir_stats(files,path)
        out '</td><td valign=top >'

        # file_filtered = files.select { |line| line.include?(filter) }
        ct = 1
        records = []
        files.each do |line|
            fullpath = path + line
            stat = File.stat(fullpath)
            dir = File.dirname(line)
            mtime = stat.mtime.strftime(TIME_FMT.YYYYMMDDHHIISS)
            trimed = line
            trimed = trimed.gsub(dir,sGray2(dir))
            filters.each do |f|
                re = Regexp.new('(' + Regexp.escape(f) + ')',Regexp::IGNORECASE)
                trimed = trimed.gsub(re,sRed('\1'))
            end
            size_str = (stat.size / 1024.0).ceil(1).to_s + sSilver('k')
            atag = '<a preview repo="' + path + '" r_path="' + line + '" >' + trimed + '</a>'
            records << {  mtime: sSilver(mtime), size: size_str , path: atag }
             ct += 1
        end
        out hash2html(records)

        out '</td></tr></table>'

    end

    def top_dir_files(path)

        html = ''
        shell = 'find "' + path + '" -type f -maxdepth 1'
        top_files = run_shell(shell,false).split_nl
        html << sBG('root') + br
        top_files.each do |line|
            html << line.gsub(path,'') + (spc * 3) + br
        end
        html
    end

    # dirの階層を深さ1と2で中身のファイル数をまとめる
    def dir_stats(files,root_path)

        html = sBG('dir') + br
        # フォルダ数をrootから2階層まで　カウント
        dep1 = Hash.new(0)
        dep2 = Hash.new(0)
        files.each do |line|
            line = line.gsub(root_path,'') # パスのもとフォルダ部分を除去
            dir_d1 = line.split('/')[1]
            dir_d2 = line.split('/')[1..2].join('/')
            dep1[dir_d1] += 1
            dep2[dir_d2] += 1
        end
        dep2.each do |k,v|
            dep1[k] = v
        end
        dep1.reject! { |dir,ct| File.file?(root_path + '/' + dir) }
        html << hash2html_nohead(hash2records(dep1))
        html

    end

    def ext_stat( path, filter, exclude )

        out sBlue('ext ')

        shell = 'find "' + path + '" -type f '
        excludes = exclude.split(/\s+/)
        excludes.each do |word|
            shell += ' | grep -iv "' + ENC.re(word) + '"' if word.length > 0
        end

        files_str = run_shell(shell ,GREP_SHELL_SHOW)
        files = files_str.split_nl
        stat = {}
        files.each do |line|
            ext =File.extname(line)
            stat[ext] = 0 unless stat.key?(ext)
            stat[ext] += 1
        end
        stat = stat.sort_by { |key, value| -1 * value }.to_h
        stat
    end

    def create_tables

    end
end
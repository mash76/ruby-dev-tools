SQLITE_PATH_GREP = File.expand_path("files/grep.sql3")
GREP_SHELL_SHOW = false

def create_tables
    "CREATE TABLE key_values (
        key	TEXT NOT NULL UNIQUE,
        value	TEXT
    );"
end

def main

    p =  $params

    out html_header("grep")
    out '<script>' + File.read("_form_events.js") + '</script>'
    out menu(__FILE__)
    # ----------------------------------------

    path = p[:path] || GREP_PATHS[0]['path']
    path_id = 0
    GREP_PATHS.each_with_index do | hash,index |
        out a_tag(File.basename(hash['path']) , "?path=" + ENC.url(hash['path'])) + spc
        path_id = index if hash['path'] == path
    end
    out br
    out s150(sBlue(File.basename(path))) + spc + sSilver(path) + br

    filter = p[:filter].to_s
    exclude = p[:exclude] || GREP_PATHS[path_id]['exclude']
    recent = p[:recent] || ""
    fsize = p[:fsize] || ''

    db = SQL3.connect_or_create(SQLITE_PATH_GREP,create_tables)

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
    out 'filter ' + i_text("filter",filter,30) + br
    out 'exclude ' + i_text("exclude",exclude,30) + br
    out 'recent ' + i_text("recent",recent) + spc + sSilver('days ')
    [1,3,5,10,20].each { |day| out a_tag(day.to_s, "javascript:setVal('recent','" + day.to_s + "')") }
    out br
    out 'fsize ' + i_text("fsize",fsize) + spc + sSilver('size')
    ["-100","-1000","+5000","+10000","+50000"].each { |s| out a_tag(s, "javascript:setVal('fsize','" + s + "')") }
    out br
    out i_submit_trans "検索"

    out "</form><hr/>"

    #search
    shell = 'find "' + path + '" -type f '
    shell += ' -mtime -' + recent if recent.length > 0
    shell += ' -size ' + fsize + 'c ' if fsize.length > 0 # sizeを2回使用したら 上限下限できる
    shell += ' | grep -i "' + ENC.re(filter) + '"' if filter.length > 0
    excludes = exclude.split(/\s+/)
    excludes.each do |word|
        shell += ' | grep -iv "' + ENC.re(word) + '"' if word.length > 0
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
    pattern = Regexp.new('(' + Regexp.escape(filter) + ')',Regexp::IGNORECASE)
    ct = 1
    records = []
    files.each do |line|
        stat = File.stat(line)
        mtime = stat.mtime.strftime(TIME_FMT.YYYYMMDDHHIISS)
        records << { path: line.gsub(path,"").gsub(pattern,sRed('\1')) , mtime: sSilver(mtime), size: (stat.size / 1024.0).round(1).to_s + sSilver('k')}
        ct += 1
    end
    out hash2html(records)

    out '</td></tr></table>'

end

def top_dir_files(path)

    html = ''
    shell = 'find "' + path + '" -type f -maxdepth 1'
    top_files = run_shell(shell,false).split_nl
    html << sBG('rootdir files') + br
    top_files.each do |line|
        html << line.gsub(path,'') + (spc * 3) + br
    end
    html
end


def dir_stats(files,path)

    html = sBG('dir files') + br
    # フォルダ数をrootから2階層まで　カウント
    folder_count = Hash.new(0)
    files.each do |line|

        trimed = line.gsub(path,'') # もとフォルダを除去
        trimed2 = trimed.split('/')[1..2].join('/')
        next unless trimed2.include?('/')
        next if File.file?(path + trimed2)
        folder_count[trimed2] += 1
    end
    html << hash2html_nohead(hash2records(folder_count))
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

main
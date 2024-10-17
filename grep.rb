SQLITE_PATH_GREP = File.expand_path("files/grep.sql3")

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


    path = p[:path] || GREP_PATHS[0]
    GREP_PATHS.each do | path |
        out a_tag(File.basename(path) , "?path=" + URI.encode_www_form_component(path)) + spc
    end
    out br

    out s150(sBlue(path)) + br


    filter = p[:filter].to_s
    exclude = p[:exclude] || ".git"
    recent = p[:recent] || ""

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
    out i_text("filter",filter) + br

    out 'exclude ' + i_text("exclude",exclude) + br
    out 'recent ' + i_text("recent",recent) + br
    out i_submit_trans "検索"
    out "</form><hr/>"

    #search
    shell = 'find "' + path + '" -type f '
    shell += ' -mtime -' + recent if recent.length > 0
    shell += ' | grep -i "' + Regexp.escape(filter) + '"' if filter.length > 0
    shell += ' | grep -iv "' + Regexp.escape(exclude) + '"' if exclude.length > 0

    files_str = run_shell(shell )
    files2 = files_str.split_nl
    out br

    # file_filtered = files.select { |line| line.include?(filter) }
    pattern = Regexp.new("(" + Regexp.escape(filter) + ")",Regexp::IGNORECASE)
    ct = 1
    files2.each do |line|
        out ct.to_s + spc + line.gsub(path,"").gsub(pattern,sRed('\1')) + br
        ct += 1
    end
end

def ext_stat( path, filter, exclude )

    out sBlue('extention stat') + br

    shell = 'find "' + path + '" -type f '
    shell += ' | grep  "' + exclude + '"' if exclude.length > 0
    files_str = run_shell(shell ,false)
    files = files_str.split_nl
    stat = {}
    files.each do |line|
        ext =File.extname(line)
        stat[ext] = 0 unless stat.key?(ext)
        stat[ext] += 1
    end
    stat
end


main

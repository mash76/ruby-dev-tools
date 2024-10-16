SQLITE_PATH_GREP = File.expand_path("files/grep.sql3")

def main
    p =  $params
    db = SQL3.connect_or_create(SQLITE_PATH_GREP,'')


    out html_header("grep")
    out '<script>' + File.read("_form_events.js") + '</script>'
    out menu(__FILE__)
    # ----------------------------------------

    home = File.expand_path("~/git_test")
    grep_path = File.expand_path("~/git_test/FizzBuzzEnterpriseEdition")

    filter = p[:filter].to_s
    exclude = p[:exclude] || ".git"

    # form
    out '<form id="f1" method="post" action="?">'
    out i_text("filter",filter) + br
    out 'exclude ' + i_text("exclude",exclude) + br
    out i_submit_trans "検索"
    out "</form><hr/>"

    #search
    shell = 'find "' + grep_path + '" -type f '
    shell += ' | grep  "' + exclude + '"' if exclude.length > 0
    files_str = run_shell(shell )
    files = files_str.split_nl
    out br


    file_filtered = files.select { |line| line.include?(filter) }

    out file_filtered.length.to_s + br
    pattern = Regexp.new("(" + Regexp.escape(filter) + ")",Regexp::IGNORECASE)
    file_filtered.each do |line|
        out line.gsub(grep_path,"").gsub(pattern,sRed('\1')) + br
    end
end


main
